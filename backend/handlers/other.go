package handlers

import (
	"context"
	"log"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/utils"

	"github.com/gin-gonic/gin"
)

// ── COMMENTS ─────────────────────────────────────────────────────

// POST /comments/:id  (id = postID)
func AddComment(c *gin.Context) {
	postID := c.Param("id")
	myID   := mw.UID(c)
	var b struct {
		Text     string `json:"text"`
		ParentID string `json:"parentId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Comment text required"})
		return
	}
	b.Text = clampRunes(b.Text, 1000)
	if flagged, cats := utils.ModerateText(context.Background(), b.Text); flagged {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Шарҳ қоидаҳои ҷамъиятиро вайрон мекунад", "categories": cats})
		return
	}

	var exists, commentsOff bool
	db.Pool.QueryRow(context.Background(),
		`SELECT TRUE, COALESCE(comments_off,false) FROM posts WHERE id=$1`,
		postID).Scan(&exists, &commentsOff)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	if commentsOff {
		c.JSON(http.StatusForbidden, gin.H{"message": "Шарҳҳо барои ин пост хомӯш карда шудаанд"})
		return
	}

	var cid string
	var createdAt interface{}
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO comments(post_id,user_id,text,parent_id)
		 VALUES($1,$2,$3,NULLIF($4,'')) RETURNING id,created_at`,
		postID, myID, b.Text, b.ParentID).Scan(&cid, &createdAt)
	db.Pool.Exec(context.Background(),
		`UPDATE posts SET comments_count=comments_count+1 WHERE id=$1`, postID)

	// Огоҳии соҳиби пост
	var postOwner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM posts WHERE id=$1`, postID).Scan(&postOwner)
	notify(postOwner, myID, "comment", postID)

	// Reply — соҳиби шарҳи волидро ҳам огоҳ кун (агар худаш набошад)
	if b.ParentID != "" {
		var parentOwner string
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM comments WHERE id=$1`, b.ParentID).Scan(&parentOwner)
		if parentOwner != "" && parentOwner != myID && parentOwner != postOwner {
			notify(parentOwner, myID, "reply", postID)
		}
	}

	var uname, uavatar string
	var verified bool
	db.Pool.QueryRow(context.Background(),
		`SELECT username,avatar,verified FROM users WHERE id=$1`, myID,
	).Scan(&uname, &uavatar, &verified)

	c.JSON(http.StatusCreated, gin.H{
		"_id": cid, "post": postID, "text": b.Text, "parentId": b.ParentID,
		"liked": false, "likesCount": 0, "createdAt": createdAt,
		"user": gin.H{"_id": myID, "username": uname, "avatar": uavatar, "verified": verified},
	})
}

// GET /comments/:id  (id = postID)
func GetComments(c *gin.Context) {
	postID := c.Param("id")
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 20)
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT c.id, c.text, c.likes_count, c.created_at, COALESCE(c.parent_id,''),
		       u.id, u.username, u.avatar, u.verified,
		       EXISTS(SELECT 1 FROM comment_likes cl WHERE cl.comment_id=c.id AND cl.user_id=$2)
		FROM comments c JOIN users u ON u.id=c.user_id
		WHERE c.post_id=$1 ORDER BY c.created_at DESC LIMIT $3 OFFSET $4`,
		postID, myID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get comments failed"})
		return
	}
	defer rows.Close()

	comments := []gin.H{}
	for rows.Next() {
		var cid, text, uid, uname, uavatar string
		var parentID string
		var likes int
		var verified, liked bool
		var createdAt interface{}
		rows.Scan(&cid, &text, &likes, &createdAt, &parentID, &uid, &uname, &uavatar, &verified, &liked)
		comments = append(comments, gin.H{
			"_id": cid, "text": text, "liked": liked, "likesCount": likes,
			"createdAt": createdAt, "parentId": parentID,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	c.JSON(http.StatusOK, gin.H{"comments": comments, "page": page, "limit": limit})
}

// DELETE /posts/:postId/comments/:id
func DeleteComment(c *gin.Context) {
	cid  := c.Param("id")
	myID := mw.UID(c)
	var postID string
	err := db.Pool.QueryRow(context.Background(),
		`DELETE FROM comments WHERE id=$1 AND user_id=$2::text RETURNING post_id`, cid, myID,
	).Scan(&postID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Comment not found"})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE posts SET comments_count=GREATEST(comments_count-1,0) WHERE id=$1`, postID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /posts/:postId/comments/:id/like
