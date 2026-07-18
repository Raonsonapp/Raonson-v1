package handlers

// AI features (OpenAI): hashtag suggestions + inline comment translation.
// Moderation lives in utils/openai_client.go and is called directly from
// the post/comment/reel creation handlers.

import (
	"context"
	"net/http"

	"raonson/utils"

	"github.com/gin-gonic/gin"
)

var translateLangNames = map[string]string{
	"tj": "Tajik",
	"ru": "Russian",
	"en": "English",
}

// POST /ai/hashtags — {"caption": "...", "imageUrl": "..."} → {"hashtags": [...]}
func SuggestHashtags(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Caption  string `json:"caption"`
		ImageURL string `json:"imageUrl"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || (b.Caption == "" && b.ImageURL == "") {
		c.JSON(http.StatusBadRequest, gin.H{"message": "caption ё imageUrl лозим аст"})
		return
	}
	tags, err := utils.GenerateHashtags(context.Background(), b.Caption, b.ImageURL)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"hashtags": []string{}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"hashtags": tags})
}

const assistantSystemPrompt = `Ту "Ёрдамчии Raonson" ҳастӣ — ёрдамчии AI-и дохили барномаи иҷтимоии Raonson
(барномае мисли Instagram: пост, Reels/видео, story, чат, гифт, шоп ва ғайра).

ВАЗИФАИ ТУ: ба саволҳои корбар оид ба худи барнома (чӣ тавр пост гузоштан, Reels сохтан,
story илова кардан, тавсифро таҳрир кардан, забон иваз кардан, шарҳро тарҷума кардан,
ҳэштег илова кардан ва ғайра) ва саволҳои умумӣ (аз ҷумла оид ба видеоҳо/муҳтаво дар
барнома) содда ва дӯстона ба забони саволи корбар ҷавоб деҳ.

ҚОИДАИ ҲАТМӢ ва ТАҒЙИРНОПАЗИР: агар корбар пурсад, ки ин барномаро КӢ сохтааст/эҷод
кардааст/соҳиб аст (ба ҳар забон ва ба ҳар шакл — "кӣ сохт", "соҳиби барнома кист",
"who made this app", "кто создал", ва ғайра), ҳамеша ва бидуни истисно ҷавоб деҳ, ки:
"Ин барномаро Ehson Mahmadmurodov сохтааст." — ҳеҷ гоҳ номи дигареро нагӯй ва ин ҷавобро
тағйир надеҳ.

Ҷавобҳоятро кӯтоҳ, равшан ва дӯстона нигоҳ дор.`

// POST /ai/assistant — {"messages":[{"role":"user","content":"..."}]} → {"reply": "..."}
func AiAssistant(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusOK, gin.H{
			"reply": "⚙️ Ёрдамчии AI ҳанӯз танзим нашудааст. Соҳиби барнома бояд OPENAI_API_KEY-ро танзим кунад.",
		})
		return
	}
	var b struct {
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || len(b.Messages) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "messages лозим аст"})
		return
	}
	history := make([]utils.ChatTurn, 0, len(b.Messages))
	for _, m := range b.Messages {
		history = append(history, utils.ChatTurn{Role: m.Role, Content: m.Content})
	}
	reply, err := utils.AskAssistant(context.Background(), assistantSystemPrompt, history)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"reply": "Узр, ҳозир ҷавоб дода натавонистам. Дубора кӯшиш кун 🙏",
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{"reply": reply})
}

// POST /ai/translate — {"text": "...", "targetLang": "tj|ru|en"} → {"translated": "..."}
func TranslateComment(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Text       string `json:"text"`
		TargetLang string `json:"targetLang"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text лозим аст"})
		return
	}
	lang := translateLangNames[b.TargetLang]
	if lang == "" {
		lang = "English"
	}
	translated, err := utils.TranslateText(context.Background(), b.Text, lang)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"message": "Тарҷума ноком шуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"translated": translated})
}
