package handlers

// Эндпоинтҳои нав, ки frontend ҷеғ мезад, вале backend намедошт.
// (block/unblock, blocked list, hashtag feed, post likers, avatar delete,
//  reel report/not-interest/stats/comment-like/reply, story reply, notif prefs)

import (
	"context"
	"encoding/json"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ═══════════════════════ BLOCK / UNBLOCK ═══════════════════════

// POST /users/:id/block
func BlockUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	if target == "" || target == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad target"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO blocks(blocker_id, blocked_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, target)
	// best-effort: мутақобилан unfollow
	db.Pool.Exec(context.Background(),
		`DELETE FROM follows WHERE (follower_id=$1 AND following_id=$2)
		    OR (follower_id=$2 AND following_id=$1)`, myID, target)
	c.JSON(http.StatusOK, gin.H{"blocked": true})
}

// POST /users/:id/unblock
func UnblockUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	db.Pool.Exec(context.Background(),
		`DELETE FROM blocks WHERE blocker_id=$1 AND blocked_id=$2`, myID, target)
	c.JSON(http.StatusOK, gin.H{"unblocked": true})
}

// POST /users/:id/report — шикоят аз корбар
func ReportUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	if target == "" || target == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad target"})
		return
	}
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO user_reports(reported_id, user_id, reason)
		 VALUES($1,$2,$3) ON CONFLICT DO NOTHING`, target, myID, b.Reason)
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /users/:id/restrict — маҳдуд кардани корбар (мисли Instagram)
func RestrictUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	if target == "" || target == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad target"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO user_restricts(user_id, restricted_id)
		 VALUES($1,$2) ON CONFLICT DO NOTHING`, myID, target)
	c.JSON(http.StatusOK, gin.H{"restricted": true})
}

// POST /users/:id/unrestrict
func UnrestrictUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	db.Pool.Exec(context.Background(),
		`DELETE FROM user_restricts WHERE user_id=$1 AND restricted_id=$2`, myID, target)
	c.JSON(http.StatusOK, gin.H{"unrestricted": true})
}

// GET /users/blocked
func GetBlockedUsers(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(),
		`SELECT u.id, u.username, COALESCE(u.avatar,''),
		        COALESCE(u.verified,false), COALESCE(u.bio,'')
		 FROM blocks b JOIN users u ON u.id=b.blocked_id
		 WHERE b.blocker_id=$1`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, gin.H{"users": miniUser(rows)})
}

// ═══════════════════════ HASHTAG FEED ═══════════════════════

// GET /posts/hashtag/:tag
func HashtagPosts(c *gin.Context) {
	myID := mw.UID(c)
	tag := c.Param("tag")
	page := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 24)
	offset := (page - 1) * limit
	pattern := "%#" + tag + "%"
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE p.caption ILIKE $2 AND COALESCE(p.hidden,false)=false
		ORDER BY p.created_at DESC LIMIT $3 OFFSET $4`,
		myID, pattern, limit, offset)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": scanFeedPosts(rows)})
}

// GET /posts/:id/likes — рӯйхати лайк кардагон
func GetPostLikers(c *gin.Context) {
	pid := c.Param("id")
	rows, err := db.Pool.Query(context.Background(),
		`SELECT u.id, u.username, COALESCE(u.avatar,''),
		        COALESCE(u.verified,false), COALESCE(u.bio,'')
		 FROM post_likes pl JOIN users u ON u.id=pl.user_id
		 WHERE pl.post_id=$1 ORDER BY pl.created_at DESC LIMIT 100`, pid)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, gin.H{"users": miniUser(rows)})
}

// DELETE /profile/avatar
func DeleteAvatar(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(), `UPDATE users SET avatar='' WHERE id=$1`, myID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// ═══════════════════════ REELS extras ═══════════════════════

// POST /reels/:id/report
func ReportReel(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO reel_reports(reel_id, user_id, reason)
		 VALUES($1,$2,$3) ON CONFLICT DO NOTHING`, rid, myID, b.Reason)
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /reels/:id/not_interest
func MarkReelNotInterested(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	db.Pool.Exec(context.Background(),
		`INSERT INTO reel_not_interested(reel_id, user_id)
		 VALUES($1,$2) ON CONFLICT DO NOTHING`, rid, myID)
	c.JSON(http.StatusOK, gin.H{"not_interested": true})
}

// GET /reels/:id/stats
func GetReelStats(c *gin.Context) {
	rid := c.Param("id")
	var likes, comments, views int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(likes_count,0), COALESCE(comments_count,0),
		        COALESCE(views_count,0) FROM reels WHERE id=$1`, rid).
		Scan(&likes, &comments, &views)
	c.JSON(http.StatusOK, gin.H{
		"likesCount": likes, "commentsCount": comments, "viewsCount": views,
	})
}

// POST /reels/:id/comments/:commentId/like — toggle
func LikeReelComment(c *gin.Context) {
	myID := mw.UID(c)
	cid := c.Param("commentId")
	var exists bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM reel_comment_likes WHERE comment_id=$1 AND user_id=$2)`,
		cid, myID).Scan(&exists)
	if exists {
		db.Pool.Exec(context.Background(),
			`DELETE FROM reel_comment_likes WHERE comment_id=$1 AND user_id=$2`, cid, myID)
		c.JSON(http.StatusOK, gin.H{"liked": false})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO reel_comment_likes(comment_id, user_id)
		 VALUES($1,$2) ON CONFLICT DO NOTHING`, cid, myID)
	c.JSON(http.StatusOK, gin.H{"liked": true})
}

// POST /reels/:id/comments/:commentId/reply
func ReplyReelComment(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	parent := c.Param("commentId")
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	var newID string
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO reel_comments(reel_id, user_id, text, parent_id)
		 VALUES($1,$2,$3,$4) RETURNING id`, rid, myID, b.Text, parent).Scan(&newID)
	c.JSON(http.StatusCreated, gin.H{"_id": newID, "text": b.Text, "parentId": parent})
}

// ═══════════════════════ STORY REPLY ═══════════════════════

// POST /stories/:id/reply
func ReplyStory(c *gin.Context) {
	myID := mw.UID(c)
	sid := c.Param("id")
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	var ownerID string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM stories WHERE id=$1`, sid).Scan(&ownerID)
	db.Pool.Exec(context.Background(),
		`INSERT INTO story_replies(story_id, from_user_id, text) VALUES($1,$2,$3)`,
		sid, myID, b.Text)
	if ownerID != "" && ownerID != myID {
		db.Pool.Exec(context.Background(),
			`INSERT INTO notifications(user_id, from_user_id, type, target_id)
			 VALUES($1,$2,'story_reply',$3)`, ownerID, myID, sid)
	}
	c.JSON(http.StatusCreated, gin.H{"sent": true})
}

// ═══════════════════════ NOTIFICATION PREFS ═══════════════════════

// GET /profile/notifications
func GetNotifPrefs(c *gin.Context) {
	myID := mw.UID(c)
	var raw string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(notif_prefs::text,'{}') FROM users WHERE id=$1`, myID).Scan(&raw)
	if raw == "" {
		raw = "{}"
	}
	c.Data(http.StatusOK, "application/json; charset=utf-8", []byte(raw))
}

// PUT /profile/notifications
func UpdateNotifPrefs(c *gin.Context) {
	myID := mw.UID(c)
	var prefs map[string]interface{}
	if err := c.ShouldBindJSON(&prefs); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad body"})
		return
	}
	jb, _ := json.Marshal(prefs)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET notif_prefs=$1::jsonb WHERE id=$2`, string(jb), myID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}
