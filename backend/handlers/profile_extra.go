package handlers

import (
	"context"
	"strings"
	"encoding/json"
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
		var collaborators []string
		var hasStory bool
		if err := rows.Scan(&pid, &cap, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &media, &liked, &saved, &pinned,
			&musicTitle, &musicArtist, &location, &tagged, &collaborators, &hasStory); err != nil {
			continue
		}
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap, "likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": nilToEmpty(media),
			"liked": liked, "saved": saved, "isPinned": pinned,
			"musicTitle": musicTitle, "musicArtist": musicArtist,
			"location": location, "taggedUsers": tagged,
			"collaborators": collaborators,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "hasStory": hasStory},
		})
	}
	return posts
}

const feedPostCols = `
	SELECT p.id, p.caption,
	       CASE WHEN COALESCE(p.hide_likes,false) AND p.user_id <> $1::text
	            THEN -1 ELSE COALESCE(p.likes_count,0) END,
	       COALESCE(p.comments_count,0), p.created_at,
	       u.id, u.username, u.avatar, COALESCE(u.verified,false),
	       (SELECT COALESCE(json_agg(
	                json_build_object('url',m.url,'type',m.type,'aspectRatio',COALESCE(m.aspect_ratio,0))
	                ORDER BY m.position),'[]'::json)
	        FROM post_media m WHERE m.post_id=p.id),
	       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1::text),
	       EXISTS(SELECT 1 FROM post_saves WHERE post_id=p.id AND user_id=$1::text),
	       COALESCE(p.is_pinned,false),
	       COALESCE(p.music_title,''), COALESCE(p.music_artist,''),
	       COALESCE(p.location,''), COALESCE(p.tagged_users,'{}'),
	       COALESCE(p.collaborators,'{}'),
	       EXISTS(SELECT 1 FROM stories s WHERE s.user_id=u.id AND s.expires_at > NOW() AND COALESCE(s.archived,false)=FALSE AND (s.user_id=$1::text OR EXISTS(SELECT 1 FROM follows hf WHERE hf.follower_id=$1::text AND hf.following_id=s.user_id)) AND (s.user_id=$1::text OR COALESCE(s.audience,'all')='all' OR EXISTS(SELECT 1 FROM close_friends hcf WHERE hcf.user_id=s.user_id AND hcf.friend_id=$1::text)))
	FROM posts p JOIN users u ON u.id=p.user_id `

// GET /profile/saved — постҳои нигоҳдошташуда (Sev)
func GetSavedPosts(c *gin.Context) {
	myID := mw.UID(c)
	page  := toInt(c.Query("page"), 1)
	if page < 1 {
		page = 1
	}
	limit := toInt(c.Query("limit"), 24)
	if limit < 1 {
		limit = 24
	}
	if limit > 60 {
		limit = 60
	}
	offset := (page - 1) * limit
	// ?collection=<id> — танҳо постҳои ҳамон папка (мисли Instagram).
	coll := strings.TrimSpace(c.Query("collection"))
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		JOIN post_saves s ON s.post_id=p.id AND s.user_id=$1::text
		WHERE $4::text = '' OR EXISTS (
		  SELECT 1 FROM saved_collection_items i
		   JOIN saved_collections sc ON sc.id = i.collection_id
		  WHERE i.collection_id = $4::text AND i.post_id = p.id
		    AND sc.user_id = $1::text)
		ORDER BY p.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, offset, coll)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}, "page": page, "limit": limit})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": scanFeedPosts(rows), "page": page, "limit": limit})
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
		  AND NOT EXISTS (SELECT 1 FROM post_tag_removals tr
		                  WHERE tr.post_id = p.id AND tr.user_id = $3::text)
		ORDER BY p.created_at DESC LIMIT 60`, myID, uname, target)
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
	mw.InvalidateUserCache(myID)
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
		`SELECT id, title, COALESCE(cover_url,''), COALESCE(story_ids,'{}'),
		        COALESCE(items,'[]'::jsonb)
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
		var itemsRaw []byte
		if rows.Scan(&id, &title, &cover, &storyIDs, &itemsRaw) == nil {
			items := []map[string]interface{}{}
			if len(itemsRaw) > 0 {
				json.Unmarshal(itemsRaw, &items)
			}
			out = append(out, gin.H{
				"_id": id, "title": title, "coverUrl": cover,
				"storyIds": storyIDs, "items": items,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"highlights": out})
}

// POST /highlights/
func CreateHighlight(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Title    string                   `json:"title"`
		CoverURL string                   `json:"coverUrl"`
		StoryIDs []string                 `json:"storyIds"`
		Items    []map[string]interface{} `json:"items"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	if b.StoryIDs == nil {
		b.StoryIDs = []string{}
	}
	if b.Items == nil {
		b.Items = []map[string]interface{}{}
	}
	// Cover-ро аз items-и аввал мегирем, агар надода бошанд.
	if b.CoverURL == "" && len(b.Items) > 0 {
		if u, ok := b.Items[0]["url"].(string); ok {
			b.CoverURL = u
		}
	}
	itemsJSON, _ := json.Marshal(b.Items)
	var id string
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO highlights (user_id, title, cover_url, story_ids, items)
		 VALUES ($1,$2,$3,$4,$5) RETURNING id`,
		myID, b.Title, b.CoverURL, b.StoryIDs, itemsJSON).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create failed"})
		return
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{
		"_id": id, "title": b.Title, "coverUrl": b.CoverURL,
		"storyIds": b.StoryIDs, "items": b.Items,
	})
}

