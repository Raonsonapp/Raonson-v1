package middleware

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	rdb "auth-service/pkg/redis"

	gojwt "github.com/golang-jwt/jwt/v5"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

func RequestLogger(log *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		reqID := c.GetHeader("X-Request-ID")
		if reqID == "" { reqID = newReqID() }
		c.Set("requestID", reqID)
		c.Header("X-Request-ID", reqID)
		c.Next()
		log.Info("http",
			zap.String("id", reqID),
			zap.String("method", c.Request.Method),
			zap.String("path", c.Request.URL.Path),
			zap.Int("status", c.Writer.Status()),
			zap.Duration("ms", time.Since(start)),
			zap.String("ip", c.ClientIP()),
		)
	}
}

func Recovery(log *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				log.Error("panic", zap.Any("err", err))
				c.AbortWithStatusJSON(http.StatusInternalServerError,
					gin.H{"success": false, "error": gin.H{"message": "internal error"}})
			}
		}()
		c.Next()
	}
}

func Auth() gin.HandlerFunc {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" { secret = "change_me" }
	return func(c *gin.Context) {
		if uid := c.GetHeader("X-User-ID"); uid != "" {
			c.Set("userID", uid); c.Next(); return
		}
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": gin.H{"message": "no token"}}); return
		}
		token := header[7:]
		if rdb.Exists("blacklist:" + token) {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": gin.H{"message": "token revoked"}}); return
		}
		tok, err := gojwt.Parse(token,
			func(t *gojwt.Token) (interface{}, error) { return []byte(secret), nil },
			gojwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !tok.Valid {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"success": false, "error": gin.H{"message": "invalid token"}}); return
		}
		claims := tok.Claims.(gojwt.MapClaims)
		c.Set("userID", claims["id"].(string))
		c.Next()
	}
}

func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct{ count int; reset time.Time }
	store := map[string]*entry{}
	var mu sync.Mutex
	go func() {
		t := time.NewTicker(time.Minute)
		for range t.C {
			now := time.Now(); mu.Lock()
			for k, e := range store { if now.After(e.reset) { delete(store, k) } }
			mu.Unlock()
		}
	}()
	return func(c *gin.Context) {
		ip := c.ClientIP(); now := time.Now()
		mu.Lock()
		e, ok := store[ip]
		if !ok || now.After(e.reset) { store[ip] = &entry{1, now.Add(window)}; mu.Unlock(); c.Next(); return }
		e.count++; n := e.count; mu.Unlock()
		if n > limit {
			c.Header("Retry-After", "60")
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"success": false, "error": gin.H{"message": "too many requests"}})
			return
		}
		c.Next()
	}
}

func newReqID() string { b := make([]byte, 8); rand.Read(b); return hex.EncodeToString(b) }
