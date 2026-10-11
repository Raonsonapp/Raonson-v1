package handlers

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"raonson/db"
	"raonson/renditions"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Нусхаҳои HLS-и Reels — пахши бе «шах шудан» дар интернети суст.
//
//  CreateReel реелро ФАВРАН нашр мекунад ва танҳо сатре ба навбат
//  (reel_renditions) илова мекунад. Коргари фонӣ (1–2 ҳамзамон):
//    1. видеоро ТАНҲО аз анбори худамон мегирад (mediaHostAllowed);
//    2. агар MP4 moov-ро дар охир дошта бошад — бе рамзгузорӣ remux
//       мекунад ва video_url-ро ба нусхаи +faststart иваз мекунад;
//    3. HLS (240p/480p/720p, сегментҳои 2 с) + preview.mp4 (2 с) месозад;
//    4. ба reels/<id>/hls/<stamp>/… бор мекунад ва hls_url, preview_url,
//       renditions_ready-ро дар reels менависад.
//  Хато → такрор бо таъхири афзоянда (1 → 5 → 25 дақиқа), баъд failed.
//  Reel-ҳои кӯҳна бо video_url/video_url_low кор мекунанд; барои онҳо
//  POST /admin/reels/renditions/backfill?limit=N.
// ══════════════════════════════════════════════════════════════════

const (
	rendMaxAttempts = 3
	rendMaxBytes    = 200 << 20
	rendStaleAfter  = 20 * time.Minute // «processing»-и бесоҳиб (сервер афтод)
	rendPoll        = 15 * time.Second
)

var (
	rendWake    = make(chan struct{}, 1)
	rendStarted sync.Once
	rendRunning bool
	// Сервер ба суроғаҳои бегона намеравад — ҳатто тавассути redirect.
	rendHTTP = &http.Client{
		Timeout: 3 * time.Minute,
		CheckRedirect: func(req *http.Request, via []*http.Request) error {
			if len(via) >= 3 || !mediaHostAllowed(req.URL.String()) {
				return errors.New("redirect not allowed")
			}
			return nil
		},
	}
)

// ── анбор: R2 ё (танҳо дар dev) папкаи маҳаллӣ ───────────────────

type mediaStore interface {
	Put(ctx context.Context, key, file, contentType string) (string, error)
}

type r2Store struct{}

func (r2Store) Put(ctx context.Context, key, file, contentType string) (string, error) {
	f, err := os.Open(file)
	if err != nil {
		return "", err
	}
	defer f.Close()
	st, err := f.Stat()
	if err != nil {
		return "", err
	}
	n := st.Size()
	_, err = getR2Client().PutObject(ctx, &s3.PutObjectInput{
		Bucket:        aws.String(r2Bucket()),
		Key:           aws.String(key),
		Body:          f,
		ContentType:   aws.String(contentType),
		ContentLength: &n,
		// Роҳ беназир аст (stamp) — ҳамеша immutable.
		CacheControl: aws.String("public, max-age=31536000, immutable"),
	})
	if err != nil {
		return "", err
	}
	return strings.TrimRight(r2PublicURL(), "/") + "/" + key, nil
}

type localStore struct{ dir, base string }

func (s localStore) Put(_ context.Context, key, file, _ string) (string, error) {
	dst := filepath.Join(s.dir, filepath.FromSlash(key))
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return "", err
	}
	in, err := os.Open(file)
	if err != nil {
		return "", err
	}
	defer in.Close()
	out, err := os.Create(dst)
	if err != nil {
		return "", err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return "", err
	}
	if err := out.Close(); err != nil {
		return "", err
	}
	return s.base + "/" + key, nil
}

// localMedia — анбори маҳаллӣ барои санҷиш (MEDIA_LOCAL_DIR +
// MEDIA_LOCAL_PUBLIC_URL). Дар release ҳеҷ гоҳ фаъол намешавад.
func localMedia() (localStore, bool) {
	dir := os.Getenv("MEDIA_LOCAL_DIR")
	base := strings.TrimRight(os.Getenv("MEDIA_LOCAL_PUBLIC_URL"), "/")
	if dir == "" || base == "" || os.Getenv("GIN_MODE") == "release" {
		return localStore{}, false
	}
	return localStore{dir: dir, base: base}, true
}

// LocalMediaEnabled — main роҳи /media-local-ро танҳо он гоҳ мекушояд.
func LocalMediaEnabled() bool { _, ok := localMedia(); return ok }

