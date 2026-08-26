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
	"raonson/utils"

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
	// best-effort: мутақобилан unfollow. RETURNING лозим аст — то донем
	// кадом робита вуҷуд дошт ва шумории дурустро кам кунем. Бе ин
	// followers_count/following_count абадӣ нодуруст мемонад.
	rows, err := db.Pool.Query(context.Background(),
		`DELETE FROM follows WHERE (follower_id=$1 AND following_id=$2)
		    OR (follower_id=$2 AND following_id=$1)
		 RETURNING follower_id, following_id`, myID, target)
	if err == nil {
		type pair struct{ follower, following string }
		var removed []pair
		for rows.Next() {
			var p pair
			if rows.Scan(&p.follower, &p.following) == nil {
				removed = append(removed, p)
			}
		}
		rows.Close()
		for _, p := range removed {
			db.Pool.Exec(context.Background(),
				`UPDATE users SET following_count=GREATEST(following_count-1,0) WHERE id=$1`,
				p.follower)
			db.Pool.Exec(context.Background(),
				`UPDATE users SET followers_count=GREATEST(followers_count-1,0) WHERE id=$1`,
				p.following)
		}
	}
	mw.InvalidateUserCache(myID)
	mw.InvalidateUserCache(target)
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

// ═══════════════════════ MUTE / UNMUTE ═══════════════════════

// POST /users/:id/mute
func MuteUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	if target == "" || target == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad target"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO muted_users(user_id, muted_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, target)
	mw.CacheDel("feed:"+myID+":1", "feed:"+myID+":2",
		"smartfeed:"+myID+":1", "smartfeed:"+myID+":2",
		"smartreels:"+myID+":1", "smartreels:"+myID+":2")
	c.JSON(http.StatusOK, gin.H{"muted": true})
}

// DELETE /users/:id/mute
func UnmuteUser(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	db.Pool.Exec(context.Background(),
		`DELETE FROM muted_users WHERE user_id=$1 AND muted_id=$2`, myID, target)
	mw.CacheDel("feed:"+myID+":1", "feed:"+myID+":2",
		"smartfeed:"+myID+":1", "smartfeed:"+myID+":2",
		"smartreels:"+myID+":1", "smartreels:"+myID+":2")
	c.JSON(http.StatusOK, gin.H{"unmuted": true})
}

// ═══════════════════════ SUGGESTED USERS ═══════════════════════

// GET /users/suggested?limit=10 (max 20)
// Корбароне, ки худамон нестем, пайравӣ накардаем ва блок нашудаанд.
func GetSuggestedUsers(c *gin.Context) {
	myID := mw.UID(c)
	limit := toInt(c.Query("limit"), 10)
	if limit < 1 {
		limit = 10
	}
	if limit > 20 {
		limit = 20
	}

	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, u.avatar, u.verified, COALESCE(u.bio,''),
		       u.followers_count
		FROM users u
		WHERE u.id <> $1
		  AND COALESCE(u.banned,false) = FALSE
		  AND NOT EXISTS (
		      SELECT 1 FROM follows f
		      WHERE f.follower_id=$1 AND f.following_id=u.id
		  )
		  AND NOT EXISTS (
		      SELECT 1 FROM blocks b
		      WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		         OR (b.blocker_id=u.id AND b.blocked_id=$1)
		  )
		ORDER BY u.followers_count DESC, u.created_at DESC
		LIMIT $2
	`, myID, limit)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}
	defer rows.Close()

	users := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, bio string
		var verified bool
		var followers int
		rows.Scan(&id, &uname, &avatar, &verified, &bio, &followers)
		users = append(users, gin.H{
			"_id":            id,
			"username":       uname,
			"avatar":         avatar,
			"verified":       verified,
			"bio":            bio,
			"followersCount": followers,
		})
	}
	c.JSON(http.StatusOK, gin.H{"users": users})
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
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO user_reports(reported_id, user_id, reason, description)
		 VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`, target, myID, b.Reason, b.Description)
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
	mw.CacheDel("profile:me:" + myID)
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// ═══════════════════════ REELS extras ═══════════════════════

