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
