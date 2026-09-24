package handlers

import (
	"context"
	"log"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	ntf "raonson/notify"
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

	// Танҳо иштирокчиёни сӯҳбат. Пеш ҳар кас ба ҳар id-и паём реаксия
	// гузошта метавонист.
	if sender, receiver := participantsOf(msgID); myID == "" ||
		(myID != sender && myID != receiver) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Паём ёфт нашуд"})
		return
	}
	body.Emoji = clampRunes(body.Emoji, 8)

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
	// НЕ "required": гиранда аз худи chatID гирифта мешавад. Пештар
	// экранҳое, ки "receiver" мефиристоданд, 400 мегирифтанд ва
	// фиристодани пост ба чат хомӯшона кор намекард.
	ReceiverID string `json:"receiverId"`
	Receiver   string `json:"receiver"` // номи алтернативӣ (socket ҳамин ном дорад)
	Text       string `json:"text"`
	MediaURL   string `json:"mediaUrl"`
	MediaType  string `json:"type"` // "text"|"image"|"video"|"audio"|"share"
	ReplyToID  string `json:"replyToId"`
	// Барои мубодилаи пост/рилс/сторис — то дар чат корти пешнамоиш барояд.
	ShareID    string `json:"shareId"`
	ShareKind  string `json:"shareKind"` // "post"|"reel"|"story"
	ShareThumb string `json:"shareThumb"`
	ShareUser  string `json:"shareUser"`
	// Расм танҳо як бор дида мешавад.
	ViewOnce   bool `json:"viewOnce"`
	// Аз чати дигар фиристода шуд (Forward) — гиранда «Фиристода шуд» мебинад.
	Forwarded  bool `json:"forwarded"`
	// Vanish mode — баъди дидан ва бастани чат нест мешавад.
	Vanish     bool `json:"vanish"`
	// Вақти фиристодан (RFC3339). Холӣ — фавран.
	SendAt     string `json:"sendAt"`
	// Шиносаи маҳаллии телефон — барои такрорнашавӣ ҳангоми
	// фиристодани дубора аз навбати офлайн.
	ClientID   string `json:"clientId"`
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

	// Гирандаро аз худи chatID мегирем — он "idA_idB"-и мураттабшуда аст.
	// Ба client бовар намекунем ва номи майдонро талаб намекунем.
	receiver := body.ReceiverID
	if receiver == "" {
		receiver = body.Receiver
	}
	// ⚠️ Фиристанда БОЯД аъзои ҳамин чат бошад. Пеш, агар chatId
	// ба ӯ тааллуқ надошт, гиранда аз body гирифта мешуд ва паём зери
	// chatId-и ду нафари бегона сабт мешуд — дар сӯҳбати онҳо пайдо мешуд.
	a, b, ok := strings.Cut(chatID, "_")
	switch {
	case ok && myID == a:
		receiver = b
	case ok && myID == b:
		receiver = a
	default:
		c.JSON(http.StatusForbidden, gin.H{"message": "Шумо аъзои ин чат нестед"})
		return
	}
	if receiver == "" || receiver == myID || chatID != sortedChatID(myID, receiver) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Гирандаи паём муайян нашуд"})
		return
	}

	// Басташуда паём фиристода наметавонад — на ба ман, на ман ба ӯ.
	// Пеш паём мерасид ва ҳатто огоҳинома медод.
	if denyIfBlocked(c, myID, receiver) {
		return
	}

	// Эътибори медиа: танҳо URL-и https + навъи иҷозатдодашуда.
	if body.MediaURL != "" {
		if !strings.HasPrefix(body.MediaURL, "https://") {
			c.JSON(http.StatusBadRequest, gin.H{"message": "mediaUrl must be https"})
			return
		}
		switch msgType {
		case "image", "video", "audio", "file", "share":
		default:
			c.JSON(http.StatusBadRequest, gin.H{"message": "invalid media type"})
			return
		}
	}

	var replyToPtr *string
	if body.ReplyToID != "" {
		replyToPtr = &body.ReplyToID
	}

	clientID := clampRunes(strings.TrimSpace(body.ClientID), 64)

	// Вақтбандӣ: танҳо дар оянда ва на дуртар аз 30 рӯз.
	var sendAt *time.Time
	if strings.TrimSpace(body.SendAt) != "" {
		t, err := time.Parse(time.RFC3339, body.SendAt)
		if err != nil || !t.After(time.Now().Add(30*time.Second)) ||
			t.After(time.Now().Add(30*24*time.Hour)) {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Вақт бояд дар оянда бошад (то 30 рӯз)"})
			return
		}
		sendAt = &t
	}

	// ⚠️ Такрор набояд паёми дуюм созад.
	//
	// Телефон паёмро дар навбат нигоҳ медорад ва ҳангоми баргаштани
	// интернет аз нав мефиристад. Агар дархости аввал расида бошад,
	// вале ҷавоб гум шуда бошад, бе ин санҷиш ҳамсӯҳбат ду паёми
	// якхела медид.
	if clientID != "" {
		var existing string
		db.Pool.QueryRow(context.Background(),
			`SELECT id FROM messages WHERE sender_id=$1 AND client_id=$2`,
			myID, clientID).Scan(&existing)
		if existing != "" {
			if msg, err := fetchMessageByID(existing, myID); err == nil {
				c.JSON(http.StatusCreated, msg)
				return
			}
		}
	}

	var msgID string
	err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO messages
		  (chat_id, sender_id, receiver_id, text, type, media_url, reply_to_id,
		   share_id, share_kind, share_thumb, share_user, view_once,
		   client_id, forwarded, vanish, scheduled_at, created_at, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,
		        NULLIF($8,''),NULLIF($9,''),NULLIF($10,''),NULLIF($11,''),$12,
		        $13,$14,$15,$16,COALESCE($16,NOW()),NOW())
		RETURNING id
	`, chatID, myID, receiver, body.Text, msgType, nullString(body.MediaURL), replyToPtr,
		body.ShareID, body.ShareKind, body.ShareThumb, body.ShareUser,
		body.ViewOnce, clientID, body.Forwarded, body.Vanish, sendAt).Scan(&msgID)
	if err != nil {
		log.Printf("[Chat] send message failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Send failed"})
		return
	}

	// Fetch full message to return
	msg, err := fetchMessageByID(msgID, myID)
	if err != nil {
		c.JSON(http.StatusCreated, gin.H{"_id": msgID})
		return
	}

	// Вақтбандишуда: ҳозир ба гиранда ҲЕҶ чиз намеравад — на socket,
	// на огоҳинома. `DeliverScheduledMessages` дар вақташ мефиристад.
	if sendAt != nil {
		msg["scheduledAt"] = *sendAt
		c.JSON(http.StatusCreated, msg)
		return
	}

	// Push to the receiver in real time (sender already has it via this
	// response / optimistic insert). Бе ин таъхири чанддақиқагӣ мешуд.
	emitChat("chat:new", msg, receiver)

	// ⚠️ Огоҳиномаи телефон. Ин ҶО НАБУД.
	//
	// `emitChat` танҳо ба WebSocket мефиристад — яъне танҳо ба
	// барномаи КУШОДА. Агар корбар барномаро баста бошад (маҳз он
	// вақте ки огоҳинома лозим аст), ҳеҷ чиз намеомад.
	//
	// Қабати огоҳинома навъи «message»-ро аллакай пурра дастгирӣ
	// мекард (`notify/kind.go`: High, ChannelMessages) — танҳо ҳеҷ
	// кас онро даъват намекард.
	//
	// Агар гиранда ин чатро ХОМӮШ карда бошад — огоҳиномаи телефон
	// намеравад. Паём худаш ҳамоно мерасад.
	if !chatMuted(receiver, myID) {
		pushNotify(receiver, myID, string(ntf.Message), chatID, "")
	}

	// Ҷавоби худкор — агар ин аввалин паём ба корбари дорои auto-reply бошад.
	maybeAutoReply(chatID, myID, receiver)

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
		       m.sender_id, m.edited_at, COALESCE(m.forwarded,false),
		       COALESCE(m.vanish,false)
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
		editedAt               *time.Time
		forwarded              bool
		vanish                 bool
	)
	if err := row.Scan(
		&id, &chatID, &text, &mType, &mediaURL, &replyToID,
		&isDeleted, &createdAt,
		&senderID, &username, &avatar, &verified,
		&senderID, &editedAt, &forwarded, &vanish,
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
		"forwarded": forwarded,
		"vanish":    vanish,
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
	if editedAt != nil {
		msg["editedAt"] = *editedAt
	}
	return msg, nil
}

// POST /chat/messages/:id/opened — расми «як бор дида мешавад» кушода шуд.
// Танҳо гиранда метавонад онро сарф кунад; баъд аз ин URL ба ҳеҷ кас
// баргардонда намешавад.
func MarkViewOnceOpened(c *gin.Context) {
	msgID := c.Param("id")
	myID  := mw.UID(c)
	ct, err := db.Pool.Exec(context.Background(), `
		UPDATE messages SET viewed_once=TRUE, read=TRUE, updated_at=NOW()
		WHERE id=$1 AND receiver_id=$2::text
		  AND COALESCE(view_once,false)=TRUE
		  AND COALESCE(viewed_once,false)=FALSE`, msgID, myID)
	if err != nil || ct.RowsAffected() == 0 {
		c.JSON(http.StatusOK, gin.H{"consumed": false})
		return
	}
	// Ба фиристанда хабар медиҳем, то дар экранаш «кушода шуд» шавад.
	sender, _ := participantsOf(msgID)
	emitChat("chat:viewOnceOpened",
		map[string]interface{}{"messageId": msgID}, sender)
	c.JSON(http.StatusOK, gin.H{"consumed": true})
}
