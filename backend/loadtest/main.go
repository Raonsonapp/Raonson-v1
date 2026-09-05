// Command loadtest — генератори бори синтетикӣ барои Raonson.
//
// Чаро дар худи анбор: барои ин муҳит абзори берунӣ (k6) насб
// нашудааст, ва натиҷа бояд такроршаванда бошад.
//
// ⚠️ ТАНҲО ба муҳити САНҶИШӢ равона кунед. Ҳеҷ гоҳ ба production:
// он маълумоти воқеиро тағйир медиҳад ва корбарони воқеиро халалдор
// мекунад.
//
// Истифода:
//
//	go run ./loadtest -url http://localhost:8099 -users 100 -dur 30s
//
// Тақсимоти дархостҳо мисли трафики воқеӣ аст, на «ҳама ба як роҳ».
package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"math/rand"
	"net/http"
	"os"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// endpoint — як роҳ ва вазни он дар трафик.
type endpoint struct {
	name   string
	path   string
	weight int
}

// mix — тақсимоти трафик. Маҷмӯи вазнҳо 100.
var mix = []endpoint{
	{"feed", "/posts/feed?page=1&limit=20", 25},
	{"reels", "/reels?page=1&limit=10", 20},
	{"profile", "/profile/me", 10},
	{"search", "/search?q=load_u1&limit=20", 8},
	{"notifications", "/notifications?page=1&limit=30", 8},
	{"stories", "/stories", 6},
	{"discover", "/discover", 5},
	{"creator", "/creator/analytics?window=7d", 5},
	{"recap", "/recap/week", 5},
	{"referrals", "/referrals/me", 4},
	{"collabs", "/collabs/pending", 4},
}

type result struct {
	name string
	ms   float64
	code int
}

func main() {
	var (
		base   = flag.String("url", "http://localhost:8099", "суроғаи сервери САНҶИШӢ")
		users  = flag.Int("users", 100, "корбарони ҳамзамон")
		dur    = flag.Duration("dur", 30*time.Second, "давомнокӣ")
		dsn    = flag.String("db", "", "DATABASE_URL-и САНҶИШӢ (барои гирифтани корбарон)")
		secret = flag.String("secret", "", "JWT_SECRET-и муҳити санҷишӣ")
		warmup = flag.Duration("warmup", 3*time.Second, "гармкунӣ")
		only   = flag.String("only", "", "танҳо як роҳ (feed, reels...)")
		// Корбари воқеӣ бетаваққуф дархост намефиристад. Бе ин
		// санҷиш маҳдудияти суръатро чен мекунад, на барномаро.
		think = flag.Duration("think", 2*time.Second, "таваққуф байни дархостҳо (0 = ҳадди ниҳоӣ)")
	)
	flag.Parse()

	if strings.Contains(*base, "hf.space") ||
		strings.Contains(*base, "raonson.app") {
		fmt.Fprintln(os.Stderr,
			"РАД ШУД: ин ба муҳити production монанд аст.")
		os.Exit(1)
	}

	// Ҳар корбари виртуалӣ токени ХУДРО мегирад. Бо як токен
	// маҳдудияти суръати барнома (500 дархост дар дақиқа барои ҳар
	// корбар) фавран кор мекунад ва санҷиш худи маҳдудиятро чен
	// мекунад, на иҷрои барномаро.
	tokens := mintTokens(*dsn, *secret, *users)
	if len(tokens) == 0 {
		fmt.Fprintln(os.Stderr,
			"токен сохта нашуд: -db ва -secret лозиманд")
		os.Exit(1)
	}
	fmt.Printf("токенҳо: %d\n", len(tokens))

	active := mix
	if *only != "" {
		active = nil
		for _, e := range mix {
			if e.name == *only {
				e.weight = 100
				active = []endpoint{e}
			}
		}
		if active == nil {
			fmt.Fprintf(os.Stderr, "роҳи номаълум: %s\n", *only)
			os.Exit(1)
		}
	}

	// Ҷадвали интихоб аз рӯи вазн.
	var table []endpoint
	for _, e := range active {
		for i := 0; i < e.weight; i++ {
			table = append(table, e)
		}
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        *users * 2,
			MaxIdleConnsPerHost: *users * 2,
			IdleConnTimeout:     60 * time.Second,
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), *warmup+*dur)
	defer cancel()

	var (
		mu      sync.Mutex
		results []result
		started time.Time
		total   int64
		errs    int64
	)

	measuring := make(chan struct{})
	go func() {
		time.Sleep(*warmup)
		mu.Lock()
		results = nil // натиҷаи гармкунӣ ҳисоб намешавад
		started = time.Now()
		mu.Unlock()
		close(measuring)
	}()

	var wg sync.WaitGroup
	for i := 0; i < *users; i++ {
		wg.Add(1)
		go func(seed int) {
			defer wg.Done()
			rng := rand.New(rand.NewSource(int64(seed)))
			for ctx.Err() == nil {
				e := table[rng.Intn(len(table))]
				t0 := time.Now()
				code := hit(ctx, client, *base+e.path, tokens[seed%len(tokens)])
				ms := float64(time.Since(t0).Microseconds()) / 1000

				select {
				case <-measuring:
					atomic.AddInt64(&total, 1)
					if code >= 400 || code == 0 {
						atomic.AddInt64(&errs, 1)
					}
					mu.Lock()
					results = append(results, result{e.name, ms, code})
					mu.Unlock()
				default:
				}

				if *think > 0 {
					// Тақсимоти тасодуфӣ: ҳамаи корбарон дар як
					// лаҳза дархост нафиристанд.
					jitter := time.Duration(rng.Int63n(int64(*think)))
					select {
					case <-ctx.Done():
					case <-time.After(*think/2 + jitter):
					}
				}
			}
		}(i)
	}
	wg.Wait()

	mu.Lock()
	defer mu.Unlock()
	elapsed := time.Since(started).Seconds()
	report(*users, elapsed, results, total, errs)
}

