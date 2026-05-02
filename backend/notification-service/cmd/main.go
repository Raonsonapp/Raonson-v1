package main

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
)

var (
	DB              *pgxpool.Pool
	RDB             *redis.Client
	bg              = context.Background()
	realtimeSvcURL  string
	fcmServerKey    string
)

// ── MODELS ────────────────────────────────────────────────────────
type Notification struct {
	ID         string      `json:"_id"`
	Type       string      `json:"type"`
	TargetID   string      `json:"targetID"`
	Read       bool        `json:"read"`
	CreatedAt  time.Time   `json:"createdAt"`
	FromUser   *NotifUser  `json:"fromUser"`
}

type NotifUser struct {
	ID       string `json:"_id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
}

// ── MAIN ──────────────────────────────────────────────────────────
func main() {
	godotenv.Load()
	realtimeSvcURL = os.Getenv("REALTIME_SERVICE_URL")
	fcmServerKey = os.Getenv("FCM_SERVER_KEY")
	initDB()
	initRedis()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"service": "notification-service", "status": "ok"})
	})

	auth := authMiddleware()
	rl := rateLimit(60, time.Minute)

	// User-facing routes
	r.GET("/notifications",           auth, rl, getNotifications)
	r.POST("/notifications/read-all", auth, markAllRead)
	r.POST("/notifications/:id/read", auth, markOneRead)
	r.DELETE("/notifications/:id",    auth, deleteNotif)
	r.POST("/notifications/push-token", auth, savePushToken)

	// Internal: called by post-service, user-service
	r.POST("/internal/notify", createNotification)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8006"
	}
	log.Printf("🔔 notification-service :%s", port)
	r.Run(":" + port)
}

// ── GET NOTIFICATIONS ─────────────────────────────────────────────
func getNotifications(c *gin.Context) {
	myID := uid(c)
	cursor := c.Query("cursor")

	cacheKey := "notifs:" + myID + ":" + cursor
	if cursor == "" {
		if data, err := RDB.Get(bg, cacheKey).Bytes(); err == nil {
			c.Header("X-Cache", "HIT")
			c.Data(200, "application/json", data)
			return
		}
	}

	var rows *pgxpool.Rows
	var err error
	if cursor == "" {
		r, e := DB.Query(bg, `
			SELECT n.id, n.type, COALESCE(n.target_id,''), n.read, n.created_at,
			  COALESCE(u.id,''), COALESCE(u.username,''), COALESCE(u.avatar,'')
			FROM notifications n
			LEFT JOIN users u ON u.id=n.from_user_id
			WHERE n.user_id=$1
			ORDER BY n.created_at DESC LIMIT 30`, myID)
		rows, err = r, e
	} else {
		r, e := DB.Query(bg, `
			SELECT n.id, n.type, COALESCE(n.target_id,''), n.read, n.created_at,
			  COALESCE(u.id,''), COALESCE(u.username,''), COALESCE(u.avatar,'')
			FROM notifications n
			LEFT JOIN users u ON u.id=n.from_user_id
			WHERE n.user_id=$1
			  AND n.created_at < (SELECT created_at FROM notifications WHERE id=$2)
			ORDER BY n.created_at DESC LIMIT 30`, myID, cursor)
		rows, err = r, e
	}
	if err != nil {
		c.JSON(500, gin.H{"message": "query failed"})
		return
	}
	defer rows.Close()

	notifs := []Notification{}
	for rows.Next() {
		n := Notification{FromUser: &NotifUser{}}
		rows.Scan(&n.ID, &n.Type, &n.TargetID, &n.Read, &n.CreatedAt,
			&n.FromUser.ID, &n.FromUser.Username, &n.FromUser.Avatar)
		notifs = append(notifs, n)
	}

	// Unread count
	unread, _ := RDB.Get(bg, "notif:unread:"+myID).Int64()

	result := gin.H{
		"notifications": notifs,
		"unreadCount":   unread,
		"cursor":        func() string { if len(notifs) > 0 { return notifs[len(notifs)-1].ID }; return "" }(),
	}

	if cursor == "" {
		if b, err := json.Marshal(result); err == nil {
			RDB.Set(bg, cacheKey, b, 30*time.Second)
		}
	}
	c.JSON(200, result)
}

// ── MARK ALL READ ─────────────────────────────────────────────────
func markAllRead(c *gin.Context) {
	myID := uid(c)
	DB.Exec(bg, `UPDATE notifications SET read=TRUE WHERE user_id=$1 AND read=FALSE`, myID)
	RDB.Set(bg, "notif:unread:"+myID, 0, 30*24*time.Hour)
	RDB.Del(bg, "notifs:"+myID+":")
	c.JSON(200, gin.H{"success": true})
}

// ── MARK ONE READ ─────────────────────────────────────────────────
func markOneRead(c *gin.Context) {
	myID := uid(c)
	nid := c.Param("id")
	DB.Exec(bg, `UPDATE notifications SET read=TRUE WHERE id=$1 AND user_id=$2`, nid, myID)
	RDB.Decr(bg, "notif:unread:"+myID)
	c.JSON(200, gin.H{"success": true})
}

// ── DELETE NOTIFICATION ───────────────────────────────────────────
func deleteNotif(c *gin.Context) {
	myID := uid(c)
	nid := c.Param("id")
	DB.Exec(bg, `DELETE FROM notifications WHERE id=$1 AND user_id=$2`, nid, myID)
	c.JSON(200, gin.H{"success": true})
}

// ── SAVE PUSH TOKEN (FCM) ─────────────────────────────────────────
func savePushToken(c *gin.Context) {
	myID := uid(c)
	var b struct {
		Token    string `json:"token"    binding:"required"`
		Platform string `json:"platform"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(400, gin.H{"message": "token required"})
		return
	}
	if b.Platform == "" {
		b.Platform = "android"
	}
	DB.Exec(bg, `
		INSERT INTO push_tokens(user_id,token,platform,updated_at)
		VALUES($1,$2,$3,NOW())
		ON CONFLICT(user_id,platform) DO UPDATE SET token=$2, updated_at=NOW()`,
		myID, b.Token, b.Platform)
	// Cache in Redis
	RDB.Set(bg, "fcm:"+myID+":"+b.Platform, b.Token, 30*24*time.Hour)
	c.JSON(200, gin.H{"success": true})
}

