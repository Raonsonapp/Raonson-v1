package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
)

var (
	hub *Hub
	RDB *redis.Client
	bg  = context.Background()
)

// ── MESSAGE TYPES ─────────────────────────────────────────────────
type WSMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// ── HUB: manages all live WebSocket connections ───────────────────
type Hub struct {
	mu      sync.RWMutex
	clients map[string]*Client // userID → Client
}

type Client struct {
	userID string
	conn   *websocket.Conn
	send   chan []byte
}

func newHub() *Hub { return &Hub{clients: make(map[string]*Client)} }

func (h *Hub) register(cl *Client) {
	h.mu.Lock()
	// Close old connection if exists
	if old, ok := h.clients[cl.userID]; ok {
		close(old.send)
	}
	h.clients[cl.userID] = cl
	h.mu.Unlock()
	log.Printf("[ws] connected: %s (total=%d)", cl.userID, len(h.clients))
}

func (h *Hub) unregister(cl *Client) {
	h.mu.Lock()
	if h.clients[cl.userID] == cl {
		delete(h.clients, cl.userID)
		close(cl.send)
	}
	h.mu.Unlock()
	log.Printf("[ws] disconnected: %s (total=%d)", cl.userID, len(h.clients))
}

// deliver returns true if client is on THIS instance
func (h *Hub) deliver(userID string, msg []byte) bool {
	h.mu.RLock()
	cl, ok := h.clients[userID]
	h.mu.RUnlock()
	if !ok {
		return false
	}
	select {
	case cl.send <- msg:
		return true
	default:
		log.Printf("[ws] send buffer full for %s, dropping", userID)
		return false
	}
}

// ── WEBSOCKET UPGRADER ────────────────────────────────────────────
var upgrader = websocket.Upgrader{
	ReadBufferSize:    4096,
	WriteBufferSize:   4096,
	EnableCompression: true,
	CheckOrigin:       func(r *http.Request) bool { return true },
}

// ── WS HANDLER ────────────────────────────────────────────────────
func wsHandler(c *gin.Context) {
	// Token via ?token=... (WebSocket headers limited in browsers)
	tokenStr := c.Query("token")
	if tokenStr == "" {
		// Also accept Authorization header for non-browser clients
		h := c.GetHeader("Authorization")
		if strings.HasPrefix(h, "Bearer ") {
			tokenStr = h[7:]
		}
	}
	userID, err := parseJWT(tokenStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Printf("[ws] upgrade error: %v", err)
		return
	}

	cl := &Client{
		userID: userID,
		conn:   conn,
		send:   make(chan []byte, 512),
	}
	hub.register(cl)
	defer hub.unregister(cl)

	// Mark online in Redis
	RDB.Set(bg, "online:"+userID, "1", 5*time.Minute)
	defer RDB.Del(bg, "online:"+userID)

	// Send welcome
	cl.send <- mustMarshal(WSMessage{Type: "connected"})

	go cl.writePump()
	cl.readPump()
}

func (cl *Client) readPump() {
	defer cl.conn.Close()
	cl.conn.SetReadLimit(512 * 1024) // 512KB max
	cl.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	cl.conn.SetPongHandler(func(string) error {
		cl.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		// Refresh online status
		RDB.Expire(bg, "online:"+cl.userID, 5*time.Minute)
		return nil
	})

	for {
		_, data, err := cl.conn.ReadMessage()
		if err != nil {
			break
		}
		var msg WSMessage
		if json.Unmarshal(data, &msg) != nil {
			continue
		}
		handleClientMessage(cl, &msg)
	}
}

