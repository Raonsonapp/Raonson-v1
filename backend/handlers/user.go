package handlers

import (
	"context"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// usernameChangeAllowed — оё корбар имрӯз метавонад username-ро тағйир диҳад?
// Танҳо вақте username воқеан дигар мешавад санҷида мешавад. Як бор дар 14 рӯз.
// Бармегардонад: changing (оё username тағйир меёбад), allowed (иҷозат ҳаст).
func usernameChangeAllowed(userID string, newUsername *string) (changing bool, allowed bool) {
	if newUsername == nil {
		return false, true
	}
	var current string
	var changedAt *time.Time
	db.Pool.QueryRow(context.Background(),
		`SELECT username, username_changed_at FROM users WHERE id=$1`,
		userID).Scan(&current, &changedAt)
	if current == *newUsername {
		return false, true
	}
	if changedAt != nil && time.Since(*changedAt) < 14*24*time.Hour {
		return true, false
	}
	return true, true
}

// GET /users/:id
func GetUserByID(c *gin.Context) {
	id   := c.Param("id")
	myID := mw.UID(c)

	u, err := getUserByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	setIsFollowing(u, myID, id)
	c.JSON(http.StatusOK, u)
}

// PUT /users/
func UpdateUser(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Bio       *string `json:"bio"`
		Avatar    *string `json:"avatar"`
		IsPrivate *bool   `json:"isPrivate"`
		Username  *string `json:"username"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	changingUsername, allowed := usernameChangeAllowed(myID, b.Username)
	if !allowed {
		c.JSON(http.StatusTooManyRequests,
			gin.H{"message": "Username can only be changed once every 14 days"})
		return
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  bio        = COALESCE($1, bio),
		  avatar     = COALESCE($2, avatar),
		  is_private = COALESCE($3, is_private),
		  username   = COALESCE($4, username),
		  username_changed_at = CASE WHEN $6 THEN NOW() ELSE username_changed_at END,
		  updated_at = NOW()
		WHERE id=$5`,
		b.Bio, b.Avatar, b.IsPrivate, b.Username, myID, changingUsername)
	if err != nil {
		if isUnique(err) {
			c.JSON(http.StatusConflict, gin.H{"message": "Username taken"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	u, _ := getUserByID(myID)
	c.JSON(http.StatusOK, u)
}

// DELETE /users/
func DeleteUser(c *gin.Context) {
	myID := mw.UID(c)
	ctx := context.Background()

	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "server error"})
		return
	}
	defer tx.Rollback(ctx)

	queries := []string{
		`DELETE FROM reel_comments WHERE user_id=$1`,
		`DELETE FROM reel_likes WHERE user_id=$1`,
		`DELETE FROM reel_saves WHERE user_id=$1`,
		`DELETE FROM reel_views WHERE user_id=$1`,
		`DELETE FROM reel_watch WHERE user_id=$1`,
		`DELETE FROM reel_not_interested WHERE user_id=$1`,
		`DELETE FROM reel_reports WHERE user_id=$1`,
		`DELETE FROM reels WHERE user_id=$1`,
		`DELETE FROM comment_likes WHERE user_id=$1`,
		`DELETE FROM comments WHERE user_id=$1`,
		`DELETE FROM post_likes WHERE user_id=$1`,
		`DELETE FROM post_saves WHERE user_id=$1`,
		`DELETE FROM post_views WHERE user_id=$1`,
		`DELETE FROM post_shares WHERE user_id=$1`,
		`DELETE FROM post_interests WHERE user_id=$1`,
		`DELETE FROM post_not_interested WHERE user_id=$1`,
		`DELETE FROM post_reports WHERE user_id=$1`,
		`DELETE FROM post_media WHERE post_id IN (SELECT id FROM posts WHERE user_id=$1)`,
		`DELETE FROM posts WHERE user_id=$1`,
		`DELETE FROM story_views WHERE user_id=$1`,
		`DELETE FROM story_likes WHERE user_id=$1`,
		`DELETE FROM story_replies WHERE from_user_id=$1`,
		`DELETE FROM stories WHERE user_id=$1`,
		`DELETE FROM highlights WHERE user_id=$1`,
		`DELETE FROM messages WHERE sender_id=$1 OR receiver_id=$1`,
		`DELETE FROM message_reactions WHERE user_id=$1`,
		`DELETE FROM chat_accepts WHERE user_id=$1 OR peer_id=$1`,
		`DELETE FROM chat_hidden WHERE user_id=$1 OR peer_id=$1`,
		`DELETE FROM group_members WHERE user_id=$1`,
		`DELETE FROM follows WHERE follower_id=$1 OR following_id=$1`,
		`DELETE FROM follow_requests WHERE requester_id=$1 OR target_id=$1`,
		`DELETE FROM close_friends WHERE user_id=$1 OR friend_id=$1`,
		`DELETE FROM blocks WHERE blocker_id=$1 OR blocked_id=$1`,
		`DELETE FROM muted_users WHERE user_id=$1 OR muted_id=$1`,
		`DELETE FROM user_reports WHERE reported_id=$1 OR user_id=$1`,
		`DELETE FROM user_restricts WHERE user_id=$1 OR restricted_id=$1`,
		`DELETE FROM notifications WHERE user_id=$1 OR from_user_id=$1`,
		`DELETE FROM push_tokens WHERE user_id=$1`,
		`DELETE FROM login_sessions WHERE user_id=$1`,
		`DELETE FROM orders WHERE buyer_id=$1 OR seller_id=$1`,
		`DELETE FROM gifts WHERE from_user_id=$1 OR to_user_id=$1`,
		`DELETE FROM promotions WHERE user_id=$1`,
		`DELETE FROM product_reviews WHERE user_id=$1`,
		`DELETE FROM events WHERE user_id=$1`,
		`DELETE FROM live_comments WHERE user_id=$1`,
		`DELETE FROM live_streams WHERE host_id=$1`,
		`DELETE FROM effects WHERE creator_id=$1`,
		`DELETE FROM effect_purchases WHERE buyer_id=$1`,
		`DELETE FROM promo_codes WHERE seller_id=$1`,
		`DELETE FROM users WHERE id=$1`,
	}

	for _, q := range queries {
		if _, err := tx.Exec(ctx, q, myID); err != nil {
			continue
		}
	}

	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "deletion failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true})
}

// GET /users/:id/posts
func GetUserPosts(c *gin.Context) {
	id     := c.Param("id")
	myID   := mw.UID(c)
	if id == "me" { id = myID }
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 24)
	offset := (page - 1) * limit

	// Постҳои pinned аввал, баъд аз рӯи сана. Бо маълумоти корбар +
	// liked/saved/isPinned — то дар экрани кушодашуда (мисли home) кор кунад.
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE p.user_id=$2 AND COALESCE(p.archived,false)=FALSE
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())
		ORDER BY COALESCE(p.is_pinned,false) DESC, p.created_at DESC
		LIMIT $3 OFFSET $4`,
		myID, id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get posts failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": scanFeedPosts(rows)})
}

// GET /users/:id/reels
func GetUserReels(c *gin.Context) {
	id     := c.Param("id")
	if id == "me" { id = mw.UID(c) }
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 24)
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT r.id, r.video_url, COALESCE(r.video_url_low,''),
		       COALESCE(r.thumbnail_url,''), r.caption,
		       COALESCE(r.views_count,0), COALESCE(r.likes_count,0),
		       COALESCE(r.comments_count,0), r.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$4),
		       EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$4),
		       EXISTS(SELECT 1 FROM stories s WHERE s.user_id=u.id AND s.expires_at > NOW())
		FROM reels r JOIN users u ON u.id=r.user_id
		WHERE r.user_id=$1
		ORDER BY r.created_at DESC LIMIT $2 OFFSET $3`,
		id, limit, offset, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get reels failed"})
		return
	}
	defer rows.Close()

	out := []gin.H{}
	for rows.Next() {
		var rid, vurl, vurlLow, thumb, cap, uid, uname, uavatar string
		var views, likes, comments int
		var verified, liked, saved, hasStory bool
		var createdAt interface{}
		rows.Scan(&rid, &vurl, &vurlLow, &thumb, &cap, &views, &likes, &comments, &createdAt,
			&uid, &uname, &uavatar, &verified, &liked, &saved, &hasStory)
		out = append(out, gin.H{
			"_id": rid, "videoUrl": vurl, "videoUrlLow": vurlLow,
			"thumbnailUrl": thumb, "caption": cap,
			"views": views, "viewsCount": views,
			"likesCount": likes, "commentsCount": comments,
			"isLiked": liked, "isSaved": saved, "createdAt": createdAt,
			"user": gin.H{
				"_id": uid, "id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "hasStory": hasStory,
			},
		})
	}
	c.JSON(http.StatusOK, out)
}

