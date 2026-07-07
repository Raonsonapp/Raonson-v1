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

// GET /posts/smart-feed
// Algorithm:
// 1. Posts аз одамони обуна (following) — охирин 48 соат
// 2. Маъмул постҳо — likes > 10 — охирин 7 рӯз
// 3. Ташрифи якхела — дубора намеояд
func GetSmartFeed(c *gin.Context) {
	myID  := mw.UID(c)
	page  := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 20)
	offset := (page - 1) * limit

	cacheKey := "smartfeed:" + myID + ":" + c.Query("page")
	if page <= 2 {
		if cached, ok := mw.CacheGet(cacheKey); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			return
		}
	}

	// Smart feed query:
	// Priority 1: Following posts (last 48h)
	// Priority 2: Popular posts (likes > 5, last 7 days)
	// Exclude: already seen (post_views table)
	rows, err := db.Pool.Query(context.Background(), `
		WITH paff AS (
		  -- Завқи корбар: эҷодкороне, ки постҳояшонро лайк/сейв кардааст.
		  SELECT creator_id, SUM(w)::int AS aff FROM (
		    SELECT p2.user_id AS creator_id, 3 AS w
		      FROM post_likes pl2 JOIN posts p2 ON p2.id=pl2.post_id
		      WHERE pl2.user_id=$1
		    UNION ALL
		    SELECT p3.user_id, 5
		      FROM post_saves ps3 JOIN posts p3 ON p3.id=ps3.post_id
		      WHERE ps3.user_id=$1
		  ) t GROUP BY creator_id
		)
		SELECT DISTINCT
		  p.id, p.caption,
		  CASE WHEN COALESCE(p.hide_likes,false) AND p.user_id <> $1
		       THEN -1 ELSE p.likes_count END AS likes_count,
		  p.comments_count, p.created_at,
		  u.id, u.username, u.avatar, u.verified,
		  (SELECT COALESCE(json_agg(
		           json_build_object('url',m.url,'type',m.type,'aspectRatio',COALESCE(m.aspect_ratio,0))
		           ORDER BY m.position),'[]'::json)
		   FROM post_media m WHERE m.post_id=p.id) AS media,
		  EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1) AS liked,
		  EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$1) AS saved,
		  COALESCE(p.hide_likes,false) AS hide_likes,
		  COALESCE(p.comments_off,false) AS comments_off,
		  COALESCE(p.music_title,''), COALESCE(p.music_artist,''),
		  COALESCE(p.location,''), COALESCE(p.tagged_users,'{}'),
		  COALESCE(p.is_product,false), COALESCE(p.price,0),
		  COALESCE(p.currency,'TJS'), COALESCE(p.product_name,''),
		  COALESCE(p.contact_raonson,false), COALESCE(p.shop_whatsapp,''),
		  COALESCE(p.shop_phone,''),
		  EXISTS(SELECT 1 FROM stories s WHERE s.user_id=u.id AND s.expires_at > NOW()),
		  -- Instagram-монанд score: following + тозагӣ + лайк + коммент
		  --   + interest score − ҷарима барои дидашуда
		  (CASE WHEN f.following_id IS NOT NULL THEN 100 ELSE 0 END
		   + GREATEST(0, 50 - EXTRACT(EPOCH FROM (NOW()-p.created_at))/3600)
		   + LEAST(50, p.likes_count)
		   + LEAST(30, p.comments_count*2)
		   + LEAST(40, COALESCE(p.interest_score,0))
		   + LEAST(45, COALESCE(pa.aff,0) * 6)
		   - CASE WHEN pv.post_id IS NOT NULL THEN 45 ELSE 0 END
		  ) AS score
		FROM posts p
		JOIN users u ON u.id=p.user_id
		LEFT JOIN follows     f  ON f.follower_id=$1 AND f.following_id=p.user_id
		LEFT JOIN post_views  pv ON pv.post_id=p.id AND pv.user_id=$1
		LEFT JOIN paff        pa ON pa.creator_id=p.user_id
		WHERE
		  u.banned = FALSE
		  AND COALESCE(p.hidden,false) = FALSE
		  AND COALESCE(p.archived,false) = FALSE
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())
		  AND NOT EXISTS(SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$1 AND b.blocked_id=p.user_id)
		           OR (b.blocker_id=p.user_id AND b.blocked_id=$1))
		  AND NOT EXISTS(SELECT 1 FROM post_interests pi
		        WHERE pi.post_id=p.id AND pi.user_id=$1 AND pi.interested=FALSE)
		  AND NOT EXISTS (SELECT 1 FROM muted_users mu
		        WHERE mu.user_id=$1 AND mu.muted_id=p.user_id)
		  AND NOT EXISTS (SELECT 1 FROM post_not_interested pni
		        WHERE pni.post_id=p.id AND pni.user_id=$1)
		  AND (
		    (f.following_id IS NOT NULL AND p.created_at > NOW() - INTERVAL '7 days')
		    OR
		    (p.likes_count >= 3 AND p.created_at > NOW() - INTERVAL '3 days')
		  )
		ORDER BY score DESC, p.created_at DESC
		LIMIT $2 OFFSET $3`,
		myID, limit, offset)

	if err != nil {
		// Fallback to regular feed
		GetFeed(c)
		return
	}
	defer rows.Close()

	posts := []gin.H{}
	for rows.Next() {
		var pid, cap, uid, uname, uavatar string
		var likes, comms int
		var verified, liked, saved, hideLikes, commentsOff bool
		var createdAt, media interface{}
		var musicTitle, musicArtist, location string
		var tagged []string
		var hasStory bool
		var score float64
		var isProduct, contactRaonson bool
		var price float64
		var currency, productName, shopWhatsapp, shopPhone string
		rows.Scan(&pid, &cap, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &media, &liked, &saved,
			&hideLikes, &commentsOff,
			&musicTitle, &musicArtist, &location, &tagged,
			&isProduct, &price, &currency, &productName,
			&contactRaonson, &shopWhatsapp, &shopPhone,
			&hasStory, &score)
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap, "likesCount": likes,
			"commentsCount": comms, "createdAt": createdAt,
			"media": nilToEmpty(media), "liked": liked, "saved": saved,
			"hideLikes": hideLikes, "commentsOff": commentsOff,
			"musicTitle": musicTitle, "musicArtist": musicArtist,
			"location": location, "taggedUsers": tagged,
			"isProduct": isProduct, "price": price, "currency": currency,
			"productName": productName, "contactRaonson": contactRaonson,
			"shopWhatsapp": shopWhatsapp, "shopPhone": shopPhone,
			"user": gin.H{
				"_id": uid, "username": uname,
				"avatar": uavatar, "verified": verified, "hasStory": hasStory,
			},
		})
	}

	// If not enough posts, fill with regular feed
	if len(posts) < limit/2 {
		GetFeed(c)
		return
	}

	result := gin.H{"posts": posts, "page": page, "limit": limit, "algo": "smart"}
	if page <= 2 {
		if b, err := json.Marshal(result); err == nil {
			mw.CacheSet(cacheKey, b, 60*time.Second)
		}
	}
	c.JSON(http.StatusOK, result)
}

// POST /posts/:id/view — track viewed posts (for feed dedup)
func TrackPostView(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	// Synchronous — query is tiny; avoids unbounded goroutine spawn under load
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_views(user_id,post_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, pid)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
