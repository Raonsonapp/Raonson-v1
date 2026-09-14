package handlers

// Реклама → галочка.
//
// Ду роҳи гирифтани галочка:
//   • обуна (пул) — тавассути Google Play Billing;
//   • реклама — шумораи муайяни нишондиҳии ТАСДИҚШУДА.
//
// Ин файл роҳи дуюмро мебандад. Роҳи аввал ҳанӯз танзим нашудааст
// (ниг. ҷавоби /ads/progress: майдони `subscription`).

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/ads"
	"raonson/db"
	mw "raonson/middleware"
	ntf "raonson/notify"
)

// GET /ads/callback — шабакаи реклама пас аз нишондиҳии воқеӣ.
//
// ⚠️ Ин роҳ БЕ авторизатсияи корбар аст, чунки онро СЕРВЕРИ шабакаи
// реклама мезанад, на телефон. Бинобар ин ягона ҳимоя имзост.
//
// Бе имзои дуруст ҳеҷ чиз ҳисоб намешавад: вагарна ҳар кас бо
// 1200 дархост галочкаро ройгон мегирифт.
func AdCallback(c *gin.Context) {
	params := map[string]string{}
	for k, v := range c.Request.URL.Query() {
		if len(v) > 0 {
			params[k] = v[0]
		}
	}
	sig := params["signature"]
	delete(params, "signature")

	if err := ads.Verify(params, sig, time.Now()); err != nil {
		// Сабаб ба берун дода намешавад — он ба ҳамлакунанда кӯмак
		// мекунад. Дар log бошад, барои ташхис лозим аст.
		c.Status(http.StatusForbidden)
		return
	}

	userID := params["user_id"]
	impression := params["transaction_id"]
	if impression == "" {
		impression = params["impression_id"]
	}
	network := params["ad_network"]

	fresh, err := ads.Record(c.Request.Context(), db.Pool,
		userID, impression, network)
	if err != nil {
		c.Status(http.StatusInternalServerError)
		return
	}
	if !fresh {
		// Такрор ё ҳадди рӯзона — ин хато НЕСТ.
		c.Status(http.StatusOK)
		return
	}

	// Галочка ХУДКОР дода мешавад — корбар ҳеҷ тугмаро намезанад.
	granted, until, err := ads.GrantIfEarned(c.Request.Context(),
		db.Pool, userID)
	if err == nil && granted {
		NotifyEvent(ntf.Event{
			UserID:       userID,
			Kind:         ntf.Achievement,
			TargetID:     "verified",
			DedupeSuffix: until.Format("2006-01-02T15"),
		})
	}
	c.Status(http.StatusOK)
}

// GET /ads/progress — вазъи корбар.
func AdProgress(c *gin.Context) {
	p, err := ads.GetProgress(c.Request.Context(), db.Pool, mw.UID(c))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, p)
}

// PUT /ads/goal — корбар зинаи ҳадафро интихоб мекунад.
//
// Бе ин, касе ки моҳро мехоҳад, дар 300 реклама се рӯз мегирифт ва
// ҳисобаш сифр мешуд.
func SetAdGoal(c *gin.Context) {
	var b struct {
		Goal string `json:"goal"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "goal required"})
		return
	}
	if err := ads.SetGoal(c.Request.Context(), db.Pool, mw.UID(c), b.Goal); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Зинаи номаълум"})
		return
	}
	p, _ := ads.GetProgress(c.Request.Context(), db.Pool, mw.UID(c))
	c.JSON(http.StatusOK, p)
}