func activeMediaStore() mediaStore {
	if ok, _ := r2Configured(); ok {
		return r2Store{}
	}
	if s, ok := localMedia(); ok {
		return s
	}
	return nil
}

// GET /media-local/*path — танҳо dev (ниг. localMedia).
func ServeLocalMedia(c *gin.Context) {
	s, ok := localMedia()
	if !ok {
		c.Status(http.StatusNotFound)
		return
	}
	rel := path.Clean("/" + c.Param("path"))
	full := filepath.Join(s.dir, filepath.FromSlash(rel))
	if !strings.HasPrefix(full, filepath.Clean(s.dir)+string(os.PathSeparator)) {
		c.Status(http.StatusNotFound)
		return
	}
	if st, err := os.Stat(full); err != nil || st.IsDir() {
		c.Status(http.StatusNotFound)
		return
	}
	if ct := renditions.ContentType(full); ct != "application/octet-stream" {
		c.Header("Content-Type", ct)
	}
	http.ServeFile(c.Writer, c.Request, full)
}

// ── навбат ───────────────────────────────────────────────────────

// EnqueueReelRendition — сатр ба навбат; ҳеҷ гоҳ CreateReel-ро бозмедорад.
//
// Суроғаи берунӣ (Aparat/YouTube ва ғ.) ба навбат намеояд.
func EnqueueReelRendition(ctx context.Context, reelID, src string) bool {
	if db.Pool == nil || reelID == "" || !mediaHostAllowed(src) {
		return false
	}
	ct, err := db.Pool.Exec(ctx, `
		INSERT INTO reel_renditions(reel_id, source_url) VALUES($1,$2)
		ON CONFLICT (reel_id) DO NOTHING`, reelID, src)
	if err != nil {
		log.Printf("[renditions] enqueue %s: %v", reelID, err)
		return false
	}
	wakeRenditions()
	return ct.RowsAffected() > 0
}

func wakeRenditions() {
	select {
	case rendWake <- struct{}{}:
	default:
	}
}

// rendRetryDelay — 1, 5, 25 дақиқа… (то 2 соат). Ҳеҷ гоҳ ҳалқаи тез.
func rendRetryDelay(attempts int) time.Duration {
	d := time.Minute
	for i := 1; i < attempts; i++ {
		d *= 5
		if d >= 2*time.Hour {
			return 2 * time.Hour
		}
	}
	return d
}

func envIntRange(key string, def, lo, hi int) int {
	return envIntRangeStr(os.Getenv(key), def, lo, hi)
}

func rendOptions() renditions.Options {
	return renditions.Options{
		Threads: envIntRange("RENDITION_FFMPEG_THREADS", 2, 1, 8),
		Preset:  os.Getenv("RENDITION_PRESET"),
		Nice:    true,
	}
}

// StartRenditionWorkers — коргарони фонӣ (RENDITION_WORKERS: 1..2).
func StartRenditionWorkers() {
	rendStarted.Do(func() {
		if os.Getenv("RENDITIONS_DISABLED") == "1" {
			log.Println("[renditions] хомӯш (RENDITIONS_DISABLED=1)")
			return
		}
		if !renditions.Available(rendOptions()) {
			log.Println("[renditions] ffmpeg/ffprobe нест — HLS сохта намешавад (Reels бо MP4 кор мекунанд)")
			return
		}
		if activeMediaStore() == nil {
			log.Println("[renditions] анбор танзим нашудааст — HLS сохта намешавад")
			return
		}
		n := envIntRange("RENDITION_WORKERS", 1, 1, 2)
		rendRunning = true
		for i := 0; i < n; i++ {
			go renditionWorker(fmt.Sprintf("w%d", i))
		}
		log.Printf("[renditions] %d коргар фаъол", n)
	})
}

type rendJob struct {
	reelID, source string
	attempts       int
}

func claimRendition(ctx context.Context) (*rendJob, error) {
	var j rendJob
	err := db.Pool.QueryRow(ctx, `
		UPDATE reel_renditions SET status='processing', attempts=attempts+1,
		       locked_at=NOW(), updated_at=NOW()
		WHERE reel_id = (
		  SELECT reel_id FROM reel_renditions
		  WHERE (status='pending' AND next_attempt_at <= NOW())
		     OR (status='processing' AND locked_at < NOW() - make_interval(secs => $1))
		  ORDER BY next_attempt_at LIMIT 1
		  FOR UPDATE SKIP LOCKED)
		RETURNING reel_id, source_url, attempts`, rendStaleAfter.Seconds()).
		Scan(&j.reelID, &j.source, &j.attempts)
	if err != nil {
		return nil, err
	}
	return &j, nil
}

