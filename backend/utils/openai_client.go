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
	"strings"
	"time"
)

// ── OpenAI integration ─────────────────────────────────────────────
// Калиди API ФАҚАТ аз env меояд (OPENAI_API_KEY, дар Render/HF Space
// ҳамчун SECRET). Ҳаргиз дар код нанависед.

const openAIBaseURL = "https://api.openai.com/v1"

var httpClient = &http.Client{Timeout: 25 * time.Second}

func openAIKey() string { return os.Getenv("OPENAI_API_KEY") }

// OpenAIEnabled — агар калид танзим шуда бошад.
func OpenAIEnabled() bool { return openAIKey() != "" }

func openAIModel() string {
	if m := os.Getenv("OPENAI_MODEL"); m != "" {
		return m
	}
	return "gpt-4o-mini"
}

func openAIRequest(ctx context.Context, path string, body any, out any) error {
	key := openAIKey()
	if key == "" {
		return errors.New("OPENAI_API_KEY not configured")
	}
	buf, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, openAIBaseURL+path, bytes.NewReader(buf))
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
	if strings.TrimSpace(text) == "" || !OpenAIEnabled() {
		return false, nil
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