// GET /users/:id/followers
func GetFollowers(c *gin.Context) {
	id := c.Param("id")
	myID := mw.UID(c)
	limit, offset := followPage(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,u.avatar,u.verified,u.bio,
		       EXISTS(SELECT 1 FROM follows ff WHERE ff.follower_id=$2::text AND ff.following_id=u.id)
		FROM follows f JOIN users u ON u.id=f.follower_id
		WHERE f.following_id=$1
		ORDER BY f.created_at DESC
		LIMIT $3 OFFSET $4`, id, myID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to load followers"})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, miniUserF(rows))
}

// GET /users/:id/following
func GetFollowing(c *gin.Context) {
	id := c.Param("id")
	myID := mw.UID(c)
	limit, offset := followPage(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,u.avatar,u.verified,u.bio,
		       EXISTS(SELECT 1 FROM follows ff WHERE ff.follower_id=$2::text AND ff.following_id=u.id)
		FROM follows f JOIN users u ON u.id=f.following_id
		WHERE f.follower_id=$1
		ORDER BY f.created_at DESC
		LIMIT $3 OFFSET $4`, id, myID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to load following"})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, miniUserF(rows))
}

// followPage — page/limit-и followers/following (default 50, max 100).
func followPage(c *gin.Context) (limit, offset int) {
	page := toInt(c.Query("page"), 1)
	if page < 1 {
		page = 1
	}
	limit = toInt(c.Query("limit"), 50)
	if limit < 1 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	return limit, (page - 1) * limit
}
