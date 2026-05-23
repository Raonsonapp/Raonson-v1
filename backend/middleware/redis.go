package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gin-gonic/gin"
)

var (
	redisURL   string
	redisToken string
	redisOK    bool
	httpClient *http.Client
)

func InitRedis() {
	redisURL   = os.Getenv("UPSTASH_REDIS_REST_URL")
	redisToken = os.Getenv("UPSTASH_REDIS_REST_TOKEN")
	redisOK    = redisURL != "" && redisToken != ""

	// ── Оптимизатсияи HTTP client барои Redis ──────────────────
	// Keep-alive connections — ҳар бор TCP-handshake нест
	httpClient = &http.Client{
		Timeout: 2 * time.Second, // Redis-ро зиёд вакт нест
		Transport: &http.Transport{
			MaxIdleConns:        50,
			MaxIdleConnsPerHost: 20,
			IdleConnTimeout:     90 * time.Second,
			DisableCompression:  true, // JSON-и хурд — compress лозим нест
		},
	}

	if redisOK {
		log.Println("✅ Redis (Upstash) connected — keep-alive enabled")
	} else {
		log.Println("⚠️  Redis not configured — in-memory cache active")
	}
}

// CacheGet — get cached value (< 2s timeout)
func CacheGet(key string) ([]byte, bool) {
	if !redisOK {
		return nil, false
	}
	ctx, cancel := context.WithTimeout(context.Background(), 800*time.Millisecond)
	defer cancel()

	req, _ := http.NewRequestWithContext(ctx, "GET", redisURL+"/get/"+key, nil)
	req.Header.Set("Authorization", "Bearer "+redisToken)

	resp, err := httpClient.Do(req)
	if err != nil || resp.StatusCode != 200 {
		return nil, false
	}
	defer resp.Body.Close()

	var result struct {
		Result *string `json:"result"`
	}
	body, _ := io.ReadAll(resp.Body)
	if err := json.Unmarshal(body, &result); err != nil || result.Result == nil {
		return nil, false
	}
	return []byte(*result.Result), true
}

// CacheSet — store value with TTL (async — блок намекунад)
func CacheSet(key string, value []byte, ttl time.Duration) {
	if !redisOK {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()

		seconds := int(ttl.Seconds())
		payload := fmt.Sprintf(`["%s", %d, "%s"]`,
			key, seconds, escapeJSON(string(value)))

		req, _ := http.NewRequestWithContext(ctx, "POST",
			redisURL+"/pipeline", bytes.NewBufferString(
				fmt.Sprintf(`[["SETEX", "%s", %d, %s]]`,
					key, seconds, jsonStr(string(value)))))
		req.Header.Set("Authorization", "Bearer "+redisToken)
		req.Header.Set("Content-Type", "application/json")
		_ = payload
		httpClient.Do(req)
	}()
}

// CacheDel — delete key(s) async
func CacheDel(keys ...string) {
	if !redisOK {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 1*time.Second)
		defer cancel()
		for _, k := range keys {
			req, _ := http.NewRequestWithContext(ctx, "GET",
				redisURL+"/del/"+k, nil)
			req.Header.Set("Authorization", "Bearer "+redisToken)
			httpClient.Do(req)
		}
	}()
}

// CacheDelete — alias for CacheDel
func CacheDelete(key string) { CacheDel(key) }

// CacheMiddleware — caches GET responses
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
		w := &responseWriter{ResponseWriter: c.Writer}
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

func escapeJSON(s string) string { return s }
func jsonStr(s string) string    { b, _ := json.Marshal(s); return string(b) }
