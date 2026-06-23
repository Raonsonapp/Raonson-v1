package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"sort"
	"strings"
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
		WHERE s.expires_at > NOW() AND COALESCE(s.archived,false)=FALSE
		ORDER BY s.created_at DESC`)
	c.JSON(http.StatusOK, scanStoryRows(rows))
}

// POST /stories/:id/archive — toggle архив (соҳиб)
func ToggleStoryArchive(c *gin.Context) {
	sid := c.Param("id")
	myID := mw.UID(c)
	var arch bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE stories SET archived = NOT COALESCE(archived,false)
		 WHERE id=$1 AND user_id=$2::text RETURNING archived`, sid, myID).Scan(&arch)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"archived": arch})
}

// POST /stories/:id/toggle-replies — хомӯш/фаъол кардани ҷавобҳо (соҳиб)
func ToggleStoryReplies(c *gin.Context) {
	sid := c.Param("id")
	myID := mw.UID(c)
	var off bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE stories SET replies_off = NOT COALESCE(replies_off,false)
		 WHERE id=$1 AND user_id=$2::text RETURNING replies_off`, sid, myID).Scan(&off)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"repliesOff": off})
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
	// Эътибори медиа: танҳо URL-и https (мисли SendMessageExt).
	if !strings.HasPrefix(b.MediaURL, "https://") {
		c.JSON(http.StatusBadRequest, gin.H{"message": "mediaUrl must be https"})
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
	// Бинандаи худи соҳибро ҳисоб намекунем (мисли Instagram).
	var owner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM stories WHERE id=$1`, sid).Scan(&owner)
	if owner == myID {
		c.JSON(http.StatusOK, gin.H{"viewed": true})
		return
	}
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
		var owner string
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM stories WHERE id=$1`, sid).Scan(&owner)
		notify(owner, myID, "story_like", sid)
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
	page  := toInt(c.Query("page"), 1)
	if page < 1 {
		page = 1
	}
	limit := toInt(c.Query("limit"), 50)
	if limit < 1 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	offset := (page - 1) * limit
	var viewCount, likeCount, replyCount int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM story_views WHERE story_id=$1::text AND user_id <> $2::text`,
		sid, ownerID).Scan(&viewCount)
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM story_likes WHERE story_id=$1::text`, sid).Scan(&likeCount)
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM story_replies WHERE story_id=$1::text`, sid).Scan(&replyCount)

	// Рӯйхати воқеии бинандагон + оё лайк кардаанд (Instagram "seen by")
	viewers := []gin.H{}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, COALESCE(u.avatar,''),
		       COALESCE(u.verified,false), COALESCE(u.full_name,''),
		       EXISTS(SELECT 1 FROM story_likes sl
		              WHERE sl.story_id=$1::text AND sl.user_id=u.id) AS liked
		FROM story_views sv JOIN users u ON u.id=sv.user_id
		WHERE sv.story_id=$1::text AND sv.user_id <> $2::text
		ORDER BY sv.viewed_at DESC NULLS LAST
		LIMIT $3 OFFSET $4`, sid, ownerID, limit, offset)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, uname, avatar, fullName string
			var verified, liked bool
			rows.Scan(&id, &uname, &avatar, &verified, &fullName, &liked)
			viewers = append(viewers, gin.H{
				"_id": id, "id": id, "username": uname, "avatar": avatar,
				"verified": verified, "fullName": fullName, "liked": liked,
			})
		}
	}

	// Омори подписчикон: чанд нафар аз пайравон диданд
	var followersTotal, followersViewed int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(followers_count,0) FROM users WHERE id=$1`,
		ownerID).Scan(&followersTotal)
	db.Pool.QueryRow(context.Background(), `
		SELECT COUNT(*) FROM story_views sv
		JOIN follows f ON f.follower_id=sv.user_id AND f.following_id=$2
		WHERE sv.story_id=$1`, sid, ownerID).Scan(&followersViewed)
	notFollowers := viewCount - followersViewed
	if notFollowers < 0 {
		notFollowers = 0
	}

	c.JSON(http.StatusOK, gin.H{
		"viewsCount":      viewCount,
		"likesCount":      likeCount,
		"repliesCount":    replyCount,
		"interactions":    likeCount + replyCount,
		"followersTotal":  followersTotal,
		"followersViewed": followersViewed,
		"nonFollowers":    notFollowers,
		"viewers":         viewers,
		"page":            page,
	})
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
	page  := toInt(c.Query("page"), 1)
	if page < 1 {
		page = 1
	}
	limit := toInt(c.Query("limit"), 30)
	if limit < 1 {
		limit = 30
	}
	if limit > 100 {
		limit = 100
	}
	offset := (page - 1) * limit
	// One row per conversation (latest message), newest first — DISTINCT ON
	// avoids the old "one row per message" duplication + 100-message truncation.
	rows, err := db.Pool.Query(context.Background(), `
		SELECT sub.id,sub.chat_id,sub.sender_id,sub.receiver_id,sub.text,sub.read,sub.created_at,
		       sub.s_username,sub.s_avatar,sub.s_verified,sub.r_username,sub.r_avatar,sub.r_verified,
		       EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=$1
		              AND f.following_id = CASE WHEN sub.sender_id=$1 THEN sub.receiver_id ELSE sub.sender_id END) AS i_follow,
		       EXISTS(SELECT 1 FROM messages mm WHERE mm.chat_id=sub.chat_id AND mm.sender_id=$1) AS i_sent,
		       EXISTS(SELECT 1 FROM chat_accepts ca WHERE ca.user_id=$1
		              AND ca.peer_id = CASE WHEN sub.sender_id=$1 THEN sub.receiver_id ELSE sub.sender_id END) AS accepted,
		       EXISTS(SELECT 1 FROM chat_hidden ch WHERE ch.user_id=$1
		              AND ch.peer_id = CASE WHEN sub.sender_id=$1 THEN sub.receiver_id ELSE sub.sender_id END) AS hidden,
		       (SELECT COUNT(*) FROM messages mu WHERE mu.chat_id=sub.chat_id
		              AND mu.receiver_id=$1 AND mu.read=false) AS unread_count
		FROM (
			SELECT DISTINCT ON (m.chat_id)
			       m.id,m.chat_id,m.sender_id,m.receiver_id,m.text,m.read,m.created_at,
			       s.username AS s_username,s.avatar AS s_avatar,s.verified AS s_verified,
			       r.username AS r_username,r.avatar AS r_avatar,r.verified AS r_verified
			FROM messages m
			JOIN users s ON s.id=m.sender_id
			JOIN users r ON r.id=m.receiver_id
			WHERE (m.sender_id=$1 OR m.receiver_id=$1)
			ORDER BY m.chat_id, m.created_at DESC
		) sub
		ORDER BY sub.created_at DESC
		LIMIT $2 OFFSET $3`, myID, limit, offset)
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
		var sVer, rVer, iFollow, iSent, accepted, hidden bool
		var unreadCount int
		rows.Scan(&msgID, &chatID, &senderID, &receiverID, &text, &read, &createdAt,
			&sUname, &sAvatar, &sVer, &rUname, &rAvatar, &rVer, &iFollow, &iSent, &accepted, &hidden, &unreadCount)

		if hidden {
			continue // корбар ин дархостро нест/пинҳон кардааст
		}
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
		// Message request: I don't follow + never replied + haven't accepted.
		isRequest := !iFollow && !iSent && !accepted
		result = append(result, gin.H{
			"_id": msgID, "chatId": chatID,
			"isMine": isMine, "text": text, "read": read, "createdAt": createdAt,
			"peer": peer, "isRequest": isRequest, "unreadCount": unreadCount,
		})
	}
	c.JSON(http.StatusOK, gin.H{"chats": result, "page": page, "limit": limit})
}