// POST /reels/:id/report
func ReportReel(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	var b struct {
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	c.ShouldBindJSON(&b)
	if b.Reason == "" {
		b.Reason = "spam"
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO reel_reports(reel_id, user_id, reason, description)
		 VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`, rid, myID, b.Reason, b.Description)
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

// POST /reels/:id/interest — frontend инро ҷеғ мезад, вале backend
// route надошт (404). Баргардонидани "not interested"-и қаблӣ, агар буда бошад.
func MarkReelInterested(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	db.Pool.Exec(context.Background(),
		`DELETE FROM reel_not_interested WHERE reel_id=$1 AND user_id=$2`, rid, myID)
	c.JSON(http.StatusOK, gin.H{"interested": true})
}

// GET /reels/:id/stats — танҳо соҳиби reel мебинад.
func GetReelStats(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)

	// Танҳо соҳиб мебинад (мисли GetPostStats).
	var ownerID string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM reels WHERE id=$1`, rid).Scan(&ownerID)
	if ownerID == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}
	if ownerID != myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Not your reel"})
		return
	}

	var likes, comments, views, saves int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(likes_count,0), COALESCE(comments_count,0),
		        COALESCE(views_count,0),
		        (SELECT COUNT(*) FROM reel_saves WHERE reel_id=$1)
		 FROM reels WHERE id=$1`, rid).
		Scan(&likes, &comments, &views, &saves)

	// Миёнаи тамошо (ms) аз reel_watch.
	var avgWatchMs int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(ROUND(AVG(watch_ms)),0)::int
		 FROM reel_watch WHERE reel_id=$1`, rid).Scan(&avgWatchMs)

	// shares — ҳоло ҷадвали shares нест → 0.
	c.JSON(http.StatusOK, gin.H{
		"views":      views,
		"likes":      likes,
		"comments":   comments,
		"saves":      saves,
		"shares":     0,
		"avgWatchMs": avgWatchMs,
	})
}

// POST /reels/:id/watch — сабти вақти тамошои як reel.
// Body: {"watchMs":1234,"completed":true}
func TrackReelWatch(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	var b struct {
		WatchMs   int  `json:"watchMs"`
		Completed bool `json:"completed"`
	}
	c.ShouldBindJSON(&b)
	if b.WatchMs < 0 {
		b.WatchMs = 0
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO reel_watch(user_id, reel_id, watch_ms, completed, created_at)
		 VALUES($1,$2,$3,$4,NOW())
		 ON CONFLICT (user_id, reel_id) DO UPDATE
		   SET watch_ms=EXCLUDED.watch_ms,
		       completed=EXCLUDED.completed,
		       created_at=NOW()`,
		myID, rid, b.WatchMs, b.Completed)
	c.JSON(http.StatusOK, gin.H{"ok": true})
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
	b.Text = clampRunes(b.Text, 1000)
	if flagged, cats := utils.ModerateText(context.Background(), b.Text); flagged {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Матн қоидаҳои ҷамъиятиро вайрон мекунад", "categories": cats})
		return
	}
	var commentsOff bool
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(comments_off,false) FROM reels WHERE id=$1`, rid).Scan(&commentsOff)
	if commentsOff {
		c.JSON(http.StatusForbidden, gin.H{"message": "Шарҳҳо барои ин Reel хомӯш карда шудаанд"})
		return
	}
	var newID string
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO reel_comments(reel_id, user_id, text, parent_id)
		 VALUES($1,$2,$3,$4) RETURNING id`, rid, myID, b.Text, parent).Scan(&newID)
	c.JSON(http.StatusCreated, gin.H{"_id": newID, "text": b.Text, "parentId": parent})
}

// PUT /reels/:id/caption — соҳиб caption-ро иваз мекунад
func UpdateReelCaption(c *gin.Context) {
	rid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Caption string `json:"caption"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "caption required"})
		return
	}
	res, err := db.Pool.Exec(context.Background(),
		`UPDATE reels SET caption=$1 WHERE id=$2 AND user_id=$3`,
		b.Caption, rid, myID)
	if err != nil || res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found or not owner"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"updated": true, "caption": b.Caption})
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
	var repliesOff bool
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id, COALESCE(replies_off,false) FROM stories WHERE id=$1`,
		sid).Scan(&ownerID, &repliesOff)
	if repliesOff {
		c.JSON(http.StatusForbidden, gin.H{"message": "Ҷавобҳо хомӯш карда шудаанд"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO story_replies(story_id, from_user_id, text) VALUES($1,$2,$3)`,
		sid, myID, b.Text)
	if ownerID != "" && ownerID != myID {
		db.Pool.Exec(context.Background(),
			`INSERT INTO notifications(user_id, from_user_id, type, target_id)
			 VALUES($1,$2,'story_reply',$3)`, ownerID, myID, sid)
		// Мисли Instagram: ҷавоби сторис ба DM-и соҳиб меравад (realtime).
		chatID := sortedChatID(myID, ownerID)
		var msgID string
		if e := db.Pool.QueryRow(context.Background(), `
			INSERT INTO messages
			  (chat_id, sender_id, receiver_id, text, type, created_at, updated_at)
			VALUES ($1,$2,$3,$4,'text',NOW(),NOW()) RETURNING id`,
			chatID, myID, ownerID,
			"💬 Ҷавоб ба сторис: "+b.Text).Scan(&msgID); e == nil {
			if msg, fe := fetchMessageByID(msgID, ownerID); fe == nil {
				emitChat("chat:new", msg, ownerID)
			}
		}
		pushNotify(ownerID, myID, "story_reply", sid, "ба сторисатон ҷавоб дод")
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
