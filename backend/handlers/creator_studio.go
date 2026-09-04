package handlers

// Creator Studio — маркази эҷодкор.
//
// Ҳама рақам аз ҷадвалҳои воқеӣ меояд. Эҷодкор ТАНҲО маълумоти
// худро мебинад: id аз токен меояд, на аз параметр.

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/ai"
	"raonson/creator"
	"raonson/db"
	mw "raonson/middleware"
)

// GET /creator/studio — ҳама чиз барои экрани асосӣ, дар як дархост.
//
// Client набояд панҷ дархости ҷудогона кунад: экран якбора пур мешавад.
func GetCreatorStudio(c *gin.Context) {
	myID := mw.UID(c)
	w := creator.ParseWindow(c.Query("window"))
	ctx := c.Request.Context()

	// Кэши кӯтоҳ: таҳлил дар ҳар кушодани экран аз нав ҳисоб намешавад.
	cacheKey := "creatorstudio:" + myID + ":" + string(w)
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	overview, err := creator.GetOverview(ctx, db.Pool, myID, w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	rec, err := creator.GetRecommendationStats(ctx, db.Pool, myID, w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	top, err := creator.GetTopRecommended(ctx, db.Pool, myID, w, 5)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	topics, err := creator.GetTopicPerformance(ctx, db.Pool, myID, w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	insights, err := creator.BuildInsights(ctx, db.Pool, myID, w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}

	payload := gin.H{
		"window":         string(w),
		"overview":       overview,
		"recommendation": rec,
		"topContent":     top,
		"topics":         topics,
		"insights":       insights,
	}
	c.JSON(http.StatusOK, payload)
	cacheJSON(cacheKey, payload, 2*time.Minute)
}

// cacheJSON натиҷаро кэш мекунад, вале посухро тағйир намедиҳад.
func cacheJSON(key string, payload gin.H, ttl time.Duration) {
	b, err := json.Marshal(payload)
	if err != nil {
		return
	}
	mw.CacheSet(key, b, ttl)
}

// GET /creator/analytics — танҳо рақамҳо (барои навсозии сабук).
func GetCreatorAnalytics(c *gin.Context) {
	myID := mw.UID(c)
	w := creator.ParseWindow(c.Query("window"))
	ctx := c.Request.Context()

	overview, err := creator.GetOverview(ctx, db.Pool, myID, w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	rec, err := creator.GetRecommendationStats(ctx, db.Pool, myID, w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"overview": overview, "recommendation": rec})
}

// GET /creator/insights — мушоҳидаҳо аз маълумоти воқеӣ.
func GetCreatorInsights(c *gin.Context) {
	w := creator.ParseWindow(c.Query("window"))
	insights, err := creator.BuildInsights(c.Request.Context(), db.Pool,
		mw.UID(c), w)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"insights": insights})
}

// POST /creator/ideas — пешниҳоди мӯҳтаво.
//
// Ин ягона ҷойест, ки LLM даъват мешавад — ва он бо дархости возеҳи
// эҷодкор рух медиҳад, на дар ҳар кушодани экран.
func GenerateCreatorIdeas(c *gin.Context) {
	if !ai.Enabled(ai.TaskChat) {
		c.JSON(http.StatusServiceUnavailable,
			gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Topic    string `json:"topic"`
		Format   string `json:"format"`
		Language string `json:"language"`
	}
	_ = c.ShouldBindJSON(&b)

	myID := mw.UID(c)
	ctx := c.Request.Context()

	// Заминаи ВОҚЕИИ эҷодкор — то пешниҳод ба ӯ мансуб бошад.
	ideaCtx, err := creator.BuildIdeaContext(ctx, db.Pool, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	lang := strings.TrimSpace(b.Language)
	if lang == "" {
		lang = ideaCtx.Language
	}
	topic := strings.TrimSpace(b.Topic)
	if topic == "" && len(ideaCtx.TopTopics) > 0 {
		topic = ideaCtx.TopTopics[0]
	}

	// Кэш: ҳамон эҷодкор + мавзӯъ + забон дар як соат такрор
	// даъвати модел намекунад.
	cacheKey := "creatorideas:" + myID + ":" + topic + ":" + lang
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	langName := map[string]string{
		"tj": "Tajik", "ru": "Russian", "en": "English",
	}[lang]
	if langName == "" {
		langName = "Tajik"
	}

	sys := "You generate ORIGINAL short-form content ideas for a creator on " +
		"Raonson, a Tajik social app. Reply ONLY with JSON: " +
		`{"ideas":[{"title":"","hook":"","idea":"","format":"","duration":"","hashtags":[""],"cta":""}]}. ` +
		"Give 4 ideas. Write every field in " + langName + ". " +
		"Never copy an existing video, song, script or another creator's work. " +
		"Never suggest anything unsafe, sexual, or targeting a private person."

	user := "Creator's best topics: " + strings.Join(ideaCtx.TopTopics, ", ") + ". "
	if topic != "" {
		user += "Focus topic: " + topic + ". "
	}
	if b.Format != "" {
		user += "Preferred format: " + b.Format + ". "
	}
	if len(ideaCtx.RecentTitles) > 0 {
		user += "Do NOT repeat these recent captions: " +
			strings.Join(ideaCtx.RecentTitles, " | ")
	}

	callCtx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()

	var out struct {
		Ideas []creator.ContentIdea `json:"ideas"`
	}
	if err := ai.CompleteJSON(callCtx, ai.TaskChat, []ai.Message{
		{Role: "system", Content: sys},
		{Role: "user", Content: user},
	}, ai.Options{Temperature: 0.9, MaxTokens: 1200}, &out); err != nil {
		// Хатои AI набояд ҳамчун хатои сервер нишон дода шавад —
		// ин хизмати иловагист.
		c.JSON(http.StatusOK, gin.H{"ideas": []creator.ContentIdea{},
			"message": "AI ҳозир ҷавоб дода натавонист"})
		return
	}
	if out.Ideas == nil {
		out.Ideas = []creator.ContentIdea{}
	}
	payload := gin.H{"ideas": out.Ideas}
	c.JSON(http.StatusOK, payload)
	cacheJSON(cacheKey, payload, time.Hour)
}