func renditionWorker(name string) {
	// Дар оғози сервер ба API фурсат медиҳем.
	time.Sleep(3 * time.Second)
	for {
		j, err := claimRendition(context.Background())
		if err != nil {
			select {
			case <-rendWake:
			case <-time.After(rendPoll):
			}
			continue
		}
		if j.attempts > rendMaxAttempts {
			// «processing»-и бесоҳиб, ки кӯшишҳояш тамом шудаанд.
			markRendition(j.reelID, "failed", "attempts exhausted", 0)
			continue
		}
		start := time.Now()
		perr := processRendition(j)
		if perr == nil {
			log.Printf("[renditions] %s: reel %s тайёр (%s)", name, j.reelID, time.Since(start).Round(time.Millisecond))
			continue
		}
		var skip *rendSkip
		switch {
		case errors.As(perr, &skip):
			markRendition(j.reelID, "skipped", perr.Error(), 0)
		case j.attempts >= rendMaxAttempts:
			markRendition(j.reelID, "failed", perr.Error(), 0)
		default:
			markRendition(j.reelID, "pending", perr.Error(), rendRetryDelay(j.attempts))
		}
		log.Printf("[renditions] %s: reel %s (кӯшиши %d): %v", name, j.reelID, j.attempts, perr)
	}
}

// rendSkip — коркард маъно надорад (на хато): такрор намешавад.
type rendSkip struct{ why string }

func (e *rendSkip) Error() string { return e.why }

func markRendition(id, status, msg string, retryIn time.Duration) {
	if len(msg) > 500 {
		msg = msg[:500]
	}
	db.Pool.Exec(context.Background(), `
		UPDATE reel_renditions SET status=$2, last_error=$3,
		       next_attempt_at=NOW() + make_interval(secs => $4),
		       locked_at=NULL, updated_at=NOW(),
		       finished_at=CASE WHEN $2 IN ('failed','skipped') THEN NOW() ELSE finished_at END
		WHERE reel_id=$1`, id, status, msg, retryIn.Seconds())
}

func rendTimeout() time.Duration {
	return time.Duration(envIntRange("RENDITION_TIMEOUT_SEC", 600, 60, 3600)) * time.Second
}

// fetchOwnMedia — файл ТАНҲО аз анбори худамон, бо ҳадди ҳаҷм.
func fetchOwnMedia(ctx context.Context, src, dst string) error {
	if !mediaHostAllowed(src) {
		return &rendSkip{"source not on our storage"}
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, src, nil)
	if err != nil {
		return err
	}
	resp, err := rendHTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusGone {
		return &rendSkip{fmt.Sprintf("source gone (%d)", resp.StatusCode)}
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("source status %d", resp.StatusCode)
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	n, err := io.Copy(f, io.LimitReader(resp.Body, rendMaxBytes+1))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		return err
	}
	if n > rendMaxBytes {
		return &rendSkip{"source too large"}
	}
	return nil
}

func rendStamp() string {
	b := make([]byte, 4)
	rand.Read(b)
	return strconv.FormatInt(time.Now().Unix(), 36) + hex.EncodeToString(b)
}