// ── CREATE NOTIFICATION — internal endpoint ───────────────────────
// Called by post-service (like/comment) and user-service (follow)
//
// Body:
//
//	{ "userID": "recipient", "fromUserID": "actor", "type": "like|comment|follow", "targetID": "post_id" }
func createNotification(c *gin.Context) {
	var b struct {
		UserID     string `json:"userID"     binding:"required"`
		FromUserID string `json:"fromUserID" binding:"required"`
		Type       string `json:"type"       binding:"required"`
		TargetID   string `json:"targetID"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}
	// Don't notify yourself
	if b.UserID == b.FromUserID {
		c.JSON(200, gin.H{"ok": true, "skipped": "self"})
		return
	}
	// Dedup — skip if same notification in last 5 min
	dedupKey := "notif:dedup:" + b.UserID + ":" + b.FromUserID + ":" + b.Type + ":" + b.TargetID
	if n, _ := RDB.Exists(bg, dedupKey).Result(); n > 0 {
		c.JSON(200, gin.H{"ok": true, "dedup": true})
		return
	}
	RDB.Set(bg, dedupKey, "1", 5*time.Minute)

	// Insert to DB
	var nid string
	DB.QueryRow(bg,
		`INSERT INTO notifications(user_id,from_user_id,type,target_id)
		 VALUES($1,$2,$3,$4) RETURNING id`,
		b.UserID, b.FromUserID, b.Type, b.TargetID).Scan(&nid)

	// Increment unread counter
	RDB.Incr(bg, "notif:unread:"+b.UserID)
	RDB.Expire(bg, "notif:unread:"+b.UserID, 30*24*time.Hour)

	// Invalidate cache
	RDB.Del(bg, "notifs:"+b.UserID+":")

	// Async: push to WebSocket + FCM
	go sendWS(b.UserID, b.Type, b.TargetID, b.FromUserID)
	go sendFCM(b.UserID, b.Type, b.FromUserID)

	c.JSON(201, gin.H{"ok": true, "id": nid})
}

// ── SEND TO WEBSOCKET via realtime-service ────────────────────────
func sendWS(userID, nType, targetID, fromUserID string) {
	if realtimeSvcURL == "" {
		return
	}
	payload, _ := json.Marshal(map[string]interface{}{
		"type":       nType,
		"targetID":   targetID,
		"fromUserID": fromUserID,
	})
	body, _ := json.Marshal(map[string]interface{}{
		"userID":  userID,
		"type":    "notification",
		"payload": json.RawMessage(payload),
	})
	resp, err := http.Post(realtimeSvcURL+"/internal/send", "application/json", bytes.NewReader(body))
	if err != nil {
		log.Printf("[notif] ws send error: %v", err)
		return
	}
	resp.Body.Close()
}

// ── SEND FCM PUSH NOTIFICATION ────────────────────────────────────
func sendFCM(userID, nType, fromUsername string) {
	if fcmServerKey == "" {
		return
	}
	// Get token from Redis first, then DB
	token, err := RDB.Get(bg, "fcm:"+userID+":android").Result()
	if err != nil {
		DB.QueryRow(bg,
			`SELECT token FROM push_tokens WHERE user_id=$1 ORDER BY updated_at DESC LIMIT 1`,
			userID).Scan(&token)
	}
	if token == "" {
		return
	}

	title, body := notifText(nType, fromUsername)
	payload := map[string]interface{}{
		"to": token,
		"notification": map[string]string{
			"title": title,
			"body":  body,
			"sound": "default",
		},
		"data": map[string]string{
			"type":        nType,
			"fromUser":    fromUsername,
			"click_action": "FLUTTER_NOTIFICATION_CLICK",
		},
		"priority": "high",
	}
	b, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "https://fcm.googleapis.com/fcm/send", bytes.NewReader(b))
	req.Header.Set("Authorization", "key="+fcmServerKey)
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		log.Printf("[notif] FCM error: %v", err)
		return
	}
	resp.Body.Close()
}

func notifText(nType, from string) (title, body string) {
	switch nType {
	case "like":
		return "New Like 💙", from + " liked your post"
	case "comment":
		return "New Comment 💬", from + " commented on your post"
	case "follow":
		return "New Follower 👤", from + " started following you"
	default:
		return "Raonson", "You have a new notification"
	}
}

// ── HELPERS ───────────────────────────────────────────────────────
func uid(c *gin.Context) string {
	v, _ := c.Get("userID")
	s, _ := v.(string)
	return s
}

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if id := c.GetHeader("X-User-ID"); id != "" {
			c.Set("userID", id)
			c.Next()
			return
		}
		h := c.GetHeader("Authorization")
		if h == "" || !strings.HasPrefix(h, "Bearer ") {
			c.JSON(401, gin.H{"message": "No token"})
			c.Abort()
			return
		}
		secret := os.Getenv("JWT_SECRET")
		if secret == "" {
			secret = "raonson-secret-change-in-prod"
		}
		tok, err := jwt.Parse(h[7:],
			func(t *jwt.Token) (interface{}, error) { return []byte(secret), nil },
			jwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !tok.Valid {
			c.JSON(401, gin.H{"message": "Invalid token"})
			c.Abort()
			return
		}
		claims := tok.Claims.(jwt.MapClaims)
		c.Set("userID", claims["id"].(string))
		c.Next()
	}
}

func rateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct {
		count int
		reset time.Time
	}
	store := map[string]*entry{}
	var mu sync.Mutex
	return func(c *gin.Context) {
		k := uid(c)
		if k == "" {
			k = c.ClientIP()
		}
		now := time.Now()
		mu.Lock()
		e, ok := store[k]
		if !ok || now.After(e.reset) {
			store[k] = &entry{1, now.Add(window)}
			mu.Unlock()
			c.Next()
			return
		}
		e.count++
		n := e.count
		mu.Unlock()
		if n > limit {
			c.JSON(429, gin.H{"message": "Too many requests"})
			c.Abort()
			return
		}
		c.Next()
	}
}

func initDB() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL not set")
	}
	cfg, _ := pgxpool.ParseConfig(dsn)
	cfg.MaxConns = 8
	cfg.MinConns = 2
	var err error
	DB, err = pgxpool.NewWithConfig(bg, cfg)
	if err != nil {
		log.Fatalf("DB init: %v", err)
	}
	if err = DB.Ping(bg); err != nil {
		log.Fatalf("DB ping: %v", err)
	}
	log.Println("✅ PostgreSQL connected")
}

func initRedis() {
	url := os.Getenv("REDIS_URL")
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	opt, _ := redis.ParseURL(url)
	opt.PoolSize = 10
	RDB = redis.NewClient(opt)
	if err := RDB.Ping(bg).Err(); err != nil {
		log.Fatalf("Redis ping: %v", err)
	}
	log.Println("✅ Redis connected")
}
