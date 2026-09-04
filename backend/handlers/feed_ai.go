package handlers

// «Лентаи AI» — қабати идорашавандаи тавсия.
//
// Ин handler-ҳо лентаи мавҷударо иваз намекунанд. Онҳо ба корбар
// имкон медиҳанд, ки афзалияти худро гӯяд ва бубинад, ки чаро чизе
// нишон дода шуд.

import (
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"raonson/db"
	"raonson/feedai"
	mw "raonson/middleware"
)

// GET /feed/preferences — профили тавсияи ХУДИ корбар.
//
// Профили каси дигар дастрас НЕСТ: маълумоти рафторӣ ҳассос аст ва
// id-и корбар аз токен меояд, на аз параметр.
func GetFeedPreferences(c *gin.Context) {
	prefs, err := feedai.GetPrefs(c.Request.Context(), db.Pool, mw.UID(c))
	if err != nil {
		c.JSON(http.StatusInternalServerError,
			gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, prefs)
}

// PUT /feed/preferences — танзимоти умумӣ.
func UpdateFeedPreferences(c *gin.Context) {
	var in feedai.PrefsInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	if len(in.Languages) > 10 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Забонҳо хеле зиёданд"})
		return
	}
	if err := feedai.SavePrefs(c.Request.Context(), db.Pool,
		mw.UID(c), in); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	invalidateFeedCache(mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"message": "Сабт шуд"})
}

// PUT /feed/preferences/topic — холи як мавзӯъ.
func SetFeedTopicPreference(c *gin.Context) {
	var b struct {
		Topic string   `json:"topic"`
		Score *float64 `json:"score"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Topic == "" || b.Score == nil {
		c.JSON(http.StatusBadRequest,
			gin.H{"message": "topic ва score лозиманд"})
		return
	}
	err := feedai.SetTopicScore(c.Request.Context(), db.Pool,
		mw.UID(c), strings.TrimSpace(b.Topic), *b.Score)
	switch {
	case errors.Is(err, feedai.ErrUnknownTopic):
		c.JSON(http.StatusNotFound, gin.H{"message": "Мавзӯъ ёфт нашуд"})
	case err != nil:
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
	default:
		invalidateFeedCache(mw.UID(c))
		c.JSON(http.StatusOK, gin.H{"message": "Сабт шуд"})
	}
}

// PUT /feed/preferences/creator — «бештар/камтар аз ин эҷодкор».
func SetFeedCreatorPreference(c *gin.Context) {
	var b struct {
		CreatorID string   `json:"creatorId"`
		Score     *float64 `json:"score"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.CreatorID == "" || b.Score == nil {
		c.JSON(http.StatusBadRequest,
			gin.H{"message": "creatorId ва score лозиманд"})
		return
	}
	if err := feedai.SetCreatorScore(c.Request.Context(), db.Pool,
		mw.UID(c), b.CreatorID, *b.Score); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}
	invalidateFeedCache(mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"message": "Сабт шуд"})
}

// POST /feed/feedback — сабти ҳодисаи тавсия.
//
// Ин endpoint зуд-зуд даъват мешавад, бинобар ин кор кам аст: сигнали
// заиф танҳо сабт мешавад ва job онро ҷамъбаст мекунад.
func RecordFeedFeedback(c *gin.Context) {
	var b struct {
		Event       string `json:"event"`
		ContentType string `json:"contentType"`
		ContentID   string `json:"contentId"`
		CreatorID   string `json:"creatorId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Event == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "event лозим аст"})
		return
	}
	in := feedai.FeedbackInput{
		Event:       feedai.Event(strings.ToUpper(strings.TrimSpace(b.Event))),
		ContentType: b.ContentType,
		ContentID:   b.ContentID,
		CreatorID:   b.CreatorID,
	}
	if err := feedai.RecordFeedback(c.Request.Context(), db.Pool,
		mw.UID(c), in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}
	// Сигнали қавӣ лентаро фавран тағйир медиҳад — кэш бояд равад.
	if in.Event == feedai.EventMoreLikeThis ||
		in.Event == feedai.EventLessLikeThis ||
		in.Event == feedai.EventCreatorMute ||
		in.Event == feedai.EventHide {
		invalidateFeedCache(mw.UID(c))
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// POST /feed/preferences/natural-language — фармони забони табиӣ.
func ParseFeedCommand(c *gin.Context) {
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text лозим аст"})
		return
	}
	text := strings.TrimSpace(b.Text)
	if text == "" || len([]rune(text)) > 500 {
		c.JSON(http.StatusBadRequest,
			gin.H{"message": "Матн бояд аз 1 то 500 аломат бошад"})
		return
	}

	ctx := c.Request.Context()
	topics, err := feedai.LoadTopics(ctx, db.Pool)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	intent, err := feedai.ParseIntent(text, topics)
	if err != nil {
		// Ин хатои сервер нест — корбар чизи нофаҳмо навишт.
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"message": "Нафаҳмидам. Мисол: «Бештар gaming, камтар ахбор»",
			"parsed":  intent,
		})
		return
	}
	if err := feedai.ApplyIntent(ctx, db.Pool, mw.UID(c), intent); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	invalidateFeedCache(mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"applied": intent})
}

// POST /feed/reset — тоза кардани афзалиятҳо.
//
// Танҳо маълумоти ТАВСИЯ нест мешавад. Аккаунт, обунаҳо, лайкҳо,
// шарҳҳо ва постҳои корбар даст нахӯрда мемонанд.
func ResetFeedPreferences(c *gin.Context) {
	var b struct {
		// keepExplicit=true — танҳо он чи система омӯхтааст тоза
		// мешавад; интихоби худи корбар мемонад.
		KeepExplicit bool `json:"keepExplicit"`
	}
	_ = c.ShouldBindJSON(&b)

	if err := feedai.ResetPrefs(c.Request.Context(), db.Pool,
		mw.UID(c), b.KeepExplicit); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	invalidateFeedCache(mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"message": "Танзимоти лента тоза шуд"})
}

// GET /feed/explanation/:contentType/:contentId — «Чаро инро мебинам?»
func GetFeedExplanation(c *gin.Context) {
	contentType := c.Param("contentType")
	contentID := c.Param("contentId")
	if contentType != "post" && contentType != "reel" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Навъи мӯҳтаво нодуруст"})
		return
	}
	ctx := c.Request.Context()

	// Эҷодкорро аз ҷадвали воқеӣ мегирем — client онро гуфта
	// наметавонад, вагарна касе метавонад шарҳи каси дигарро созад.
	var creatorID string
	table := "posts"
	if contentType == "reel" {
		table = "reels"
	}
	if err := db.Pool.QueryRow(ctx,
		`SELECT user_id FROM `+table+` WHERE id=$1`, contentID).
		Scan(&creatorID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Мӯҳтаво ёфт нашуд"})
		return
	}

	exp, err := feedai.Explain(ctx, db.Pool, mw.UID(c),
		contentType, contentID, creatorID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, exp)
}

// invalidateFeedCache кэши лентаи корбарро мебарорад.
//
// Бе ин, «монанди ин камтар» то анҷоми TTL ҳеҷ таъсир намекард ва
// корбар фикр мекард, ки тугма кор намекунад.
func invalidateFeedCache(userID string) {
	mw.CacheDel(
		"smartfeed:"+userID+":1", "smartfeed:"+userID+":2",
		"smartreels:"+userID+":1", "smartreels:"+userID+":2",
	)
}
