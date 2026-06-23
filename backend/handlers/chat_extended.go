package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/sockets"

	"github.com/gin-gonic/gin"
)

// ─────────────────────────────────────────────────────────────────
//  POST /messages/:id/react
// ─────────────────────────────────────────────────────────────────
func ReactToMessage(c *gin.Context) {
	msgID := c.Param("id")
	myID  := mw.UID(c)

	var body struct {
		Emoji string `json:"emoji" binding:"required"`
	}
	if err := c.ShouldBindJSON(&body); err != nil || body.Emoji == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "emoji required"})
		return
	}

	// Upsert: remove old reaction by same user on same message, then insert
	_, err := db.Pool.Exec(context.Background(), `
		INSERT INTO message_reactions (message_id, user_id, emoji, created_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT (message_id, user_id) DO UPDATE SET emoji=$3, created_at=NOW()
	`, msgID, myID, body.Emoji)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "db error"})
		return
	}

	// Push to both participants in real time
	sender, receiver := participantsOf(msgID)
	emitChat("chat:reaction", map[string]interface{}{
		"messageId": msgID,
		"emoji":     body.Emoji,
		"userId":    myID,
	}, sender, receiver)

	c.JSON(http.StatusOK, gin.H{"reacted": true, "emoji": body.Emoji})
}

// ─────────────────────────────────────────────────────────────────
//  DELETE /messages/:id
// ─────────────────────────────────────────────────────────────────
func DeleteMessage(c *gin.Context) {
	msgID := c.Param("id")
	myID  := mw.UID(c)

	// Only sender can delete
	var senderID, receiverID string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT sender_id, COALESCE(receiver_id,'') FROM messages WHERE id=$1`,
		msgID).Scan(&senderID, &receiverID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "message not found"})
		return
	}
	if senderID != myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "not your message"})
		return
	}

	// Soft-delete: mark as deleted, clear text
	_, err = db.Pool.Exec(context.Background(), `
		UPDATE messages SET is_deleted=true, text='', updated_at=NOW()
		WHERE id=$1`, msgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "db error"})
		return
	}

	// Push deletion to both participants in real time
	emitChat("chat:delete", map[string]interface{}{
		"messageId": msgID,
	}, senderID, receiverID)

	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// ─────────────────────────────────────────────────────────────────
//  Real-time push helper — fires the event over the WS hub to each
//  participant (deduplicated). Бе ин, паёмҳои бо REST фиристодашуда
//  ба тарафи дигар фавран намерасиданд (таъхири чанддақиқагӣ).
// ─────────────────────────────────────────────────────────────────
func emitChat(event string, data interface{}, userIDs ...string) {
	seen := map[string]bool{}
	for _, uid := range userIDs {
		if uid == "" || seen[uid] {
			continue
		}
		seen[uid] = true
		sockets.EmitToUser(uid, event, data)
	}
}

// participantsOf — sender_id ва receiver_id-и як паёмро бармегардонад.
func participantsOf(msgID string) (sender, receiver string) {
	db.Pool.QueryRow(context.Background(),
		`SELECT sender_id, COALESCE(receiver_id,'') FROM messages WHERE id=$1`,
		msgID).Scan(&sender, &receiver)
	return
}

// ─────────────────────────────────────────────────────────────────
//  Extended SendMessage — supports mediaUrl, replyToId, type
// ─────────────────────────────────────────────────────────────────
type SendMessageExtRequest struct {
	ReceiverID string `json:"receiverId" binding:"required"`
	Text       string `json:"text"`
	MediaURL   string `json:"mediaUrl"`
	MediaType  string `json:"type"` // "text"|"image"|"video"|"audio"
	ReplyToID  string `json:"replyToId"`
}

func SendMessageExt(c *gin.Context) {
	chatID := c.Param("chatId")
	myID   := mw.UID(c)

	var body SendMessageExtRequest
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}
	if body.Text == "" && body.MediaURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text or mediaUrl required"})
		return
	}

	msgType := body.MediaType
	if msgType == "" {
		msgType = "text"
	}

	// Эътибори медиа: танҳо URL-и https + навъи иҷозатдодашуда.
	if body.MediaURL != "" {
		if !strings.HasPrefix(body.MediaURL, "https://") {
			c.JSON(http.StatusBadRequest, gin.H{"message": "mediaUrl must be https"})
			return
		}
		switch msgType {
		case "image", "video", "audio", "file":
		default:
			c.JSON(http.StatusBadRequest, gin.H{"message": "invalid media type"})
			return
		}
	}

	var replyToPtr *string
	if body.ReplyToID != "" {
		replyToPtr = &body.ReplyToID
	}

	var msgID string
	err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO messages
		  (chat_id, sender_id, receiver_id, text, type, media_url, reply_to_id, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW())
		RETURNING id
	`, chatID, myID, body.ReceiverID, body.Text, msgType, nullString(body.MediaURL), replyToPtr).Scan(&msgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "db error: " + err.Error()})
		return
	}

	// Fetch full message to return
	msg, err := fetchMessageByID(msgID, myID)
	if err != nil {
		c.JSON(http.StatusCreated, gin.H{"_id": msgID})
		return
	}

	// Push to the receiver in real time (sender already has it via this
	// response / optimistic insert). Бе ин таъхири чанддақиқагӣ мешуд.
	emitChat("chat:new", msg, body.ReceiverID)

	c.JSON(http.StatusCreated, msg)
}

func nullString(s string) interface{} {
	if s == "" {
		return nil
	}
	return s
}

func fetchMessageByID(msgID, myID string) (map[string]interface{}, error) {
	row := db.Pool.QueryRow(context.Background(), `
		SELECT m.id, m.chat_id, m.text, m.type, m.media_url, m.reply_to_id,
		       m.is_deleted, m.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       m.sender_id
		FROM messages m
		JOIN users u ON u.id = m.sender_id
		WHERE m.id = $1
	`, msgID)

	var (
		id, chatID, text, mType string
		mediaURL, replyToID     *string
		isDeleted               bool
		createdAt               time.Time
		senderID, username, avatar string
		verified               bool
	)
	if err := row.Scan(
		&id, &chatID, &text, &mType, &mediaURL, &replyToID,
		&isDeleted, &createdAt,
		&senderID, &username, &avatar, &verified,
		&senderID,
	); err != nil {
		return nil, err
	}

	msg := map[string]interface{}{
		"_id":       id,
		"chatId":    chatID,
		"text":      text,
		"type":      mType,
		"isDeleted": isDeleted,
		"createdAt": createdAt,
		"isMine":    senderID == myID,
		"sender": map[string]interface{}{
			"_id":      senderID,
			"username": username,
			"avatar":   avatar,
			"verified": verified,
		},
	}
	if mediaURL != nil {
		msg["mediaUrl"] = *mediaURL
	}
	if replyToID != nil {
		msg["replyToId"] = *replyToID
	}
	return msg, nil
}
