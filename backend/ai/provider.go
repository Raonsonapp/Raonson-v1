// Package ai як қабати ягонаи LLM барои тамоми Raonson аст.
//
// Пеш аз ин, AI дар се ҷои гуногун буд:
//   - utils/openai_client.go → api.openai.com (пулакӣ)
//   - handlers/openai.go     → нусхаи дуюми ҳамон чиз
//   - handlers/tutor.go      → Groq/Llama (ройгон) — танҳо ин кор мекард
//
// Дар натиҷа hashtag, тарҷума ва холи сифат бе калиди пулакии OpenAI
// умуман кор намекарданд. Ин пакет ҳамаро ба ЯК интерфейс меорад ва
// имкон медиҳад, ки барои ҳар вазифа модели ҷудогона таъин шавад.
//
// ҲЕҶ API ихтироъ намешавад: ҳамаи provider-ҳои дастгиришаванда
// интерфейси OpenAI-compatible доранд (Groq, OpenRouter, Together,
// DeepInfra ва ғ.), яъне ҳамон роҳи /chat/completions. Калид ва URL
// ФАҚАТ аз env меоянд.
package ai

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
)

// Task — навъи вазифа. Барои ҳар кадом модели ҷудогона таъин мешавад,
// зеро вазифаҳо талаботи гуногун доранд: муошират ҷавоби табиӣ мехоҳад,
// таҳлил дақиқӣ, коднависӣ модели махсус.
type Task string

const (
	// TaskChat — муошират, ёрдамчӣ, муаллим.
	TaskChat Task = "chat"
	// TaskCode — коднависӣ.
	TaskCode Task = "code"
	// TaskAnalysis — таҳлили маълумот, хулосабарорӣ (Creator Insights).
	TaskAnalysis Task = "analysis"
	// TaskFast — вазифаҳои хурду зуд: хэштег, тарҷума, холи сифат.
	// Модели хурд ин ҷо кофист ва хеле тезтар аст.
	TaskFast Task = "fast"
	// TaskVision — таҳлили расм.
	TaskVision Task = "vision"
)

var ErrNotConfigured = errors.New("ai: калиди LLM танзим нашудааст")

// Config — танзимоти як вазифа.
type Config struct {
	APIKey string
	APIURL string
	Model  string
}

// maxResponseBytes — ҳадди ҷавоби провайдер.
//
// Ҷавоби воқеӣ даҳҳо килобайт аст; ин ҳад танҳо аз ҷавоби вайрон ё
// бадният муҳофизат мекунад.
const maxResponseBytes = 4 << 20 // 4 МБ

// httpClient — вақти интизорӣ.
//
// 60 сония барои дархосте, ки одам мунтазир аст, хеле дароз буд:
// экран як дақиқа мехобид ва баъд ҳам метавонист хато диҳад.
// Ҳадди воқеии моделҳо чанд сония аст.
var httpClient = &http.Client{
	Timeout: time.Duration(envInt("AI_TIMEOUT_SECONDS", 20)) * time.Second,
}

// envInt — танзими адад аз env.
func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return def
}

// defaultURL — endpoint-и OpenAI-compatible.
//
// Пешфарз ҳамон чизест, ки дар ин repo аллакай кор мекунад
// (handlers/tutor.go). Соҳиби барнома метавонад онро ба ҳар
// provider-и дигари OpenAI-compatible иваз кунад.
const defaultURL = "https://api.groq.com/openai/v1/chat/completions"

// defaultModel — ҳамон модели дар repo санҷидашуда.
//
// Барои ҳар вазифа модели ҷудогона тавассути env таъин мешавад;
// номи моделҳо ин ҷо сахткод НАМЕШАВАД, зеро рӯйхати моделҳои
// ройгон бо мурури вақт тағйир меёбад ва номи ихтироъшуда
// дархостро вайрон мекунад.
const defaultModel = "llama-3.3-70b-versatile"

// envOr аввалин калиди холинабударо мегирад.
func envOr(keys []string, def string) string {
	for _, k := range keys {
		if v := strings.TrimSpace(os.Getenv(k)); v != "" {
			return v
		}
	}
	return def
}

// ConfigFor танзимоти вазифаро месозад.
//
// Тартиби ҷустуҷӯ: калиди махсуси вазифа → калиди умумӣ → калидҳои
// кӯҳна (TUTOR_*, OPENAI_*), то танзимоти мавҷуда бешикаст монад.
func ConfigFor(t Task) Config {
	up := strings.ToUpper(string(t))
	return Config{
		APIKey: envOr([]string{
			"AI_" + up + "_API_KEY",
			"AI_API_KEY",
			"TUTOR_API_KEY",
			"OPENAI_API_KEY",
		}, ""),
		APIURL: envOr([]string{
			"AI_" + up + "_API_URL",
			"AI_API_URL",
			"TUTOR_API_URL",
		}, defaultURL),
		Model: envOr([]string{
			"AI_" + up + "_MODEL",
			"AI_MODEL",
			"TUTOR_MODEL",
		}, defaultModel),
	}
}

