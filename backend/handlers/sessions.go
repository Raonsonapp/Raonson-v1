package handlers

import (
	"context"
	"net/http"
	"strings"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// Таърихи воридшавӣ / дастгоҳҳои фаъол (Login history).

// recordLogin — ҳангоми Login як сабти нав месозад (device + IP).
func recordLogin(userID string, c *gin.Context) {
	device := parseDevice(c.Request.UserAgent())
	ip := c.ClientIP()
	go func() {
		db.Pool.Exec(context.Background(),
			`INSERT INTO login_sessions(user_id, device, ip) VALUES($1,$2,$3)`,
			userID, device, ip)
		// Танҳо 20 сабти охирин нигоҳ дошта мешавад.
		db.Pool.Exec(context.Background(), `
			DELETE FROM login_sessions WHERE user_id=$1 AND id NOT IN (
				SELECT id FROM login_sessions WHERE user_id=$1
				ORDER BY created_at DESC LIMIT 20)`, userID)
	}()
}

func parseDevice(ua string) string {
	ua = strings.TrimSpace(ua)
	if ua == "" {
		return "Дастгоҳи номаълум"
	}
	l := strings.ToLower(ua)
	os := "Дастгоҳ"
	switch {
	case strings.Contains(l, "android"):
		os = "Android"
	case strings.Contains(l, "iphone") || strings.Contains(l, "ios"):
		os = "iPhone"
	case strings.Contains(l, "ipad"):
		os = "iPad"
	case strings.Contains(l, "windows"):
		os = "Windows"
	case strings.Contains(l, "mac"):
		os = "Mac"
	case strings.Contains(l, "linux"):
		os = "Linux"
	}
	if len(ua) > 60 {
		ua = ua[:60]
	}
	return os + " · " + ua
}

// GET /auth/sessions → таърихи воридшавии корбар
func GetSessions(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(),
		`SELECT id, device, ip, created_at FROM login_sessions
		 WHERE user_id=$1 ORDER BY created_at DESC LIMIT 20`, myID)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, device, ip string
			var createdAt interface{}
			rows.Scan(&id, &device, &ip, &createdAt)
			out = append(out, gin.H{
				"id": id, "device": device, "ip": ip, "createdAt": createdAt,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"sessions": out})
}

// POST /auth/revoke-all → таърихро тоза мекунад
func RevokeAllSessions(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(),
		`DELETE FROM login_sessions WHERE user_id=$1`, myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// PUT /profile/auto-reply {text} → танзими ҷавоби худкор
func SetAutoReply(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Text string `json:"text"`
	}
	c.ShouldBindJSON(&b)
	text := strings.TrimSpace(b.Text)
	if len(text) > 500 {
		text = text[:500]
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET auto_reply=$1 WHERE id=$2`, text, myID)
	c.JSON(http.StatusOK, gin.H{"autoReply": text})
}

// GET /profile/auto-reply → матни ҷории ҷавоби худкор
func GetAutoReply(c *gin.Context) {
	myID := mw.UID(c)
	var text string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(auto_reply,'') FROM users WHERE id=$1`, myID).Scan(&text)
	c.JSON(http.StatusOK, gin.H{"autoReply": text})
}

// maybeAutoReply — вақте ин аввалин паёми фиристанда дар чат бошад ва
// қабулкунанда ҷавоби худкор дошта бошад, як ҷавоби худкор мефиристад.
func maybeAutoReply(chatID, senderID, receiverID string) {
	if senderID == receiverID { // ба худ ҷавоби худкор намеравад
		return
	}
	go func() {
		var reply string
		db.Pool.QueryRow(context.Background(),
			`SELECT COALESCE(auto_reply,'') FROM users WHERE id=$1`,
			receiverID).Scan(&reply)
		if strings.TrimSpace(reply) == "" {
			return
		}
		var cnt int
		db.Pool.QueryRow(context.Background(),
			`SELECT COUNT(*) FROM messages WHERE chat_id=$1 AND sender_id=$2`,
			chatID, senderID).Scan(&cnt)
		if cnt != 1 { // на аввалин паём
			return
		}
		var msgID string
		err := db.Pool.QueryRow(context.Background(), `
			INSERT INTO messages
			  (chat_id, sender_id, receiver_id, text, type, created_at, updated_at)
			VALUES ($1, $2, $3, $4, 'text', NOW(), NOW()) RETURNING id`,
			chatID, receiverID, senderID, reply).Scan(&msgID)
		if err != nil {
			return
		}
		// Фиристанда ҷавобро фавран мебинад (на танҳо баъди refresh).
		if msg, e := fetchMessageByID(msgID, senderID); e == nil {
			emitChat("chat:new", msg, senderID)
		}
	}()
}