func ToggleCommentLike(c *gin.Context) {
	cid  := c.Param("id")
	myID := mw.UID(c)
	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM comment_likes WHERE comment_id=$1::text AND user_id=$2::text)`,
		cid, myID).Scan(&liked)
	if liked {
		db.Pool.Exec(context.Background(),
			`DELETE FROM comment_likes WHERE comment_id=$1::text AND user_id=$2::text`, cid, myID)
		db.Pool.Exec(context.Background(),
			`UPDATE comments SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, cid)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO comment_likes(comment_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, cid, myID)
		db.Pool.Exec(context.Background(),
			`UPDATE comments SET likes_count=likes_count+1 WHERE id=$1`, cid)
	}
	c.JSON(http.StatusOK, gin.H{"liked": !liked})
}
// PUT /comments/:id — таҳрири comment
func EditComment(c *gin.Context) {
	cid  := c.Param("id")
	myID := mw.UID(c)

	var b struct {
		Text string `json:"text"`
	}

	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	b.Text = clampRunes(b.Text, 1000)

	res, err := db.Pool.Exec(context.Background(),
		`UPDATE comments
		 SET text=$1, updated_at=NOW()
		 WHERE id=$2 AND user_id=$3`,
		b.Text, cid, myID)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}

	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{
			"message": "Comment not found or not owner",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"updated": true,
		"text":    b.Text,
	})
}

// ── FOLLOW ───────────────────────────────────────────────────────

// POST /follow/:id
func FollowUser(c *gin.Context) {
	targetID := c.Param("id")
	myID     := mw.UID(c)
	if targetID == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Cannot follow yourself"})
		return
	}
	var isPrivate bool
	err := db.Pool.QueryRow(context.Background(),
		`SELECT is_private FROM users WHERE id=$1`, targetID).Scan(&isPrivate)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	var alreadyFollowing bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1::text AND following_id=$2::text)`,
		myID, targetID).Scan(&alreadyFollowing)
	if alreadyFollowing {
		c.JSON(http.StatusOK, gin.H{"following": true})
		return
	}
	if isPrivate {
		db.Pool.Exec(context.Background(),
			`INSERT INTO follow_requests(requester_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
			myID, targetID)
		notify(targetID, myID, "follow_request", myID)
		c.JSON(http.StatusOK, gin.H{"requested": true})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO follows(follower_id,following_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET followers_count=followers_count+1 WHERE id=$1`, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET following_count=following_count+1 WHERE id=$1`, myID)
	notify(targetID, myID, "follow", myID)

	// Push notification to target
	go func() {
		var username string
		db.Pool.QueryRow(context.Background(),
			`SELECT username FROM users WHERE id=$1`, myID).Scan(&username)
		if username != "" {
			SendPushToUser(targetID, "Raonson", username+" started following you",
				map[string]string{"type":"follow","userId":myID})
		}
	}()
	c.JSON(http.StatusOK, gin.H{"following": true})
}

// DELETE /follow/:id  or POST /unfollow/:id
func UnfollowUser(c *gin.Context) {
	targetID := c.Param("id")
	myID     := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM follows WHERE follower_id=$1::text AND following_id=$2::text`, myID, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET followers_count=GREATEST(followers_count-1,0) WHERE id=$1`, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET following_count=GREATEST(following_count-1,0) WHERE id=$1`, myID)
	c.JSON(http.StatusOK, gin.H{"following": false})
}

// POST /follow/request/:id/accept
func AcceptRequest(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM follow_requests WHERE requester_id=$1::text AND target_id=$2::text`, rid, myID)
	db.Pool.Exec(context.Background(),
		`INSERT INTO follows(follower_id,following_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, rid, myID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET followers_count=followers_count+1 WHERE id=$1`, myID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET following_count=following_count+1 WHERE id=$1`, rid)
	c.JSON(http.StatusOK, gin.H{"accepted": true})
}

// POST /follow/request/:id/reject
func RejectRequest(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM follow_requests WHERE requester_id=$1::text AND target_id=$2::text`, rid, myID)
	c.JSON(http.StatusOK, gin.H{"rejected": true})
}

// ── SEARCH ───────────────────────────────────────────────────────

