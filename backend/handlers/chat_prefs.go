package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Функсияҳои чат, ки Instagram дорад ва Raonson надошт:
//
//    PUT  /chat/messages/:id   — таҳрири паём (15 дақиқа, танҳо матн)
//    POST /chat/pin/:peerId    — пин кардани чат (то 3, дар боло)
//    POST /chat/mute/:peerId   — хомӯш кардани чат (бе огоҳиномаи телефон)
//
//  Forward дар `SendMessageExt` аст: парчами `forwarded`.
// ══════════════════════════════════════════════════════════════════

// Instagram паёмро дар 15 дақиқаи аввал таҳрир карданро иҷозат медиҳад.
const messageEditWindow = 15 * time.Minute

// Ҳадди чатҳои пиншуда — ҳамон мисли Instagram.
const maxPinnedChats = 3

// PUT /chat/messages/:id {text}
func EditMessage(c *gin.Context) {
	msgID := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text лозим"})
		return
	}
	text := clampRunes(strings.TrimSpace(b.Text), 4000)
	if text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Паём холӣ буда наметавонад"})
		return
	}

	var sender, receiver, chatID, mtype string
	var deleted bool
	var created time.Time
	err := db.Pool.QueryRow(context.Background(), `
		SELECT sender_id, COALESCE(receiver_id,''), chat_id,
		       COALESCE(type,'text'), COALESCE(is_deleted,false), created_at
		FROM messages WHERE id=$1`, msgID).
		Scan(&sender, &receiver, &chatID, &mtype, &deleted, &created)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Паём ёфт нашуд"})
		return
	}
	// Ҳамон ҷавоб барои «паёми бегона» ва «нест» — то мавҷудияти
	// паёми каси дигар ошкор нашавад.
	if sender != myID {
		c.JSON(http.StatusNotFound, gin.H{"message": "Паём ёфт нашуд"})
		return
	}
	if deleted {
		c.JSON(http.StatusConflict, gin.H{"message": "Паём нест карда шудааст"})
		return
	}
	if mtype != "text" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Танҳо паёми матнӣ таҳрир мешавад"})
		return
	}
	if !canEditMessage(created, time.Now()) {
		c.JSON(http.StatusForbidden, gin.H{"message": "Паёмро танҳо дар 15 дақиқаи аввал таҳрир кардан мумкин аст"})
		return
	}

	var editedAt time.Time
	if err := db.Pool.QueryRow(context.Background(), `
		UPDATE messages SET text=$1, edited_at=NOW(), updated_at=NOW()
		WHERE id=$2 AND sender_id=$3 RETURNING edited_at`,
		text, msgID, myID).Scan(&editedAt); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Таҳрир нашуд"})
		return
	}

	payload := map[string]interface{}{
		"messageId": msgID, "chatId": chatID, "text": text, "editedAt": editedAt,
	}
	emitChat("chat:edit", payload, sender, receiver)
	c.JSON(http.StatusOK, payload)
}

// canEditMessage — ҳанӯз дар равзанаи таҳрир аст?
func canEditMessage(created, now time.Time) bool {
	return now.Sub(created) <= messageEditWindow
}

// POST /chat/pin/:peerId {pinned}
func PinChat(c *gin.Context) {
	myID := mw.UID(c)
	peer := c.Param("peerId")
	if peer == "" || peer == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad peer"})
		return
	}
	var b struct {
		Pinned bool `json:"pinned"`
	}
	_ = c.ShouldBindJSON(&b)

	if b.Pinned {
		var n int
		db.Pool.QueryRow(context.Background(), `
			SELECT COUNT(*) FROM chat_prefs
			WHERE user_id=$1 AND pinned AND peer_id<>$2`, myID, peer).Scan(&n)
		if n >= maxPinnedChats {
			c.JSON(http.StatusConflict, gin.H{
				"message": "Ҳадди аксар 3 чатро пин кардан мумкин аст"})
			return
		}
	}
	_, err := db.Pool.Exec(context.Background(), `
		INSERT INTO chat_prefs(user_id, peer_id, pinned, pinned_at)
		VALUES($1,$2,$3, CASE WHEN $3 THEN NOW() END)
		ON CONFLICT (user_id, peer_id) DO UPDATE
		   SET pinned=$3, pinned_at = CASE WHEN $3 THEN NOW() END`,
		myID, peer, b.Pinned)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Пин нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"pinned": b.Pinned})
}

// POST /chat/mute/:peerId {muted}
func MuteChat(c *gin.Context) {
	myID := mw.UID(c)
	peer := c.Param("peerId")
	if peer == "" || peer == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad peer"})
		return
	}
	var b struct {
		Muted bool `json:"muted"`
	}
	_ = c.ShouldBindJSON(&b)
	_, err := db.Pool.Exec(context.Background(), `
		INSERT INTO chat_prefs(user_id, peer_id, muted) VALUES($1,$2,$3)
		ON CONFLICT (user_id, peer_id) DO UPDATE SET muted=$3`,
		myID, peer, b.Muted)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хомӯш нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"muted": b.Muted})
}

// chatMuted — гиранда ин чатро хомӯш кардааст?
//
// Паём ҳамоно мерасад (дар чат ва дар рӯйхат), танҳо огоҳиномаи
// телефон намеояд — маҳз мисли Instagram.
func chatMuted(receiver, sender string) bool {
	var m bool
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(muted,false) FROM chat_prefs WHERE user_id=$1 AND peer_id=$2`,
		receiver, sender).Scan(&m)
	return m
}
