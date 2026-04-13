package handlers

import (
	"context"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── POST /posts/:id/report ────────────────────────────────────────
// Дигар user → жалоб мефиристад
func ReportPost(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}

	db.Pool.Exec(context.Background(),
		`INSERT INTO post_reports(post_id, user_id, reason, created_at)
		 VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`,
		pid, myID, b.Reason, time.Now())

	// Агар > 10 жалоб → автоматӣ пинҳон кун
	var count int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM post_reports WHERE post_id=$1`, pid).Scan(&count)
	if count >= 10 {
		db.Pool.Exec(context.Background(),
			`UPDATE posts SET hidden=TRUE WHERE id=$1`, pid)
	}

	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// ── POST /posts/:id/interest ──────────────────────────────────────
// "Интересно" — алгоритм бештар нишон медиҳад
func MarkInterest(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	db.Pool.Exec(context.Background(),
		`INSERT INTO post_interests(post_id, user_id, interested, created_at)
		 VALUES($1,$2,TRUE,$3)
		 ON CONFLICT(post_id, user_id) DO UPDATE SET interested=TRUE`,
		pid, myID, time.Now())

	// Score-ро зиёд кун
	db.Pool.Exec(context.Background(),
		`UPDATE posts SET interest_score = COALESCE(interest_score,0) + 1 WHERE id=$1`, pid)

	c.JSON(http.StatusOK, gin.H{"interested": true})
}

// ── POST /posts/:id/not_interest ─────────────────────────────────
// "Неинтересно" — пост аз feed пинҳон мешавад ба ин user
func MarkNotInterest(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	db.Pool.Exec(context.Background(),
		`INSERT INTO post_interests(post_id, user_id, interested, created_at)
		 VALUES($1,$2,FALSE,$3)
		 ON CONFLICT(post_id, user_id) DO UPDATE SET interested=FALSE`,
		pid, myID, time.Now())

	// Score-ро кам кун
	db.Pool.Exec(context.Background(),
		`UPDATE posts SET interest_score = COALESCE(interest_score,0) - 1 WHERE id=$1`, pid)

	c.JSON(http.StatusOK, gin.H{"not_interested": true, "hidden": true})
}

// ── PUT /posts/:id/caption ────────────────────────────────────────
// Соҳиби пост → тавсифро тағир медиҳад
func UpdatePostCaption(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Caption string `json:"caption"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "caption required"})
		return
	}

	res, _ := db.Pool.Exec(context.Background(),
		`UPDATE posts SET caption=$1, updated_at=NOW() WHERE id=$2 AND user_id=$3`,
		b.Caption, pid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found or not owner"})
		return
	}

	// Cache-ро тоза кун
	mw.CacheDel("feed:"+myID+":1", "smartfeed:"+myID+":1")
	c.JSON(http.StatusOK, gin.H{"updated": true, "caption": b.Caption})
}

// ── PUT /posts/:id/music ──────────────────────────────────────────
// Соҳиби пост → мусиқаро тағир медиҳад
func UpdatePostMusic(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		MusicTitle  string `json:"musicTitle"`
		MusicArtist string `json:"musicArtist"`
		MusicUrl    string `json:"musicUrl"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "music data required"})
		return
	}

	res, _ := db.Pool.Exec(context.Background(),
		`UPDATE posts SET music_title=$1, music_artist=$2, music_url=$3, updated_at=NOW()
		 WHERE id=$4 AND user_id=$5`,
		b.MusicTitle, b.MusicArtist, b.MusicUrl, pid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found or not owner"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"updated": true})
}

// ── GET /posts/:id/stats ──────────────────────────────────────────
// Соҳиби пост → статистика мебинад
func GetPostStats(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	// Танҳо соҳиб мебинад
	var ownerID string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM posts WHERE id=$1`, pid).Scan(&ownerID)
	if ownerID != myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Not your post"})
		return
	}

	var likes, comments, views, saves, reports int
	db.Pool.QueryRow(context.Background(),
		`SELECT likes_count, comments_count,
		        (SELECT COUNT(*) FROM post_views   WHERE post_id=$1),
		        (SELECT COUNT(*) FROM post_saves   WHERE post_id=$1),
		        (SELECT COUNT(*) FROM post_reports WHERE post_id=$1)
		 FROM posts WHERE id=$1`, pid).Scan(&likes, &comments, &views, &saves, &reports)

	c.JSON(http.StatusOK, gin.H{
		"likes":    likes,
		"comments": comments,
		"views":    views,
		"saves":    saves,
		"reports":  reports,
	})
}