// GET /search?q=...
func Search(c *gin.Context) {
	q := c.Query("q")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Query required"})
		return
	}
	like := "%" + q + "%"

	// Users
	uRows, _ := db.Pool.Query(context.Background(), `
		SELECT id,username,avatar,verified,bio,followers_count
		FROM users WHERE username ILIKE $1 AND banned=FALSE
		ORDER BY followers_count DESC, username ASC LIMIT 20`, like)
	users := []gin.H{}
	if uRows != nil {
		for uRows.Next() {
			var id, uname, avatar, bio string
			var verified bool
			var fc int
			uRows.Scan(&id, &uname, &avatar, &verified, &bio, &fc)
			users = append(users, gin.H{
				"_id": id, "id": id, "username": uname,
				"avatar": avatar, "verified": verified,
				"bio": bio, "followersCount": fc,
			})
		}
		uRows.Close()
	}

	// Posts
	pRows, _ := db.Pool.Query(context.Background(), `
		SELECT p.id, p.caption, p.likes_count, p.comments_count, p.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type)
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id)
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE p.caption ILIKE $1
		ORDER BY p.likes_count DESC, p.created_at DESC LIMIT 20`, like)
	posts := []gin.H{}
	if pRows != nil {
		for pRows.Next() {
			var pid, cap, uid, uname, uavatar string
			var likes, comms int
			var verified bool
			var createdAt, media interface{}
			pRows.Scan(&pid, &cap, &likes, &comms, &createdAt, &uid, &uname, &uavatar, &verified, &media)
			posts = append(posts, gin.H{
				"_id": pid, "caption": cap, "likesCount": likes,
				"commentsCount": comms, "createdAt": createdAt, "media": nilToEmpty(media),
				"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
			})
		}
		pRows.Close()
	}

	// Reels
	rRows, _ := db.Pool.Query(context.Background(), `
		SELECT id,video_url,caption,views_count,likes_count,created_at
		FROM reels WHERE caption ILIKE $1
		ORDER BY views_count DESC, likes_count DESC LIMIT 10`, like)
	reels := []gin.H{}
	if rRows != nil {
		for rRows.Next() {
			var rid, vurl, cap string
			var views, likes int
			var createdAt interface{}
			rRows.Scan(&rid, &vurl, &cap, &views, &likes, &createdAt)
			reels = append(reels, gin.H{
				"_id": rid, "videoUrl": vurl, "caption": cap,
				"views": views, "likesCount": likes, "createdAt": createdAt,
			})
		}
		rRows.Close()
	}

	c.JSON(http.StatusOK, gin.H{"users": users, "posts": posts, "reels": reels})
}

// GET /search/users?q=...
func SearchUsers(c *gin.Context) {
	q := c.Query("q")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Query required"})
		return
	}
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT id,username,avatar,verified,bio,followers_count
		FROM users WHERE username ILIKE $1 AND banned=FALSE
		ORDER BY followers_count DESC, username ASC LIMIT 30`,
		"%"+q+"%")
	users := []gin.H{}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var id, uname, avatar, bio string
			var verified bool
			var fc int
			rows.Scan(&id, &uname, &avatar, &verified, &bio, &fc)
			users = append(users, gin.H{
				"_id": id, "id": id, "username": uname,
				"avatar": avatar, "verified": verified,
				"bio": bio, "followersCount": fc,
			})
		}
	}
	c.JSON(http.StatusOK, users)
}

// ── REELS ─────────────────────────────────────────────────────────

// POST /reels
func CreateReel(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Caption      string `json:"caption"`
		VideoURL     string `json:"videoUrl"`
		VideoURLLow  string `json:"videoUrlLow"`
		ThumbnailURL string `json:"thumbnailUrl"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.VideoURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "videoUrl is required"})
		return
	}
	b.Caption = clampRunes(b.Caption, 2200)
	if flagged, cats := utils.ModerateText(context.Background(), b.Caption); flagged {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Тавсиф қоидаҳои ҷамъиятиро вайрон мекунад", "categories": cats})
		return
	}
	var rid string
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO reels(user_id,caption,video_url,video_url_low,thumbnail_url) VALUES($1,$2,$3,$4,$5) RETURNING id`,
		myID, b.Caption, b.VideoURL, b.VideoURLLow, b.ThumbnailURL).Scan(&rid)
	mw.CacheDel("smartreels:"+myID+":1", "smartreels:"+myID+":2", "explore:grid")
	c.JSON(http.StatusCreated, gin.H{
		"_id": rid, "videoUrl": b.VideoURL, "videoUrlLow": b.VideoURLLow,
		"thumbnailUrl": b.ThumbnailURL,
		"caption": b.Caption, "likesCount": 0, "viewsCount": 0,
	})
}

// GET /reels
func GetReels(c *gin.Context) {
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 20)
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT r.id, r.video_url, COALESCE(r.video_url_low,''), COALESCE(r.thumbnail_url,''), r.caption, r.views_count,
		       CASE WHEN COALESCE(r.hide_likes,false) AND r.user_id <> $1::text
		            THEN -1 ELSE r.likes_count END, r.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$1::text),
		       EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$1::text),
		       EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=$1::text AND f.following_id=r.user_id)
		FROM reels r JOIN users u ON u.id=r.user_id
		ORDER BY r.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, offset)
	if err != nil {
		log.Printf("[GetReels] query error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get reels failed"})
		return
	}
	defer rows.Close()

	reels := []gin.H{}
	for rows.Next() {
		var rid, vurl, vurlLow, thumb, cap, uid, uname, uavatar string
		var views, likes int
		var verified, liked, saved, following bool
		var createdAt interface{}
		rows.Scan(&rid, &vurl, &vurlLow, &thumb, &cap, &views, &likes, &createdAt,
			&uid, &uname, &uavatar, &verified, &liked, &saved, &following)
		reels = append(reels, gin.H{
			"_id": rid, "videoUrl": vurl, "videoUrlLow": vurlLow,
			"thumbnailUrl": thumb, "caption": cap,
			"viewsCount": views, "likesCount": likes,
			"isLiked": liked, "isSaved": saved, "createdAt": createdAt,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "isFollowing": following},
		})
	}
	c.JSON(http.StatusOK, gin.H{"reels": reels, "page": page, "limit": limit})
}

// POST /reels/:id/view
func AddReelView(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE reels SET views_count=views_count+1 WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"viewed": true})
}

// POST /reels/:id/like
func ToggleReelLike(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM reel_likes WHERE reel_id=$1::text AND user_id=$2::text)`,
		rid, myID).Scan(&liked)
	if liked {
		// UNLIKE — count танҳо вақте кам мешавад, ки сатр воқеан ҳазф шуд.
		ct, _ := db.Pool.Exec(context.Background(),
			`DELETE FROM reel_likes WHERE reel_id=$1::text AND user_id=$2::text`, rid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE reels SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, rid)
		}
	} else {
		// LIKE — count танҳо вақте зиёд мешавад, ки сатр воқеан нав илова шуд.
		ct, _ := db.Pool.Exec(context.Background(),
			`INSERT INTO reel_likes(reel_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, rid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE reels SET likes_count=likes_count+1 WHERE id=$1`, rid)
			var owner string
			db.Pool.QueryRow(context.Background(),
				`SELECT user_id FROM reels WHERE id=$1`, rid).Scan(&owner)
			notify(owner, myID, "reel_like", rid)
		}
	}
	c.JSON(http.StatusOK, gin.H{"liked": !liked})
}