func processRendition(j *rendJob) error {
	ctx, cancel := context.WithTimeout(context.Background(), rendTimeout())
	defer cancel()
	store := activeMediaStore()
	if store == nil {
		return errors.New("storage not configured")
	}
	var videoURL, videoLow string
	if err := db.Pool.QueryRow(ctx,
		`SELECT video_url, COALESCE(video_url_low,'') FROM reels WHERE id=$1`, j.reelID).
		Scan(&videoURL, &videoLow); err != nil {
		return &rendSkip{"reel not found"}
	}
	tmp, err := os.MkdirTemp("", "raonson-rend-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)
	o := rendOptions()

	src := filepath.Join(tmp, "src")
	if err := fetchOwnMedia(ctx, videoURL, src); err != nil {
		return err
	}
	info, err := renditions.Probe(ctx, o, src)
	if err != nil {
		return &rendSkip{"not a video: " + err.Error()}
	}
	if max := envIntRange("RENDITION_MAX_SECONDS", 600, 10, 7200); info.Duration > float64(max) {
		return &rendSkip{fmt.Sprintf("too long (%.0fs)", info.Duration)}
	}
	stamp := rendStamp()
	prefix := "reels/" + j.reelID + "/hls/" + stamp + "/"

	// ── +faststart: MP4-и асл ва нусхаи паст ──
	mp4Prefix := "reels/" + j.reelID + "/mp4/" + stamp + "/"
	ensureFaststart(ctx, o, store, j.reelID, "video_url", videoURL, src, mp4Prefix+"src.mp4")
	if videoLow != "" && videoLow != videoURL && mediaHostAllowed(videoLow) {
		low := filepath.Join(tmp, "low")
		if fetchOwnMedia(ctx, videoLow, low) == nil {
			ensureFaststart(ctx, o, store, j.reelID, "video_url_low", videoLow, low, mp4Prefix+"src_low.mp4")
		}
	}

	out := filepath.Join(tmp, "out")
	res, err := renditions.Transcode(ctx, o, src, out)
	if err != nil {
		return err
	}
	// Аввал сегментҳо, баъд плейлистҳо, охир master: плеер ҳеҷ гоҳ
	// суроғаеро намебинад, ки ҳанӯз бор нашудааст.
	ordered := make([]string, 0, len(res.Files))
	var lists []string
	for _, f := range res.Files {
		if strings.HasSuffix(f, ".m3u8") {
			if f != res.Master {
				lists = append(lists, f)
			}
			continue
		}
		ordered = append(ordered, f)
	}
	ordered = append(append(ordered, lists...), res.Master)
	urls := map[string]string{}
	for _, f := range ordered {
		u, err := store.Put(ctx, prefix+f, filepath.Join(out, filepath.FromSlash(f)), renditions.ContentType(f))
		if err != nil {
			return fmt.Errorf("upload %s: %w", f, err)
		}
		urls[f] = u
	}
	ct, err := db.Pool.Exec(ctx, `
		UPDATE reels SET hls_url=$2, hls_low_url=$3, preview_url=$4, renditions_ready=TRUE
		WHERE id=$1`, j.reelID, urls[res.Master], urls[res.Low], urls[res.Preview])
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return &rendSkip{"reel deleted during processing"}
	}
	names := make([]string, 0, len(res.Variants))
	for _, v := range res.Variants {
		names = append(names, v.Name)
	}
	db.Pool.Exec(ctx, `
		UPDATE reel_renditions SET status='ready', last_error='', locked_at=NULL,
		       variants=$2, duration_sec=$3, updated_at=NOW(), finished_at=NOW()
		WHERE reel_id=$1`, j.reelID, strings.Join(names, ","), info.Duration)
	return nil
}

// ensureFaststart — агар moov дар охир бошад, бе рамзгузорӣ remux карда,
// сутунро ба нусхаи нав иваз мекунад. Хато → ҳеҷ чиз иваз намешавад.
func ensureFaststart(ctx context.Context, o renditions.Options, store mediaStore,
	reelID, column, oldURL, file, key string) {
	fast, err := renditions.IsFaststart(file)
	if err != nil || fast {
		return
	}
	fixed := file + ".fast.mp4"
	if err := renditions.Remux(ctx, o, file, fixed); err != nil {
		log.Printf("[renditions] remux %s: %v", reelID, err)
		return
	}
	u, err := store.Put(ctx, key, fixed, "video/mp4")
	if err != nil {
		log.Printf("[renditions] faststart upload %s: %v", reelID, err)
		return
	}
	// column аз рӯйхати сахт аст (на аз корбар).
	if column != "video_url" && column != "video_url_low" {
		return
	}
	db.Pool.Exec(ctx, `UPDATE reels SET `+column+`=$2 WHERE id=$1 AND `+column+`=$3`,
		reelID, u, oldURL)
}

// ── ҷавоби API ───────────────────────────────────────────────────

