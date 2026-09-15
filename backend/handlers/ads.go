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
	"errors"
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

// ── Роҳи Yandex: хабари барнома ──────────────────────────────────
//
// ⚠️ Yandex Rewarded SSV НАДОРАД — он ҳеҷ гоҳ ба /ads/callback занг
// намезанад. Ягона хабардиҳанда худи барнома аст, яъне манбаи
// бебовар. Ниг. ads/session.go: чаро ин ҷо имзо нест ва ба ҷои он
// чӣ ҳаст.

// adWatchReq — он чи барнома фиристода МЕТАВОНАД.
//
// Ин рӯйхат қасдан кӯтоҳ аст. Миқдори мукофот, зина, баланс ва
// шиносаи корбар ин ҷо НЕСТАНД: онҳоро сервер худаш муайян мекунад.
// Агар барнома онҳоро фиристад ҳам, gin онҳоро партофта мефиристад.
type adWatchReq struct {
	AdUnitID  string `json:"adUnitId"`
	SessionID string `json:"sessionId"`
	Platform  string `json:"platform"`
}

// POST /ads/watch-session — пеш аз нишон додани реклама.
func AdWatchSession(c *gin.Context) {
	var req adWatchReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Дархости нодуруст"})
		return
	}

	s, err := ads.CreateSession(c.Request.Context(), db.Pool,
		mw.UID(c), req.AdUnitID)
	if err != nil {
		if errors.Is(err, ads.ErrRewardedNotConfigured) {
			// Хусусият хомӯш аст — ва экран инро рост мегӯяд.
			c.JSON(http.StatusServiceUnavailable,
				gin.H{"message": "Реклама ҳоло дастрас нест"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"message": "Дархости нодуруст"})
		return
	}
	c.JSON(http.StatusOK, s)
}

// POST /ads/watched — пас аз он ки Yandex мукофотро эълон кард.
func AdWatched(c *gin.Context) {
	var req adWatchReq
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Дархости нодуруст"})
		return
	}

	userID := mw.UID(c)
	res, err := ads.ConsumeAndCredit(c.Request.Context(), db.Pool,
		userID, req.SessionID, req.AdUnitID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}

	if res == ads.ClaimCounted {
		granted, until, gerr := ads.GrantIfEarned(c.Request.Context(),
			db.Pool, userID)
		if gerr == nil && granted {
			NotifyEvent(ntf.Event{
				UserID:       userID,
				Kind:         ntf.Achievement,
				TargetID:     "verified",
				DedupeSuffix: until.Format("2006-01-02T15"),
			})
		}
	}

	// Пешрафт ҳамроҳ бармегардад, то барнома дархости дуюм назанад
	// ва рақамро худаш ҳисоб накунад.
	p, _ := ads.GetProgress(c.Request.Context(), db.Pool, userID)
	body := gin.H{
		"counted":  res == ads.ClaimCounted,
		"reason":   string(res),
		"progress": p,
	}

	switch res {
	case ads.ClaimCounted, ads.ClaimDailyCap:
		// Ҳадди рӯзона хато нест: реклама дида шуд, вале ҳисоб
		// намешавад. Барнома инро ором нишон медиҳад.
		c.JSON(http.StatusOK, body)
	case ads.ClaimDuplicate:
		c.JSON(http.StatusConflict, body)
	case ads.ClaimTooFast:
		c.JSON(http.StatusTooManyRequests, body)
	default:
		c.JSON(http.StatusForbidden, body)
	}
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
