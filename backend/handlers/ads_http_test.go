package handlers

// Сарҳади HTTP-и мукофоти реклама.
//
// Тестҳои ads/session_db_test.go мантиқро месанҷанд. Ин ҷо чизи
// дигар санҷида мешавад: оё дархости ВОҚЕИИ HTTP ҳимояро убур карда
// метавонад.
//
// Се савол:
//   • бе токен чӣ мешавад;
//   • оё барнома метавонад бигӯяд «ман корбари дигарам»;
//   • оё дархостҳои пай дар пай маҳдуд мешаванд.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/db"
	mw "raonson/middleware"
)

const httpTestUnit = "R-M-19230220-2"

func adsRouter(t *testing.T) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/ads", mw.Auth(), mw.RateLimit(30, 60))
	g.POST("/watch-session", AdWatchSession)
	g.POST("/watched", AdWatched)
	return r
}

// adsTestDB базаро мепайвандад ва db.Pool-ро мегузорад.
func adsTestDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	if os.Getenv("RAONSON_TEST_DB") == "" {
		t.Skip("RAONSON_TEST_DB гузошта нашудааст")
	}
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL нест")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	prev := db.Pool
	db.Pool = pool
	t.Cleanup(func() { db.Pool = prev; pool.Close() })
	return pool
}

func adsUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	n := fmt.Sprintf("adshttp_%d", time.Now().UnixNano())
	var id string
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO users(username, email, password)
		VALUES ($1,$2,'x') RETURNING id`,
		n, n+"@test.invalid").Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

func tokenFor(t *testing.T, userID string) string {
	t.Helper()
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":  userID,
		"exp": time.Now().Add(time.Hour).Unix(),
	})
	s, err := tok.SignedString([]byte(os.Getenv("JWT_SECRET")))
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func do(t *testing.T, r *gin.Engine, path, token string,
	body map[string]any) *httptest.ResponseRecorder {
	t.Helper()
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(http.MethodPost, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func adsHTTPSetup(t *testing.T) {
	t.Helper()
	t.Setenv("JWT_SECRET", "test-secret-for-ads-http")
	t.Setenv("YANDEX_REWARDED_ID", httpTestUnit)
	t.Setenv("ADS_MIN_WATCH_SEC", "0")
	t.Setenv("ADS_MIN_CLAIM_INTERVAL_SEC", "0")
	t.Setenv("ADS_DAILY_CAP", "100000")
	// Маҳдудияти суръат аз рӯи калид ҷамъ мешавад ва байни тестҳо
	// мемонад; зарбкунанда онро барои тестҳои оддӣ мекушояд.
	t.Setenv("RATE_LIMIT_MULTIPLIER", "1000")
}

// ── Авторизатсия ─────────────────────────────────────────────────

func TestAdsEndpointsNeedAuth(t *testing.T) {
	adsTestDB(t)
	adsHTTPSetup(t)
	r := adsRouter(t)

	for _, path := range []string{"/ads/watch-session", "/ads/watched"} {
		w := do(t, r, path, "", map[string]any{"adUnitId": httpTestUnit})
		if w.Code != http.StatusUnauthorized {
			t.Fatalf("%s бе токен: %d, бояд 401", path, w.Code)
		}
	}
}

func TestAdsRejectsForgedToken(t *testing.T) {
	adsTestDB(t)
	adsHTTPSetup(t)
	r := adsRouter(t)

	// Токен бо калиди дигар имзо шуд.
	tok := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id": "someone", "exp": time.Now().Add(time.Hour).Unix(),
	})
	forged, _ := tok.SignedString([]byte("wrong-key"))

	w := do(t, r, "/ads/watch-session", forged,
		map[string]any{"adUnitId": httpTestUnit})
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("токени сохта қабул шуд: %d", w.Code)
	}
}

// ── Корбар аз JWT, на аз бадани дархост ──────────────────────────

func TestClientCannotChooseUser(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	r := adsRouter(t)

	victim := adsUser(t, pool)
	attacker := adsUser(t, pool)

	// Ҳамлакунанда шиносаи қурбониро дар бадан мефиристад.
	w := do(t, r, "/ads/watch-session", tokenFor(t, attacker),
		map[string]any{
			"adUnitId": httpTestUnit,
			"userId":   victim,
			"user_id":  victim,
		})
	if w.Code != http.StatusOK {
		t.Fatalf("сеанс сохта нашуд: %d %s", w.Code, w.Body.String())
	}

	var resp struct {
		SessionID string `json:"sessionId"`
	}
	json.Unmarshal(w.Body.Bytes(), &resp)

	// Сеанс бояд ба ҲАМЛАКУНАНДА тааллуқ дошта бошад.
	var owner string
	pool.QueryRow(context.Background(),
		`SELECT user_id FROM ad_watch_sessions WHERE id=$1`,
		resp.SessionID).Scan(&owner)
	if owner != attacker {
		t.Fatalf("шиносаи корбар аз бадани дархост гирифта шуд: %s", owner)
	}

	// Ҳисоб низ ба ҳамлакунанда меравад, на ба қурбонӣ.
	w = do(t, r, "/ads/watched", tokenFor(t, attacker), map[string]any{
		"adUnitId":  httpTestUnit,
		"sessionId": resp.SessionID,
		"userId":    victim,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("ҳисоб нашуд: %d %s", w.Code, w.Body.String())
	}

	var n int
	pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM ad_rewards WHERE user_id=$1`, victim).Scan(&n)
	if n != 0 {
		t.Fatalf("қурбонӣ %d реклама гирифт", n)
	}
}

