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
	myID := mw.UID(c)
	page := toInt(c.Query("page"), 1)
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
		WITH my_likes AS (
		  -- Маҳдуд: завқ аз фаъолияти нав меояд. Бе ин ҳар дархост
		  -- тамоми таърихи лайкҳои корбарро скан мекард.
		  SELECT reel_id FROM reel_likes WHERE user_id=$1 LIMIT 300
		),
		my_saves AS (
		  SELECT reel_id FROM reel_saves WHERE user_id=$1 LIMIT 200
		),
		aff AS (
		  -- Завқи корбар: эҷодкороне, ки реалҳояшонро лайк/сейв кардааст.
		  -- like=3 балл, save=5 балл (save сигнали қавитар).
		  SELECT creator_id, SUM(w)::int AS aff FROM (
		    SELECT r2.user_id AS creator_id, 3 AS w
		      FROM my_likes ml JOIN reels r2 ON r2.id=ml.reel_id
		    UNION ALL
		    SELECT r3.user_id, 5
		      FROM my_saves ms JOIN reels r3 ON r3.id=ms.reel_id
		  ) t GROUP BY creator_id
		),
		cr AS (
		  -- Сатҳи итмоми тамошо барои ҳар reel (0..1).
		  -- Танҳо 30 рӯзи охир: query-и берунӣ ҳам ҳамин давраро мегирад,
		  -- вале бе ин филтр ин CTE ТАМОМИ ҷадвали reel_watch-ро (ҳар
		  -- тамошои ҳар корбар, ҳамеша) дар ҳар дархост агрегат мекард.
		  SELECT reel_id,
		         AVG(CASE WHEN completed THEN 1.0 ELSE 0.0 END) AS completion_rate
		    FROM reel_watch
		   WHERE created_at > NOW() - INTERVAL '30 days'
		   GROUP BY reel_id
		),
		scored AS (
		  SELECT
		    r.id, r.video_url, COALESCE(r.video_url_low,'') AS video_url_low,
		    COALESCE(r.thumbnail_url,'') AS thumbnail_url,
		    r.caption, r.views_count,
		    COALESCE(r.audio_id,'')     AS audio_id,
		    COALESCE(r.audio_title,'')  AS audio_title,
		    COALESCE(r.audio_artist,'') AS audio_artist,
		    COALESCE(r.audio_cover,'')  AS audio_cover,
		    CASE WHEN COALESCE(r.hide_likes,false) AND r.user_id <> $1
		         THEN -1 ELSE r.likes_count END AS likes_count,
		    r.comments_count, r.created_at,
		    u.id AS uid, u.username, u.avatar, u.verified,
		    EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$1) AS liked,
		    EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$1) AS saved,
		    EXISTS(SELECT 1 FROM follows fo WHERE fo.follower_id=$1 AND fo.following_id=r.user_id) AS following,
		    COALESCE(r.hide_likes,false) AS hide_likes,
		    COALESCE(r.comments_off,false) AS comments_off,
		    EXISTS(SELECT 1 FROM stories s WHERE s.user_id=r.user_id AND s.expires_at > NOW() AND COALESCE(s.archived,false)=FALSE AND (s.user_id=$1 OR EXISTS(SELECT 1 FROM follows hf WHERE hf.follower_id=$1 AND hf.following_id=s.user_id)) AND (s.user_id=$1 OR COALESCE(s.audience,'all')='all' OR EXISTS(SELECT 1 FROM close_friends hcf WHERE hcf.user_id=s.user_id AND hcf.friend_id=$1))) AS has_story,
		    -- Алгоритми баллгузорӣ
		    (
		      -- 1. Дӯстон: +50
		      CASE WHEN f.following_id IS NOT NULL THEN 50 ELSE 0 END
		      -- 2. Engagement rate: likes/(views+1)*40
		      -- COALESCE лозим: агар views_count=0 бошад, NULLIF NULL медиҳад ва
		      -- бе он тамоми score ба NULL табдил меёфт (reel-ҳои нав аз рейтинг мебаромаданд).
		      + COALESCE(LEAST(40, (r.likes_count::float / NULLIF(r.views_count,0) * 40)), 0)
		      -- 3. Рекентность: нав = баланд (max 30 балл, 24с кам мешавад)
		      + GREATEST(0, 30 - EXTRACT(EPOCH FROM (NOW()-r.created_at))/3600)
		      -- 4. Comments bonus
		      + LEAST(10, r.comments_count)
		      -- 5. Trending: views > 100 = +15
		      + CASE WHEN r.views_count > 100 THEN 15 ELSE 0 END
		      -- 5b. Completion rate: ҳиссаи тамошои пурра — то +20
		      + LEAST(20, COALESCE(cr.completion_rate,0) * 20)
		      -- 6. Завқ (taste): эҷодкори маҳбуб — то +50
		      + LEAST(50, COALESCE(af.aff,0) * 6)
		      -- 7. Тасодуфӣ барои variety (0-8)
		      + (RANDOM() * 8)
		    ) AS score
		  FROM reels r
		  JOIN users u ON u.id=r.user_id
		  LEFT JOIN follows f ON f.follower_id=$1 AND f.following_id=r.user_id
		  LEFT JOIN aff af ON af.creator_id = u.id
		  LEFT JOIN cr ON cr.reel_id = r.id
		  WHERE
		    u.banned = FALSE
		    AND r.created_at > NOW() - INTERVAL '30 days'
		    -- Нишондашударо нишон намедиҳем
		    AND NOT EXISTS (
		      SELECT 1 FROM reel_views rv
		      WHERE rv.reel_id=r.id AND rv.user_id=$1
		      AND rv.viewed_at > NOW() - INTERVAL '24 hours'
		    )
		    -- Корбари блокшуда
		    AND NOT EXISTS (
		      SELECT 1 FROM blocks b
		      WHERE (b.blocker_id=$1 AND b.blocked_id=r.user_id)
		         OR (b.blocker_id=r.user_id AND b.blocked_id=$1)
		    )
		    -- "Маро шавқманд намекунад"
		    AND NOT EXISTS (
		      SELECT 1 FROM reel_not_interested rni
		      WHERE rni.reel_id=r.id AND rni.user_id=$1
		    )
		    -- Корбари хомӯшкардашуда (muted)
		    AND NOT EXISTS (
		      SELECT 1 FROM muted_users mu
		      WHERE mu.user_id=$1 AND mu.muted_id=r.user_id
		    )
		)
		SELECT id, video_url, video_url_low, thumbnail_url, caption,
		       views_count, likes_count,
		       comments_count, created_at, uid, username, avatar,
		       verified, liked, saved, following, hide_likes, comments_off,
		       has_story, audio_id, audio_title, audio_artist, audio_cover, score
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
		var id, videoURL, videoURLLow, thumb, cap, uid, uname, uavatar string
		var audioID, audioTitle, audioArtist, audioCover string
		var views, likes, comms int
		var verified, liked, saved, following, hideLikes, commentsOff, hasStory bool
		var createdAt interface{}
		var score float64

		if err := rows.Scan(&id, &videoURL, &videoURLLow, &thumb, &cap, &views, &likes,
			&comms, &createdAt, &uid, &uname, &uavatar,
			&verified, &liked, &saved, &following, &hideLikes, &commentsOff,
			&hasStory, &audioID, &audioTitle, &audioArtist, &audioCover,
			&score); err != nil {
			continue
		}
		reels = append(reels, gin.H{
			"id": id, "_id": id,
			"videoUrl": videoURL, "videoUrlLow": videoURLLow,
			"thumbnailUrl": thumb, "caption": cap,
			"viewsCount": views, "likesCount": likes,
			"commentsCount": comms, "createdAt": createdAt,
			"isLiked": liked, "isSaved": saved,
			"hideLikes": hideLikes, "commentsDisabled": commentsOff,
			"audio": reelAudioJSON(audioID, audioTitle, audioArtist, audioCover, uname),
			"user": gin.H{
				"id": uid, "_id": uid,
				"username": uname, "avatar": uavatar,
				"verified": verified, "isFollowing": following,
				"hasStory": hasStory,
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
	rid := c.Param("id")
	myID := mw.UID(c)

	// Ҳар як user танҳо 1 маротиба ҳисоб мешавад.
	// DO NOTHING → RowsAffected танҳо ҳангоми дидани АВВАЛИН > 0 мешавад.
	ct, err := db.Pool.Exec(context.Background(), `
		INSERT INTO reel_views (user_id, reel_id, viewed_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (user_id, reel_id) DO NOTHING
	`, myID, rid)

	// Шумораи views танҳо ҳангоми бори АВВАЛ зиёд мешавад
	if err == nil && ct.RowsAffected() > 0 {
		db.Pool.Exec(context.Background(), `
			UPDATE reels SET views_count=views_count+1 WHERE id=$1
		`, rid)
	}

	c.JSON(http.StatusOK, gin.H{"ok": true})
}
