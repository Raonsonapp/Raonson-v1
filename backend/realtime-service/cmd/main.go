package main

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"

	"realtime-service/pkg/config"
	"realtime-service/pkg/logger"
	rdb "realtime-service/pkg/redis"

	"github.com/gin-gonic/gin"
	gojwt "github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
	"github.com/joho/godotenv"
	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

// ── TYPES ─────────────────────────────────────────────────────────
type WSMessage struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

type Client struct {
	userID string
	conn   *websocket.Conn
	send   chan []byte
}

// ── HUB ───────────────────────────────────────────────────────────
type Hub struct {
	mu      sync.RWMutex
	clients map[string]*Client
}

func newHub() *Hub { return &Hub{clients: make(map[string]*Client)} }

func (h *Hub) register(cl *Client) {
	h.mu.Lock()
	if old, ok := h.clients[cl.userID]; ok { close(old.send) }
	h.clients[cl.userID] = cl
	total := len(h.clients)
	h.mu.Unlock()
	logger.Info("ws connected", zap.String("userID", cl.userID), zap.Int("total", total))
}

func (h *Hub) unregister(cl *Client) {
	h.mu.Lock()
	if h.clients[cl.userID] == cl {
		delete(h.clients, cl.userID)
		close(cl.send)
	}
	total := len(h.clients)
	h.mu.Unlock()
	logger.Info("ws disconnected", zap.String("userID", cl.userID), zap.Int("total", total))
}

func (h *Hub) deliver(userID string, msg []byte) bool {
	h.mu.RLock()
	cl, ok := h.clients[userID]
	h.mu.RUnlock()
	if !ok { return false }
	select {
	case cl.send <- msg:
		return true
	default:
		logger.Warn("send buffer full", zap.String("userID", userID))
		return false
	}
}

// ── GLOBALS ───────────────────────────────────────────────────────
var (
	hub      *Hub
	upgrader = websocket.Upgrader{
		ReadBufferSize:    4096,
		WriteBufferSize:   4096,
		EnableCompression: true,
		CheckOrigin:       func(r *http.Request) bool { return true },
	}
)

// ── WS HANDLER ────────────────────────────────────────────────────
func wsHandler(c *gin.Context) {
	tokenStr := c.Query("token")
	if tokenStr == "" {
		if h := c.GetHeader("Authorization"); strings.HasPrefix(h, "Bearer ") {
			tokenStr = h[7:]
		}
	}
	userID, err := parseJWT(tokenStr, os.Getenv("JWT_SECRET"))
	if err != nil {
		c.JSON(401, gin.H{"error": "invalid token"}); return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		logger.Error("ws upgrade", zap.Error(err)); return
	}

	cl := &Client{userID: userID, conn: conn, send: make(chan []byte, 512)}
	hub.register(cl)
	defer hub.unregister(cl)

	// Mark online
	rdb.C.Set(context.Background(), "online:"+userID, "1", 5*time.Minute)
	defer rdb.C.Del(context.Background(), "online:"+userID)

	// Send welcome
	cl.send <- mustMarshal(WSMessage{Type: "connected"})

	go cl.writePump()
	cl.readPump()
}

func (cl *Client) readPump() {
	defer cl.conn.Close()
	cl.conn.SetReadLimit(512 * 1024)
	cl.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	cl.conn.SetPongHandler(func(string) error {
		cl.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		rdb.C.Expire(context.Background(), "online:"+cl.userID, 5*time.Minute)
		return nil
	})
	for {
		_, data, err := cl.conn.ReadMessage()
		if err != nil { break }
		var msg WSMessage
		if json.Unmarshal(data, &msg) != nil { continue }
		handleMsg(cl, &msg)
	}
}

func (cl *Client) writePump() {
	ticker := time.NewTicker(25 * time.Second)
	defer func() { ticker.Stop(); cl.conn.Close() }()
	for {
		select {
		case msg, ok := <-cl.send:
			cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok { cl.conn.WriteMessage(websocket.CloseMessage, []byte{}); return }
			if err := cl.conn.WriteMessage(websocket.TextMessage, msg); err != nil { return }
		case <-ticker.C:
			cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := cl.conn.WriteMessage(websocket.PingMessage, nil); err != nil { return }
		}
	}
}

