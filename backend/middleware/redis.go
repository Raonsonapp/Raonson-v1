package middleware

// ── Cache Strategy: Local (RAM) first, Redis optional ───────────────
// HuggingFace 16GB RAM → in-process cache is fastest & free
// Redis (Upstash) используем только если UPSTASH_REDIS_REST_URL задан

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

	httpClient = &http.Client{
		Timeout: 1500 * time.Millisecond,
		Transport: &http.Transport{
			MaxIdleConns:        30,
			MaxIdleConnsPerHost: 15,
			IdleConnTimeout:     90 * time.Second,
			DisableCompression:  true,
		},
	}

	if redisOK {
		log.Println("✅ Cache: In-Process (primary) + Redis (secondary)")
	} else {
		log.Printf("✅ Cache: In-Process only (16GB RAM) — %d entries warm", LocalSize())
	}
}

// CacheGet — LOCAL first (0ms), then Redis (20-50ms)
func CacheGet(key string) ([]byte, bool) {
	// 1. Local cache (fastest)
	if v, ok := LocalGet(key); ok {
		return v, true
	}
	// 2. Redis (if configured)
	if !redisOK {
		return nil, false
	}
	return redisGet(key)
}

// CacheSet — LOCAL always, Redis async
func CacheSet(key string, value []byte, ttl time.Duration) {
	LocalSet(key, value, ttl)
	if redisOK {
		go redisSet(key, value, ttl)
	}
}

// CacheDel — both caches
func CacheDel(keys ...string) {
	LocalDel(keys...)
	if redisOK {
		go func() {
			for _, k := range keys {
				redisDel(k)
			}
		}()
	}
}

func CacheDelete(key string) { CacheDel(key) }

// InvalidateUserCache — ҳамаи middleware-cache-и як userро пок мекунад.
// Пас аз ҳар write (like, follow, comment, delete post) ин ҷеғ зада мешавад,
// то навбати ҳамон корбар ба GET-ҳо javob-и НАВРО бигирад, на cached-и қаблӣ.
func InvalidateUserCache(userID string) {
	if userID == "" {
		return
	}
	LocalDelPrefix("cache:" + userID + ":")
	// Redis — prefix scan гарон аст, дар инҷо skip мекунем; TTL-и кӯтоҳ
	// (5s) кофӣ аст, ки Redis-и stale худ ба худ таъмир шавад.
}

// CacheMiddleware — cache GET responses.
// КРИТИКӢ: калиди cache бояд userID-ро дар бар гирад, вагарна User A
// javob-и personalized-и User B-ро мебинад (data leak + like/follow-и
// нодуруст). Пеш аз ислоҳ калид танҳо URL буд ва cross-user data leak
// сабаби "лайкҳо гум мешаванд", "стори реалтайм нест", "обуна суст" буд.
func CacheMiddleware(ttl time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		if c.Request.Method != "GET" {
			c.Next()
			return
		}
		uid, _ := c.Get("userID")
		userKey, _ := uid.(string)
		if userKey == "" {
			userKey = "anon"
		}
		key := "cache:" + userKey + ":" + c.Request.URL.String()
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

// ── Redis helpers ─────────────────────────────────────────────────────
func redisGet(key string) ([]byte, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), 600*time.Millisecond)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, "GET", redisURL+"/get/"+key, nil)
	req.Header.Set("Authorization", "Bearer "+redisToken)
	resp, err := httpClient.Do(req)
	if err != nil || resp.StatusCode != 200 {
		return nil, false
	}
	defer resp.Body.Close()
	var result struct{ Result *string `json:"result"` }
	body, _ := io.ReadAll(resp.Body)
	if json.Unmarshal(body, &result) != nil || result.Result == nil {
		return nil, false
	}
	v := []byte(*result.Result)
	LocalSet(key, v, 30*time.Second) // warm local
	return v, true
}

func redisSet(key string, value []byte, ttl time.Duration) {
	ctx, cancel := context.WithTimeout(context.Background(), 800*time.Millisecond)
	defer cancel()
	seconds := int(ttl.Seconds())
	body := fmt.Sprintf(`[["SETEX","%s",%d,%s]]`, key, seconds, jsonStr(string(value)))
	req, _ := http.NewRequestWithContext(ctx, "POST",
		redisURL+"/pipeline", bytes.NewBufferString(body))
	req.Header.Set("Authorization", "Bearer "+redisToken)
	req.Header.Set("Content-Type", "application/json")
	httpClient.Do(req)
}

func redisDel(key string) {
	ctx, cancel := context.WithTimeout(context.Background(), 500*time.Millisecond)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, "GET", redisURL+"/del/"+key, nil)
	req.Header.Set("Authorization", "Bearer "+redisToken)
	httpClient.Do(req)
}

func jsonStr(s string) string { b, _ := json.Marshal(s); return string(b) }

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

// RedisConfigured мегӯяд, ки оё кэши дуюмдараҷа танзим шудааст.
//
// Барои ташхис: бе Redis барнома кор мекунад, вале ҳар нусхаи сервер
// кэши худро дорад.
func RedisConfigured() bool { return redisOK }
