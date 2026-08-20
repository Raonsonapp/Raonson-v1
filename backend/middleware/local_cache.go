package middleware

// ── In-Process Cache — HuggingFace RAM-ро истифода мебарем ──────────
// 16GB RAM дорад — Redis лозим нест, in-memory кифоя аст ва ЗУДТАР!
// RTT Redis: ~20-50ms | RTT in-process: ~0ms

import (
	"sync"
	"time"
)

type cacheEntry struct {
	value     []byte
	expiresAt time.Time
}

var (
	localCache  = make(map[string]cacheEntry)
	cacheMu     sync.RWMutex
	cleanupOnce sync.Once
)

func init() {
	cleanupOnce.Do(func() {
		go func() {
			ticker := time.NewTicker(5 * time.Minute)
			for range ticker.C {
				cleanExpired()
			}
		}()
	})
}

func cleanExpired() {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	now := time.Now()
	for k, v := range localCache {
		if now.After(v.expiresAt) {
			delete(localCache, k)
		}
	}
}

// LocalGet — in-process cache get (0ms latency)
func LocalGet(key string) ([]byte, bool) {
	cacheMu.RLock()
	entry, ok := localCache[key]
	cacheMu.RUnlock()
	if !ok || time.Now().After(entry.expiresAt) {
		return nil, false
	}
	return entry.value, true
}

// LocalSet — in-process cache set
func LocalSet(key string, value []byte, ttl time.Duration) {
	cacheMu.Lock()
	localCache[key] = cacheEntry{
		value:     value,
		expiresAt: time.Now().Add(ttl),
	}
	cacheMu.Unlock()
}

// LocalDel — delete key(s)
func LocalDel(keys ...string) {
	cacheMu.Lock()
	for _, k := range keys {
		delete(localCache, k)
	}
	cacheMu.Unlock()
}

// LocalDelPrefix — delete all keys with given prefix (barои
// invalidate кардани ҳамаи middleware-cache-и як user пас аз write).
func LocalDelPrefix(prefix string) int {
	cacheMu.Lock()
	defer cacheMu.Unlock()
	n := 0
	for k := range localCache {
		if len(k) >= len(prefix) && k[:len(prefix)] == prefix {
			delete(localCache, k)
			n++
		}
	}
	return n
}

// LocalSize — cache size in entries
func LocalSize() int {
	cacheMu.RLock()
	defer cacheMu.RUnlock()
	return len(localCache)
}
