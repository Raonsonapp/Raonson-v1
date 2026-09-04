package handlers

// Садои рилс — «Ин садоро истифода бар».
//
// Дар Instagram садо як объекти мустақил аст: онро пахш кардан мумкин
// аст, ҳамаи рилсҳои бо ҳамон садо сохташударо дидан мумкин аст ва
// садоро барои худ захира кардан мумкин аст. Дар Raonson садо танҳо
// НИШОН дода мешуд ва ҳеҷ ҷо захира намешуд.

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"

	"raonson/db"
	mw "raonson/middleware"
)

// AudioInput — садои интихобшуда ҳангоми сохтани рилс.
type AudioInput struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Artist     string `json:"artist"`
	CoverURL   string `json:"coverUrl"`
	PreviewURL string `json:"previewUrl"`
}

// clean маълумоти садоро тоза ва маҳдуд мекунад.
//
// Агар садо ном надошта бошад, он садои холист — сабт намешавад.
func (a AudioInput) clean() AudioInput {
	a.ID = clampRunes(strings.TrimSpace(a.ID), 100)
	a.Title = clampRunes(strings.TrimSpace(a.Title), 200)
	a.Artist = clampRunes(strings.TrimSpace(a.Artist), 200)
	a.CoverURL = clampRunes(strings.TrimSpace(a.CoverURL), 500)
	a.PreviewURL = clampRunes(strings.TrimSpace(a.PreviewURL), 500)
	return a
}

func (a AudioInput) isEmpty() bool { return a.ID == "" || a.Title == "" }

// registerAudio садоро дар реестр сабт мекунад ва шумориши
// истифодаро як воҳид зиёд мекунад.
//
// ON CONFLICT — садои якхела аз ду корбар як сатр мемонад.
func registerAudio(ctx context.Context, a AudioInput, ownerID string) {
	if a.isEmpty() {
		return
	}
	_, err := db.Pool.Exec(ctx, `
		INSERT INTO reel_audios(id, title, artist, cover_url, preview_url, owner_id, usage_count)
		VALUES ($1,$2,$3,$4,$5,$6,1)
		ON CONFLICT (id) DO UPDATE SET
		  usage_count = reel_audios.usage_count + 1,
		  -- Ном ва расм навсозӣ мешаванд, вале соҳиб не: садо аз они
		  -- касест, ки онро аввал сохт.
		  title       = EXCLUDED.title,
		  artist      = EXCLUDED.artist,
		  cover_url   = EXCLUDED.cover_url,
		  preview_url = EXCLUDED.preview_url`,
		a.ID, a.Title, a.Artist, a.CoverURL, a.PreviewURL, ownerID)
	if err != nil {
		// Сабти садо набояд сохтани рилсро қатъ кунад.
		logAudioErr("register", err)
	}
}

func logAudioErr(op string, err error) {
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		// Логи оддӣ — бе маълумоти корбар.
		println("reel audio:", op, err.Error())
	}
}