// attachReelPlayback — hlsUrl / hlsLowUrl / previewUrl / renditionsReady
// ба рӯйхати тайёри reels (як дархост). Холӣ → client бо MP4 бозӣ мекунад.
func attachReelPlayback(reels []gin.H) {
	ids := make([]string, 0, len(reels))
	for _, r := range reels {
		r["hlsUrl"], r["hlsLowUrl"], r["previewUrl"], r["renditionsReady"] = "", "", "", false
		if id, _ := r["_id"].(string); id != "" {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 || db.Pool == nil {
		return
	}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT id, COALESCE(hls_url,''), COALESCE(hls_low_url,''), COALESCE(preview_url,'')
		FROM reels WHERE id = ANY($1) AND COALESCE(renditions_ready,false)`, ids)
	if err != nil {
		return
	}
	defer rows.Close()
	type pb struct{ hls, low, preview string }
	found := map[string]pb{}
	for rows.Next() {
		var id string
		var p pb
		if rows.Scan(&id, &p.hls, &p.low, &p.preview) == nil {
			found[id] = p
		}
	}
	for _, r := range reels {
		if id, _ := r["_id"].(string); id != "" {
			if p, ok := found[id]; ok && p.hls != "" {
				r["hlsUrl"], r["hlsLowUrl"], r["previewUrl"], r["renditionsReady"] = p.hls, p.low, p.preview, true
			}
		}
	}
}

// reelRenditionStatus — "none" | pending | processing | ready | failed | skipped.
func reelRenditionStatus(ctx context.Context, id string) string {
	st := "none"
	if db.Pool != nil {
		db.Pool.QueryRow(ctx, `SELECT status FROM reel_renditions WHERE reel_id=$1`, id).Scan(&st)
	}
	return st
}

// ── admin ────────────────────────────────────────────────────────

// POST /admin/reels/renditions/backfill?limit=50&retryFailed=1
//
// Reel-ҳои кӯҳнаро (навтарин аввал) ба навбат мегузорад. Дар як даъват
// на бештар аз 200 — коргар 1–2 видеоро ҳамзамон коркард мекунад.
func AdminBackfillRenditions(c *gin.Context) {
	limit := envIntRangeStr(c.Query("limit"), 50, 1, 200)
	ctx := c.Request.Context()
	retried := int64(0)
	if c.Query("retryFailed") == "1" {
		ct, _ := db.Pool.Exec(ctx, `
			UPDATE reel_renditions SET status='pending', attempts=0, next_attempt_at=NOW(),
			       last_error='', updated_at=NOW()
			WHERE status='failed'`)
		retried = ct.RowsAffected()
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT r.id, r.video_url FROM reels r
		WHERE COALESCE(r.renditions_ready,false)=FALSE
		  AND COALESCE(r.media_missing,false)=FALSE
		  AND NOT EXISTS (SELECT 1 FROM reel_renditions q WHERE q.reel_id=r.id)
		ORDER BY r.created_at DESC LIMIT $1`, limit*4)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "backfill failed"})
		return
	}
	type cand struct{ id, url string }
	var cands []cand
	for rows.Next() {
		var x cand
		if rows.Scan(&x.id, &x.url) == nil {
			cands = append(cands, x)
		}
	}
	rows.Close()
	queued, skipped := 0, 0
	for _, x := range cands {
		if queued >= limit {
			break
		}
		if EnqueueReelRendition(ctx, x.id, x.url) {
			queued++
		} else {
			skipped++
		}
	}
	c.JSON(http.StatusOK, gin.H{"queued": queued, "skippedExternal": skipped,
		"retriedFailed": retried, "workerRunning": rendRunning})
}

// GET /admin/reels/renditions — ҳолати навбат.
func AdminRenditionStatus(c *gin.Context) {
	counts := gin.H{}
	rows, err := db.Pool.Query(c.Request.Context(),
		`SELECT status, COUNT(*) FROM reel_renditions GROUP BY status`)
	if err == nil {
		for rows.Next() {
			var s string
			var n int
			if rows.Scan(&s, &n) == nil {
				counts[s] = n
			}
		}
		rows.Close()
	}
	var missing int
	db.Pool.QueryRow(c.Request.Context(), `
		SELECT COUNT(*) FROM reels r WHERE COALESCE(r.renditions_ready,false)=FALSE
		  AND NOT EXISTS (SELECT 1 FROM reel_renditions q WHERE q.reel_id=r.id)`).Scan(&missing)
	failed := []gin.H{}
	if fr, err := db.Pool.Query(c.Request.Context(), `
		SELECT reel_id, attempts, COALESCE(last_error,''), updated_at FROM reel_renditions
		WHERE status='failed' ORDER BY updated_at DESC LIMIT 20`); err == nil {
		for fr.Next() {
			var id, msg string
			var n int
			var at time.Time
			if fr.Scan(&id, &n, &msg, &at) == nil {
				failed = append(failed, gin.H{"reelId": id, "attempts": n, "error": msg, "at": at})
			}
		}
		fr.Close()
	}
	c.JSON(http.StatusOK, gin.H{"counts": counts, "notQueued": missing,
		"workerRunning": rendRunning, "recentFailures": failed})
}

func envIntRangeStr(s string, def, lo, hi int) int {
	n, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	if n < lo {
		return lo
	}
	if n > hi {
		return hi
	}
	return n
}
