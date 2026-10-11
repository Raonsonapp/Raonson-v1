package handlers

// Коргари HLS-и Reels.
//
//   • қисмҳои соф (таъхири такрор, анбори маҳаллӣ, роҳи /media-local);
//   • тамоми роҳ бо базаи ҳақиқӣ ва ffmpeg: видеои 3-сонияӣ (moov дар
//     охир) → remux +faststart, master + 3 зина + preview, сутунҳои reels.
//
// Тести база бе RAONSON_TEST_DB, тести ffmpeg бе ffmpeg гузаронда мешавад.

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"raonson/renditions"

	"github.com/gin-gonic/gin"
)

func TestRendRetryDelayIsExponentialAndCapped(t *testing.T) {
	want := []time.Duration{time.Minute, 5 * time.Minute, 25 * time.Minute, 2 * time.Hour, 2 * time.Hour}
	for i, w := range want {
		if got := rendRetryDelay(i + 1); got != w {
			t.Errorf("attempt %d: got %s want %s", i+1, got, w)
		}
	}
}

func TestEnvIntRangeClamps(t *testing.T) {
	cases := map[string]int{"": 1, "x": 1, "0": 1, "1": 1, "2": 2, "9": 2}
	for in, want := range cases {
		if got := envIntRangeStr(in, 1, 1, 2); got != want {
			t.Errorf("%q → %d want %d", in, got, want)
		}
	}
}

func TestLocalMediaNeverInRelease(t *testing.T) {
	t.Setenv("MEDIA_LOCAL_DIR", t.TempDir())
	t.Setenv("MEDIA_LOCAL_PUBLIC_URL", "http://127.0.0.1:1/media-local")
	t.Setenv("GIN_MODE", "release")
	if LocalMediaEnabled() {
		t.Fatal("local media must be disabled in release")
	}
	t.Setenv("GIN_MODE", "debug")
	if !LocalMediaEnabled() {
		t.Fatal("local media should be enabled in debug with both env vars")
	}
}

