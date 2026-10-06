package moderation

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"mime/multipart"
	"net/http"
	"os"
	"strings"
	"time"
)

// ImageProvider — classifier-и NSFW.
//
// Score — 0..1 (эҳтимоли мӯҳтавои ҷинсӣ/урён), cats — категорияҳо.
type ImageProvider interface {
	Name() string
	Classify(ctx context.Context, data []byte, mime string) (score float64, cats []string, err error)
}

// providerClient — бе пайгирии redirect: provider набояд серверро
// ба суроғаи дигар фиристад.
var providerClient = &http.Client{
	Timeout: 25 * time.Second,
	CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	},
}

func env(k string) string { return strings.TrimSpace(os.Getenv(k)) }

// imageProvider — provider аз env. nil — ҳеҷ кадом танзим нашудааст.
//
// MODERATION_IMAGE_PROVIDER (hf | sightengine | openai | none) интихобро
// маҷбур мекунад; холӣ — аввалин танзимшуда бо ҳамин тартиб.
func imageProvider() ImageProvider {
	pref := strings.ToLower(env("MODERATION_IMAGE_PROVIDER"))
	hf := func() ImageProvider {
		u := env("MODERATION_IMAGE_URL")
		tok := env("HF_TOKEN")
		if u == "" && tok == "" {
			return nil
		}
		if u == "" {
			u = "https://router.huggingface.co/hf-inference/models/Falconsai/nsfw_image_detection"
		}
		return hfProvider{url: u, token: tok}
	}
	se := func() ImageProvider {
		u, s := env("SIGHTENGINE_USER"), env("SIGHTENGINE_SECRET")
		if u == "" || s == "" {
			return nil
		}
		url := env("MODERATION_SIGHTENGINE_URL")
		if url == "" {
			url = "https://api.sightengine.com/1.0/check.json"
		}
		return sightengineProvider{url: url, user: u, secret: s}
	}
	oa := func() ImageProvider {
		k := env("OPENAI_API_KEY")
		if k == "" {
			return nil
		}
		url := env("MODERATION_OPENAI_URL")
		if url == "" {
			url = "https://api.openai.com/v1/moderations"
		}
		return openAIProvider{url: url, key: k}
	}
	switch pref {
	case "none", "off":
		return nil
	case "hf", "huggingface":
		return hf()
	case "sightengine":
		return se()
	case "openai":
		return oa()
	}
	for _, f := range []func() ImageProvider{hf, se, oa} {
		if p := f(); p != nil {
			return p
		}
	}
	return nil
}

// ImageProviderConfigured — оё расм санҷида мешавад?
func ImageProviderConfigured() bool { return imageProvider() != nil }

func maxImageBytes() int64 { return int64(envInt("MODERATION_IMAGE_MAX_MB", 15)) << 20 }

// unscanned — provider нест: иҷозат + навбати admin.
func unscanned(reason string) Verdict {
	return Verdict{Action: Review, Unscanned: true, Categories: []string{CatUnscanned},
		Provider: "none", Reason: reason, MediaCaused: true}
}

// uncertain — санҷидан нашуд ё хол норавшан: пинҳон то тасдиқи admin.
func uncertain(provider, reason string, score float64) Verdict {
	return Verdict{Action: Review, Categories: []string{CatUncertain}, Score: score,
		Provider: provider, Reason: reason, MediaCaused: true}
}

// CheckImageBytes — расм дар хотира (масалан ҳангоми боргузорӣ).
func CheckImageBytes(ctx context.Context, data []byte) Verdict {
	p := imageProvider()
	if p == nil {
		return unscanned("no_image_provider")
	}
	return classify(ctx, p, data)
}

