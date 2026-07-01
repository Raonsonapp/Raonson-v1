package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"os"
	"time"

	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// AI-муаллими коднависӣ — proxy ба LLM-и open-source (Groq/Llama ва ғ.).
// Калид дар env: TUTOR_API_KEY, TUTOR_API_URL, TUTOR_MODEL — ҳеҷ гоҳ дар апп нест.

func tutorEnv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

// Роҳнамои омӯзиш барои ҳар соҳа.
var tutorTracks = map[string]string{
	"app":     "коднависии барнома (мобилӣ, бо Flutter/Dart)",
	"backend": "backend (сервер, бо Go ё Node.js ва базаи додаҳо)",
	"design":  "дизайни UI/UX (тартиб, ранг, фазо, типографика)",
	"icons":   "сохтани icon-ҳо (SVG/Figma, дар сатҳи Instagram)",
	"website": "сохтани вебсайт (HTML, CSS, JavaScript)",
	"ai":      "сунъии зеҳни (AI) — чист, чӣ тавр кор мекунад, чӣ тавр истифода бурда мешавад",
}

func tutorSystemPrompt(track, lang string) string {
	topic := tutorTracks[track]
	if topic == "" {
		topic = "коднависӣ"
	}
	langLine := ""
	if lang != "" {
		langLine = "Забони барномасозии интихобкардаи корбар: " + lang + ". "
	}
	return `Ту «Устоз» ҳастӣ — муаллими беҳамтои ` + topic + `. ` + langLine + `
Вазифаи ту: ба корбар ин соҳаро чунон СОДА фаҳмонӣ, ки ҳатто кӯдаки 10-сола ёд гирад.

ҚОИДАҲОИ ҲАТМӢ:
1. Ба забони ТОҶИКӢ (содда), гарм ва рӯҳбаландкунанда навис. Калимаҳои техникиро содда кун.
2. Ҳар дафъа ФАҚАТ ЯК қадами хурд омӯзон — на ҳамаро якбора. Кӯтоҳ навис.
3. Ҳамеша МИСОЛҲОИ ҲАЁТӢ биёр: хона, ошхона, боғ, сабад, хишт, қуттӣ. Мисол: «Column мисли қуттӣ аст, ки чизҳоро аз боло ба поён мечинад».
4. Ҳангоми фаҳмондани код, онро ХАТ БА ХАТ бо шарҳи рақамдор фаҳмон (мисли // 1. ... // 2. ...).
5. Таъкид кун: ҳар қадаре код дарозтар ва «таг ба таг» (indent) шавад, ҳамон қадар дар охир бояд қавс ")" гузошта шавад, то онро маҳкам кунӣ. Кушодиро бо пӯшидан ҷуфт кун.
6. Дар охири ҳар дарс, ЯК вазифаи хурди амалӣ деҳ (мисли муаллим).
7. Агар корбар хато кунад — ҷанг накун, бо меҳрубонӣ хаторо нишон деҳ ва бо мисоли содда фаҳмон, чаро.
8. Ҳадаф: дар 1 моҳ корбар як чизи ХЕЛЕ СОДА созад (масалан як экрани хурд, як API-и хурд, ё як icon).
9. Ҳар посух кӯтоҳ, равшан ва бо як эмоҷии хурд ва як савол дар охир («Тайёрӣ ба қадами навбатӣ? 🙂») тамом шавад.
Ту мисли ChatGPT дар фаҳмондан устои беҳамто бош.`
}

func TutorChat(c *gin.Context) {
	_ = mw.UID(c) // танҳо корбарони воридшуда
	var b struct {
		Track    string `json:"track"`
		Lang     string `json:"lang"`
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}

	apiKey := os.Getenv("TUTOR_API_KEY")
	if apiKey == "" {
		c.JSON(http.StatusOK, gin.H{
			"reply": "⚙️ Муаллими AI ҳанӯз танзим нашудааст. Соҳиби барнома бояд " +
				"калиди ройгони LLM-ро (масалан Groq) дар TUTOR_API_KEY гузорад.",
			"configured": false,
		})
		return
	}
	apiURL := tutorEnv("TUTOR_API_URL", "https://api.groq.com/openai/v1/chat/completions")
	model := tutorEnv("TUTOR_MODEL", "llama-3.3-70b-versatile")

	// Паёмҳо: system + таърих (охирин 12-то).
	msgs := []map[string]string{
		{"role": "system", "content": tutorSystemPrompt(b.Track, b.Lang)},
	}
	start := 0
	if len(b.Messages) > 12 {
		start = len(b.Messages) - 12
	}
	for _, m := range b.Messages[start:] {
		role := m.Role
		if role != "user" && role != "assistant" {
			role = "user"
		}
		msgs = append(msgs, map[string]string{"role": role, "content": m.Content})
	}

	payload, _ := json.Marshal(map[string]interface{}{
		"model":       model,
		"messages":    msgs,
		"temperature": 0.6,
		"max_tokens":  900,
	})

	ctx, cancel := context.WithTimeout(context.Background(), 40*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, apiURL,
		bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+apiKey)

	resp, err := (&http.Client{Timeout: 45 * time.Second}).Do(req)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"reply": "Узр, ҳозир ба муаллим пайваст шуда натавонистам. Дубора кӯшиш кун 🙏",
		})
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
		msg := "Узр, ҳозир ҷавоб гирифта натавонистам. Дубора кӯшиш кун 🙏"
		if out.Error.Message != "" {
			msg = "Хатои муаллим: " + out.Error.Message
		}
		c.JSON(http.StatusOK, gin.H{"reply": msg})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"reply": out.Choices[0].Message.Content, "configured": true,
	})
}
