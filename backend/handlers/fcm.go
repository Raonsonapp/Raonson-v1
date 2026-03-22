package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── FCM Push Notifications ────────────────────────────────────────
// Барои Firebase Cloud Messaging (FCM)
// env: FCM_SERVER_KEY = ключи Firebase

// POST /notifications/push-token   ← Flutter FCM token-ро мефиристад
func SavePushToken(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Token    string `json:"token"`
		Platform string `json:"platform"` // android|ios
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Token == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "token required"})
		return
	}

	db.Pool.Exec(context.Background(), `
		INSERT INTO push_tokens(user_id, token, platform)
		VALUES($1,$2,$3)
		ON CONFLICT(user_id, platform)
		DO UPDATE SET token=$3, updated_at=NOW()`,
		myID, b.Token, b.Platform)

	c.JSON(http.StatusOK, gin.H{"saved": true})
}

// SendPushToUser — helper барои дигар handler-ҳо
func SendPushToUser(toUserID, title, body string, data map[string]string) {
	fcmKey := os.Getenv("FCM_SERVER_KEY")
	if fcmKey == "" {
		return // FCM configured nist
	}

	// Get user's FCM tokens
	rows, err := db.Pool.Query(context.Background(),
		`SELECT token FROM push_tokens WHERE user_id=$1`, toUserID)
	if err != nil {
		return
	}
	defer rows.Close()

	var tokens []string
	for rows.Next() {
		var t string
		rows.Scan(&t)
		tokens = append(tokens, t)
	}
	if len(tokens) == 0 {
		return
	}

	// Send to each token
	for _, token := range tokens {
		go sendFCM(fcmKey, token, title, body, data)
	}
}

func sendFCM(key, token, title, body string, data map[string]string) {
	payload := map[string]interface{}{
		"to": token,
		"notification": map[string]string{
			"title": title,
			"body":  body,
			"sound": "default",
		},
		"data":     data,
		"priority": "high",
	}

	b, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST",
		"https://fcm.googleapis.com/fcm/send",
		bytes.NewReader(b))
	if err != nil {
		return
	}
	req.Header.Set("Authorization", "key="+key)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	fmt.Printf("[FCM] token:%s... status:%d resp:%s\n",
		token[:10], resp.StatusCode, string(respBody[:min(50, len(respBody))]))
}

func min(a, b int) int {
	if a < b { return a }
	return b
}
