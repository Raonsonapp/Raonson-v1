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
