package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// ── IP Block ──────────────────────────────────────────────────────
var (
	blockedIPs = map[string]bool{}
	blockedMu  sync.RWMutex
)

func BlockIP(ip string)   { blockedMu.Lock(); blockedIPs[ip] = true; blockedMu.Unlock() }
func UnblockIP(ip string) { blockedMu.Lock(); delete(blockedIPs, ip); blockedMu.Unlock() }

func IPBlock() gin.HandlerFunc {
	return func(c *gin.Context) {
		ip := clientIP(c)
		blockedMu.RLock()
		blocked := blockedIPs[ip]
		blockedMu.RUnlock()
		if blocked {
			c.JSON(http.StatusForbidden, gin.H{"error": "Your IP has been blocked"})
			c.Abort()
			return
		}
		c.Next()
	}
}

// ── Anti-Spam (20 req/sec per IP+path) ───────────────────────────
var (
	spamMap = map[string]*spamEntry{}
	spamMu  sync.Mutex
)

type spamEntry struct {
	count int
	last  time.Time
}

func AntiSpam() gin.HandlerFunc {
	return func(c *gin.Context) {
		key := clientIP(c) + ":" + c.FullPath()
		now := time.Now()
		spamMu.Lock()
		e, ok := spamMap[key]
		if !ok {
			e = &spamEntry{}
			spamMap[key] = e
		}
		if now.Sub(e.last) < time.Second {
			e.count++
		} else {
			e.count = 1
		}
		e.last = now
		count := e.count
		spamMu.Unlock()
		if count > 30 { // 20 → 30 (мобайл тезтар запрос мефиристад)
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "Spam detected. Please slow down."})
			c.Abort()
			return
		}
		c.Next()
	}
}

// ── Anti-Abuse (per user action) ─────────────────────────────────
var (
	abuseMap = map[string]*abuseEntry{}
	abuseMu  sync.Mutex
)

type abuseEntry struct {
	count int
	start time.Time
}

func AntiAbuse(action string, limit int, windowSec int) gin.HandlerFunc {
	window := time.Duration(windowSec) * time.Second
	return func(c *gin.Context) {
		uid := UID(c)
		if uid == "" {
			uid = clientIP(c)
		}
		key := uid + ":" + action
		now := time.Now()
		abuseMu.Lock()
		e, ok := abuseMap[key]
		if !ok {
			e = &abuseEntry{start: now}
			abuseMap[key] = e
		}
		if now.Sub(e.start) > window {
			e.count = 0
			e.start = now
		}
		e.count++
		count := e.count
		abuseMu.Unlock()
		if count > limit {
			c.JSON(http.StatusForbidden, gin.H{"error": "Abusive behavior detected"})
			c.Abort()
			return
		}
		c.Next()
	}
}

// ── Rate Limit — USER-BASED (не IP-based) ────────────────────────
// Пеш аз ин IP-асос буд → ҳама кербарон як limit доштанд!
// Акнун ҳар кербар мустақил limit дорад.
var (
	rlMap = map[string][]time.Time{}
	rlMu  sync.Mutex
)

func RateLimit(limit int, windowSec int) gin.HandlerFunc {
	window := time.Duration(windowSec) * time.Second
	return func(c *gin.Context) {
		// Калид: userID (агар login карда) ё IP
		key := UID(c)
		if key == "" {
			key = "ip:" + clientIP(c)
		}

		now := time.Now()
		rlMu.Lock()
		times := rlMap[key]
		valid := times[:0]
		for _, t := range times {
			if now.Sub(t) < window {
				valid = append(valid, t)
			}
		}
		valid = append(valid, now)
		rlMap[key] = valid
		count := len(valid)
		rlMu.Unlock()

		if count > limit {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"success": false,
				"message": "Too many requests. Please try again later.",
			})
			c.Abort()
			return
		}
		c.Next()
	}
}

// init launches a background janitor that prunes stale entries from the
// in-memory anti-spam / anti-abuse / rate-limit maps so they can't grow
// unbounded (every unique IP+path / userID would otherwise leak forever).
func init() {
	go func() {
		ticker := time.NewTicker(5 * time.Minute)
		defer ticker.Stop()
		for range ticker.C {
			now := time.Now()

			spamMu.Lock()
			for k, e := range spamMap {
				if now.Sub(e.last) > 2*time.Minute {
					delete(spamMap, k)
				}
			}
			spamMu.Unlock()

			abuseMu.Lock()
			for k, e := range abuseMap {
				if now.Sub(e.start) > 24*time.Hour {
					delete(abuseMap, k)
				}
			}
			abuseMu.Unlock()

			rlMu.Lock()
			for k, times := range rlMap {
				if len(times) == 0 ||
					now.Sub(times[len(times)-1]) > 10*time.Minute {
					delete(rlMap, k)
				}
			}
			rlMu.Unlock()
		}
	}()
}

func clientIP(c *gin.Context) string {
	if fwd := c.GetHeader("X-Forwarded-For"); fwd != "" {
		return fwd
	}
	return c.ClientIP()
}
