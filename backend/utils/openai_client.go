package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"raonson/ai"
)

// ── OpenAI integration ─────────────────────────────────────────────
// Калиди API ФАҚАТ аз env меояд (OPENAI_API_KEY, дар Render/HF Space
// ҳамчун SECRET). Ҳаргиз дар код нанависед.

const openAIBaseURL = "https://api.openai.com/v1"

var httpClient = &http.Client{Timeout: 25 * time.Second}

func openAIKey() string { return os.Getenv("OPENAI_API_KEY") }

// OpenAIEnabled — оё ягон provider-и LLM танзим шудааст?
//
// Пештар ин танҳо OPENAI_API_KEY-ро месанҷид, бинобар ин хэштег,
// тарҷума ва холи сифат бе калиди ПУЛАКӢ умуман кор намекарданд.
// Ҳоло ҳар provider-и OpenAI-compatible (аз ҷумла ройгон) кофист.
func OpenAIEnabled() bool { return ai.Enabled(ai.TaskFast) }

// hasOpenAIModeration — endpoint-и /moderations танҳо дар OpenAI ҳаст.
// Provider-ҳои дигар онро надоранд, бинобар ин модератсия роҳи
// дигар мегирад (ниг. ModerateText).
func hasOpenAIModeration() bool { return openAIKey() != "" }

func openAIModel() string {
	if m := os.Getenv("OPENAI_MODEL"); m != "" {
		return m
	}
	return "gpt-4o-mini"
}

// openAIRequest дархостро ба provider-и танзимшуда мефиристад.
//
// /chat/completions ба ҳар provider-и OpenAI-compatible меравад;
// /moderations танҳо ба OpenAI, зеро дигарон онро надоранд.
func openAIRequest(ctx context.Context, path string, body any, out any) error {
	key, url := openAIKey(), openAIBaseURL+path
	if path == "/chat/completions" {
		cfg := ai.ConfigFor(ai.TaskFast)
		if cfg.APIKey != "" {
			key, url = cfg.APIKey, cfg.APIURL
			// Модели танзимшуда бартарӣ дорад: сохтори chatReq
			// майдони Model дорад, вале он ба OpenAI ишора мекунад.
			if m, ok := body.(chatReq); ok {
				m.Model = cfg.Model
				body = m
			}
		}
	}
	if key == "" {
		return errors.New("ai: LLM provider not configured")
	}
	buf, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(buf))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode >= 400 {
		return fmt.Errorf("openai %s: %d %s", path, resp.StatusCode, string(data))
	}
	return json.Unmarshal(data, out)
}

// ═══════════════════════ MODERATION ═══════════════════════
// https://platform.openai.com/docs/api-reference/moderations

type moderationResp struct {
	Results []struct {
		Flagged    bool            `json:"flagged"`
		Categories map[string]bool `json:"categories"`
	} `json:"results"`
}

// ModerateText — матнро тавассути OpenAI Moderation API месанҷад.
// Fail-open: агар OPENAI_API_KEY танзим нашуда бошад ё дархост ноком
// шавад (хатои шабака, timeout), матн иҷозат дода мешавад — то
// хатои беруна корбаронро аз нашри мӯҳтаво маҳдуд накунад.
func ModerateText(ctx context.Context, text string) (flagged bool, categories []string) {
	if strings.TrimSpace(text) == "" {
		return false, nil
	}
	// Provider-и ройгон endpoint-и /moderations надорад. Ба ҷои
	// хомӯшона гузарондани ҳама чиз, модератсия бо худи модел иҷро
	// мешавад — ин модератсияи ВОҚЕӢ аст, на рад кардани санҷиш.
	if !hasOpenAIModeration() {
		return moderateWithModel(ctx, text)
	}
	var out moderationResp
	err := openAIRequest(ctx, "/moderations", map[string]string{
		"model": "omni-moderation-latest",
		"input": text,
	}, &out)
	if err != nil || len(out.Results) == 0 {
		return false, nil
	}
	r := out.Results[0]
	if !r.Flagged {
		return false, nil
	}
	for cat, v := range r.Categories {
		if v {
			categories = append(categories, cat)
		}
	}
	return true, categories
}

// ═══════════════════════ CHAT COMPLETIONS ═══════════════════════

type chatMsg struct {
	Role    string `json:"role"`
	Content any    `json:"content"`
}

