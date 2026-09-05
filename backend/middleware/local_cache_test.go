package middleware

import (
	"fmt"
	"testing"
	"time"
)

// Кэш набояд бе ҳад калон шавад: дар 50 000 корбар байни ду
// поксозӣ даҳҳо ҳазор ҷавоб ҷамъ мешуд.
func TestCacheStaysBounded(t *testing.T) {
	old := maxCacheEntries
	maxCacheEntries = 100
	defer func() {
		maxCacheEntries = old
		cacheMu.Lock()
		localCache = make(map[string]cacheEntry)
		cacheMu.Unlock()
	}()

	for i := 0; i < 5000; i++ {
		LocalSet(fmt.Sprintf("k%d", i), []byte("v"), 10*time.Minute)
	}
	if n := LocalSize(); n > maxCacheEntries {
		t.Errorf("кэш %d вуруди дорад, ҳад %d", n, maxCacheEntries)
	}
}

// Поксозӣ вурудиҳои кӯҳнаро мебарорад.
func TestExpiredEntriesAreRemoved(t *testing.T) {
	cacheMu.Lock()
	localCache = make(map[string]cacheEntry)
	cacheMu.Unlock()

	LocalSet("зинда", []byte("v"), time.Hour)
	LocalSet("кӯҳна", []byte("v"), time.Millisecond)
	time.Sleep(10 * time.Millisecond)
	cleanExpired()

	if _, ok := LocalGet("кӯҳна"); ok {
		t.Error("вуруди кӯҳна намонда буд")
	}
	if _, ok := LocalGet("зинда"); !ok {
		t.Error("вуруди зинда бароварда шуд")
	}
}

// Навиштан ва хондани ҳамзамон набояд ба нажод оварад.
// Бо -race иҷро шавад.
func TestConcurrentAccess(t *testing.T) {
	done := make(chan struct{})
	for i := 0; i < 8; i++ {
		go func(n int) {
			for j := 0; j < 500; j++ {
				k := fmt.Sprintf("c%d-%d", n, j%50)
				LocalSet(k, []byte("v"), time.Minute)
				LocalGet(k)
			}
			done <- struct{}{}
		}(i)
	}
	for i := 0; i < 8; i++ {
		<-done
	}
}
