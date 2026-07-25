package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

func openaiKey() string { return os.Getenv("OPENAI_API_KEY") }

func callOpenAI(system, user string, maxTokens int) (string, error) {
	key := openaiKey()
	if key == "" {
		return "", nil
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"model": "gpt-4o-mini",
		"messages": []map[string]string{
			{"role": "system", "content": system},
			{"role": "user", "content": user},
		},
		"temperature": 0.3,
		"max_tokens":  maxTokens,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.openai.com/v1/chat/completions", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+key)

	resp, err := (&http.Client{Timeout: 35 * time.Second}).Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	var out struct {
		Choices []struct {
			Message struct{ Content string `json:"content"` } `json:"message"`
		} `json:"choices"`
	}
	json.NewDecoder(resp.Body).Decode(&out)
	if len(out.Choices) == 0 {
		return "", nil
	}
	return strings.TrimSpace(out.Choices[0].Message.Content), nil
}

// POST /ai/moderate — модератсия тавассути OpenAI
// Body: {"text":"..."}
// Returns: {"safe":true/false,"reason":"..."}
func AIModerate(c *gin.Context) {
	_ = mw.UID(c)
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || strings.TrimSpace(b.Text) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}

	key := openaiKey()
	if key == "" {
		c.JSON(http.StatusOK, gin.H{"safe": true, "configured": false})
		return
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"input": b.Text,
		"model": "omni-moderation-latest",
	})

	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.openai.com/v1/moderations", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+key)

	resp, err := (&http.Client{Timeout: 20 * time.Second}).Do(req)
	if err != nil {
		log.Printf("[AIModerate] OpenAI error: %v", err)
		c.JSON(http.StatusOK, gin.H{"safe": true, "configured": true})
		return
	}
	defer resp.Body.Close()

	var out struct {
		Results []struct {
			Flagged    bool               `json:"flagged"`
			Categories map[string]bool    `json:"categories"`
		} `json:"results"`
	}
	json.NewDecoder(resp.Body).Decode(&out)

	if len(out.Results) == 0 {
		c.JSON(http.StatusOK, gin.H{"safe": true, "configured": true})
		return
	}

	result := out.Results[0]
	reason := ""
	if result.Flagged {
		flagged := []string{}
		for cat, val := range result.Categories {
			if val {
				flagged = append(flagged, cat)
			}
		}
		reason = strings.Join(flagged, ", ")
	}

	c.JSON(http.StatusOK, gin.H{
		"safe":       !result.Flagged,
		"reason":     reason,
		"configured": true,
	})
}

// POST /ai/hashtags — ҳаштегҳои аз матн тавлидшуда
// Body: {"text":"..."}
// Returns: {"hashtags":["#travel","#nature",...],"configured":true}
func AIHashtags(c *gin.Context) {
	_ = mw.UID(c)
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || strings.TrimSpace(b.Text) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}

	if openaiKey() == "" {
		c.JSON(http.StatusOK, gin.H{"hashtags": []string{}, "configured": false})
		return
	}

	system := `Ту мутахассиси SMM ва хэштегҳо ҳастӣ.
Барои матни додашуда 15-25 хэштеги мувофиқ ва машҳур пешниҳод кун.
Омехтаи тоҷикӣ, русӣ, англисӣ хэштегҳоро нависед.
ФОРМАТ: танҳо хэштегҳоро бо фосила нависед, бе шарҳ ва бе нумерация.
Мисол: #travel #сафар #nature #путешествие #instatravel`

	result, err := callOpenAI(system, b.Text, 300)
	if err != nil || result == "" {
		c.JSON(http.StatusOK, gin.H{"hashtags": []string{}, "configured": true,
			"message": "AI натавонист хэштегҳо пешниҳод кунад"})
		return
	}

	tags := []string{}
	for _, word := range strings.Fields(result) {
		w := strings.TrimSpace(word)
		if strings.HasPrefix(w, "#") && len(w) > 1 {
			tags = append(tags, w)
		}
	}

	c.JSON(http.StatusOK, gin.H{"hashtags": tags, "configured": true})
}

// POST /ai/translate — тарҷумаи матн
// Body: {"text":"...","to":"ru"} — to = забони мақсад (default: en)
// Returns: {"translation":"...","configured":true}
func AITranslate(c *gin.Context) {
	_ = mw.UID(c)
	var b struct {
		Text string `json:"text"`
		To   string `json:"to"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || strings.TrimSpace(b.Text) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}

	if openaiKey() == "" {
		c.JSON(http.StatusOK, gin.H{"translation": "", "configured": false})
		return
	}

	targetLang := b.To
	if targetLang == "" {
		targetLang = "en"
	}

	langNames := map[string]string{
		"en": "English", "ru": "Russian", "tg": "Tajik",
		"fa": "Persian", "uz": "Uzbek", "ar": "Arabic",
		"tr": "Turkish", "de": "German", "fr": "French",
		"es": "Spanish", "zh": "Chinese", "hi": "Hindi",
	}
	langName := langNames[targetLang]
	if langName == "" {
		langName = targetLang
	}

	system := "Translate the following text to " + langName + ". " +
		"Return ONLY the translation, no explanations or notes."

	result, err := callOpenAI(system, b.Text, 500)
	if err != nil || result == "" {
		c.JSON(http.StatusOK, gin.H{"translation": "", "configured": true,
			"message": "Тарҷума ноком шуд"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"translation": result,
		"configured":  true,
	})
}

// moderateText — internal helper; called from CreatePost/AddComment to auto-check.
// Returns true if safe, false if flagged.
func moderateText(text string) bool {
	key := openaiKey()
	if key == "" {
		return true
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"input": text,
		"model": "omni-moderation-latest",
	})

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://api.openai.com/v1/moderations", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+key)

	resp, err := (&http.Client{Timeout: 12 * time.Second}).Do(req)
	if err != nil {
		return true
	}
	defer resp.Body.Close()

	var out struct {
		Results []struct {
			Flagged bool `json:"flagged"`
		} `json:"results"`
	}
	json.NewDecoder(resp.Body).Decode(&out)
	if len(out.Results) == 0 {
		return true
	}
	return !out.Results[0].Flagged
}
