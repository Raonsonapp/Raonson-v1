package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"os"
	"strings"
	"time"

	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// AI-абзорҳо барои Pro — тавассути ҳамон LLM-и proxy (Groq/Llama).
// POST /ai/text {task, text, lang} → {result}
// task: caption | hashtags | improve | translate | summarize

func aiSystemPrompt(task, lang string) string {
	switch task {
	case "caption":
		return "Ту як мутахассиси SMM ҳастӣ. Барои акс/видеои корбар як CAPTION-и " +
			"кӯтоҳ, ҷолиб ва эҳсосотӣ нависед (ба тоҷикӣ, агар дигар хоҳиш набошад). " +
			"2–3 сатр, бо 2–4 эмоҷии мувофиқ. Танҳо худи матни caption-ро баргардон."
	case "hashtags":
		return "Ту мутахассиси hashtag ҳастӣ. Барои матни додашуда 15–25 хэштеги " +
			"мувофиқ ва машҳур пешниҳод кун (омехтаи тоҷикӣ/русӣ/англисӣ). " +
			"Танҳо хэштегҳоро бо фосила баргардон, мисли #сафар #натура."
	case "improve":
		return "Матни корбарро беҳтар кун: хатоҳои имло/грамматикаро ислоҳ кун, " +
			"равшантар ва ҷолибтар созед, вале маъно ва забонашро нигоҳ дор. " +
			"Танҳо матни беҳтаршударо баргардон."
	case "translate":
		to := lang
		if to == "" {
			to = "en"
		}
		return "Матни корбарро ба забони «" + to + "» тарҷума кун. " +
			"Танҳо тарҷумаро баргардон, бе шарҳ."
	case "summarize":
		return "Шарҳҳо/матни додашударо дар 2–3 ҷумлаи кӯтоҳ ҷамъбаст кун (тоҷикӣ). " +
			"Танҳо ҷамъбастро баргардон."
	default:
		return "Ба корбар ёрӣ деҳ. Танҳо натиҷаро баргардон."
	}
}

func AIText(c *gin.Context) {
	_ = mw.UID(c)
	var b struct {
		Task string `json:"task"`
		Text string `json:"text"`
		Lang string `json:"lang"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}
	b.Task = strings.TrimSpace(b.Task)
	if b.Task == "" {
		b.Task = "improve"
	}

	apiKey := os.Getenv("TUTOR_API_KEY")
	if apiKey == "" {
		c.JSON(http.StatusOK, gin.H{
			"result":     "",
			"configured": false,
			"message": "AI ҳанӯз танзим нашудааст. Калиди ройгони LLM (TUTOR_API_KEY) лозим.",
		})
		return
	}
	apiURL := tutorEnv("TUTOR_API_URL", "https://api.groq.com/openai/v1/chat/completions")
	model := tutorEnv("TUTOR_MODEL", "llama-3.3-70b-versatile")

	userMsg := b.Text
	if strings.TrimSpace(userMsg) == "" && b.Task == "caption" {
		userMsg = "Барои як акси зебо як caption нависед."
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"model": model,
		"messages": []map[string]string{
			{"role": "system", "content": aiSystemPrompt(b.Task, b.Lang)},
			{"role": "user", "content": userMsg},
		},
		"temperature": 0.7,
		"max_tokens":  500,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, apiURL,
		bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := (&http.Client{Timeout: 45 * time.Second}).Do(req)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"result": "", "message": "AI дастрас нест. Дубора кӯшиш кунед 🙏"})
		return
	}
	defer resp.Body.Close()

	var out struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
		Error struct {
			Message string `json:"message"`
		} `json:"error"`
	}
	json.NewDecoder(resp.Body).Decode(&out)

	if len(out.Choices) == 0 || out.Choices[0].Message.Content == "" {
		msg := "AI ҷавоб дода натавонист. Дубора кӯшиш кунед 🙏"
		if out.Error.Message != "" {
			msg = "Хатои AI: " + out.Error.Message
		}
		c.JSON(http.StatusOK, gin.H{"result": "", "message": msg})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"result":     strings.TrimSpace(out.Choices[0].Message.Content),
		"configured": true,
	})
}