// POST /reels/:id/save
func ToggleReelSave(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	var saved bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM reel_saves WHERE reel_id=$1::text AND user_id=$2::text)`,
		rid, myID).Scan(&saved)
	if saved {
		db.Pool.Exec(context.Background(),
			`DELETE FROM reel_saves WHERE reel_id=$1::text AND user_id=$2::text`, rid, myID)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO reel_saves(reel_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, rid, myID)
	}
	c.JSON(http.StatusOK, gin.H{"saved": !saved})
}

// DELETE /reels/:id
func DeleteReel(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM reels WHERE id=$1 AND user_id=$2::text`, rid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}
	mw.CacheDel("explore:grid") // то аз search фавран нопадид шавад
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// GET /reels/:id/comments
func GetReelComments(c *gin.Context) {
	rid := c.Param("id")
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT rc.id,rc.text,rc.created_at,u.id,u.username,u.avatar,u.verified
		FROM reel_comments rc JOIN users u ON u.id=rc.user_id
		WHERE rc.reel_id=$1 ORDER BY rc.created_at ASC`, rid)
	comments := []gin.H{}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var cid, text, uid, uname, uavatar string
			var verified bool
			var createdAt interface{}
			rows.Scan(&cid, &text, &createdAt, &uid, &uname, &uavatar, &verified)
			comments = append(comments, gin.H{
				"_id": cid, "text": text, "createdAt": createdAt,
				"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"comments": comments})
}

// POST /reels/:id/comments
func AddReelComment(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	var b struct{ Text string `json:"text"` }
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	if flagged, cats := utils.ModerateText(context.Background(), b.Text); flagged {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Шарҳ қоидаҳои ҷамъиятиро вайрон мекунад", "categories": cats})
		return
	}
	var cid string
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO reel_comments(reel_id,user_id,text) VALUES($1,$2,$3) RETURNING id`,
		rid, myID, b.Text).Scan(&cid)
	db.Pool.Exec(context.Background(),
		`UPDATE reels SET comments_count=comments_count+1 WHERE id=$1`, rid)
	var owner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM reels WHERE id=$1`, rid).Scan(&owner)
	notify(owner, myID, "reel_comment", rid)
	c.JSON(http.StatusCreated, gin.H{"_id": cid, "text": b.Text})
}