// ── MESSAGE ROUTER ────────────────────────────────────────────────
func handleMsg(cl *Client, msg *WSMessage) {
	switch msg.Type {
	case "ping":
		cl.send <- mustMarshal(WSMessage{Type: "pong"})

	case "chat":
		var p struct {
			ReceiverID string `json:"receiverID"`
			Text       string `json:"text"`
		}
		json.Unmarshal(msg.Payload, &p)
		if p.ReceiverID == "" || p.Text == "" { return }
		payload, _ := json.Marshal(map[string]interface{}{
			"senderID": cl.userID, "text": p.Text,
			"time": time.Now().Format(time.RFC3339),
		})
		out := mustMarshal(WSMessage{Type: "chat", Payload: payload})
		if !hub.deliver(p.ReceiverID, out) {
			publishRedis(p.ReceiverID, out)
		}

	case "typing":
		var p struct{ ReceiverID string `json:"receiverID"` }
		json.Unmarshal(msg.Payload, &p)
		if p.ReceiverID == "" { return }
		payload, _ := json.Marshal(map[string]interface{}{"senderID": cl.userID})
		out := mustMarshal(WSMessage{Type: "typing", Payload: payload})
		if !hub.deliver(p.ReceiverID, out) {
			publishRedis(p.ReceiverID, out)
		}

	case "presence_online":
		rdb.C.Set(context.Background(), "online:"+cl.userID, "1", 5*time.Minute)
	}
}

// ── REDIS PUB/SUB — cross-instance messaging ─────────────────────
type pubEnvelope struct {
	UserID  string          `json:"userID"`
	Message json.RawMessage `json:"message"`
}

func publishRedis(userID string, msg []byte) {
	env := pubEnvelope{UserID: userID, Message: msg}
	b, _ := json.Marshal(env)
	rdb.C.Publish(context.Background(), "ws:broadcast", b)
}

func startPubSub() {
	ps := rdb.C.Subscribe(context.Background(), "ws:broadcast")
	go func() {
		for m := range ps.Channel() {
			var env pubEnvelope
			if json.Unmarshal([]byte(m.Payload), &env) == nil {
				hub.deliver(env.UserID, env.Message)
			}
		}
	}()
	logger.Info("✅ Redis PubSub listening on ws:broadcast")
}

// ── INTERNAL API — called by notification-service ─────────────────
func sendHandler(c *gin.Context) {
	var b struct {
		UserID  string          `json:"userID"  binding:"required"`
		Type    string          `json:"type"    binding:"required"`
		Payload json.RawMessage `json:"payload"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(400, gin.H{"error": err.Error()}); return
	}
	msg := mustMarshal(WSMessage{Type: b.Type, Payload: b.Payload})
	if !hub.deliver(b.UserID, msg) {
		publishRedis(b.UserID, msg)
	}
	c.JSON(200, gin.H{"ok": true})
}

func onlineHandler(c *gin.Context) {
	userID := c.Param("id")
	n, _ := rdb.C.Exists(context.Background(), "online:"+userID).Result()
	c.JSON(200, gin.H{"online": n > 0})
}

// ── MAIN ──────────────────────────────────────────────────────────
func main() {
	godotenv.Load()
	logger.Init("realtime-service")
	defer logger.Sync()

	cfg, err := config.Load()
	if err != nil {
		logger.Fatal("config", zap.Error(err))
	}

	if err := rdb.Init(); err != nil {
		logger.Fatal("redis", zap.Error(err))
	}
	defer rdb.Close()

	hub = newHub()
	startPubSub()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(func(c *gin.Context) {
		start := time.Now(); c.Next()
		logger.Info("http",
			zap.String("method", c.Request.Method),
			zap.String("path", c.Request.URL.Path),
			zap.Int("status", c.Writer.Status()),
			zap.Duration("ms", time.Since(start)),
		)
	}, func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				logger.Error("panic", zap.Any("err", err))
				c.AbortWithStatusJSON(500, gin.H{"error": "internal error"})
			}
		}()
		c.Next()
	})

	r.GET("/health", func(c *gin.Context) {
		hub.mu.RLock(); total := len(hub.clients); hub.mu.RUnlock()
		c.JSON(200, gin.H{"service": "realtime-service", "connections": total, "status": "ok"})
	})

	r.GET("/ws", wsHandler)
	r.POST("/internal/send", sendHandler)
	r.GET("/internal/online/:id", onlineHandler)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	go func() {
		logger.Info("realtime-service started", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("realtime-service shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	logger.Info("realtime-service stopped")
}

// ── helpers ───────────────────────────────────────────────────────
func mustMarshal(v interface{}) []byte { b, _ := json.Marshal(v); return b }

func parseJWT(token, secret string) (string, error) {
	if token == "" { return "", gojwt.ErrTokenMalformed }
	if secret == "" { secret = "change_me" }
	tok, err := gojwt.Parse(token,
		func(t *gojwt.Token) (interface{}, error) { return []byte(secret), nil },
		gojwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !tok.Valid { return "", err }
	claims := tok.Claims.(gojwt.MapClaims)
	uid, _ := claims["id"].(string)
	return uid, nil
}

var _ *goredis.Client // keep import