// PATCH /highlights/:id — номро тағйир медиҳад ва/ё items-ро нав мекунад.
func UpdateHighlight(c *gin.Context) {
	myID := mw.UID(c)
	id := c.Param("id")
	var b struct {
		Title    *string                   `json:"title"`
		CoverURL *string                   `json:"coverUrl"`
		Items    *[]map[string]interface{} `json:"items"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	var itemsJSON []byte
	if b.Items != nil {
		itemsJSON, _ = json.Marshal(*b.Items)
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE highlights SET
		  title     = COALESCE($1, title),
		  cover_url = COALESCE($2, cover_url),
		  items     = COALESCE($3::jsonb, items)
		WHERE id=$4 AND user_id=$5::text`,
		b.Title, b.CoverURL, itemsJSON, id, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"updated": true})
}

// DELETE /highlights/:id
func DeleteHighlight(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM highlights WHERE id=$1 AND user_id=$2::text`,
		c.Param("id"), myID)
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}


// DELETE /posts/:id/tag — корбар қайди худро аз пост мегирад.
// Instagram низ ҳамин тавр: ҳар кас метавонад қайд кунад, вале
// қайдшуда метавонад онро аз профили худ бардорад.
func RemoveMyTag(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	if pid == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "post id required"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_tag_removals(post_id,user_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING`, pid, myID)
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

// ── ПАПКАҲОИ ЗАХИРАШУДА (Collections) ────────────────────────────

// GET /collections — рӯйхати папкаҳо бо шумора ва расми муқова.
func GetCollections(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT sc.id, sc.name,
		       (SELECT COUNT(*) FROM saved_collection_items i
		         WHERE i.collection_id = sc.id),
		       COALESCE((SELECT m.url FROM saved_collection_items i2
		         JOIN post_media m ON m.post_id = i2.post_id
		        WHERE i2.collection_id = sc.id
		        ORDER BY i2.added_at DESC, m.position ASC LIMIT 1), '')
		FROM saved_collections sc
		WHERE sc.user_id = $1::text
		ORDER BY sc.created_at DESC`, myID)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, name, cover string
			var count int
			if rows.Scan(&id, &name, &count, &cover) == nil {
				out = append(out, gin.H{
					"_id": id, "name": name, "count": count, "cover": cover})
			}
		}
	}
	c.JSON(http.StatusOK, gin.H{"collections": out})
}

// POST /collections — папкаи нав.
func CreateCollection(c *gin.Context) {
	myID := mw.UID(c)
	var b struct{ Name string `json:"name"` }
	name := ""
	if c.ShouldBindJSON(&b) == nil {
		name = clampRunes(strings.TrimSpace(b.Name), 40)
	}
	if name == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Номи папка лозим аст"})
		return
	}
	var id string
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO saved_collections(user_id,name) VALUES($1,$2) RETURNING id`,
		myID, name).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сохта нашуд"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"_id": id, "name": name, "count": 0, "cover": ""})
}

// DELETE /collections/:id — папкаро нест мекунад (постҳо захира мемонанд).
func DeleteCollection(c *gin.Context) {
	myID := mw.UID(c)
	cid  := c.Param("id")
	ct, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM saved_collections WHERE id=$1 AND user_id=$2::text`, cid, myID)
	if ct.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Папка ёфт нашуд"})
		return
	}
	db.Pool.Exec(context.Background(),
		`DELETE FROM saved_collection_items WHERE collection_id=$1`, cid)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// POST /collections/:id/posts — пост ба папка (ва захира мешавад).
// DELETE ҳамон роҳ — аз папка мебарорад.
func AddPostToCollection(c *gin.Context) {
	myID := mw.UID(c)
	cid  := c.Param("id")
	var b struct{ PostID string `json:"postId"` }
	if c.ShouldBindJSON(&b) != nil || b.PostID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "postId лозим аст"})
		return
	}
	if !ownsCollection(cid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "Папкаи шумо нест"})
		return
	}
	// Пост ба папка меафтад — пас ҳатман захирашуда бошад.
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_saves(user_id,post_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, b.PostID)
	db.Pool.Exec(context.Background(),
		`INSERT INTO saved_collection_items(collection_id,post_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING`, cid, b.PostID)
	c.JSON(http.StatusOK, gin.H{"added": true})
}

func RemovePostFromCollection(c *gin.Context) {
	myID := mw.UID(c)
	cid  := c.Param("id")
	pid  := c.Param("postId")
	if !ownsCollection(cid, myID) {
		c.JSON(http.StatusForbidden, gin.H{"message": "Папкаи шумо нест"})
		return
	}
	db.Pool.Exec(context.Background(),
		`DELETE FROM saved_collection_items WHERE collection_id=$1 AND post_id=$2`,
		cid, pid)
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

func ownsCollection(collectionID, userID string) bool {
	var ok bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM saved_collections
		  WHERE id=$1 AND user_id=$2::text)`, collectionID, userID).Scan(&ok)
	return ok
}
