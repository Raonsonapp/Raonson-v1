package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// scanFeedPosts — постҳоро бо маълумоти корбар (мисли feed) ба JSON табдил медиҳад.
func scanFeedPosts(rows interface {
	Next() bool
	Scan(...interface{}) error
	Close()
}, ) []gin.H {
	defer rows.Close()
	posts := []gin.H{}
	for rows.Next() {
		var pid, cap, uid, uname, uavatar string
		var likes, comms int
		var verified, liked, saved, pinned bool
		var createdAt, media interface{}
		var musicTitle, musicArtist, location string
		var tagged []string
		var hasStory bool
		if err := rows.Scan(&pid, &cap, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &media, &liked, &saved, &pinned,
			&musicTitle, &musicArtist, &location, &tagged, &hasStory); err != nil {
			continue
		}
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap, "likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": nilToEmpty(media),
			"liked": liked, "saved": saved, "isPinned": pinned,
			"musicTitle": musicTitle, "musicArtist": musicArtist,
			"location": location, "taggedUsers": tagged,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "hasStory": hasStory},
		})
	}
	return posts
}

const feedPostCols = `
	SELECT p.id, p.caption, COALESCE(p.likes_count,0), COALESCE(p.comments_count,0), p.created_at,
	       u.id, u.username, u.avatar, COALESCE(u.verified,false),
	       (SELECT COALESCE(json_agg(
	                json_build_object('url',m.url,'type',m.type)
	                ORDER BY m.position),'[]'::json)
	        FROM post_media m WHERE m.post_id=p.id),
	       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1::text),
	       EXISTS(SELECT 1 FROM post_saves WHERE post_id=p.id AND user_id=$1::text),
	       COALESCE(p.is_pinned,false),
	       COALESCE(p.music_title,''), COALESCE(p.music_artist,''),
	       COALESCE(p.location,''), COALESCE(p.tagged_users,'{}'),
	       EXISTS(SELECT 1 FROM stories s WHERE s.user_id=u.id AND s.expires_at > NOW())
	FROM posts p JOIN users u ON u.id=p.user_id `

// GET /profile/saved — постҳои нигоҳдошташуда (Sev)
func GetSavedPosts(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		JOIN post_saves s ON s.post_id=p.id AND s.user_id=$1::text
		ORDER BY p.created_at DESC LIMIT 60`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": scanFeedPosts(rows)})
}

// GET /users/:id/tagged — постҳое ки корбар дар онҳо зикр (@) шудааст
func GetTaggedPosts(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	if target == "me" {
		target = myID
	}
	var uname string
	db.Pool.QueryRow(context.Background(),
		`SELECT username FROM users WHERE id=$1`, target).Scan(&uname)
	if uname == "" {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}})
		return
	}
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE p.caption ILIKE '%@' || $2 || '%'
		ORDER BY p.created_at DESC LIMIT 60`, myID, uname)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": scanFeedPosts(rows)})
}

// POST /posts/:id/pin — пост-ро баланд мекунад/мегирад (танҳо соҳиб)
func PinPost(c *gin.Context) {
	myID := mw.UID(c)
	pid := c.Param("id")
	var b struct {
		Pin bool `json:"pin"`
	}
	c.ShouldBindJSON(&b)
	db.Pool.Exec(context.Background(),
		`UPDATE posts SET is_pinned=$1 WHERE id=$2 AND user_id=$3::text`,
		b.Pin, pid, myID)
	c.JSON(http.StatusOK, gin.H{"isPinned": b.Pin})
}

// ── HIGHLIGHTS (Актуальный) ──────────────────────────────────────────

// GET /highlights/:userId
func GetHighlights(c *gin.Context) {
	uid := c.Param("id")
	if uid == "me" {
		uid = mw.UID(c)
	}
	rows, err := db.Pool.Query(context.Background(),
		`SELECT id, title, COALESCE(cover_url,''), COALESCE(story_ids,'{}')
		 FROM highlights WHERE user_id=$1 ORDER BY created_at ASC`, uid)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"highlights": []gin.H{}})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, title, cover string
		var storyIDs []string
		if rows.Scan(&id, &title, &cover, &storyIDs) == nil {
			out = append(out, gin.H{
				"_id": id, "title": title, "coverUrl": cover, "storyIds": storyIDs,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"highlights": out})
}

// POST /highlights/
func CreateHighlight(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Title    string   `json:"title"`
		CoverURL string   `json:"coverUrl"`
		StoryIDs []string `json:"storyIds"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	if b.StoryIDs == nil {
		b.StoryIDs = []string{}
	}
	var id string
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO highlights (user_id, title, cover_url, story_ids)
		 VALUES ($1,$2,$3,$4) RETURNING id`,
		myID, b.Title, b.CoverURL, b.StoryIDs).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"_id": id, "title": b.Title, "coverUrl": b.CoverURL, "storyIds": b.StoryIDs,
	})
}

// DELETE /highlights/:id
func DeleteHighlight(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM highlights WHERE id=$1 AND user_id=$2::text`,
		c.Param("id"), myID)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}
