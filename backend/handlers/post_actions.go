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

// ── POST /posts/:id/hide-likes ── (toggle) танҳо соҳиб ──
func TogglePostHideLikes(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	var hide bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET hide_likes = NOT COALESCE(hide_likes,false)
		 WHERE id=$1 AND user_id=$2 RETURNING hide_likes`, pid, myID).Scan(&hide)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"hideLikes": hide})
}

// ── POST /posts/:id/toggle-comments ── (toggle) танҳо соҳиб ──
func TogglePostComments(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	var off bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET comments_off = NOT COALESCE(comments_off,false)
		 WHERE id=$1 AND user_id=$2 RETURNING comments_off`, pid, myID).Scan(&off)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"commentsOff": off})
}

// ── POST /posts/:id/archive ── (toggle) танҳо соҳиб ──
func TogglePostArchive(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	var arch bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET archived = NOT COALESCE(archived,false)
		 WHERE id=$1 AND user_id=$2 RETURNING archived`, pid, myID).Scan(&arch)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	mw.CacheDel("explore:grid")
	c.JSON(http.StatusOK, gin.H{"archived": arch})
}

// ── POST /reels/:id/hide-likes ── (toggle) танҳо соҳиб ──
func ToggleReelHideLikes(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var hide bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE reels SET hide_likes = NOT COALESCE(hide_likes,false)
		 WHERE id=$1 AND user_id=$2::text RETURNING hide_likes`, rid, myID).Scan(&hide)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"hideLikes": hide})
}

// ── POST /reels/:id/toggle-comments ── (toggle) танҳо соҳиб ──
func ToggleReelComments(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var off bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE reels SET comments_off = NOT COALESCE(comments_off,false)
		 WHERE id=$1 AND user_id=$2::text RETURNING comments_off`, rid, myID).Scan(&off)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"commentsOff": off})
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

// ── POST /posts/:id/not-interested ────────────────────────────────
// Пост аз feed-и алгоритмии ин корбар доимӣ пинҳон мешавад.
func PostNotInterested(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	if pid == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad post"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_not_interested(post_id, user_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING`, pid, myID)
	mw.CacheDel("feed:"+myID+":1", "feed:"+myID+":2",
		"smartfeed:"+myID+":1", "smartfeed:"+myID+":2")
	c.JSON(http.StatusOK, gin.H{"not_interested": true})
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

	// Аудитория: бинандагоне, ки ба муаллиф обуна шудаанд vs дигарон.
	var fromFollowers, fromOthers int
	db.Pool.QueryRow(context.Background(),
		`SELECT
		   COUNT(*) FILTER (WHERE f.follower_id IS NOT NULL),
		   COUNT(*) FILTER (WHERE f.follower_id IS NULL)
		 FROM post_views pv
		 LEFT JOIN follows f
		   ON f.follower_id = pv.user_id AND f.following_id = $2
		 WHERE pv.post_id = $1`, pid, myID).Scan(&fromFollowers, &fromOthers)

	// shares — ҳоло ҷадвали post_shares нест → 0.
	c.JSON(http.StatusOK, gin.H{
		"likes":         likes,
		"comments":      comments,
		"views":         views,
		"saves":         saves,
		"reports":       reports,
		"shares":        0,
		"fromFollowers": fromFollowers,
		"fromOthers":    fromOthers,
	})
}