type chatReq struct {
	Model       string    `json:"model"`
	Messages    []chatMsg `json:"messages"`
	Temperature float64   `json:"temperature,omitempty"`
}

type chatResp struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

// digitsOnly — аввалин пайдарпаии рақамҳоро аз матн мегирад
// (масалан "Score: 82/100" → "82").
func digitsOnly(s string) string {
	var b strings.Builder
	started := false
	for _, r := range s {
		if r >= '0' && r <= '9' {
			b.WriteRune(r)
			started = true
		} else if started {
			break
		}
	}
	return b.String()
}

func stripCodeFence(s string) string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "```json")
	s = strings.TrimPrefix(s, "```")
	s = strings.TrimSuffix(s, "```")
	return strings.TrimSpace(s)
}

// GenerateHashtags — тавассути GPT (vision-capable, масалан gpt-4o)
// аз рӯи тавсиф (ва расм, агар imageURL дода шуда бошад) ҳэштегҳои
// мувофиқ (ба забони тавсиф) тавлид мекунад.
func GenerateHashtags(ctx context.Context, caption, imageURL string) ([]string, error) {
	if !OpenAIEnabled() {
		return nil, errors.New("OPENAI_API_KEY not configured")
	}
	content := []map[string]any{
		{"type": "text", "text": fmt.Sprintf(
			"Тавсифи пост: %q\n\nБар асоси ин тавсиф (ва расм, агар дода шуда бошад), "+
				"5 то 8 ҳэштеги мувофиқ пешниҳод кун, ба ҳамон забоне, ки тавсиф навишта шудааст. "+
				"ТАНҲО як JSON массиви сатрҳо баргардон, чизи дигар нанавис. Масалан: "+
				`["#табиат","#дустон","#хушбахти"]. Ҳар ҳэштег бо # сар шавад, бе фосила дар дохили калима.`,
			caption)},
	}
	if imageURL != "" {
		content = append(content, map[string]any{
			"type":      "image_url",
			"image_url": map[string]string{"url": imageURL},
		})
	}

	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: "You are a hashtag generator for a social media app. Always reply with a raw JSON array of hashtag strings only, no markdown, no explanation."},
			{Role: "user", Content: content},
		},
		Temperature: 0.7,
	}, &out)
	if err != nil {
		return nil, err
	}
	if len(out.Choices) == 0 {
		return nil, errors.New("empty response from openai")
	}
	raw := stripCodeFence(out.Choices[0].Message.Content)
	var tags []string
	if err := json.Unmarshal([]byte(raw), &tags); err != nil {
		return nil, fmt.Errorf("parse hashtags: %w", err)
	}
	return tags, nil
}

// TranslateText — матнро ба забони targetLang тарҷума мекунад.
func TranslateText(ctx context.Context, text, targetLang string) (string, error) {
	if !OpenAIEnabled() {
		return "", errors.New("OPENAI_API_KEY not configured")
	}
	if targetLang == "" {
		targetLang = "English"
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: fmt.Sprintf(
				"You are a translation engine embedded in a social app. Translate the user's message into %s. "+
					"Reply with ONLY the translated text — no quotes, no explanation, no original text.", targetLang)},
			{Role: "user", Content: text},
		},
		Temperature: 0.2,
	}, &out)
	if err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", errors.New("empty response from openai")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}

// GeneratePostCaption — AI Post Creator: аз рӯи мавзӯи кӯтоҳи корбар
// (масалан "футбол") як пости тайёр (матн + emoji + hashtag дар охир,
// ба ҳамон забоне, ки мавзӯъ навишта шудааст) месозад.
func GeneratePostCaption(ctx context.Context, topic string) (string, error) {
	if !OpenAIEnabled() {
		return "", errors.New("OPENAI_API_KEY not configured")
	}
	if strings.TrimSpace(topic) == "" {
		return "", errors.New("topic is empty")
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: "You write ready-to-publish social media post captions for a social app. " +
				"Write in the SAME language as the user's topic. Keep it natural, 2-5 sentences, include 1-3 " +
				"fitting emoji inline, and end with 3-6 relevant hashtags on their own line (hashtags start with #, " +
				"no spaces inside a hashtag). Reply with ONLY the caption text, nothing else — no quotes, no preamble."},
			{Role: "user", Content: topic},
		},
		Temperature: 0.85,
	}, &out)
	if err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", errors.New("empty response from openai")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}

