package handlers

// Модератсия: огоҳиҳо (strikes), маҳдудкунӣ, барқарорсозӣ, нест
// кардани медиаи манъшуда.
//
// Тестҳои база бе RAONSON_TEST_DB + DATABASE_URL гузаронда мешаванд
// (схема бояд аллакай бошад — сервер онро ҳангоми оғоз месозад).

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"

	mw "raonson/middleware"
	"raonson/moderation"
)

func TestModRequestHashIsStable(t *testing.T) {
	a := modRequest{Surface: "post", Texts: []string{" watch porn "}, Media: []modMedia{{URL: "u1"}}}
	b := modRequest{Surface: "comment", Texts: []string{"watch porn"}, Media: []modMedia{{URL: "u1"}}}
	if a.hash() != b.hash() {
		t.Fatal("ҳамон мӯҳтаво дар ҷои дигар — ҳамон hash (огоҳии дукарата нест)")
	}
	c := modRequest{Texts: []string{"watch porn"}, Media: []modMedia{{URL: "u2"}}}
	if a.hash() == c.hash() {
		t.Fatal("медиаи дигар — hash-и дигар")
	}
}

func TestR2KeyOf(t *testing.T) {
	t.Setenv("CF_R2_PUBLIC_URL", "https://cdn.raonson.tj")
	if k := r2KeyOf("https://cdn.raonson.tj/images/a.jpg"); k != "images/a.jpg" {
		t.Fatalf("key: %q", k)
	}
	for _, u := range []string{"https://evil.example/images/a.jpg", "https://cdn.raonson.tj.evil/x", ""} {
		if k := r2KeyOf(u); k != "" {
			t.Fatalf("%q → %q: суроғаи бегона калид надорад", u, k)
		}
	}
}

func TestStrikeEnvDefaults(t *testing.T) {
	t.Setenv("MODERATION_STRIKE_LIMIT", "")
	t.Setenv("MODERATION_SUSPEND_DAYS", "bad")
	if strikeLimit() != 3 || strikeWindowDays() != 30 || suspendDays() != 7 {
		t.Fatal("пешфарз: 3 огоҳӣ / 30 рӯз / 7 рӯз")
	}
	t.Setenv("MODERATION_STRIKE_LIMIT", "5")
	if strikeLimit() != 5 {
		t.Fatal("env")
	}
}

func TestSuspendedMessageIsTajik(t *testing.T) {
	m := suspendedMessage(time.Date(2026, 1, 2, 10, 0, 0, 0, time.UTC))
	if !strings.Contains(m, "02.01.2026 15:00") || !strings.Contains(m, "маҳдуд") {
		t.Fatalf("%q", m)
	}
}

// ── база ──────────────────────────────────────────────────────────

func modRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/", mw.Auth())
	g.POST("/publish", func(c *gin.Context) {
		var b struct {
			Text  string `json:"text"`
			Media string `json:"media"`
		}
		c.ShouldBindJSON(&b)
		req := modRequest{Surface: "post", Texts: []string{b.Text}}
		if b.Media != "" {
			req.Media = []modMedia{{URL: b.Media}}
		}
		out, ok := screenContent(c, mw.UID(c), req)
		if !ok {
			return
		}
		c.JSON(http.StatusOK, gin.H{"queue": out.Queue, "hold": out.Hold})
	})
	g.POST("/admin/restore/:id", AdminModerationRestore)
	return r
}

func decode(t *testing.T, w *httptest.ResponseRecorder) map[string]any {
	t.Helper()
	m := map[string]any{}
	json.Unmarshal(w.Body.Bytes(), &m)
	return m
}

func TestStrikesSuspendAfterThreeAndRestore(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("JWT_SECRET", "test-secret-moderation")
	t.Setenv("MODERATION_IMAGE_PROVIDER", "none")
	r := modRouter()
	uid := adsUser(t, pool)
	tok := tokenFor(t, uid)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM moderation_strikes WHERE user_id=$1`, uid)
		pool.Exec(context.Background(), `DELETE FROM moderation_queue WHERE user_id=$1`, uid)
	})

	if w := do(t, r, "/publish", tok, map[string]any{"text": "Салом дӯстон"}); w.Code != 200 {
		t.Fatalf("матни тоза: %d %s", w.Code, w.Body.String())
	}
	// Ҳамон матни бад се бор — танҳо ЯК огоҳӣ (такрор).
	for i := 0; i < 3; i++ {
		w := do(t, r, "/publish", tok, map[string]any{"text": "free porn here"})
		if w.Code != 403 || decode(t, w)["message"] != ContentBlockedMessage ||
			decode(t, w)["code"] != "content_blocked" {
			t.Fatalf("бад → 403: %d %s", w.Code, w.Body.String())
		}
	}
	var n int
	pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM moderation_strikes WHERE user_id=$1`, uid).Scan(&n)
	if n != 1 {
		t.Fatalf("такрор огоҳии нав намедиҳад: %d", n)
	}
	// Дашном — рад, вале огоҳӣ не.
	if w := do(t, r, "/publish", tok, map[string]any{"text": "иди нахуй"}); w.Code != 403 {
		t.Fatalf("дашном: %d", w.Code)
	}
	pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM moderation_strikes WHERE user_id=$1`, uid).Scan(&n)
	if n != 1 {
		t.Fatalf("дашном огоҳӣ намедиҳад: %d", n)
	}
	// Огоҳии дуюм — ҳанӯз маҳдуд нест.
	do(t, r, "/publish", tok, map[string]any{"text": "смотри порно"})
	if suspendedUntil(context.Background(), uid) != nil {
		t.Fatal("2 огоҳӣ — ҳанӯз маҳдуд нест")
	}
	// Сеюм → маҳдуд.
	w := do(t, r, "/publish", tok, map[string]any{"text": "xvideos link"})
	if w.Code != 403 || decode(t, w)["suspendedUntil"] == nil {
		t.Fatalf("огоҳии сеюм → маҳдуд: %d %s", w.Code, w.Body.String())
	}
	until := suspendedUntil(context.Background(), uid)
	if until == nil || until.Sub(time.Now()) < 6*24*time.Hour {
		t.Fatalf("маҳдудкунии ~7 рӯз: %v", until)
	}
	// Ҳоло матни тоза ҳам — 403 account_suspended.
	w = do(t, r, "/publish", tok, map[string]any{"text": "Салом"})
	if w.Code != 403 || decode(t, w)["code"] != "account_suspended" {
		t.Fatalf("маҳдуд нашр карда наметавонад: %d %s", w.Code, w.Body.String())
	}
	// Admin огоҳ шуд: сатри suspension дар навбат.
	var pend int
	pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM moderation_queue
		WHERE user_id=$1 AND action='suspension' AND status='pending'`, uid).Scan(&pend)
	if pend != 1 {
		t.Fatalf("сатри suspension: %d", pend)
	}
	// Бани доимӣ ХУДКОР нест.
	var banned bool
	pool.QueryRow(context.Background(), `SELECT COALESCE(banned,false) FROM users WHERE id=$1`, uid).Scan(&banned)
	if banned {
		t.Fatal("бани доимӣ танҳо аз ҷониби admin")
	}
	// Барқарорсозӣ.
	if w := do(t, r, "/admin/restore/"+uid, tok, nil); w.Code != 200 {
		t.Fatalf("restore: %d", w.Code)
	}
	if w := do(t, r, "/publish", tok, map[string]any{"text": "Салом"}); w.Code != 200 {
		t.Fatalf("баъди барқарорсозӣ: %d %s", w.Code, w.Body.String())
	}
}

