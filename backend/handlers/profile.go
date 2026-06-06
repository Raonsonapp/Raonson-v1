package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// GET /profile/me — with 30s personal cache
func GetMyProfile(c *gin.Context) {
	myID := mw.UID(c)

	// Personal cache key
	cacheKey := "profile:me:" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", myID)
	u, err := scanFullUser(row)
	if err != nil {
		log.Printf("[Profile] GetMyProfile error: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	clearExpiredNote(myID, u)
	u["isFollowing"] = false

	// Постҳо ва маълумот якҷо — 1 trip to DB
	posts := postsForUser(myID, 30)
	result := gin.H{"user": u, "posts": posts}

	// Cache барои 30 сония
	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 30*time.Second)
	}

	c.JSON(http.StatusOK, result)
}

// GET /profile/:username — with cache
func GetProfile(c *gin.Context) {
	username := c.Param("username")
	myID := mw.UID(c)

	cacheKey := "profile:u:" + username + ":" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE username=$1", username)
	u, err := scanFullUser(row)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Profile not found"})
		return
	}

	uid := u["id"].(string)
	clearExpiredNote(uid, u)
	setIsFollowing(u, myID, uid)

	posts := postsForUser(uid, 30)
	result := gin.H{"user": u, "posts": posts}

	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 30*time.Second)
	}

	c.JSON(http.StatusOK, result)
}

// PUT /profile/ — invalidate cache after update
func UpdateProfile(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Bio       *string `json:"bio"`
		Avatar    *string `json:"avatar"`
		IsPrivate *bool   `json:"isPrivate"`
		Username  *string `json:"username"`
		Website   *string `json:"website"`
		Location  *string `json:"location"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  bio        = COALESCE($1, bio),
		  avatar     = COALESCE($2, avatar),
		  is_private = COALESCE($3, is_private),
		  username   = COALESCE($4, username),
		  website    = COALESCE($5, website),
		  location   = COALESCE($6, location),
		  updated_at = NOW()
		WHERE id=$7`,
		b.Bio, b.Avatar, b.IsPrivate, b.Username,
		b.Website, b.Location, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	// Кэшро нест кун
	mw.CacheDel("profile:me:"+myID)

	// Return updated profile
	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", myID)
	u, _ := scanFullUser(row)
	c.JSON(http.StatusOK, gin.H{"user": u})
}

// PUT /profile/settings — theme + language нигоҳ медорад (cross-device sync)
func UpdateSettings(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Theme    *string `json:"theme"`
		Language *string `json:"language"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  theme      = COALESCE($1, theme),
		  language   = COALESCE($2, language),
		  updated_at = NOW()
		WHERE id=$3`, b.Theme, b.Language, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	mw.CacheDel("profile:me:" + myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func SetNote(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Note string                 `json:"note"`
		Song map[string]interface{} `json:"song"`
	}
	c.ShouldBindJSON(&b)

	text := b.Note
	if len([]rune(text)) > 60 {
		text = string([]rune(text)[:60])
	}

	var (
		title, artist, artUrl, previewUrl string
		trackMs, startMs, endMs           int
	)
	endMs = 30000
	if b.Song != nil {
		title, _      = b.Song["title"].(string)
		artist, _     = b.Song["artist"].(string)
		artUrl, _     = b.Song["artUrl"].(string)
		previewUrl, _ = b.Song["previewUrl"].(string)
		if v, ok := b.Song["trackMs"].(float64); ok { trackMs = int(v) }
		if v, ok := b.Song["startMs"].(float64); ok { startMs = int(v) }
		if v, ok := b.Song["endMs"].(float64);   ok { endMs   = int(v) }
	}

	hasContent := text != "" || title != ""
	var expires interface{}
	if hasContent {
		expires = time.Now().Add(24 * time.Hour)
	}

	db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  note=$1, note_expires_at=$2,
		  note_song_title=$3, note_song_artist=$4, note_song_art_url=$5,
		  note_song_preview_url=$6, note_song_track_ms=$7,
		  note_song_start_ms=$8, note_song_end_ms=$9
		WHERE id=$10`,
		text, expires, title, artist, artUrl, previewUrl,
		trackMs, startMs, endMs, myID)

	c.JSON(http.StatusOK, gin.H{"note": text})
}

// GET /profile/notes/friends
func GetFriendsNotes(c *gin.Context) {
	myID := mw.UID(c)
	log.Printf("[Profile] GetFriendsNotes userID=%s", myID)

	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,u.avatar,u.verified,
		       u.note,u.note_expires_at,
		       u.note_song_title,u.note_song_artist,u.note_song_art_url,
		       u.note_song_preview_url,u.note_song_track_ms,
		       u.note_song_start_ms,u.note_song_end_ms
		FROM follows f JOIN users u ON u.id=f.following_id
		WHERE f.follower_id=$1
		  AND u.note_expires_at > NOW()
		  AND (u.note != '' OR u.note_song_title != '')`,
		myID)
	if err != nil {
		log.Printf("[Profile] GetFriendsNotes error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get notes failed"})
		return
	}
	defer rows.Close()

	friends := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, note, stTitle, stArtist, stArtUrl, stPreviewUrl string
		var verified bool
		var noteExp interface{}
		var stTrackMs, stStartMs, stEndMs int
		rows.Scan(&id, &uname, &avatar, &verified, &note, &noteExp,
			&stTitle, &stArtist, &stArtUrl, &stPreviewUrl,
			&stTrackMs, &stStartMs, &stEndMs)
		friends = append(friends, gin.H{
			"_id": id, "username": uname, "avatar": avatar, "verified": verified,
			"note": note, "noteExpiresAt": noteExp,
			"noteSong": gin.H{
				"title": stTitle, "artist": stArtist, "artUrl": stArtUrl,
				"previewUrl": stPreviewUrl, "trackMs": stTrackMs,
				"startMs": stStartMs, "endMs": stEndMs,
			},
		})
	}
	c.JSON(http.StatusOK, gin.H{"notes": friends})
}

func clearExpiredNote(uid string, u gin.H) {
	if exp, ok := u["noteExpiresAt"]; ok && exp != nil {
		if t, ok := exp.(time.Time); ok && t.Before(time.Now()) {
			db.Pool.Exec(context.Background(), `
				UPDATE users SET note='', note_expires_at=NULL WHERE id=$1`, uid)
			u["note"] = ""
			u["noteExpiresAt"] = nil
		}
	}
}