// Миқдор, зина ва баланс аз барнома қабул НАМЕШАВАНД.
func TestClientCannotSupplyRewardAmount(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	r := adsRouter(t)
	u := adsUser(t, pool)
	tok := tokenFor(t, u)

	w := do(t, r, "/ads/watch-session", tok,
		map[string]any{"adUnitId": httpTestUnit})
	var resp struct {
		SessionID string `json:"sessionId"`
	}
	json.Unmarshal(w.Body.Bytes(), &resp)

	w = do(t, r, "/ads/watched", tok, map[string]any{
		"adUnitId":  httpTestUnit,
		"sessionId": resp.SessionID,
		// Ҳамаи инҳо бояд сарфи назар карда шаванд.
		"amount":  1000,
		"coins":   1000,
		"reward":  1000,
		"tier":    "30d",
		"balance": 999999,
		"watched": 999999,
	})
	if w.Code != http.StatusOK {
		t.Fatalf("%d %s", w.Code, w.Body.String())
	}

	// Як тамошо — як сатр, новобаста аз он чи барнома фиристод.
	var n int
	pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM ad_rewards WHERE user_id=$1`, u).Scan(&n)
	if n != 1 {
		t.Fatalf("барнома миқдорро таъин кард: %d сатр", n)
	}

	// Зина низ иваз нашуд.
	var goal string
	pool.QueryRow(context.Background(),
		`SELECT goal FROM verification_state WHERE user_id=$1`, u).Scan(&goal)
	if goal != "" && goal != "3d" {
		t.Fatalf("зина аз барнома гирифта шуд: %s", goal)
	}
}

// ── Ҷавобҳо ──────────────────────────────────────────────────────

func TestReusedSessionReturnsConflict(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	r := adsRouter(t)
	u := adsUser(t, pool)
	tok := tokenFor(t, u)

	w := do(t, r, "/ads/watch-session", tok,
		map[string]any{"adUnitId": httpTestUnit})
	var resp struct {
		SessionID string `json:"sessionId"`
	}
	json.Unmarshal(w.Body.Bytes(), &resp)

	body := map[string]any{
		"adUnitId": httpTestUnit, "sessionId": resp.SessionID,
	}
	if w := do(t, r, "/ads/watched", tok, body); w.Code != http.StatusOK {
		t.Fatalf("якум: %d", w.Code)
	}
	if w := do(t, r, "/ads/watched", tok, body); w.Code != http.StatusConflict {
		t.Fatalf("такрор: %d, бояд 409", w.Code)
	}
}

func TestUnknownSessionReturnsForbidden(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	r := adsRouter(t)
	u := adsUser(t, pool)

	w := do(t, r, "/ads/watched", tokenFor(t, u), map[string]any{
		"adUnitId":  httpTestUnit,
		"sessionId": "00000000000000000000000000000000",
	})
	if w.Code != http.StatusForbidden {
		t.Fatalf("%d, бояд 403", w.Code)
	}
}

// Бе YANDEX_REWARDED_ID хусусият хомӯш аст ва инро рост мегӯяд.
func TestNoRewardedIdReturns503(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	t.Setenv("YANDEX_REWARDED_ID", "")
	r := adsRouter(t)
	u := adsUser(t, pool)

	w := do(t, r, "/ads/watch-session", tokenFor(t, u),
		map[string]any{"adUnitId": httpTestUnit})
	if w.Code != http.StatusServiceUnavailable {
		t.Fatalf("%d, бояд 503", w.Code)
	}
}

// ── Маҳдудияти суръат ────────────────────────────────────────────

func TestRateLimitStopsFlood(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	// Зарбкунанда хомӯш — маҳз ҳамин ҷо ҳад санҷида мешавад.
	t.Setenv("RATE_LIMIT_MULTIPLIER", "")

	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/ads", mw.Auth(), mw.RateLimit(5, 60))
	g.POST("/watch-session", AdWatchSession)

	u := adsUser(t, pool)
	tok := tokenFor(t, u)
	body := map[string]any{"adUnitId": httpTestUnit}

	var limited bool
	for i := 0; i < 20; i++ {
		if do(t, r, "/ads/watch-session", tok, body).Code ==
			http.StatusTooManyRequests {
			limited = true
			break
		}
	}
	if !limited {
		t.Fatal("20 дархост бе маҳдудият гузашт")
	}
}