func hit(ctx context.Context, c *http.Client, url, token string) int {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return 0
	}
	req.Header.Set("Authorization", "Bearer "+token)
	resp, err := c.Do(req)
	if err != nil {
		return 0
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<20))
	return resp.StatusCode
}

// mintTokens барои корбарони СИНТЕТИКӢ токен месозад.
//
// Ин роҳ танҳо барои муҳити санҷишӣ аст: он ҳамон secret-и муҳити
// санҷиширо истифода мебарад ва бақайдгирии оммавиро (ки худаш
// маҳдудияти суръат дорад) бартараф мекунад.
func mintTokens(dsn, secret string, n int) []string {
	if dsn == "" || secret == "" {
		return nil
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		fmt.Fprintln(os.Stderr, "база:", err)
		return nil
	}
	defer pool.Close()

	rows, err := pool.Query(context.Background(), `
		SELECT id FROM users WHERE username LIKE 'load_u%' LIMIT $1`, n)
	if err != nil {
		fmt.Fprintln(os.Stderr, "корбарон:", err)
		return nil
	}
	defer rows.Close()

	var out []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			continue
		}
		t, err := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
			"id":  id,
			"exp": time.Now().Add(2 * time.Hour).Unix(),
		}).SignedString([]byte(secret))
		if err == nil {
			out = append(out, t)
		}
	}
	return out
}

func report(users int, elapsed float64, rs []result, total, errs int64) {
	if len(rs) == 0 {
		fmt.Println("натиҷа нест")
		return
	}
	all := make([]float64, len(rs))
	byName := map[string][]float64{}
	codes := map[int]int{}
	for i, r := range rs {
		all[i] = r.ms
		byName[r.name] = append(byName[r.name], r.ms)
		codes[r.code]++
	}

	fmt.Printf("\n─── БОР: %d корбари ҳамзамон, %.1f с ───\n", users, elapsed)
	fmt.Printf("дархостҳо: %d   RPS: %.0f   хато: %d (%.2f%%)\n",
		total, float64(total)/elapsed, errs,
		float64(errs)*100/float64(max64(total, 1)))
	fmt.Printf("p50: %.0f мс   p95: %.0f мс   p99: %.0f мс   max: %.0f мс\n",
		pct(all, 50), pct(all, 95), pct(all, 99), pct(all, 100))

	fmt.Println("\nроҳ            n      p50     p95     p99")
	names := make([]string, 0, len(byName))
	for n := range byName {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		v := byName[n]
		fmt.Printf("%-14s %-6d %-7.0f %-7.0f %-7.0f\n",
			n, len(v), pct(v, 50), pct(v, 95), pct(v, 99))
	}

	fmt.Print("\nрамзҳо: ")
	for c, n := range codes {
		fmt.Printf("%d=%d  ", c, n)
	}
	fmt.Println()
}

// pct — фоизи додашуда. Ҳисоби оддӣ ва возеҳ.
func pct(v []float64, p int) float64 {
	if len(v) == 0 {
		return 0
	}
	s := append([]float64(nil), v...)
	sort.Float64s(s)
	i := (len(s) - 1) * p / 100
	return s[i]
}

func max64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}