func TestSevereSuspendsImmediately(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("JWT_SECRET", "test-secret-moderation")
	r := modRouter()
	uid := adsUser(t, pool)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM moderation_strikes WHERE user_id=$1`, uid)
		pool.Exec(context.Background(), `DELETE FROM moderation_queue WHERE user_id=$1`, uid)
	})
	w := do(t, r, "/publish", tokenFor(t, uid), map[string]any{"text": "child porn"})
	if w.Code != 403 || decode(t, w)["suspendedUntil"] == nil {
		t.Fatalf("severe → фавран маҳдуд: %d %s", w.Code, w.Body.String())
	}
}

func TestAdminsAreNotAutoSuspended(t *testing.T) {
	pool := adsTestDB(t)
	uid := adsUser(t, pool)
	pool.Exec(context.Background(), `UPDATE users SET role='admin' WHERE id=$1`, uid)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM moderation_strikes WHERE user_id=$1`, uid)
		pool.Exec(context.Background(), `DELETE FROM moderation_queue WHERE user_id=$1`, uid)
	})
	if suspendUser(context.Background(), uid, "test", false) != nil {
		t.Fatal("admin худкор маҳдуд намешавад")
	}
}

func TestDeleteBlockedMediaOnlyOwnUnused(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("CF_ACCOUNT_ID", "a")
	t.Setenv("CF_R2_ACCESS_KEY", "b")
	t.Setenv("CF_R2_SECRET_KEY", "c")
	t.Setenv("CF_R2_PUBLIC_URL", "https://cdn.test.invalid")
	var mu sync.Mutex
	deleted := []string{}
	old := r2DeleteObject
	r2DeleteObject = func(_ context.Context, key string) error {
		mu.Lock()
		deleted = append(deleted, key)
		mu.Unlock()
		return nil
	}
	t.Cleanup(func() { r2DeleteObject = old })

	owner, other := adsUser(t, pool), adsUser(t, pool)
	stamp := time.Now().Format("150405.000000")
	mine := "https://cdn.test.invalid/images/mine-" + stamp + ".jpg"
	theirs := "https://cdn.test.invalid/images/theirs-" + stamp + ".jpg"
	ctx := context.Background()
	pool.Exec(ctx, `INSERT INTO media_uploads(url,user_id,kind,verdict) VALUES($1,$2,'image','allow')`, mine, owner)
	pool.Exec(ctx, `INSERT INTO media_uploads(url,user_id,kind,verdict) VALUES($1,$2,'image','allow')`, theirs, other)
	t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM media_uploads WHERE url = ANY($1)`, []string{mine, theirs}) })

	deleteBlockedMedia(ctx, owner, []modMedia{{URL: mine}, {URL: theirs}})
	if len(deleted) != 1 || !strings.HasSuffix(mine, deleted[0]) {
		t.Fatalf("танҳо файли худ нест мешавад: %v", deleted)
	}
}

func TestUploadVerdictReused(t *testing.T) {
	pool := adsTestDB(t)
	uid := adsUser(t, pool)
	u := "https://cdn.test.invalid/images/cached-" + time.Now().Format("150405.000000") + ".jpg"
	recordUpload(uid, u, "image/jpeg", moderation.Verdict{Action: moderation.Review, Score: 0.7})
	t.Cleanup(func() { pool.Exec(context.Background(), `DELETE FROM media_uploads WHERE url=$1`, u) })
	v := evaluate(context.Background(), modRequest{Media: []modMedia{{URL: u}}})
	if v.Action != moderation.Review || v.Unscanned {
		t.Fatalf("қарори боргузорӣ (шубҳанок) истифода мешавад: %+v", v)
	}
}
