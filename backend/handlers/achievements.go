package handlers

// Дастовардҳо ва зинаи эҷодкор.
//
// Ҳама аз сервер ҳисоб мешавад. Client наметавонад нишон талаб кунад
// ва наметавонад зинаи худро эълон кунад.

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/creator"
	"raonson/db"
	mw "raonson/middleware"
)

// GET /creator/achievements — нишонҳо ва зина.
//
// Ҳангоми кушодан нишонҳои нав ҳисоб ва сабт мешаванд: барои ин job-и
// ҷудогона лозим нест ва эҷодкор натиҷаро фавран мебинад.
func GetCreatorAchievements(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()

	cacheKey := "achievements:" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	list, err := creator.SyncAchievements(ctx, db.Pool, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	level, err := creator.GetCreatorLevel(ctx, db.Pool, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}

	payload := gin.H{"achievements": list, "level": level}
	c.JSON(http.StatusOK, payload)
	cacheJSON(cacheKey, payload, 2*time.Minute)
}
