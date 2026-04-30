package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── STORIES ──────────────────────────────────────────────────────

// GET /stories
func GetStories(c *gin.Context) {
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT s.id,s.media_url,s.media_type,s.expires_at,s.created_at,
		       u.id,u.username,u.avatar,u.verified
		FROM stories s JOIN users u ON u.id=s.user_id
		WHERE s.expires_at > NOW() ORDER BY s.created_at DESC`)
	c.JSON(http.StatusOK, scanStoryRows(rows))
}

// GET /stories/my
func GetMyStories(c *gin.Context) {
	myID := mw.UID(c)
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT s.id,s.media_url,s.media_type,s.expires_at,s.created_at,
		       u.id,u.username,u.avatar,u.verified
		FROM stories s JOIN users u ON u.id=s.user_id
		WHERE s.user_id=$1 AND s.expires_at > NOW()
		ORDER BY s.created_at DESC`, myID)
	c.JSON(http.StatusOK, scanStoryRows(rows))
}

// POST /stories
func CreateStory(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		MediaURL  string `json:"mediaUrl"`
		MediaType string `json:"mediaType"`
		Caption   string `json:"caption"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.MediaURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "mediaUrl and mediaType required"})
		return
	}
	exp := time.Now().Add(24 * time.Hour)
	var sid string
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO stories(user_id,media_url,media_type,expires_at,caption) VALUES($1,$2,$3,$4,$5) RETURNING id`,
		myID, b.MediaURL, b.MediaType, exp, b.Caption).Scan(&sid)
	c.JSON(http.StatusCreated, gin.H{
		"_id": sid, "mediaUrl": b.MediaURL, "mediaType": b.MediaType,
		"expiresAt": exp, "caption": b.Caption,
	})
}

// POST /stories/:id/view
func ViewStory(c *gin.Context) {
	sid  := c.Param("id")
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`INSERT INTO story_views(story_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, sid, myID)
	c.JSON(http.StatusOK, gin.H{"viewed": true})
}

// POST /stories/:id/like
func LikeStory(c *gin.Context) {
	sid  := c.Param("id")
	myID := mw.UID(c)
	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM story_likes WHERE story_id=$1::text AND user_id=$2::text)`,
		sid, myID).Scan(&liked)
	if liked {
		db.Pool.Exec(context.Background(),
			`DELETE FROM story_likes WHERE story_id=$1::text AND user_id=$2::text`, sid, myID)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO story_likes(story_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, sid, myID)
	}
	c.JSON(http.StatusOK, gin.H{"liked": !liked})
}

// GET /stories/:id/viewers
func GetStoryViewers(c *gin.Context) {
	sid  := c.Param("id")
	myID := mw.UID(c)
	var ownerID string
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM stories WHERE id=$1`, sid).Scan(&ownerID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Story not found"})
		return
	}
	if ownerID != myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Not authorized"})
		return
	}
	var viewCount, likeCount int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM story_views WHERE story_id=$1::text`, sid).Scan(&viewCount)
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM story_likes WHERE story_id=$1::text`, sid).Scan(&likeCount)
	c.JSON(http.StatusOK, gin.H{"viewsCount": viewCount, "likesCount": likeCount})
}

// DELETE /stories/:id
func DeleteStory(c *gin.Context) {
	sid  := c.Param("id")
	myID := mw.UID(c)
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM stories WHERE id=$1 AND user_id=$2::text`, sid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Story not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

