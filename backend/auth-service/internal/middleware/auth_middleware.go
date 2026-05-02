package middleware

import (
	"net/http"
	"strings"
	"sync"
	"time"

	"auth-service/pkg/jwt"
	rdb "auth-service/pkg/redis"

	"github.com/gin-gonic/gin"
)

// Auth — JWT-ро тасдиқ мекунад ва userID-ро set мекунад
func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "No token"})
			c.Abort()
			return
		}
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token format"})
			c.Abort()
			return
		}
		tokenStr := parts[1]
		// Check blacklist
		if rdb.Exists("blacklist:" + tokenStr) {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Token revoked"})
			c.Abort()
			return
		}
		userID, err := jwt.ParseAccess(tokenStr)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
			c.Abort()
			return
		}
		c.Set("userID", userID)
		c.Next()
	}
}

// RateLimit — per-IP, in-memory (auth endpoints учун)
func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct {
		count int
		reset time.Time
	}
	store := make(map[string]*entry)
	var mu sync.Mutex

	return func(c *gin.Context) {
		ip := c.ClientIP()
		now := time.Now()
		mu.Lock()
		e, ok := store[ip]
		if !ok || now.After(e.reset) {
			store[ip] = &entry{count: 1, reset: now.Add(window)}
			mu.Unlock()
			c.Next()
			return
		}
		e.count++
		count := e.count
		mu.Unlock()
		if count > limit {
			c.Header("Retry-After", "60")
			c.JSON(http.StatusTooManyRequests, gin.H{
				"message": "Too many requests. Please try again later.",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}
