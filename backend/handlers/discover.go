package handlers

// Кашфиёт: «Кашфи имрӯз», Trend Radar, эҷодкорони боло раванда.
//
// Ин ҷо алгоритми ДУЮМИ лента сохта намешавад. Бахши «Барои шумо»
// маҳз ҳамон GetSmartFeed-ро истифода мебарад; ин ҷо танҳо бахшҳои
// кашфиёт ҷамъ карда мешаванд.

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/db"
	"raonson/discover"
	"raonson/feedai"
	mw "raonson/middleware"
)

// GET /discover — «Кашфи имрӯз».
//
// Ҳама бахшҳо дар як дархост. Кэши кӯтоҳ: тренд ва эҷодкорон дар
// паснамо ҳисоб мешаванд ва дар як дақиқа тағйир намеёбанд.
func GetDiscoverToday(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()

	cacheKey := "discover:" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	trends, err := discover.GetTrends(ctx, db.Pool, 10)
	if err != nil {
		trends = []discover.Trend{}
	}
	rising, err := discover.GetRisingCreators(ctx, db.Pool, myID, 10)
	if err != nil {
		rising = []discover.RisingCreator{}
	}

	// «Одамони мувофиқ» — ҳамон engine-и Лентаи AI, на нусхаи нав.
	people, err := feedai.FindPeople(ctx, db.Pool, myID, nil, 10)
	if err != nil {
		people = []feedai.Person{}
	}

	// Мавзӯъҳои корбар — барои бахши «Мавзӯъҳо барои шумо».
	prefs, err := feedai.GetPrefs(ctx, db.Pool, myID)
	topics := []gin.H{}
	if err == nil {
		for _, t := range prefs.Topics {
			if t.Score > 0.05 {
				topics = append(topics, gin.H{
					"slug": t.Slug, "nameTj": t.NameTJ,
					"nameRu": t.NameRU, "nameEn": t.NameEN,
					"score": t.Score,
				})
			}
			if len(topics) >= 6 {
				break
			}
		}
	}

	payload := gin.H{
		"trends":          trends,
		"risingCreators":  rising,
		"suggestedPeople": people,
		"topicsForYou":    topics,
	}
	c.JSON(http.StatusOK, payload)
	cacheJSON(cacheKey, payload, time.Minute)
}

// GET /discover/trending — танҳо Trend Radar.
func GetTrendRadar(c *gin.Context) {
	trends, err := discover.GetTrends(c.Request.Context(), db.Pool, 20)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"trends": trends})
}

// GET /discover/people — эҷодкорони боло раванда + мувофиқ.
//
// Ду рӯйхати ҷудогона: «боло раванда» аз рафтори платформа меояд,
// «мувофиқ» аз шавқи ХУДИ корбар. Онҳо ба саволҳои гуногун ҷавоб
// медиҳанд ва омехта кардани онҳо ҳарду сабабро гум мекард.
func GetDiscoverPeople(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()

	rising, err := discover.GetRisingCreators(ctx, db.Pool, myID, 20)
	if err != nil {
		rising = []discover.RisingCreator{}
	}
	people, err := feedai.FindPeople(ctx, db.Pool, myID, nil, 20)
	if err != nil {
		people = []feedai.Person{}
	}
	c.JSON(http.StatusOK, gin.H{
		"rising":    rising,
		"suggested": people,
	})
}
