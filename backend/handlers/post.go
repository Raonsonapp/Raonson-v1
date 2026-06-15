package handlers

import (
	"context"
	"log"
	"encoding/json"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/sockets"

	"github.com/gin-gonic/gin"
)

// POST /posts
func CreatePost(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Caption       string                   `json:"caption"`
		Media         []map[string]interface{} `json:"media"`
		MusicTitle    string                   `json:"musicTitle"`
		MusicArtist   string                   `json:"musicArtist"`
		Location      string                   `json:"location"`
		TaggedUsers   []string                 `json:"taggedUsers"`
		Collaborators []string                 `json:"collaborators"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || len(b.Media) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "At least one media item required"})
		return
	}
	if b.TaggedUsers == nil {
		b.TaggedUsers = []string{}
	}
	if b.Collaborators == nil {
		b.Collaborators = []string{}
	}

	tx, err := db.Pool.Begin(context.Background())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}
	defer tx.Rollback(context.Background())

	var postID string
	if err = tx.QueryRow(context.Background(),
		`INSERT INTO posts(user_id,caption,music_title,music_artist,location,tagged_users,collaborators)
		 VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
		myID, b.Caption, b.MusicTitle, b.MusicArtist, b.Location, b.TaggedUsers, b.Collaborators).Scan(&postID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}

	for i, m := range b.Media {
		url, _ := m["url"].(string)
		t, _   := m["type"].(string)
		if t == "" { t = "image" }
		tx.Exec(context.Background(),
			`INSERT INTO post_media(post_id,url,type,position) VALUES($1,$2,$3,$4)`,
			postID, url, t, i)
	}
	tx.Exec(context.Background(),
		`UPDATE users SET posts_count=posts_count+1 WHERE id=$1`, myID)
	tx.Commit(context.Background())

	// Invalidate feed cache for this user
	mw.CacheDel("feed:"+myID+":1", "feed:"+myID+":")

// ➕ ИЛОВА
var uname, uavatar string
var verified bool

db.Pool.QueryRow(context.Background(),
	`SELECT username, avatar, verified FROM users WHERE id=$1`, myID,
).Scan(&uname, &uavatar, &verified)

// ➕ ИЛОВА
wsPost := gin.H{
	"_id":           postID,
	"caption":       b.Caption,
	"media":         b.Media,
	"likesCount":    0,
	"commentsCount": 0,
	"liked":         false,
	"saved":         false,
	"musicTitle":    b.MusicTitle,
	"musicArtist":   b.MusicArtist,
	"location":      b.Location,
	"taggedUsers":   b.TaggedUsers,
	"collaborators": b.Collaborators,
	"createdAt":     time.Now().Format(time.RFC3339),
	"user": gin.H{
		"_id":      myID,
		"username": uname,
		"avatar":   uavatar,
		"verified": verified,
	},
}

// ➕ ИЛОВА
go sockets.BroadcastNewPost(myID, wsPost)

// 🔁 ИВАЗ
c.JSON(http.StatusCreated, wsPost)
}

// GET /posts  GET /posts/feed
func GetFeed(c *gin.Context) {
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 20)
	offset := (page - 1) * limit

	// Cache key per user+page (30 sec TTL — fresh but fast)
	cacheKey := "feed:" + myID + ":" + c.Query("page")
	if page == 1 {
		if cached, ok := mw.CacheGet(cacheKey); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			return
		}
	}

	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, p.caption,
		       CASE WHEN COALESCE(p.hide_likes,false) AND p.user_id <> $1::text
		            THEN -1 ELSE p.likes_count END,
		       p.comments_count, p.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type)
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id),
		       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1::text),
		       EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$1::text)
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE COALESCE(p.archived,false) = FALSE
		ORDER BY p.created_at DESC
		LIMIT $2 OFFSET $3`, myID, limit, offset)
	if err != nil {
		log.Printf("[GetFeed] query error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get feed failed"})
		return
	}
	defer rows.Close()

	posts := []gin.H{}
	for rows.Next() {
		var pid, cap, uid, uname, uavatar string
		var likes, comms int
		var verified, liked, saved bool
		var createdAt, media interface{}
		rows.Scan(&pid, &cap, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &media, &liked, &saved)
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap, "likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": nilToEmpty(media),
			"liked": liked, "saved": saved,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	result := gin.H{"posts": posts, "page": page, "limit": limit}
	if page == 1 {
		if b, err := json.Marshal(result); err == nil {
			mw.CacheSet(cacheKey, b, 30*time.Second)
		}
	}
	c.JSON(http.StatusOK, result)
}

// GET /posts/:id
func GetPost(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	var pid2, cap, uid, uname, uavatar string
	var likes, comms int
	var verified, liked, saved bool
	var createdAt, media interface{}

	err := db.Pool.QueryRow(context.Background(), `
		SELECT p.id, p.caption, p.likes_count, p.comments_count, p.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type)
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id),
		       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$2::text),
		       EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$2::text)
		FROM posts p JOIN users u ON u.id=p.user_id WHERE p.id=$1`,
		pid, myID).Scan(&pid2, &cap, &likes, &comms, &createdAt,
		&uid, &uname, &uavatar, &verified, &media, &liked, &saved)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"_id": pid2, "caption": cap, "likesCount": likes, "commentsCount": comms,
		"createdAt": createdAt, "media": nilToEmpty(media), "liked": liked, "saved": saved,
		"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
	})
}

// DELETE /posts/:id
func DeletePost(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM posts WHERE id=$1 AND user_id=$2::text`, pid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET posts_count=GREATEST(posts_count-1,0) WHERE id=$1`, myID)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// POST /posts/:id/like
func TogglePostLike(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM post_likes WHERE post_id=$1::text AND user_id=$2::text)`,
		pid, myID).Scan(&liked)

	if liked {
		db.Pool.Exec(context.Background(),
			`DELETE FROM post_likes WHERE post_id=$1::text AND user_id=$2::text`, pid, myID)
		db.Pool.Exec(context.Background(),
			`UPDATE posts SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, pid)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO post_likes(post_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, pid, myID)
		db.Pool.Exec(context.Background(),
			`UPDATE posts SET likes_count=likes_count+1 WHERE id=$1`, pid)
		var owner string
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM posts WHERE id=$1`, pid).Scan(&owner)
		notify(owner, myID, "like", pid)
	}

	var cnt int
	db.Pool.QueryRow(context.Background(),
		`SELECT likes_count FROM posts WHERE id=$1`, pid).Scan(&cnt)
	// Push notification to post owner
	if !liked {
		go func() {
			var ownerID, username string
			db.Pool.QueryRow(context.Background(),
				`SELECT p.user_id, u.username FROM posts p
				 JOIN users u ON u.id=(SELECT id FROM users WHERE id=$2)
				 WHERE p.id=$1`, pid, myID).Scan(&ownerID, &username)
			if ownerID != "" && ownerID != myID {
				SendPushToUser(ownerID, "Raonson", username+" liked your post",
					map[string]string{"type":"like","postId":pid})
			}
		}()
	}
	c.JSON(http.StatusOK, gin.H{"liked": !liked, "likesCount": cnt})
}

// POST /posts/:id/save
func TogglePostSave(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	var saved bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM post_saves WHERE post_id=$1::text AND user_id=$2::text)`,
		pid, myID).Scan(&saved)

	if saved {
		db.Pool.Exec(context.Background(),
			`DELETE FROM post_saves WHERE post_id=$1::text AND user_id=$2::text`, pid, myID)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO post_saves(post_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, pid, myID)
	}
	c.JSON(http.StatusOK, gin.H{"saved": !saved})
}