func classify(ctx context.Context, p ImageProvider, data []byte) Verdict {
	if len(data) == 0 {
		return uncertain(p.Name(), "empty", 0)
	}
	if int64(len(data)) > maxImageBytes() {
		return uncertain(p.Name(), "too_large", 0)
	}
	mime := http.DetectContentType(data)
	if !strings.HasPrefix(mime, "image/") {
		return uncertain(p.Name(), "not_image:"+mime, 0)
	}
	cctx, cancel := timeoutCtx(ctx, 25*time.Second)
	defer cancel()
	score, cats, err := p.Classify(cctx, data, mime)
	if err != nil {
		log.Printf("[moderation] %s: санҷиши расм ноком (%v) — то санҷиши admin пинҳон", p.Name(), err)
		return uncertain(p.Name(), "provider_error", 0)
	}
	if hasCat(cats, CatMinors) {
		return Verdict{Action: Block, Categories: mergeCats([]string{CatMinors, CatNudity}, cats),
			Score: score, Severe: true, Provider: p.Name(), Reason: "minors", MediaCaused: true}
	}
	switch {
	case score >= BlockThreshold():
		return Verdict{Action: Block, Categories: mergeCats([]string{CatNudity}, cats),
			Score: score, Provider: p.Name(), Reason: fmt.Sprintf("score=%.2f", score), MediaCaused: true}
	case score >= ReviewThreshold():
		return uncertain(p.Name(), fmt.Sprintf("score=%.2f", score), score)
	}
	return Verdict{Action: Allow, Score: score, Provider: p.Name(), MediaCaused: true}
}

func hasCat(cats []string, c string) bool {
	for _, x := range cats {
		if x == c {
			return true
		}
	}
	return false
}

// ── гирифтани медиа танҳо аз анбори худи мо ────────────────────────

var errForeignHost = errors.New("media host not allowed")

// fetchClient — бе redirect (анбор набояд моро ба ҷои дигар фиристад).
var fetchClient = &http.Client{
	Timeout: 60 * time.Second,
	CheckRedirect: func(*http.Request, []*http.Request) error {
		return http.ErrUseLastResponse
	},
}

// openMedia — ҷавоби HTTP барои суроғаи анбори худи мо.
func openMedia(ctx context.Context, raw string) (*http.Response, error) {
	if !MediaFetchAllowed(raw) {
		return nil, errForeignHost
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, raw, nil)
	if err != nil {
		return nil, err
	}
	resp, err := fetchClient.Do(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		resp.Body.Close()
		return nil, fmt.Errorf("status %d", resp.StatusCode)
	}
	return resp, nil
}

func fetchBytes(ctx context.Context, raw string, max int64) ([]byte, error) {
	resp, err := openMedia(ctx, raw)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	data, err := io.ReadAll(io.LimitReader(resp.Body, max+1))
	if err != nil {
		return nil, err
	}
	if int64(len(data)) > max {
		return nil, errors.New("too large")
	}
	return data, nil
}

// CheckImageURL — расм аз анбори худи мо.
func CheckImageURL(ctx context.Context, raw string) Verdict {
	p := imageProvider()
	if p == nil {
		return unscanned("no_image_provider")
	}
	if strings.TrimSpace(raw) == "" {
		return Verdict{Action: Allow}
	}
	cctx, cancel := timeoutCtx(ctx, 15*time.Second)
	defer cancel()
	data, err := fetchBytes(cctx, raw, maxImageBytes())
	if err != nil {
		if errors.Is(err, errForeignHost) {
			// Суроғаи бегона — сервер онро намекушояд (SSRF).
			return uncertain(p.Name(), "foreign_host", 0)
		}
		log.Printf("[moderation] расм гирифта нашуд: %v", err)
		return uncertain(p.Name(), "fetch_failed", 0)
	}
	return classify(ctx, p, data)
}

// ── Hugging Face Inference ─────────────────────────────────────────
//
// Модели image-classification (пешфарз Falconsai/nsfw_image_detection):
// ҷавоб [{"label":"nsfw","score":0.98},{"label":"normal","score":0.02}].
// Моделҳои дигар («porn», «hentai», «sexy», «neutral») ҳам фаҳмида
// мешаванд.

type hfProvider struct{ url, token string }

func (hfProvider) Name() string { return "huggingface" }

func (p hfProvider) Classify(ctx context.Context, data []byte, mime string) (float64, []string, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.url, bytes.NewReader(data))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", mime)
	req.Header.Set("x-wait-for-model", "true")
	if p.token != "" {
		req.Header.Set("Authorization", "Bearer "+p.token)
	}
	resp, err := providerClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return 0, nil, fmt.Errorf("huggingface HTTP %d", resp.StatusCode)
	}
	return parseHF(body)
}

type hfLabel struct {
	Label string  `json:"label"`
	Score float64 `json:"score"`
}

