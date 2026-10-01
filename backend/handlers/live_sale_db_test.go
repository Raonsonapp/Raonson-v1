package handlers

// Ду камбудӣ, ки танҳо бо базаи ҳақиқӣ санҷида мешаванд:
//
//   • Эфири «мурда». Агар барномаи ҳост афтад ё интернет қатъ шавад,
//     /live/:id/end ҳеҷ гоҳ намеояд. Пеш чунин эфир то абад дар
//     рӯйхат «🔴 LIVE» мемонд. Акнун хондани рӯйхат аз ҷониби ҳост
//     «зинда ҳастам» аст ва эфири беҷавоб баста мешавад.
//
//   • Тахфифи маҳсул (salePct) дар шакли умумии пост. Пеш онро танҳо
//     /shop медод — «Харид» дар лента нархи пурраро нишон медод.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	mw "raonson/middleware"
)

func liveRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/live", mw.Auth())
	g.GET("/", ListLive)
	g.POST("/start", StartLive)
	return r
}

func liveIDs(t *testing.T, r *gin.Engine, tok string) map[string]bool {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet, "/live/", nil)
	req.Header.Set("Authorization", "Bearer "+tok)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("GET /live/ → %d: %s", w.Code, w.Body.String())
	}
	var b struct {
		Streams []struct {
			ID string `json:"id"`
		} `json:"streams"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &b); err != nil {
		t.Fatal(err)
	}
	out := map[string]bool{}
	for _, s := range b.Streams {
		out[s.ID] = true
	}
	return out
}

func TestLiveStreamWithoutHeartbeatIsEnded(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("JWT_SECRET", "test-secret-live")
	r := liveRouter()
	host, viewer := adsUser(t, pool), adsUser(t, pool)
	hostTok, viewerTok := tokenFor(t, host), tokenFor(t, viewer)

	w := do(t, r, "/live/start", hostTok, map[string]any{"title": "санҷиш"})
	if w.Code != http.StatusOK {
		t.Fatalf("start → %d: %s", w.Code, w.Body.String())
	}
	var started struct {
		ID string `json:"id"`
	}
	json.Unmarshal(w.Body.Bytes(), &started)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM live_streams WHERE id=$1`, started.ID)
	})

	if !liveIDs(t, r, viewerTok)[started.ID] {
		t.Fatal("эфири нав бояд дар рӯйхат бошад")
	}

	// Ҳост 2 дақиқа хабар надод (барнома афтод).
	pool.Exec(context.Background(), `
		UPDATE live_streams SET heartbeat_at = NOW() - INTERVAL '2 minutes',
		       started_at = NOW() - INTERVAL '3 minutes' WHERE id=$1`, started.ID)
	if liveIDs(t, r, viewerTok)[started.ID] {
		t.Fatal("эфире, ки ҳост 2 дақиқа хабар надод, набояд дар рӯйхат бошад")
	}
	var active bool
	pool.QueryRow(context.Background(),
		`SELECT active FROM live_streams WHERE id=$1`, started.ID).Scan(&active)
	if active {
		t.Fatal("эфири беҷавоб бояд баста шавад (active=false)")
	}
}

func TestLiveHostPollKeepsStreamAlive(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("JWT_SECRET", "test-secret-live")
	r := liveRouter()
	host, viewer := adsUser(t, pool), adsUser(t, pool)
	hostTok, viewerTok := tokenFor(t, host), tokenFor(t, viewer)

	w := do(t, r, "/live/start", hostTok, map[string]any{"title": "дароз"})
	var started struct {
		ID string `json:"id"`
	}
	json.Unmarshal(w.Body.Bytes(), &started)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM live_streams WHERE id=$1`, started.ID)
	})

	// Эфир 10 дақиқа пеш оғоз шуд, вале ҳост ҳоло рӯйхатро мехонад.
	pool.Exec(context.Background(), `
		UPDATE live_streams SET heartbeat_at = NOW() - INTERVAL '60 seconds',
		       started_at = NOW() - INTERVAL '10 minutes' WHERE id=$1`, started.ID)
	liveIDs(t, r, hostTok) // poll-и ҳост = «зинда ҳастам»
	if !liveIDs(t, r, viewerTok)[started.ID] {
		t.Fatal("эфири дароз бо ҳости фаъол набояд баста шавад")
	}
}

func TestAttachSalePctOnlyActiveSale(t *testing.T) {
	pool := adsTestDB(t)
	owner := adsUser(t, pool)
	ctx := context.Background()
	mk := func(isProduct bool, pct int, until string) string {
		var id string
		if err := pool.QueryRow(ctx, `
			INSERT INTO posts(user_id, caption, is_product, price, sale_pct, sale_until)
			VALUES($1,'x',$2,100,$3, NOW() + $4::interval) RETURNING id`,
			owner, isProduct, pct, until).Scan(&id); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM posts WHERE id=$1`, id) })
		return id
	}
	onSale := mk(true, 25, "1 day")
	expired := mk(true, 40, "-1 day")
	plain := mk(false, 30, "1 day") // пости оддӣ — тахфиф маъно надорад

	posts := []gin.H{
		{"_id": onSale, "isProduct": true},
		{"_id": expired, "isProduct": true},
		{"_id": plain, "isProduct": false},
	}
	attachSalePct(posts)
	want := []int{25, 0, 0}
	for i, p := range posts {
		if p["salePct"] != want[i] {
			t.Errorf("пост %d: salePct=%v, бояд %d", i, p["salePct"], want[i])
		}
	}
}
