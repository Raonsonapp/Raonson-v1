package middleware

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"os"
	"strconv"
	"strings"
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

// AntiSpam аз селоби дархост муҳофизат мекунад.
//
// Калид: корбар, агар ӯ ворид шуда бошад; вагарна IP.
//
// Чаро на ҳамеша IP: дар шабакаҳои мобилӣ ҳазорон корбар паси ЯК
// суроғаи IP мешинанд (CGNAT). Бо калиди IP онҳо якдигарро маҳдуд
// мекарданд ва барнома «худсарона суст» менамуд. Корбари воридшуда
// аллакай маҳдудияти шахсии худро дорад (RateLimit).
func AntiSpam() gin.HandlerFunc {
	spamSweepOnce.Do(startSpamSweeper)
	return func(c *gin.Context) {
		key := spamKey(c) + ":" + c.FullPath()
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
		if count > spamLimit() {
			c.JSON(http.StatusTooManyRequests, gin.H{"error": "Spam detected. Please slow down."})
			c.Abort()
			return
		}
		c.Next()
	}
}

// spamKey як «фиристанда»-ро муайян мекунад.
//
// AntiSpam ПЕШ аз миёнафзори авторизатсия иҷро мешавад, бинобар ин
// UID(c) ҳанӯз холист. Аз ин рӯ худи токен ҳамчун нишона гирифта
// мешавад: ду корбар токенҳои гуногун доранд, вале дархостҳои ҳамон
// корбар як калид мегиранд.
//
// Токен ба хотира ё log намеравад — танҳо хулосаи кӯтоҳи он.
// spamLimit — ҳадди дархост дар як сония.
//
// Пешфарз 30: мобилӣ дархостҳоро дастаҷамъӣ мефиристад. Муҳити
// санҷиш метавонад онро баланд кунад; production бе тағйир мемонад.
func spamLimit() int {
	n := 30
	if v := os.Getenv("RATE_LIMIT_MULTIPLIER"); v != "" {
		if m, err := strconv.Atoi(v); err == nil && m > 1 {
			n *= m
		}
	}
	return n
}

func spamKey(c *gin.Context) string {
	if h := c.GetHeader("Authorization"); len(h) > 24 {
		sum := sha256.Sum256([]byte(h))
		return "t:" + hex.EncodeToString(sum[:8])
	}
	return "ip:" + clientIP(c)
}

var spamSweepOnce sync.Once

// startSpamSweeper вурудиҳои кӯҳнаро мебарорад.
//
// spamMap низ бе ин абадӣ калон мешуд: ҳар ҷуфти «корбар/IP + роҳ»
// дар хотира мемонд.
func startSpamSweeper() {
	go func() {
		t := time.NewTicker(5 * time.Minute)
		defer t.Stop()
		for range t.C {
			cutoff := time.Now().Add(-5 * time.Minute)
			spamMu.Lock()
			for k, e := range spamMap {
				if e.last.Before(cutoff) {
					delete(spamMap, k)
				}
			}
			spamMu.Unlock()
		}
	}()
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

// rlSweepOnce корҳои поксозиро як бор оғоз мекунад.
var rlSweepOnce sync.Once

// startRLSweeper вурудиҳои кӯҳнаро мебарорад.
//
// Бе ин rlMap АБАДӢ калон мешуд: ҳар корбар ва ҳар IP, ки ягон бор
// омад, дар хотира мемонд ва ҳеҷ гоҳ пок намешуд. Дар 50 000 корбар
// ин оҳиста-оҳиста хотираро мехӯрад.
func startRLSweeper() {
	go func() {
		t := time.NewTicker(5 * time.Minute)
		defer t.Stop()
		for range t.C {
			cutoff := time.Now().Add(-10 * time.Minute)
			rlMu.Lock()
			for k, times := range rlMap {
				if len(times) == 0 || times[len(times)-1].Before(cutoff) {
					delete(rlMap, k)
				}
			}
			rlMu.Unlock()
		}
	}()
}

// RateLimit маҳдудияти суръатро месозад.
//
// Ҳадҳо аз env танзим мешаванд, вале пешфарз ҳамон аст: муҳити
// санҷиш метавонад онҳоро баланд кунад, production бе тағйир монад.
func RateLimit(limit int, windowSec int) gin.HandlerFunc {
	rlSweepOnce.Do(startRLSweeper)
	if v := os.Getenv("RATE_LIMIT_MULTIPLIER"); v != "" {
		if m, err := strconv.Atoi(v); err == nil && m > 1 {
			limit *= m
		}
	}
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
		if i := strings.Index(fwd, ","); i != -1 {
			return strings.TrimSpace(fwd[:i])
		}
		return strings.TrimSpace(fwd)
	}
	return c.ClientIP()
}