// POST /chat/requests/:peerId/accept — дархостро қабул мекунад
func AcceptChatRequest(c *gin.Context) {
	myID := mw.UID(c)
	peer := c.Param("peerId")
	if peer == "" || peer == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad peer"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO chat_accepts(user_id,peer_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, peer)
	// Агар қаблан пинҳон карда буд, барқарор кунем.
	db.Pool.Exec(context.Background(),
		`DELETE FROM chat_hidden WHERE user_id=$1 AND peer_id=$2`, myID, peer)
	c.JSON(http.StatusOK, gin.H{"accepted": true})
}

// POST /chat/requests/:peerId/delete — дархостро нест/пинҳон мекунад
func DeleteChatRequest(c *gin.Context) {
	myID := mw.UID(c)
	peer := c.Param("peerId")
	if peer == "" || peer == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad peer"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO chat_hidden(user_id,peer_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, peer)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// GET /chat/:chatId/messages
func GetMessages(c *gin.Context) {
	chatID := c.Param("chatId")
	myID   := mw.UID(c)
	page  := toInt(c.Query("page"), 1)
	if page < 1 {
		page = 1
	}
	limit := toInt(c.Query("limit"), 30)
	if limit < 1 {
		limit = 30
	}
	if limit > 100 {
		limit = 100
	}
	offset := (page - 1) * limit
	// Паёмҳои ОХИРИНро (page) мегирем (на аввалин), вале бо тартиби афзоянда
	// бармегардонем — то дар чатҳои дароз ҳам зуд ва дуруст бошад.
	// Иштироккунанда: танҳо паёмҳое, ки корбар фиристода ё гирифтааст. Шарти
	// (sender_id=$4 OR receiver_id=$4) ҳатмист — то паёмҳои ХУДИ корбар ҳеҷ
	// гоҳ пинҳон нашаванд (вагарна паёми навфиристода "гум" мешуд).
	rows, err := db.Pool.Query(context.Background(), `
		SELECT id,chat_id,sender_id,text,media_url,type,reply_to_id,
		       is_deleted,read,created_at,username,avatar,verified
		FROM (
		  SELECT m.id,m.chat_id,m.sender_id,m.text,COALESCE(m.media_url,'') media_url,
		         COALESCE(m.type,'text') type,COALESCE(m.reply_to_id,'') reply_to_id,
		         COALESCE(m.is_deleted,false) is_deleted,m.read,m.created_at,
		         u.username,u.avatar,u.verified
		  FROM messages m JOIN users u ON u.id=m.sender_id
		  WHERE m.chat_id=$1 AND (m.sender_id=$4 OR m.receiver_id=$4)
		  ORDER BY m.created_at DESC LIMIT $2 OFFSET $3
		) sub ORDER BY created_at ASC`, chatID, limit, offset, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get messages failed"})
		return
	}
	defer rows.Close()

	messages := []gin.H{}
	for rows.Next() {
		var mid, cid, sid, text, murl, mtype, replyTo string
		var read, isDeleted bool
		var createdAt interface{}
		var uname, uavatar string
		var verified bool
		rows.Scan(&mid, &cid, &sid, &text, &murl, &mtype, &replyTo, &isDeleted,
			&read, &createdAt, &uname, &uavatar, &verified)
		messages = append(messages, gin.H{
			"_id": mid, "chatId": cid, "text": text, "mediaUrl": murl,
			"type": mtype, "replyToId": replyTo, "isDeleted": isDeleted,
			"read": read, "createdAt": createdAt,
			"sender": gin.H{"_id": sid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	c.JSON(http.StatusOK, gin.H{"messages": messages, "page": page, "limit": limit})
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
	b.Text = clampRunes(b.Text, 1000)

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
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`UPDATE notifications SET read=TRUE WHERE id=$1 AND user_id=$2`,
		c.Param("id"), myID)
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
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM notifications WHERE id=$1 AND user_id=$2`, c.Param("id"), myID)
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
		       u.id, u.username, u.avatar,
		       (SELECT COUNT(*) FROM post_views pv WHERE pv.post_id=p.id)
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE COALESCE(p.hidden,false)=FALSE
		  AND COALESCE(p.archived,false)=FALSE
		  AND COALESCE(u.banned,false)=FALSE
		ORDER BY p.likes_count DESC, p.created_at DESC LIMIT 40`)
	posts := []gin.H{}
	if pRows != nil {
		defer pRows.Close()
		for pRows.Next() {
			var pid, uid, uname, uavatar string
			var likes int
			var views int64
			var createdAt, media interface{}
			pRows.Scan(&pid, &likes, &createdAt, &media, &uid, &uname, &uavatar, &views)
			posts = append(posts, gin.H{
				"_id": pid, "likesCount": likes, "viewsCount": views,
				"createdAt": createdAt,
				"media": nilToEmpty(media),
				"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar},
			})
		}
	}

	rRows, _ := db.Pool.Query(context.Background(), `
		SELECT id, video_url, likes_count, views_count
		FROM reels
		ORDER BY likes_count DESC LIMIT 20`)
	reels := []gin.H{}
	if rRows != nil {
		defer rRows.Close()
		for rRows.Next() {
			var rid, vurl string
			var likes, views int
			rRows.Scan(&rid, &vurl, &likes, &views)
			reels = append(reels, gin.H{
				"_id": rid, "videoUrl": vurl,
				"thumbnailUrl": vurl, // use video URL as thumbnail fallback
				"likesCount": likes, "viewsCount": views,
			})
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

// POST /admin/verify/:id — галочка медиҳад (admin only).
// Body: {"months": 1..12} → то N моҳ; {"months": 0} ё холӣ → беохир (бе мӯҳлат).
func VerifyUser(c *gin.Context) {
	var b struct {
		Months int `json:"months"`
	}
	c.ShouldBindJSON(&b)
	if b.Months > 0 {
		if b.Months > 12 {
			b.Months = 12
		}
		db.Pool.Exec(context.Background(),
			`UPDATE users SET verified=TRUE,
			        verified_until = NOW() + ($2 * INTERVAL '1 month')
			 WHERE id=$1`, c.Param("id"), b.Months)
		c.JSON(http.StatusOK, gin.H{"verified": true, "months": b.Months})
		return
	}
	// Беохир
	db.Pool.Exec(context.Background(),
		`UPDATE users SET verified=TRUE, verified_until=NULL WHERE id=$1`,
		c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"verified": true, "months": 0})
}

// POST /admin/unverify/:id — галочкаро мегирад (admin only).
// Аккаунти соҳиби барнома (@raonson) ҳеҷ гоҳ галочкаашро гум намекунад.
func UnverifyUser(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE users SET verified=FALSE
		 WHERE id=$1 AND LOWER(username) <> 'raonson'`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"verified": false})
}

// POST /admin/vip/:id — VIP медиҳад (720p/1080p-и аниме) (admin only).
func SetVip(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE users SET is_vip=TRUE WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"is_vip": true})
}

// POST /admin/unvip/:id — VIP-ро мегирад (admin only).
func UnsetVip(c *gin.Context) {
	db.Pool.Exec(context.Background(),
		`UPDATE users SET is_vip=FALSE WHERE id=$1`, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"is_vip": false})
}

// DELETE /admin/users/:id — аккаунтро пурра нест мекунад (admin only).
// Соҳиби барнома (@raonson) нест карда намешавад.
func AdminDeleteUser(c *gin.Context) {
	id := c.Param("id")
	var uname string
	db.Pool.QueryRow(context.Background(),
		`SELECT username FROM users WHERE id=$1`, id).Scan(&uname)
	if uname == "" {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}
	if uname == "raonson" {
		c.JSON(http.StatusForbidden, gin.H{"error": "Owner account cannot be deleted"})
		return
	}
	if _, err := db.Pool.Exec(context.Background(),
		`DELETE FROM users WHERE id=$1`, id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Delete failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// GET /admin/users?q=<query> — рӯйхати корбарон барои admin (ҷустуҷӯ)
func AdminListUsers(c *gin.Context) {
	q := c.Query("q")
	rows, err := db.Pool.Query(context.Background(), `
		SELECT id, username, COALESCE(avatar,''),
		       COALESCE(verified,false), COALESCE(banned,false),
		       COALESCE(role,'user'), COALESCE(is_vip,false),
		       COALESCE(phone,'')
		FROM users
		WHERE ($1 = '' OR username ILIKE '%' || $1 || '%')
		ORDER BY (LOWER(username)='raonson') DESC, username ASC
		LIMIT 50`, q)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Query failed"})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, username, avatar, role, phone string
		var verified, banned, isVip bool
		if rows.Scan(&id, &username, &avatar, &verified, &banned, &role, &isVip, &phone) == nil {
			// Соҳиби барнома ҳамеша VIP нишон дода мешавад.
			if strings.EqualFold(username, "raonson") {
				isVip = true
			}
			out = append(out, gin.H{
				"_id": id, "id": id, "username": username, "avatar": avatar,
				"verified": verified, "banned": banned, "role": role,
				"is_vip": isVip, "phone": phone,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"users": out})
}

var _ = sort.Strings
var _ = time.Now