func scanStoryRows(rows interface {
	Next() bool
	Scan(...any) error
	Close()
}) []gin.H {
	stories := []gin.H{}
	if rows == nil {
		return stories
	}
	defer rows.Close()
	for rows.Next() {
		var sid, murl, mtype, uid, uname, uavatar string
		var verified bool
		var exp, createdAt interface{}
		rows.Scan(&sid, &murl, &mtype, &exp, &createdAt, &uid, &uname, &uavatar, &verified)
		stories = append(stories, gin.H{
			"_id": sid, "mediaUrl": murl, "mediaType": mtype,
			"expiresAt": exp, "createdAt": createdAt,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	return stories
}

// ── CHAT ─────────────────────────────────────────────────────────

// GET /chat/with/:userId
func GetOrCreateChat(c *gin.Context) {
	myID   := mw.UID(c)
	peerID := c.Param("userId")
	c.JSON(http.StatusOK, gin.H{"chatId": sortedChatID(myID, peerID)})
}

// GET /chat
func GetChats(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT m.id,m.chat_id,m.sender_id,m.receiver_id,m.text,m.read,m.created_at,
		       s.username,s.avatar,s.verified,
		       r.username,r.avatar,r.verified
		FROM messages m
		JOIN users s ON s.id=m.sender_id
		JOIN users r ON r.id=m.receiver_id
		WHERE (m.sender_id=$1 OR m.receiver_id=$1)
		ORDER BY m.created_at DESC LIMIT 100`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get chats failed"})
		return
	}
	defer rows.Close()

	result := []gin.H{}
	for rows.Next() {
		var msgID, chatID, senderID, receiverID, text string
		var read bool
		var createdAt interface{}
		var sUname, sAvatar, rUname, rAvatar string
		var sVer, rVer bool
		rows.Scan(&msgID, &chatID, &senderID, &receiverID, &text, &read, &createdAt,
			&sUname, &sAvatar, &sVer, &rUname, &rAvatar, &rVer)

		isMine := senderID == myID
		var peer gin.H
		if isMine {
			peer = gin.H{"_id": receiverID, "username": rUname, "avatar": rAvatar, "verified": rVer}
		} else {
			peer = gin.H{"_id": senderID, "username": sUname, "avatar": sAvatar, "verified": sVer}
		}
		if peer["username"] == "" {
			continue
		}
		result = append(result, gin.H{
			"_id": msgID, "chatId": chatID,
			"isMine": isMine, "text": text, "read": read, "createdAt": createdAt,
			"peer": peer,
		})
	}
	c.JSON(http.StatusOK, result)
}

// GET /chat/:chatId/messages
func GetMessages(c *gin.Context) {
	chatID := c.Param("chatId")
	rows, err := db.Pool.Query(context.Background(), `
		SELECT m.id,m.chat_id,m.sender_id,m.text,m.media_url,m.read,m.created_at,
		       u.username,u.avatar,u.verified
		FROM messages m JOIN users u ON u.id=m.sender_id
		WHERE m.chat_id=$1 ORDER BY m.created_at ASC LIMIT 100`, chatID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get messages failed"})
		return
	}
	defer rows.Close()

	messages := []gin.H{}
	for rows.Next() {
		var mid, cid, sid, text, murl string
		var read bool
		var createdAt interface{}
		var uname, uavatar string
		var verified bool
		rows.Scan(&mid, &cid, &sid, &text, &murl, &read, &createdAt, &uname, &uavatar, &verified)
		messages = append(messages, gin.H{
			"_id": mid, "chatId": cid, "text": text, "mediaUrl": murl,
			"read": read, "createdAt": createdAt,
			"sender": gin.H{"_id": sid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	c.JSON(http.StatusOK, gin.H{"messages": messages})
}

// POST /chat/:chatId/messages
func SendMessage(c *gin.Context) {
	chatID := c.Param("chatId")
	myID   := mw.UID(c)
	var b struct {
		Text       string `json:"text"`
		ReceiverID string `json:"receiverId"`
	}
	c.ShouldBindJSON(&b)

	var msgID string
	var createdAt interface{}
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO messages(chat_id,sender_id,receiver_id,text) VALUES($1,$2,$3,$4) RETURNING id,created_at`,
		chatID, myID, b.ReceiverID, b.Text).Scan(&msgID, &createdAt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Send failed"})
		return
	}

	var uname, uavatar string
	var verified bool
	db.Pool.QueryRow(context.Background(),
		`SELECT username,avatar,verified FROM users WHERE id=$1`, myID,
	).Scan(&uname, &uavatar, &verified)

	c.JSON(http.StatusCreated, gin.H{
		"_id": msgID, "chatId": chatID, "text": b.Text, "read": false,
		"createdAt": createdAt,
		"sender": gin.H{"_id": myID, "username": uname, "avatar": uavatar, "verified": verified},
	})
}

// POST /chat/:chatId/read
func MarkChatRead(c *gin.Context) {
	chatID := c.Param("chatId")
	myID   := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`UPDATE messages SET read=TRUE WHERE chat_id=$1::text AND receiver_id=$2::text`, chatID, myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}


// ── NOTIFICATIONS ─────────────────────────────────────────────────

// GET /notifications
func GetNotifications(c *gin.Context) {
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 30)
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT n.id,n.type,n.target_id,n.read,n.created_at,
		       u.id,u.username,u.avatar,u.verified
		FROM notifications n
		LEFT JOIN users u ON u.id=n.from_user_id
		WHERE n.user_id=$1
		ORDER BY n.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get notifications failed"})
		return
	}
	defer rows.Close()

	notifs := []gin.H{}
	for rows.Next() {
		var nid, ntype string
		var targetID, uid, uname, uavatar *string
		var read, verified bool
		var createdAt interface{}
		rows.Scan(&nid, &ntype, &targetID, &read, &createdAt,
			&uid, &uname, &uavatar, &verified)
		n := gin.H{"_id": nid, "type": ntype, "read": read, "createdAt": createdAt}
		if targetID != nil { n["targetId"] = *targetID }
		if uid != nil {
			n["fromUser"] = gin.H{
				"_id": *uid, "username": *uname,
				"avatar": *uavatar, "verified": verified,
			}
		}
		notifs = append(notifs, n)
	}
	var unread int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1::text AND read=FALSE`, myID).Scan(&unread)
	c.JSON(http.StatusOK, gin.H{"notifications": notifs, "unreadCount": unread, "page": page})
}

// POST /notifications/:id/read
func MarkNotifRead(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE notifications SET read=TRUE WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"read": true})
}

// POST /notifications/read-all
func MarkAllNotifsRead(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`UPDATE notifications SET read=TRUE WHERE user_id=$1::text`, myID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// DELETE /notifications/:id
func DeleteNotification(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`DELETE FROM notifications WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// ── EXPLORE ───────────────────────────────────────────────────────

// GET /explore  (cached 5 min)
func ExploreGrid(c *gin.Context) {
	cacheKey := "explore:grid"
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}
	pRows, _ := db.Pool.Query(context.Background(), `
		SELECT p.id, p.likes_count, p.created_at,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type)
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id),
		       u.id, u.username, u.avatar
		FROM posts p JOIN users u ON u.id=p.user_id
		ORDER BY p.likes_count DESC, p.created_at DESC LIMIT 40`)
	posts := []gin.H{}
	if pRows != nil {
		defer pRows.Close()
		for pRows.Next() {
			var pid, uid, uname, uavatar string
			var likes int
			var createdAt, media interface{}
			pRows.Scan(&pid, &likes, &createdAt, &media, &uid, &uname, &uavatar)
			posts = append(posts, gin.H{
				"_id": pid, "likesCount": likes, "createdAt": createdAt,
				"media": nilToEmpty(media),
				"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar},
			})
		}
	}

	rRows, _ := db.Pool.Query(context.Background(), `
		SELECT id,video_url,likes_count FROM reels
		ORDER BY likes_count DESC LIMIT 20`)
	reels := []gin.H{}
	if rRows != nil {
		defer rRows.Close()
		for rRows.Next() {
			var rid, vurl string
			var likes int
			rRows.Scan(&rid, &vurl, &likes)
			reels = append(reels, gin.H{"_id": rid, "videoUrl": vurl, "likesCount": likes})
		}
	}
	result := gin.H{"posts": posts, "reels": reels}
	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 5*time.Minute)
	}
	c.JSON(http.StatusOK, result)
}

// POST /upload
func UploadFile(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Upload via Cloudinary directly from Flutter"})
}

// ── ADMIN ─────────────────────────────────────────────────────────

// GET /admin/stats
func AdminStats(c *gin.Context) {
	var users, posts, reels, stories, notifs int
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM users`).Scan(&users)
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM posts`).Scan(&posts)
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM reels`).Scan(&reels)
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM stories WHERE expires_at > NOW()`).Scan(&stories)
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM notifications`).Scan(&notifs)
	c.JSON(http.StatusOK, gin.H{
		"users": users, "posts": posts, "reels": reels,
		"stories": stories, "notifications": notifs,
	})
}

// POST /admin/ban/:id
func BanUser(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE users SET banned=TRUE WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"banned": true})
}

// POST /admin/unban/:id
func UnbanUser(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE users SET banned=FALSE WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"banned": false})
}

var _ = sort.Strings
var _ = time.Now