func (cl *Client) writePump() {
	ticker := time.NewTicker(25 * time.Second)
	defer func() {
		ticker.Stop()
		cl.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-cl.send:
			cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				cl.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := cl.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := cl.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// ── CLIENT MESSAGE ROUTER ─────────────────────────────────────────
func handleClientMessage(cl *Client, msg *WSMessage) {
	switch msg.Type {

	case "ping":
		cl.send <- mustMarshal(WSMessage{Type: "pong"})

	case "chat":
		// Direct message to another user
		var p struct {
			ReceiverID string `json:"receiverID"`
			Text       string `json:"text"`
		}
		json.Unmarshal(msg.Payload, &p)
		if p.ReceiverID == "" || p.Text == "" {
			return
		}
		payload, _ := json.Marshal(map[string]interface{}{
			"senderID": cl.userID,
			"text":     p.Text,
			"time":     time.Now().Format(time.RFC3339),
		})
		out := mustMarshal(WSMessage{Type: "chat", Payload: payload})
		// Try local, fallback to Redis PubSub
		if !hub.deliver(p.ReceiverID, out) {
			publishToRedis(p.ReceiverID, out)
		}

	case "typing":
		var p struct{ ReceiverID string `json:"receiverID"` }
		json.Unmarshal(msg.Payload, &p)
		if p.ReceiverID == "" {
			return
		}
		payload, _ := json.Marshal(map[string]interface{}{"senderID": cl.userID})
		out := mustMarshal(WSMessage{Type: "typing", Payload: payload})
		if !hub.deliver(p.ReceiverID, out) {
			publishToRedis(p.ReceiverID, out)
		}

	case "presence_online":
		RDB.Set(bg, "online:"+cl.userID, "1", 5*time.Minute)
	}
}

// ── REDIS PUB/SUB — cross-instance messaging ─────────────────────
type pubSubEnvelope struct {
	UserID  string          `json:"userID"`
	Message json.RawMessage `json:"message"`
}

func publishToRedis(userID string, msg []byte) {
	env := pubSubEnvelope{UserID: userID, Message: msg}
	b, _ := json.Marshal(env)
	RDB.Publish(bg, "ws:broadcast", b)
}

func startPubSub() {
	ps := RDB.Subscribe(bg, "ws:broadcast")
	go func() {
		ch := ps.Channel()
		for redisMsg := range ch {
			var env pubSubEnvelope
			if json.Unmarshal([]byte(redisMsg.Payload), &env) == nil {
				hub.deliver(env.UserID, env.Message)
			}
		}
	}()
	log.Println("✅ Redis PubSub started on ws:broadcast")
}

// ── INTERNAL API — called by notification-service ─────────────────
func sendHandler(c *gin.Context) {
	var b struct {
		UserID  string          `json:"userID"  binding:"required"`
		Type    string          `json:"type"    binding:"required"`
		Payload json.RawMessage `json:"payload"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	msg := mustMarshal(WSMessage{Type: b.Type, Payload: b.Payload})
	if !hub.deliver(b.UserID, msg) {
		publishToRedis(b.UserID, msg)
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ── ONLINE STATUS ─────────────────────────────────────────────────
func isOnlineHandler(c *gin.Context) {
	userID := c.Param("id")
	n, _ := RDB.Exists(bg, "online:"+userID).Result()
	c.JSON(http.StatusOK, gin.H{"online": n > 0})
}

// ── HELPERS ───────────────────────────────────────────────────────
func mustMarshal(v interface{}) []byte {
	b, _ := json.Marshal(v)
	return b
}

func parseJWT(tokenStr string) (string, error) {
	if tokenStr == "" {
		return "", jwt.ErrTokenMalformed
	}
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		secret = "raonson-secret-change-in-prod"
	}
	tok, err := jwt.Parse(tokenStr,
		func(t *jwt.Token) (interface{}, error) { return []byte(secret), nil },
		jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !tok.Valid {
		return "", err
	}
	claims := tok.Claims.(jwt.MapClaims)
	id, _ := claims["id"].(string)
	return id, nil
}

// ── MAIN ──────────────────────────────────────────────────────────
func main() {
	godotenv.Load()
	initRedis()

	hub = newHub()
	startPubSub()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())

	r.GET("/health", func(c *gin.Context) {
		hub.mu.RLock()
		total := len(hub.clients)
		hub.mu.RUnlock()
		c.JSON(200, gin.H{"service": "realtime-service", "connections": total})
	})

	// WebSocket endpoint — Flutter connects here
	r.GET("/ws", wsHandler)

	// Internal endpoints
	r.POST("/internal/send", sendHandler)
	r.GET("/internal/online/:id", isOnlineHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8005"
	}
	log.Printf("⚡ realtime-service :%s", port)
	r.Run(":" + port)
}

func initRedis() {
	url := os.Getenv("REDIS_URL")
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	opt, _ := redis.ParseURL(url)
	opt.PoolSize = 20
	opt.MinIdleConns = 5
	RDB = redis.NewClient(opt)
	if err := RDB.Ping(bg).Err(); err != nil {
		log.Fatalf("Redis ping: %v", err)
	}
	log.Println("✅ Redis connected")
}