// SuggestComment — AI Comment: як шарҳи мувофиқ ва табиӣ барои пост
// (бо назардошти тавсиф ва расм, агар дода шуда бошад) пешниҳод мекунад.
func SuggestComment(ctx context.Context, postCaption, imageURL string) (string, error) {
	if !OpenAIEnabled() {
		return "", errors.New("OPENAI_API_KEY not configured")
	}
	content := []map[string]any{
		{"type": "text", "text": fmt.Sprintf(
			"Тавсифи пост: %q\n\nЯк шарҳи кӯтоҳ, дӯстона ва табиӣ барои ин пост нависед "+
				"(ба ҳамон забоне, ки тавсиф навишта шудааст, ё агар тавсиф холӣ бошад — ба тоҷикӣ). "+
				"Метавонед 1 emoji истифода баред. ТАНҲО матни шарҳро баргардонед, чизи дигар не.",
			postCaption)},
	}
	if imageURL != "" {
		content = append(content, map[string]any{
			"type":      "image_url",
			"image_url": map[string]string{"url": imageURL},
		})
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: "You suggest one short, natural, friendly comment for a social media post. Reply with only the comment text."},
			{Role: "user", Content: content},
		},
		Temperature: 0.8,
	}, &out)
	if err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", errors.New("empty response from openai")
	}
	return strings.Trim(strings.TrimSpace(out.Choices[0].Message.Content), `"`), nil
}

// GenerateProfileBio — AI Profile Assistant: бо сароҳати кӯтоҳи корбар
// (касбу кор/шавқ) BIO-и кӯтоҳи касбӣ месозад.
func GenerateProfileBio(ctx context.Context, input string) (string, error) {
	if !OpenAIEnabled() {
		return "", errors.New("OPENAI_API_KEY not configured")
	}
	if strings.TrimSpace(input) == "" {
		return "", errors.New("input is empty")
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: "You write short, professional social-media bio text (max ~150 characters), " +
				"in the SAME language as the user's input, based on their profession/interests. May use 1-2 fitting " +
				"emoji. Reply with ONLY the bio text, nothing else."},
			{Role: "user", Content: input},
		},
		Temperature: 0.7,
	}, &out)
	if err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", errors.New("empty response from openai")
	}
	return strings.Trim(strings.TrimSpace(out.Choices[0].Message.Content), `"`), nil
}

// ScorePostQuality — AI Feed: тахминан 0-100 холи "ҷолибияти эҳтимолӣ"-и
// пост барои алгоритми лента медиҳад (best-effort, дар CreatePost
// асинхронӣ ҷеғ зада мешавад — ба нашри пост монеъ намешавад).
func ScorePostQuality(ctx context.Context, caption string) (int, error) {
	if !OpenAIEnabled() {
		return 0, errors.New("OPENAI_API_KEY not configured")
	}
	if strings.TrimSpace(caption) == "" {
		return 0, nil
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: "You rate how engaging/interesting a social media post caption likely is " +
				"to a general audience, from 0 to 100. Reply with ONLY the integer number, nothing else."},
			{Role: "user", Content: caption},
		},
		Temperature: 0.3,
	}, &out)
	if err != nil {
		return 0, err
	}
	if len(out.Choices) == 0 {
		return 0, errors.New("empty response from openai")
	}
	digits := digitsOnly(out.Choices[0].Message.Content)
	if digits == "" {
		return 0, fmt.Errorf("parse score: no digits in %q", out.Choices[0].Message.Content)
	}
	score, err2 := strconv.Atoi(digits)
	if err2 != nil {
		return 0, fmt.Errorf("parse score: %w", err2)
	}
	if score < 0 {
		score = 0
	}
	if score > 100 {
		score = 100
	}
	return score, nil
}

// SearchQuery — натиҷаи таҳлили GPT аз дархости ҷустуҷӯии забони табиӣ.
type SearchQuery struct {
	Keywords  []string `json:"keywords"`
	Type      string   `json:"type"`      // "post" | "reel" | "any"
	Timeframe string   `json:"timeframe"` // "today" | "week" | "any"
}

