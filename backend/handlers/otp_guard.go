package handlers

import (
	"crypto/rand"
	"crypto/subtle"
	"fmt"
	"math/big"
	"strings"
	"sync"
	"time"

	mw "raonson/middleware"
)

// ══════════════════════════════════════════════════════════════════
//  Ҳифзи рамзҳои якдафъаина (OTP).
//
//  Пеш:
//    • рамз аз math/rand сохта мешуд (пешгӯишаванда);
//    • шумораи кӯшишҳои нодуруст маҳдуд набуд — рамзи 6-рақама
//      (1 000 000 вариант) дар 10 дақиқа бо дархостҳои зиёд ёфта
//      мешуд ва ҳисоби ҳар кас ба даст меафтод;
//    • фиристодан ба як рақам маҳдуд набуд — SMS-и пулакиро ба
//      ҳар рақам беохир фиристодан мумкин буд.
//
//  Ҳадҳо ба IP вобаста нестанд (онро сохтакорӣ кардан мумкин аст) —
//  ба ҳисоб, телефон ва почта.
// ══════════════════════════════════════════════════════════════════

const otpMaxAttempts = 5

type otpCounter struct {
	n     int
	until time.Time
}

var (
	otpMu       sync.Mutex
	otpCounters = map[string]*otpCounter{}
)

// secureOTP — рамзи 6-рақама аз crypto/rand.
func secureOTP() string {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return fmt.Sprintf("%06d", time.Now().UnixNano()%1000000)
	}
	return fmt.Sprintf("%06d", n.Int64())
}

// bump — ҳисобкунаки key-ро зиёд мекунад ва қимати навро медиҳад.
func bump(key string, ttl time.Duration) int {
	otpMu.Lock()
	defer otpMu.Unlock()
	now := time.Now()
	if len(otpCounters) > 200000 {
		for k, v := range otpCounters {
			if now.After(v.until) {
				delete(otpCounters, k)
			}
		}
	}
	c := otpCounters[key]
	if c == nil || now.After(c.until) {
		c = &otpCounter{until: now.Add(ttl)}
		otpCounters[key] = c
	}
	c.n++
	return c.n
}

func resetCounter(key string) {
	otpMu.Lock()
	delete(otpCounters, key)
	otpMu.Unlock()
}

// otpSendAllowed — то `max` фиристодан дар `per` барои як ҳадаф.
func otpSendAllowed(target string, max int, per time.Duration) bool {
	return bump("send:"+target, per) <= max
}

// checkOTP — рамзи дар кэш бударо бо рамзи додашуда муқоиса мекунад.
// Баъди 5 кӯшиши нодуруст рамз нест мешавад (бояд нав дархост кард).
// Бармегардонад: (дуруст, қуфл шуд).
func checkOTP(cacheKey, given string) (bool, bool) {
	st, _ := checkOTPDetailed(cacheKey, given)
	return st == otpOK, st == otpLocked
}

type otpStatus int

const (
	otpOK otpStatus = iota
	otpWrong
	otpLocked
	otpMissing // рамз нест: мӯҳлат гузашт, истифода шуд ё қуфл шуда буд
)

// checkOTPDetailed — мисли checkOTP, вале «нодуруст» ва «гузашт»-ро фарқ
// мекунад ва шумораи кӯшишҳои боқимондаро медиҳад.
func checkOTPDetailed(cacheKey, given string) (otpStatus, int) {
	stored, ok := mw.CacheGet(cacheKey)
	if !ok {
		return otpMissing, 0
	}
	given = strings.TrimSpace(given)
	if len(given) == len(stored) &&
		subtle.ConstantTimeCompare(stored, []byte(given)) == 1 {
		mw.CacheDel(cacheKey)
		resetCounter("try:" + cacheKey)
		return otpOK, otpMaxAttempts
	}
	n := bump("try:"+cacheKey, 15*time.Minute)
	if n >= otpMaxAttempts {
		mw.CacheDel(cacheKey)
		resetCounter("try:" + cacheKey)
		return otpLocked, 0
	}
	return otpWrong, otpMaxAttempts - n
}

// storeOTP — рамзи навро мегузорад ва ҳисоби кӯшишҳоро аз нав мекунад.
func storeOTP(cacheKey, otp string, ttl time.Duration) {
	mw.CacheSet(cacheKey, []byte(otp), ttl)
	resetCounter("try:" + cacheKey)
}