// GET /reels/audio/:id — маълумоти садо + рилсҳои бо он сохташуда.
func GetReelAudio(c *gin.Context) {
	audioID := c.Param("audioId")
	if audioID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "audio id лозим аст"})
		return
	}
	myID := mw.UID(c)
	ctx := c.Request.Context()

	var title, artist, cover, preview, ownerID string
	err := db.Pool.QueryRow(ctx, `
		SELECT title, COALESCE(artist,''), COALESCE(cover_url,''),
		       COALESCE(preview_url,''), COALESCE(owner_id,'')
		FROM reel_audios WHERE id=$1`, audioID).
		Scan(&title, &artist, &cover, &preview, &ownerID)
	if errors.Is(err, pgx.ErrNoRows) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Садо ёфт нашуд"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}

	// Шумориши воқеӣ аз рилсҳо — на сутуни эҳтимолан кӯҳнашуда.
	var count int
	db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM reels r JOIN users u ON u.id=r.user_id
		WHERE r.audio_id=$1 AND u.banned=FALSE`, audioID).Scan(&count)

	var saved bool
	if myID != "" {
		db.Pool.QueryRow(ctx, `
			SELECT EXISTS(SELECT 1 FROM saved_audios
			WHERE user_id=$1 AND audio_id=$2)`, myID, audioID).Scan(&saved)
	}

	// Рилсҳои бо ҳамин садо. Корбари блокшуда ва бандкардашуда берун.
	rows, err := db.Pool.Query(ctx, `
		SELECT r.id, COALESCE(r.thumbnail_url,''), r.video_url,
		       r.views_count, r.likes_count, u.id, u.username, u.avatar
		FROM reels r
		JOIN users u ON u.id = r.user_id
		WHERE r.audio_id=$1 AND u.banned=FALSE
		  AND NOT EXISTS (
		    SELECT 1 FROM blocks b
		    WHERE (b.blocker_id=$2 AND b.blocked_id=r.user_id)
		       OR (b.blocker_id=r.user_id AND b.blocked_id=$2))
		ORDER BY r.views_count DESC, r.created_at DESC
		LIMIT 60`, audioID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer rows.Close()

	reels := []gin.H{}
	for rows.Next() {
		var id, thumb, video, uid, uname, avatar string
		var views, likes int
		if err := rows.Scan(&id, &thumb, &video, &views, &likes,
			&uid, &uname, &avatar); err != nil {
			continue
		}
		reels = append(reels, gin.H{
			"_id": id, "thumbnailUrl": thumb, "videoUrl": video,
			"viewsCount": views, "likesCount": likes,
			"user": gin.H{"_id": uid, "username": uname, "avatar": avatar},
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"id": audioID, "title": title, "artist": artist,
		"coverUrl": cover, "previewUrl": preview,
		"ownerId": ownerID, "reelsCount": count, "saved": saved,
		"reels": reels,
	})
}

// POST /reels/audio/:id/save — захира ё бекор кардани захира.
func ToggleSaveAudio(c *gin.Context) {
	myID := mw.UID(c)
	audioID := c.Param("audioId")
	ctx := c.Request.Context()

	// Танҳо садои воқеан мавҷуд захира мешавад.
	var exists bool
	if err := db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM reel_audios WHERE id=$1)`,
		audioID).Scan(&exists); err != nil || !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "Садо ёфт нашуд"})
		return
	}

	tag, err := db.Pool.Exec(ctx,
		`DELETE FROM saved_audios WHERE user_id=$1 AND audio_id=$2`, myID, audioID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	if tag.RowsAffected() > 0 {
		c.JSON(http.StatusOK, gin.H{"saved": false})
		return
	}
	if _, err := db.Pool.Exec(ctx,
		`INSERT INTO saved_audios(user_id, audio_id) VALUES ($1,$2)
		 ON CONFLICT DO NOTHING`, myID, audioID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"saved": true})
}

// GET /reels/audio/saved — садоҳои захиракардаи корбар.
func GetSavedAudios(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT a.id, a.title, COALESCE(a.artist,''), COALESCE(a.cover_url,''),
		       COALESCE(a.preview_url,''), COALESCE(a.usage_count,0)
		FROM saved_audios s
		JOIN reel_audios a ON a.id = s.audio_id
		WHERE s.user_id=$1
		ORDER BY s.created_at DESC LIMIT 100`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, gin.H{"audios": scanAudioList(rows)})
}

// GET /reels/audio/trending — садоҳои маъмул.
//
// Танҳо садоҳое, ки дар 14 рӯзи охир воқеан истифода шудаанд — вагарна
// рӯйхат сол ба сол ҳамон садоҳоро нишон медиҳад.
func GetTrendingAudios(c *gin.Context) {
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT a.id, a.title, COALESCE(a.artist,''), COALESCE(a.cover_url,''),
		       COALESCE(a.preview_url,''), COUNT(r.id) AS recent
		FROM reel_audios a
		JOIN reels r ON r.audio_id = a.id
		JOIN users u ON u.id = r.user_id AND u.banned = FALSE
		WHERE r.created_at > NOW() - INTERVAL '14 days'
		GROUP BY a.id, a.title, a.artist, a.cover_url, a.preview_url
		ORDER BY recent DESC, a.usage_count DESC
		LIMIT 30`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, gin.H{"audios": scanAudioList(rows)})
}

func scanAudioList(rows pgx.Rows) []gin.H {
	out := []gin.H{}
	for rows.Next() {
		var id, title, artist, cover, preview string
		var count int
		if err := rows.Scan(&id, &title, &artist, &cover, &preview, &count); err != nil {
			continue
		}
		out = append(out, gin.H{
			"id": id, "title": title, "artist": artist,
			"coverUrl": cover, "previewUrl": preview, "reelsCount": count,
		})
	}
	return out
}

// reelAudioJSON садоро барои ҷавоб омода мекунад.
//
// Агар рилс садои интихобшуда надошта бошад, «садои аслии @корбар»
// нишон дода мешавад — ҳамон рафторе, ки Instagram дорад. Ин ном
// сохта нест: он воқеан садои худи видео аст.
func reelAudioJSON(id, title, artist, cover, username string) gin.H {
	if id == "" || title == "" {
		return gin.H{
			"id": "", "title": "оригинал садо", "artist": username,
			"coverUrl": "", "previewUrl": "", "isOriginal": true,
		}
	}
	return gin.H{
		"id": id, "title": title, "artist": artist,
		"coverUrl": cover, "previewUrl": "", "isOriginal": false,
	}
}