func parseHF(body []byte) (float64, []string, error) {
	var flat []hfLabel
	if err := json.Unmarshal(body, &flat); err != nil {
		var nested [][]hfLabel
		if err2 := json.Unmarshal(body, &nested); err2 != nil || len(nested) == 0 {
			return 0, nil, fmt.Errorf("huggingface: unexpected response")
		}
		flat = nested[0]
	}
	if len(flat) == 0 {
		return 0, nil, fmt.Errorf("huggingface: empty response")
	}
	score := 0.0
	for _, l := range flat {
		s := 0.0
		switch strings.ToLower(strings.TrimSpace(l.Label)) {
		case "nsfw", "porn", "pornography", "hentai", "explicit", "sexual", "unsafe", "nude", "nudity":
			s = l.Score
		case "sexy", "suggestive":
			s = l.Score * 0.6
		}
		if s > score {
			score = s
		}
	}
	return score, []string{CatNudity}, nil
}

// ── Sightengine (nudity-2.1) ───────────────────────────────────────

type sightengineProvider struct{ url, user, secret string }

func (sightengineProvider) Name() string { return "sightengine" }

func (p sightengineProvider) Classify(ctx context.Context, data []byte, mime string) (float64, []string, error) {
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	w.WriteField("models", "nudity-2.1")
	w.WriteField("api_user", p.user)
	w.WriteField("api_secret", p.secret)
	ext := ".jpg"
	if i := strings.Index(mime, "/"); i >= 0 {
		ext = "." + mime[i+1:]
	}
	fw, err := w.CreateFormFile("media", "image"+ext)
	if err != nil {
		return 0, nil, err
	}
	fw.Write(data)
	w.Close()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.url, &buf)
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", w.FormDataContentType())
	resp, err := providerClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return 0, nil, fmt.Errorf("sightengine HTTP %d", resp.StatusCode)
	}
	return parseSightengine(body)
}

func parseSightengine(body []byte) (float64, []string, error) {
	var out struct {
		Status string `json:"status"`
		Nudity struct {
			SexualActivity float64 `json:"sexual_activity"`
			SexualDisplay  float64 `json:"sexual_display"`
			Erotica        float64 `json:"erotica"`
			VerySuggestive float64 `json:"very_suggestive"`
			// nudity-2.0 (кӯҳна)
			Raw     float64 `json:"raw"`
			Partial float64 `json:"partial"`
		} `json:"nudity"`
		Error struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	if err := json.Unmarshal(body, &out); err != nil {
		return 0, nil, fmt.Errorf("sightengine: unexpected response")
	}
	if out.Status != "success" {
		return 0, nil, fmt.Errorf("sightengine: status %q", out.Status)
	}
	n := out.Nudity
	score := max(n.SexualActivity, n.SexualDisplay, n.Erotica, n.Raw, n.VerySuggestive*0.7, n.Partial*0.6)
	return score, []string{CatNudity}, nil
}

// ── OpenAI omni-moderation (расм) ──────────────────────────────────
//
// Расм ҳамчун data: URL фиристода мешавад — OpenAI ба анбори мо
// дархост намекунад.

type openAIProvider struct{ url, key string }

func (openAIProvider) Name() string { return "openai" }

func (p openAIProvider) Classify(ctx context.Context, data []byte, mime string) (float64, []string, error) {
	payload, _ := json.Marshal(map[string]any{
		"model": "omni-moderation-latest",
		"input": []map[string]any{{
			"type":      "image_url",
			"image_url": map[string]string{"url": "data:" + mime + ";base64," + base64.StdEncoding.EncodeToString(data)},
		}},
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, p.url, bytes.NewReader(payload))
	if err != nil {
		return 0, nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+p.key)
	resp, err := providerClient.Do(req)
	if err != nil {
		return 0, nil, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		return 0, nil, fmt.Errorf("openai moderation HTTP %d", resp.StatusCode)
	}
	return parseOpenAIModeration(body)
}

func parseOpenAIModeration(body []byte) (float64, []string, error) {
	var out struct {
		Results []struct {
			Categories     map[string]bool    `json:"categories"`
			CategoryScores map[string]float64 `json:"category_scores"`
		} `json:"results"`
	}
	if err := json.Unmarshal(body, &out); err != nil || len(out.Results) == 0 {
		return 0, nil, fmt.Errorf("openai moderation: unexpected response")
	}
	r := out.Results[0]
	score := max(r.CategoryScores["sexual"], r.CategoryScores["sexual/minors"])
	cats := []string{CatNudity}
	if r.Categories["sexual/minors"] {
		cats = append(cats, CatMinors)
	}
	return score, cats, nil
}
