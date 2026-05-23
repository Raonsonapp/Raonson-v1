package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// GET /reels/smart?page=1&limit=20
// Instagram-like Reels algorithm:
// 1. Дӯстонро аввал (50 балл)
// 2. Trending (кам вақт + зиёд view)
// 3. Нав нишондашуда нест (dedup)
// 4. Нав корбарони шабеҳ (interest graph)
func GetSmartReels(c *gin.Context) {
	myID  := mw.UID(c)
	page  := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 15) // Instagram 15 рил бор мекунад
	offset := (page - 1) * limit

	// Cache барои page 1 (30 сония)
	cacheKey := "smartreels:" + myID + ":" + c.Query("page")
	if page == 1 {
		if cached, ok := mw.CacheGet(cacheKey); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			return
		}
	}

	rows, err := db.Pool.Query(context.Background(), `
		WITH scored AS (
		  SELECT
		    r.id, r.video_url, r.caption, r.views_count,
		    r.likes_count, r.comments_count, r.created_at,
		    u.id AS uid, u.username, u.avatar, u.verified,
		    EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$1) AS liked,
		    EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$1) AS saved,
		    -- Алгоритми баллгузорӣ
		    (
		      -- 1. Дӯстон: +50
		      CASE WHEN f.following_id IS NOT NULL THEN 50 ELSE 0 END
		      -- 2. Engagement rate: likes/(views+1)*40
		      + LEAST(40, (r.likes_count::float / NULLIF(r.views_count,0) * 40))
		      -- 3. Рекентность: нав = баланд (max 30 балл, 24с кам мешавад)
		      + GREATEST(0, 30 - EXTRACT(EPOCH FROM (NOW()-r.created_at))/3600)
		      -- 4. Comments bonus
		      + LEAST(10, r.comments_count)
		      -- 5. Trending: views > 100 = +15
		      + CASE WHEN r.views_count > 100 THEN 15 ELSE 0 END
		      -- 6. Тасодуфӣ барои variety (0-10)
		      + (RANDOM() * 10)
		    ) AS score
		  FROM reels r
		  JOIN users u ON u.id=r.user_id
		  LEFT JOIN follows f ON f.follower_id=$1 AND f.following_id=r.user_id
		  WHERE
		    u.banned = FALSE
		    AND r.created_at > NOW() - INTERVAL '30 days'
		    -- Нишондашударо нишон намедиҳем
		    AND NOT EXISTS (
		      SELECT 1 FROM reel_views rv
		      WHERE rv.reel_id=r.id AND rv.user_id=$1
		      AND rv.viewed_at > NOW() - INTERVAL '24 hours'
		    )
		)
		SELECT id, video_url, caption, views_count, likes_count,
		       comments_count, created_at, uid, username, avatar,
		       verified, liked, saved, score
		FROM scored
		ORDER BY score DESC
		LIMIT $2 OFFSET $3
	`, myID, limit, offset)

	if err != nil {
		// Fallback ба оддӣ
		GetReels(c)
		return
	}
	defer rows.Close()

	reels := []gin.H{}
	for rows.Next() {
		var id, videoURL, cap, uid, uname, uavatar string
		var views, likes, comms int
		var verified, liked, saved bool
		var createdAt interface{}
		var score float64

		if err := rows.Scan(&id, &videoURL, &cap, &views, &likes,
			&comms, &createdAt, &uid, &uname, &uavatar,
			&verified, &liked, &saved, &score); err != nil {
			continue
		}
		reels = append(reels, gin.H{
			"id": id, "_id": id,
			"videoUrl": videoURL, "caption": cap,
			"viewsCount": views, "likesCount": likes,
			"commentsCount": comms, "createdAt": createdAt,
			"isLiked": liked, "isSaved": saved,
			"user": gin.H{
				"id": uid, "_id": uid,
				"username": uname, "avatar": uavatar,
				"verified": verified,
			},
		})
	}

	// Агар кам бошад, оддӣ илова мекунем
	if len(reels) < limit/2 {
		GetReels(c)
		return
	}

	result := gin.H{
		"reels": reels, "page": page,
		"limit": limit, "algo": "instagram_style",
	}

	if page == 1 {
		if b, err := json.Marshal(result); err == nil {
			mw.CacheSet(cacheKey, b, 30*time.Second)
		}
	}
	c.JSON(http.StatusOK, result)
}

// POST /reels/:id/view — view tracking (dedup барои алгоритм)
func TrackReelView(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)

	db.Pool.Exec(context.Background(), `
		INSERT INTO reel_views (user_id, reel_id, viewed_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (user_id, reel_id) DO UPDATE SET viewed_at=NOW()
	`, myID, rid)

	// Шумораи views зиёд мешавад
	db.Pool.Exec(context.Background(), `
		UPDATE reels SET views_count=views_count+1 WHERE id=$1
	`, rid)

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