// ParseSearchQuery — AI Search: дархости забони табииро (масалан
// "видеоҳои Тоҷикистон дар бораи футбол") ба калидвожаҳо + навъи
// мӯҳтаво + давраи вақт табдил медиҳад, то бо SQL ILIKE ҷустуҷӯ шавад.
func ParseSearchQuery(ctx context.Context, query string) (SearchQuery, error) {
	var sq SearchQuery
	if !OpenAIEnabled() {
		return sq, errors.New("OPENAI_API_KEY not configured")
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model: openAIModel(),
		Messages: []chatMsg{
			{Role: "system", Content: `You turn a natural-language search query (any language) into a JSON object: ` +
				`{"keywords": ["..."], "type": "post"|"reel"|"any", "timeframe": "today"|"week"|"any"}. ` +
				`"keywords" are 1-5 short topical search words/phrases (translate slang/abbreviations to plain nouns, ` +
				`keep them in the query's original language). "type" is "reel" if the query mentions videos/reels, ` +
				`"post" if it mentions posts/photos, otherwise "any". "timeframe" is "today" if the query mentions ` +
				`today/now, "week" if it mentions this week/recent, otherwise "any". Reply with ONLY the raw JSON object.`},
			{Role: "user", Content: query},
		},
		Temperature: 0.1,
	}, &out)
	if err != nil {
		return sq, err
	}
	if len(out.Choices) == 0 {
		return sq, errors.New("empty response from openai")
	}
	raw := stripCodeFence(out.Choices[0].Message.Content)
	if err := json.Unmarshal([]byte(raw), &sq); err != nil {
		return sq, fmt.Errorf("parse search query: %w", err)
	}
	return sq, nil
}

// ChatTurn — як паёми таърихи чат (role: "user" ё "assistant").
type ChatTurn struct {
	Role    string
	Content string
}

// AskAssistant — чат бисёрқадама бо system prompt (масалан, ёрдамчии
// дохили барнома). history-и охирин 16 паём мефиристад, то токен зиёд нашавад.
func AskAssistant(ctx context.Context, systemPrompt string, history []ChatTurn) (string, error) {
	if !OpenAIEnabled() {
		return "", errors.New("OPENAI_API_KEY not configured")
	}
	msgs := []chatMsg{{Role: "system", Content: systemPrompt}}
	start := 0
	if len(history) > 16 {
		start = len(history) - 16
	}
	for _, h := range history[start:] {
		role := h.Role
		if role != "user" && role != "assistant" {
			role = "user"
		}
		msgs = append(msgs, chatMsg{Role: role, Content: h.Content})
	}
	var out chatResp
	err := openAIRequest(ctx, "/chat/completions", chatReq{
		Model:       openAIModel(),
		Messages:    msgs,
		Temperature: 0.5,
	}, &out)
	if err != nil {
		return "", err
	}
	if len(out.Choices) == 0 {
		return "", errors.New("empty response from openai")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}

// moderateWithModel матнро бо модели чат тафтиш мекунад.
//
// Барои provider-ҳое, ки endpoint-и махсуси модератсия надоранд.
// Ҳангоми ҳар гуна шубҳа (хато, ҷавоби нофаҳмо) матн ИҶОЗАТ дода
// мешавад — ҳамон рафторе, ки OpenAI-и танзимнашуда дошт. Бастани
// пости бегуноҳ аз надидани як пости бад бадтар аст, ва модератсияи
// дастӣ (report) ба ҳар ҳол кор мекунад.
func moderateWithModel(ctx context.Context, text string) (bool, []string) {
	if !ai.Enabled(ai.TaskFast) {
		return false, nil
	}
	var out struct {
		Flagged    bool     `json:"flagged"`
		Categories []string `json:"categories"`
	}
	err := ai.CompleteJSON(ctx, ai.TaskFast, []ai.Message{
		{Role: "system", Content: "You are a content safety classifier for a social app. " +
			"Reply ONLY with JSON: {\"flagged\":bool,\"categories\":[string]}. " +
			"Flag only genuinely harmful content: sexual content involving minors, " +
			"credible threats of violence, terrorism, or explicit sexual content. " +
			"Ordinary criticism, slang, jokes and strong language are NOT flagged."},
		{Role: "user", Content: text},
	}, ai.Options{Temperature: 0, MaxTokens: 120}, &out)
	if err != nil {
		return false, nil
	}
	if !out.Flagged {
		return false, nil
	}
	return true, out.Categories
}
