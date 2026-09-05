package handlers

import (
	"net/http"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/push"

	"github.com/gin-gonic/gin"
)

// ── Токени дастгоҳ ───────────────────────────────────────────────
//
// Худи фиристодан дар пакети push аст (FCM HTTP v1). Танзимот:
// FCM_SERVICE_ACCOUNT_JSON ё FCM_SERVICE_ACCOUNT_FILE.
//
// FCM_SERVER_KEY-и қаблӣ дигар кор НАМЕКУНАД: Google Legacy API-ро
// хомӯш кард ва он суроға 404 бармегардонад.

// POST /notifications/push-token   ← барнома токени FCM-ро мефиристад
//
// Як дастгоҳ — як сатр. Ҷадвали қаблӣ UNIQUE(user_id, platform) дошт,
// яъне телефон ва планшети ҳамон корбар ҳамдигарро мепӯшониданд ва
// огоҳинома танҳо ба дастгоҳи охирин мерасид.
func SavePushToken(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Token    string `json:"token"`
		Platform string `json:"platform"` // android | ios
		// DeviceID ихтиёрист: бо он токени кӯҳнаи ҲАМОН дастгоҳ пок
		// мешавад, вагарна сатрҳои мурда ҷамъ мешаванд.
		DeviceID string `json:"deviceId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "token required"})
		return
	}
	if err := push.SaveToken(c.Request.Context(), db.Pool,
		myID, b.Token, b.Platform, b.DeviceID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"saved": true})
}

// DELETE /notifications/push-token — баромадан аз аккаунт дар ин дастгоҳ.
//
// Бе ин, огоҳиномаҳои корбари қаблӣ ба ҳамон телефон мерафтанд.
func DeletePushToken(c *gin.Context) {
	var b struct {
		Token string `json:"token"`
	}
	c.ShouldBindJSON(&b)
	if b.Token == "" {
		b.Token = c.Query("token")
	}
	push.DeleteToken(c.Request.Context(), db.Pool, mw.UID(c), b.Token)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}
