package handlers

// Ҷамъбасти ҳафтагӣ — «Ҳафтаи шумо дар Raonson».
//
// Ҳафтаи ГУЗАШТА як бор ҳисоб мешавад ва дигар тағйир намеёбад,
// бинобар ин он дар ҷадвал нигоҳ дошта мешавад. Ҳафтаи ҶОРӢ ҳанӯз
// пур нашудааст ва ҳар бор аз нав ҳисоб мешавад — вале бо кэши кӯтоҳ.

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/creator"
	"raonson/db"
	mw "raonson/middleware"
)

// recapWeek ҳафтаи дархостшударо муайян мекунад.
//
// Пешфарз — ҳафтаи ГУЗАШТАи пурра: ҷамъбасти ҳафтаи нимкора
// рақамҳои нопурраро ҳамчун натиҷаи ниҳоӣ нишон медиҳад.
// `?week=current` ҳафтаи ҷориро медиҳад, барои онҳое ки ҳозир
// дидан мехоҳанд.
func recapWeek(c *gin.Context) (start time.Time, current bool) {
	this := creator.WeekStart(time.Now())
	if c.Query("week") == "current" {
		return this, true
	}
	return this.AddDate(0, 0, -7), false
}

// GET /recap/week — ҷамъбасти бинанда.
func GetViewerRecap(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()
	week, current := recapWeek(c)

	// Ҳафтаи гузашта: агар аллакай ҳисоб шуда бошад, ҳамонро медиҳем.
	if !current {
		var saved creator.ViewerRecap
		if ok, _ := creator.LoadRecap(ctx, db.Pool, myID, "viewer",
			week, &saved); ok {
			c.JSON(http.StatusOK, gin.H{"recap": saved, "current": false})
			return
		}
	}

	r, err := creator.BuildViewerRecap(ctx, db.Pool, myID, week)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	// Ҳафтаи пурра дигар тағйир намеёбад — як бор нигоҳ медорем.
	//
	// Ҷамъбасти холӣ нигоҳ дошта НАМЕШАВАД: мавзӯъҳо дар паснамо
	// таъин мешаванд ва кор карда метавонад қафо монад — сифри
	// муваққатӣ набояд абадӣ шавад.
	if !current && r.HasEnoughData {
		creator.SaveRecap(ctx, db.Pool, myID, "viewer", week, r)
	}
	c.JSON(http.StatusOK, gin.H{"recap": r, "current": current})
}

// GET /creator/recap/week — ҷамъбасти эҷодкор.
func GetCreatorRecap(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()
	week, current := recapWeek(c)

	if !current {
		var saved creator.CreatorRecap
		if ok, _ := creator.LoadRecap(ctx, db.Pool, myID, "creator",
			week, &saved); ok {
			c.JSON(http.StatusOK, gin.H{"recap": saved, "current": false})
			return
		}
	}

	// Ҳисоби эҷодкор гаронтар аст — кэши кӯтоҳ барои ҳафтаи ҷорӣ.
	cacheKey := "recap:creator:" + myID + ":" + week.Format("2006-01-02")
	if current {
		if cached, ok := mw.CacheGet(cacheKey); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			return
		}
	}

	r, err := creator.BuildCreatorRecap(ctx, db.Pool, myID, week)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	if !current && r.HasEnoughData {
		creator.SaveRecap(ctx, db.Pool, myID, "creator", week, r)
	}
	body := gin.H{"recap": r, "current": current}
	if current {
		cacheJSON(cacheKey, body, 5*time.Minute)
	}
	c.JSON(http.StatusOK, body)
}