// Enabled — оё барои ин вазифа LLM дастрас аст?
//
// Ҳар ҷое, ки AI истифода мешавад, БОЯД инро санҷад ва бе AI ҳам
// кор кунад: набудани калид набояд функсияро вайрон кунад.
func Enabled(t Task) bool { return ConfigFor(t).APIKey != "" }

// AnyEnabled — оё ҳадди ақал як вазифа танзим шудааст?
func AnyEnabled() bool {
	for _, t := range []Task{TaskChat, TaskCode, TaskAnalysis, TaskFast, TaskVision} {
		if Enabled(t) {
			return true
		}
	}
	return false
}

// Message — як паём дар муколама.
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// Options — танзимоти як дархост.
type Options struct {
	Temperature float64
	MaxTokens   int
	// JSONMode — аз модел ҷавоби JSON талаб мекунад. Ҳама provider-ҳо
	// онро дастгирӣ намекунанд, бинобар ин натиҷа ба ҳар ҳол тафтиш
	// мешавад.
	JSONMode bool
}

// Complete як дархост ба модел мефиристад ва матни ҷавобро мегирад.
func Complete(ctx context.Context, t Task, msgs []Message, opt Options) (string, error) {
	cfg := ConfigFor(t)
	if cfg.APIKey == "" {
		return "", ErrNotConfigured
	}
	if opt.MaxTokens <= 0 {
		opt.MaxTokens = 800
	}
	if opt.Temperature == 0 {
		opt.Temperature = 0.6
	}

	body := map[string]any{
		"model":       cfg.Model,
		"messages":    msgs,
		"temperature": opt.Temperature,
		"max_tokens":  opt.MaxTokens,
	}
	if opt.JSONMode {
		body["response_format"] = map[string]string{"type": "json_object"}
	}
	buf, err := json.Marshal(body)
	if err != nil {
		return "", err
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, cfg.APIURL,
		bytes.NewReader(buf))
	if err != nil {
		return "", err
	}
	req.Header.Set("Authorization", "Bearer "+cfg.APIKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	// Ҷавоб маҳдуд хонда мешавад: провайдери вайрон ё бадният
	// метавонад ҷавоби бепоён диҳад ва хотираро тамом кунад.
	data, _ := io.ReadAll(io.LimitReader(resp.Body, maxResponseBytes))
	if resp.StatusCode >= 400 {
		// Матни хатои provider ба корбар НАМЕРАВАД — он метавонад
		// маълумоти дохилӣ дошта бошад. Танҳо код сабт мешавад.
		return "", fmt.Errorf("ai: provider status %d", resp.StatusCode)
	}

	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.Unmarshal(data, &out); err != nil {
		return "", fmt.Errorf("ai: ҷавоби нофаҳмо: %w", err)
	}
	if len(out.Choices) == 0 {
		return "", errors.New("ai: ҷавоби холӣ")
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}

// CompleteJSON ҷавоби JSON мегирад ва онро ба out мегузорад.
//
// Модел баъзан JSON-ро бо матни изофӣ ё дар ```json печонида
// бармегардонад — ин ҷо тоза карда мешавад, вагарна таҷзия мешиканад.
func CompleteJSON(ctx context.Context, t Task, msgs []Message,
	opt Options, out any) error {
	opt.JSONMode = true
	raw, err := Complete(ctx, t, msgs, opt)
	if err != nil {
		return err
	}
	return json.Unmarshal([]byte(extractJSON(raw)), out)
}

// extractJSON матни атрофи JSON-ро мебарорад.
func extractJSON(s string) string {
	s = strings.TrimSpace(s)
	// Блоки ```json ... ```
	if i := strings.Index(s, "```"); i >= 0 {
		rest := s[i+3:]
		if j := strings.Index(rest, "\n"); j >= 0 {
			rest = rest[j+1:]
		}
		if k := strings.Index(rest, "```"); k >= 0 {
			s = strings.TrimSpace(rest[:k])
		}
	}
	// Аввалин { ё [ то охирини мувофиқ.
	start := strings.IndexAny(s, "{[")
	if start < 0 {
		return s
	}
	open := s[start]
	closeCh := byte('}')
	if open == '[' {
		closeCh = ']'
	}
	end := strings.LastIndexByte(s, closeCh)
	if end <= start {
		return s
	}
	return s[start : end+1]
}
