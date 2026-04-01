package middleware

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

// ── Simple Redis client via Upstash REST API ──────────────────────
// Upstash provides a REST API — no TCP needed, works serverless.
// Free tier: 10,000 requests/day, 256MB

var (
	redisURL   string
	redisToken string
	redisOK    bool
)

func InitRedis() {
	redisURL   = os.Getenv("UPSTASH_REDIS_REST_URL")
	redisToken = os.Getenv("UPSTASH_REDIS_REST_TOKEN")
	redisOK    = redisURL != "" && redisToken != ""
	if redisOK {
		log.Println("✅ Redis (Upstash) connected")
	} else {
		log.Println("⚠️  Redis not configured — caching disabled")
	}
}

// CacheGet — get cached value
func CacheGet(key string) ([]byte, bool) {
	if !redisOK {
		return nil, false
	}
	req, _ := http.NewRequestWithContext(context.Background(),
		"GET", redisURL+"/get/"+key, nil)
	req.Header.Set("Authorization", "Bearer "+redisToken)
	resp, err := http.DefaultClient.Do(req)
	if err != nil || resp.StatusCode != 200 {
		return nil, false
	}
	defer resp.Body.Close()
	var result struct {
		Result *string `json:"result"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, false
	}
	if result.Result == nil {
		return nil, false
	}
	return []byte(*result.Result), true
}

// CacheSet — store value with TTL
func CacheSet(key string, value []byte, ttl time.Duration) {
	if !redisOK {
		return
	}
	seconds := int(ttl.Seconds())
	url := redisURL + "/setex/" + key + "/" + itoa(seconds) + "/" + string(value)
	req, _ := http.NewRequestWithContext(context.Background(), "GET", url, nil)
	req.Header.Set("Authorization", "Bearer "+redisToken)
	go http.DefaultClient.Do(req)
}

// CacheDel — delete key(s)
func CacheDel(keys ...string) {
	if !redisOK {
		return
	}
	for _, k := range keys {
		req, _ := http.NewRequestWithContext(context.Background(),
			"GET", redisURL+"/del/"+k, nil)
		req.Header.Set("Authorization", "Bearer "+redisToken)
		go http.DefaultClient.Do(req)
	}
}

// CacheMiddleware — caches GET responses
// Usage: r.GET("/explore", CacheMiddleware(5*time.Minute), handler)
func CacheMiddleware(ttl time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if !redisOK || c.Request.Method != "GET" {
			c.Next()
			return
		}

		key := "cache:" + c.Request.URL.String()

		if cached, ok := CacheGet(key); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			c.Abort()
			return
		}

		// Capture response
		w := &responseWriter{ResponseWriter: c.Writer, body: []byte{}}
		c.Writer = w
		c.Next()

		if w.status == http.StatusOK && len(w.body) > 0 {
			CacheSet(key, w.body, ttl)
		}
	}
}

type responseWriter struct {
	gin.ResponseWriter
	body   []byte
	status int
}

func (w *responseWriter) Write(b []byte) (int, error) {
	w.body = append(w.body, b...)
	return w.ResponseWriter.Write(b)
}

func (w *responseWriter) WriteHeader(code int) {
	w.status = code
	w.ResponseWriter.WriteHeader(code)
}

func itoa(n int) string {
	return string(rune('0'+n/10)) + string(rune('0'+n%10))
}

func CacheDelete(key string) {
	CacheDel(key)
}