func TestServeLocalMediaBlocksTraversalAndSetsTypes(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("MEDIA_LOCAL_DIR", dir)
	t.Setenv("MEDIA_LOCAL_PUBLIC_URL", "http://x/media-local")
	t.Setenv("GIN_MODE", "debug")
	os.MkdirAll(filepath.Join(dir, "reels", "a"), 0o755)
	os.WriteFile(filepath.Join(dir, "reels", "a", "master.m3u8"), []byte("#EXTM3U\n"), 0o644)
	os.WriteFile(filepath.Join(filepath.Dir(dir), "secret.txt"), []byte("x"), 0o644)

	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/media-local/*path", ServeLocalMedia)
	get := func(p string) *httptest.ResponseRecorder {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, p, nil))
		return w
	}
	w := get("/media-local/reels/a/master.m3u8")
	if w.Code != 200 || w.Header().Get("Content-Type") != "application/vnd.apple.mpegurl" {
		t.Fatalf("m3u8: %d %q", w.Code, w.Header().Get("Content-Type"))
	}
	for _, p := range []string{"/media-local/../secret.txt", "/media-local/reels/../../secret.txt",
		"/media-local/reels", "/media-local/nope.ts"} {
		if w := get(p); w.Code == 200 {
			t.Errorf("%s served (%d)", p, w.Code)
		}
	}
}

func TestEnqueueRefusesExternalSources(t *testing.T) {
	t.Setenv("CF_R2_PUBLIC_URL", "https://media.raonson.example")
	t.Setenv("MEDIA_ALLOWED_HOSTS", "")
	// db.Pool метавонад nil бошад — ҳарду ҳолат бояд false диҳанд.
	for _, u := range []string{"https://www.aparat.com/v/abc", "http://169.254.169.254/latest",
		"https://evil.example/x.mp4", ""} {
		if EnqueueReelRendition(context.Background(), "r1", u) {
			t.Errorf("%s was queued", u)
		}
	}
}

// ── тамоми роҳ: база + ffmpeg ─────────────────────────────────────

func TestRenditionWorkerEndToEnd(t *testing.T) {
	pool := adsTestDB(t)
	if !renditions.Available(renditions.Options{}) {
		t.Skip("ffmpeg нест")
	}
	dir := t.TempDir()
	srv := httptest.NewServer(http.FileServer(http.Dir(dir)))
	defer srv.Close()
	host := strings.TrimPrefix(srv.URL, "http://")
	t.Setenv("GIN_MODE", "debug")
	t.Setenv("CF_ACCOUNT_ID", "") // R2 нест → анбори маҳаллӣ
	t.Setenv("MEDIA_LOCAL_DIR", dir)
	t.Setenv("MEDIA_LOCAL_PUBLIC_URL", srv.URL)
	t.Setenv("MEDIA_ALLOWED_HOSTS", host)
	t.Setenv("MEDIA_ALLOW_HTTP", "1")
	t.Setenv("RENDITION_PRESET", "ultrafast")

	// Видеои 3-сонияӣ, амудӣ, бо садо, moov дар ОХИР.
	os.MkdirAll(filepath.Join(dir, "videos"), 0o755)
	src := filepath.Join(dir, "videos", "src.mp4")
	if b, err := exec.Command("ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
		"-f", "lavfi", "-i", "testsrc2=size=720x1280:rate=30:duration=3",
		"-f", "lavfi", "-i", "sine=frequency=440:duration=3",
		"-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p",
		"-c:a", "aac", "-shortest", src).CombinedOutput(); err != nil {
		t.Fatalf("ffmpeg: %v %s", err, b)
	}
	if fs, _ := renditions.IsFaststart(src); fs {
		t.Fatal("fixture should not be faststart")
	}

	ctx := context.Background()
	uid := adsUser(t, pool)
	srcURL := srv.URL + "/videos/src.mp4"
	var rid string
	if err := pool.QueryRow(ctx, `INSERT INTO reels(user_id, video_url) VALUES($1,$2) RETURNING id`,
		uid, srcURL).Scan(&rid); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM reels WHERE id=$1`, rid) })

	if !EnqueueReelRendition(ctx, rid, srcURL) {
		t.Fatal("not queued")
	}
	if EnqueueReelRendition(ctx, rid, srcURL) {
		t.Fatal("queued twice")
	}
	if err := processRendition(&rendJob{reelID: rid, source: srcURL, attempts: 1}); err != nil {
		t.Fatalf("process: %v", err)
	}

	var hls, low, preview, video, status string
	var ready bool
	pool.QueryRow(ctx, `SELECT hls_url, hls_low_url, preview_url, renditions_ready, video_url FROM reels WHERE id=$1`, rid).
		Scan(&hls, &low, &preview, &ready, &video)
	pool.QueryRow(ctx, `SELECT status FROM reel_renditions WHERE reel_id=$1`, rid).Scan(&status)
	if !ready || status != "ready" {
		t.Fatalf("ready=%v status=%s", ready, status)
	}
	prefix := srv.URL + "/reels/" + rid + "/hls/"
	if !strings.HasPrefix(hls, prefix) || !strings.HasSuffix(hls, "/master.m3u8") ||
		!strings.HasSuffix(low, "/240p/index.m3u8") || !strings.HasSuffix(preview, "/preview.mp4") {
		t.Fatalf("urls: %s %s %s", hls, low, preview)
	}
	// video_url → нусхаи +faststart (moov дар аввал).
	if video == srcURL || !strings.HasPrefix(video, srv.URL+"/reels/"+rid+"/mp4/") {
		t.Fatalf("video_url not replaced with faststart copy: %s", video)
	}
	fast := filepath.Join(dir, filepath.FromSlash(strings.TrimPrefix(video, srv.URL+"/")))
	if fs, err := renditions.IsFaststart(fast); err != nil || !fs {
		t.Fatalf("faststart copy: %v %v", fs, err)
	}

	body := func(u string) string {
		resp, err := http.Get(u)
		if err != nil || resp.StatusCode != 200 {
			t.Fatalf("GET %s: %v %v", u, err, resp)
		}
		defer resp.Body.Close()
		b, _ := io.ReadAll(resp.Body)
		return string(b)
	}
	master := body(hls)
	if n := strings.Count(master, "#EXT-X-STREAM-INF"); n != 3 {
		t.Fatalf("master has %d variants:\n%s", n, master)
	}
	base := strings.TrimSuffix(hls, "master.m3u8")
	for _, v := range []string{"240p", "480p", "720p"} {
		pl := body(base + v + "/index.m3u8")
		if !strings.Contains(pl, "seg_000.ts") || !strings.Contains(pl, "#EXT-X-ENDLIST") {
			t.Errorf("%s playlist:\n%s", v, pl)
		}
		if len(body(base+v+"/seg_000.ts")) == 0 {
			t.Errorf("%s: empty segment", v)
		}
	}
	if len(body(preview)) == 0 {
		t.Fatal("empty preview")
	}

	// Ҷавоби API: майдонҳо дар рӯйхат.
	list := []gin.H{{"_id": rid}, {"_id": "nope"}}
	attachReelPlayback(list)
	if list[0]["hlsUrl"] != hls || list[0]["renditionsReady"] != true || list[0]["previewUrl"] != preview {
		t.Fatalf("attach: %v", list[0])
	}
	if list[1]["hlsUrl"] != "" || list[1]["renditionsReady"] != false {
		t.Fatalf("attach default: %v", list[1])
	}
}

func TestRenditionWorkerRetriesAndSkips(t *testing.T) {
	pool := adsTestDB(t)
	fail := true
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.HasSuffix(r.URL.Path, "redir.mp4") {
			http.Redirect(w, r, "http://169.254.169.254/latest/meta-data", http.StatusFound)
			return
		}
		if strings.HasSuffix(r.URL.Path, "gone.mp4") {
			http.NotFound(w, r)
			return
		}
		if fail {
			http.Error(w, "boom", http.StatusBadGateway)
		}
	}))
	defer srv.Close()
	dir := t.TempDir()
	t.Setenv("GIN_MODE", "debug")
	t.Setenv("CF_ACCOUNT_ID", "")
	t.Setenv("MEDIA_LOCAL_DIR", dir)
	t.Setenv("MEDIA_LOCAL_PUBLIC_URL", srv.URL)
	t.Setenv("MEDIA_ALLOWED_HOSTS", strings.TrimPrefix(srv.URL, "http://"))
	t.Setenv("MEDIA_ALLOW_HTTP", "1")

	ctx := context.Background()
	uid := adsUser(t, pool)
	mk := func(u string) string {
		var id string
		if err := pool.QueryRow(ctx, `INSERT INTO reels(user_id, video_url) VALUES($1,$2) RETURNING id`,
			uid, u).Scan(&id); err != nil {
			t.Fatal(err)
		}
		t.Cleanup(func() { pool.Exec(ctx, `DELETE FROM reels WHERE id=$1`, id) })
		return id
	}

	// 502 → хатои муваққатӣ: кӯшиши навбатӣ баъд аз 1 дақиқа.
	r1 := mk(srv.URL + "/flaky.mp4")
	err := processRendition(&rendJob{reelID: r1, attempts: 1})
	var skip *rendSkip
	if err == nil || errors.As(err, &skip) {
		t.Fatalf("502 should be retryable error, got %v", err)
	}
	EnqueueReelRendition(ctx, r1, srv.URL+"/flaky.mp4")
	markRendition(r1, "pending", err.Error(), rendRetryDelay(1))
	var wait float64
	pool.QueryRow(ctx, `SELECT EXTRACT(EPOCH FROM next_attempt_at - NOW()) FROM reel_renditions WHERE reel_id=$1`, r1).Scan(&wait)
	if wait < 50 || wait > 70 {
		t.Fatalf("next attempt in %.0fs, want ~60s", wait)
	}

	// 404 → «skipped», бе такрор.
	r2 := mk(srv.URL + "/gone.mp4")
	if err := processRendition(&rendJob{reelID: r2, attempts: 1}); !errors.As(err, &skip) {
		t.Fatalf("404 should skip, got %v", err)
	}
	// Redirect ба суроғаи бегона пайравӣ намешавад.
	r4 := mk(srv.URL + "/redir.mp4")
	if err := processRendition(&rendJob{reelID: r4, attempts: 1}); err == nil ||
		!strings.Contains(err.Error(), "redirect not allowed") {
		t.Fatalf("redirect to foreign host followed: %v", err)
	}
	// Ҳамчунин суроғаи бегона (redirect ҳам) ҳеҷ гоҳ гирифта намешавад.
	r3 := mk("https://evil.example/x.mp4")
	if err := processRendition(&rendJob{reelID: r3, attempts: 1}); !errors.As(err, &skip) {
		t.Fatalf("foreign host should skip, got %v", err)
	}
}
