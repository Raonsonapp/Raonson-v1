package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/moderation"
	"raonson/sockets"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Модератсияи пеш аз нашр — иҷро (enforcement).
//
//  Санҷиш худаш дар package moderation аст. Ин ҷо: чӣ кор кардан бо
//  қарор.
//
//  СИЁСАТ (policy):
//
//    BLOCK  → 403 «Ин мӯҳтаво қоидаҳои Raonson-ро вайрон мекунад».
//             Чизе сабт намешавад. Дар навбати admin сатри «blocked»
//             (аудит) мемонад. 18+ ва кӯдакон → огоҳӣ (strike).
//             Дашном ва линки вирусӣ рад мешаванд, вале strike не.
//             Медиаи боргузоштаи ҲАМИН корбар, ки сабаби манъ буд ва
//             дар ҷои дигар истифода нашудааст, аз R2 нест мешавад.
//
//    REVIEW (шубҳанок: хол байни ҳадҳо, provider хато дод, калимаи
//             «суст», суроғаи бегонаи медиа) →
//             пост / Reel / сторис / шарҳ: ПИНҲОН сабт мешавад то admin
//             тасдиқ кунад (муаллиф онро мебинад, дигарон не);
//             паёми чат ва bio: фиристода мешавад + ба навбати admin
//             (паёми хусусӣ «пинҳон» маъно надорад; паёмро рад кардан
//             барои шубҳа аз ҳад сахт аст).
//
//    UNSCANNED (provider-и расм танзим нашудааст ё ffmpeg нест) →
//             иҷозат дода мешавад ва ба навбати admin («санҷиданашуда»)
//             меравад. Дар log-и оғоз инро возеҳ мегӯяд.
//
//  STRIKES: 3 огоҳӣ дар 30 рӯз → маҳдудкунии худкор 7 рӯз
//  (users.suspended_until): ворид шудан ва хондан мумкин, нашр — не.
//  Кӯдакон (severe) → фавран маҳдуд + admin. Бани ДОИМӢ танҳо аз
//  ҷониби admin — хатои classifier набояд ҳисобро абадан бандад.
//  Ҳамаи рақамҳо аз env: MODERATION_STRIKE_LIMIT, _STRIKE_WINDOW_DAYS,
//  _SUSPEND_DAYS.
// ══════════════════════════════════════════════════════════════════

// ContentBlockedMessage — ҳамон матн дар ҳамаи экранҳо.
const ContentBlockedMessage = "Ин мӯҳтаво қоидаҳои Raonson-ро вайрон мекунад"

func init() {
	// SSRF: медиа танҳо аз анбори худи мо гирифта мешавад.
	moderation.SetMediaFetchAllowed(mediaHostAllowed)
	// Роҳи кӯҳнаи сокет (`chat:send`) ҳам ҳамон санҷишро мегузарад.
	sockets.ModerateChatText = func(uid, text string) bool {
		ok, _ := moderateQuiet(uid, "message", text)
		return ok
	}
}

func modEnvInt(k string, def int) int {
	if v, err := strconv.Atoi(strings.TrimSpace(os.Getenv(k))); err == nil && v > 0 {
		return v
	}
	return def
}

func strikeLimit() int      { return modEnvInt("MODERATION_STRIKE_LIMIT", 3) }
func strikeWindowDays() int { return modEnvInt("MODERATION_STRIKE_WINDOW_DAYS", 30) }
func suspendDays() int      { return modEnvInt("MODERATION_SUSPEND_DAYS", 7) }

// modMedia — як файли медиа.
type modMedia struct {
	URL   string
	Video bool
}

// modRequest — он чи нашр шудан мехоҳад.
type modRequest struct {
	Surface string // post, reel, story, comment, reel_comment, message, group_message, bio, ...
	Texts   []string
	Media   []modMedia
	// AI — матн ба provider-и AI ҳам фиристода шавад (мӯҳтавои оммавӣ).
	AI bool
}

// modOutcome — натиҷа барои даъваткунанда.
type modOutcome struct {
	Verdict moderation.Verdict
	// Hold — мӯҳтаво пинҳон сабт шавад то тасдиқи admin.
	Hold bool
	// Queue — баъди сохтан ба навбати admin гузошта шавад.
	Queue bool
}

func (r modRequest) joinedText() string {
	parts := []string{}
	for _, t := range r.Texts {
		if strings.TrimSpace(t) != "" {
			parts = append(parts, t)
		}
	}
	return clampRunes(strings.Join(parts, "\n"), 1000)
}

func (r modRequest) firstMedia() (string, string) {
	for _, m := range r.Media {
		if m.URL != "" {
			if m.Video {
				return m.URL, "video"
			}
			return m.URL, "image"
		}
	}
	return "", ""
}

func (r modRequest) hash() string {
	h := sha256.New()
	for _, t := range r.Texts {
		h.Write([]byte(strings.TrimSpace(t)))
		h.Write([]byte{0})
	}
	for _, m := range r.Media {
		h.Write([]byte(m.URL))
		h.Write([]byte{1})
	}
	return hex.EncodeToString(h.Sum(nil))
}

// ── маҳдудкунӣ ────────────────────────────────────────────────────

// suspendedUntil — то кай корбар нашр карда наметавонад (nil — маҳдуд нест).
func suspendedUntil(ctx context.Context, uid string) *time.Time {
	var t *time.Time
	if db.Pool == nil || uid == "" {
		return nil
	}
	db.Pool.QueryRow(ctx,
		`SELECT suspended_until FROM users WHERE id=$1 AND suspended_until > NOW()`, uid).Scan(&t)
	return t
}

func suspendedMessage(t time.Time) string {
	return fmt.Sprintf("Ҳисоби шумо то %s барои нашр маҳдуд шудааст, зеро мӯҳтаво "+
		"қоидаҳои Raonson-ро вайрон кард. Хондан ва дидан мумкин аст.",
		t.In(time.FixedZone("TJT", 5*3600)).Format("02.01.2006 15:04"))
}

// ensureNotSuspended — 403, агар корбар муваққатан маҳдуд бошад.
func ensureNotSuspended(c *gin.Context, uid string) bool {
	if t := suspendedUntil(c.Request.Context(), uid); t != nil {
		c.JSON(http.StatusForbidden, gin.H{
			"message":        suspendedMessage(*t),
			"code":           "account_suspended",
			"suspendedUntil": t.UTC().Format(time.RFC3339),
		})
		return false
	}
	return true
}

// ── санҷиш ────────────────────────────────────────────────────────

// cachedMediaVerdicts — қарорҳое, ки ҳангоми боргузорӣ гирифта шуданд.
func cachedMediaVerdicts(ctx context.Context, urls []string) map[string]moderation.Verdict {
	out := map[string]moderation.Verdict{}
	if len(urls) == 0 || db.Pool == nil {
		return out
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT url, verdict, held, categories, score, provider
		FROM media_uploads WHERE url = ANY($1)`, urls)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var u, verdict, provider string
		var held bool
		var cats []string
		var score float32
		if rows.Scan(&u, &verdict, &held, &cats, &score, &provider) != nil {
			continue
		}
		v := moderation.Verdict{Categories: cats, Score: float64(score), Provider: provider,
			MediaCaused: true, Reason: "upload-verdict"}
		switch verdict {
		case "block":
			v.Action = moderation.Block
		case "review":
			v.Action = moderation.Review
			v.Unscanned = !held
		default:
			v.Action = moderation.Allow
		}
		out[u] = v
	}
	return out
}

// evaluate — ҳамаи матн ва медиаро месанҷад.
func evaluate(ctx context.Context, r modRequest) moderation.Verdict {
	items := []moderation.Item{}
	for _, t := range r.Texts {
		if strings.TrimSpace(t) != "" {
			items = append(items, moderation.Item{Kind: moderation.KindText, Text: t, AI: r.AI})
		}
	}
	urls := []string{}
	for _, m := range r.Media {
		if m.URL != "" {
			urls = append(urls, m.URL)
		}
	}
	cached := cachedMediaVerdicts(ctx, urls)
	v := moderation.Verdict{Action: moderation.Allow}
	seen := map[string]bool{}
	for _, m := range r.Media {
		if m.URL == "" || seen[m.URL] {
			continue
		}
		seen[m.URL] = true
		if cv, ok := cached[m.URL]; ok {
			v = moderation.Merge(v, cv)
			continue
		}
		kind := moderation.KindImage
		if m.Video {
			kind = moderation.KindVideo
		}
		items = append(items, moderation.Item{Kind: kind, URL: m.URL})
	}
	if v.Action == moderation.Block {
		return v
	}
	cctx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	return moderation.Merge(v, moderation.CheckAll(cctx, items...))
}

// screenContent — санҷиши маҳдудкунӣ + мӯҳтаво.
//
// ok=false — ҷавоб аллакай навишта шуд (403), даъваткунанда бояд
// фавран баргардад.
func screenContent(c *gin.Context, uid string, r modRequest) (modOutcome, bool) {
	if !ensureNotSuspended(c, uid) {
		return modOutcome{}, false
	}
	v := evaluate(c.Request.Context(), r)
	if v.Action == moderation.Block {
		until := recordBlock(c.Request.Context(), uid, r, v)
		body := gin.H{
			"message":    ContentBlockedMessage,
			"code":       "content_blocked",
			"categories": v.Categories,
		}
		if until != nil {
			body["suspendedUntil"] = until.UTC().Format(time.RFC3339)
		}
		c.JSON(http.StatusForbidden, body)
		return modOutcome{Verdict: v}, false
	}
	out := modOutcome{Verdict: v}
	if v.Action == moderation.Review {
		out.Queue = true
		out.Hold = !v.Unscanned
	}
	return out, true
}

// moderateQuiet — бе ҷавоби HTTP (сокет, роҳҳои дохилӣ).
func moderateQuiet(uid, surface, text string) (bool, moderation.Verdict) {
	ctx := context.Background()
	if suspendedUntil(ctx, uid) != nil {
		return false, moderation.Verdict{Action: moderation.Block}
	}
	r := modRequest{Surface: surface, Texts: []string{text}}
	v := evaluate(ctx, r)
	if v.Action == moderation.Block {
		recordBlock(ctx, uid, r, v)
		return false, v
	}
	if v.Action == moderation.Review {
		queueReview(uid, r, "", modOutcome{Verdict: v, Queue: true}, false)
	}
	return true, v
}

// ── навбати admin ─────────────────────────────────────────────────

func insertQueue(ctx context.Context, uid, surface, target, text, mediaURL, mediaKind string,
	v moderation.Verdict, action string, held bool, status string) int64 {
	if db.Pool == nil {
		return 0
	}
	cats := v.Categories
	if cats == nil {
		cats = []string{}
	}
	var id int64
	err := db.Pool.QueryRow(ctx, `
		INSERT INTO moderation_queue(user_id, surface, target_id, text, media_url, media_kind,
		    categories, score, provider, reason, action, held, status)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id`,
		uid, surface, target, text, mediaURL, mediaKind, cats, v.Score,
		v.Provider, clampRunes(v.Reason, 200), action, held, status).Scan(&id)
	if err != nil {
		log.Printf("[moderation] навбат сабт нашуд: %v", err)
	}
	return id
}

// queueReview — мӯҳтавои сохташударо ба навбати admin мегузорад.
// held — оё мӯҳтаво воқеан пинҳон сабт шуд.
func queueReview(uid string, r modRequest, targetID string, out modOutcome, held bool) {
	if !out.Queue {
		return
	}
	action := "review"
	if out.Verdict.Unscanned {
		action = "unscanned"
	}
	murl, mkind := r.firstMedia()
	insertQueue(context.Background(), uid, r.Surface, targetID, r.joinedText(), murl, mkind,
		out.Verdict, action, held, "pending")
	if out.Verdict.Unscanned {
		log.Printf("[moderation] %s %s: медиа САНҶИДА НАШУД (%s) — иҷозат дода шуд ва ба навбати admin рафт",
			r.Surface, targetID, out.Verdict.Reason)
	} else {
		log.Printf("[moderation] %s %s: шубҳанок (%v, %s) — held=%v, ба навбати admin",
			r.Surface, targetID, out.Verdict.Categories, out.Verdict.Reason, held)
	}
}

// recordBlock — сабти аудит, strike ва тоза кардани медиа.
// Бармегардонад: то кай корбар ҳоло маҳдуд аст (агар маҳдуд шуда бошад).
func recordBlock(ctx context.Context, uid string, r modRequest, v moderation.Verdict) *time.Time {
	ctx = context.WithoutCancel(ctx)
	murl, mkind := r.firstMedia()
	qid := insertQueue(ctx, uid, r.Surface, "", r.joinedText(), murl, mkind, v, "block", false, "blocked")
	log.Printf("[moderation] BLOCK %s user=%s cats=%v by=%s (%s)",
		r.Surface, uid, v.Categories, v.Provider, v.Reason)
	if v.MediaCaused {
		deleteBlockedMedia(ctx, uid, r.Media)
	}
	if !v.Strikeable() {
		return nil
	}
	return addStrike(ctx, uid, qid, r.Surface, v, r.hash())
}

// addStrike — огоҳӣ; баъди ҳад — маҳдудкунии муваққатӣ.
func addStrike(ctx context.Context, uid string, queueID int64, surface string,
	v moderation.Verdict, contentHash string) *time.Time {
	if db.Pool == nil || uid == "" {
		return nil
	}
	// Такрори ҳамон мӯҳтаво дар 24 соат (навбати офлайн, тугмаи дукарата)
	// огоҳии дуюм НАМЕДИҲАД — вагарна як паём се огоҳӣ мешуд.
	var dup bool
	db.Pool.QueryRow(ctx, `
		SELECT EXISTS(SELECT 1 FROM moderation_strikes
		  WHERE user_id=$1 AND content_hash=$2 AND created_at > NOW() - INTERVAL '24 hours')`,
		uid, contentHash).Scan(&dup)
	if dup {
		return suspendedUntil(ctx, uid)
	}
	cats := v.Categories
	if cats == nil {
		cats = []string{}
	}
	db.Pool.Exec(ctx, `
		INSERT INTO moderation_strikes(user_id, queue_id, surface, categories, severe, content_hash)
		VALUES($1, NULLIF($2,0), $3, $4, $5, $6)`, uid, queueID, surface, cats, v.Severe, contentHash)

	if cur := suspendedUntil(ctx, uid); cur != nil {
		return cur
	}
	if v.Severe {
		return suspendUser(ctx, uid, "Мӯҳтавои ҷинсӣ бо иштироки кӯдакон (санҷиши фаврии admin)", true)
	}
	var n int
	db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM moderation_strikes
		WHERE user_id=$1 AND created_at > NOW() - make_interval(days => $2)`,
		uid, strikeWindowDays()).Scan(&n)
	if n >= strikeLimit() {
		return suspendUser(ctx, uid,
			fmt.Sprintf("%d огоҳӣ дар %d рӯз", n, strikeWindowDays()), false)
	}
	return nil
}

// suspendUser — маҳдудкунии муваққатӣ + сатр дар навбати admin.
func suspendUser(ctx context.Context, uid, reason string, severe bool) *time.Time {
	var until time.Time
	// Соҳиби барнома ва admin-ҳо худкор маҳдуд намешаванд.
	err := db.Pool.QueryRow(ctx, `
		UPDATE users SET suspended_until = NOW() + make_interval(days => $2),
		                 suspension_reason = $3
		WHERE id=$1 AND username<>'raonson' AND COALESCE(role,'user')<>'admin'
		RETURNING suspended_until`, uid, suspendDays(), reason).Scan(&until)
	if err != nil {
		return nil
	}
	cats := []string{"suspension"}
	if severe {
		cats = append(cats, moderation.CatMinors)
	}
	// Хабар ба admin: сатри «suspension» дар САРИ навбати модератсия
	// (ва рақами интизорӣ дар панели admin). Огоҳиномаи телефон
	// ҷудогона фиристода намешавад — қабати огоҳиномаҳо намуди нав
	// намегирад.
	insertQueue(ctx, uid, "account", uid, reason, "", "",
		moderation.Verdict{Categories: cats, Severe: severe, Reason: reason},
		"suspension", false, "pending")
	log.Printf("[moderation] ⚠️ корбар %s то %s маҳдуд шуд: %s", uid, until.Format(time.RFC3339), reason)
	mw.InvalidateUserCache(uid)
	return &until
}

// ── нест кардани медиаи манъшуда аз R2 ─────────────────────────────

var r2DeleteObject = func(ctx context.Context, key string) error {
	_, err := getR2Client().DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(r2Bucket()), Key: aws.String(key)})
	return err
}

// r2KeyOf — калиди объект, агар суроға дар анбори мо бошад.
func r2KeyOf(raw string) string {
	base := strings.TrimRight(os.Getenv("CF_R2_PUBLIC_URL"), "/")
	if base == "" || !strings.HasPrefix(raw, base+"/") {
		return ""
	}
	return strings.TrimPrefix(raw, base+"/")
}

// deleteBlockedMedia — файли манъшударо нест мекунад, ТАНҲО агар:
// худи ҳамин корбар онро бор карда бошад (media_uploads) ва он дар
// ҳеҷ пост/Reel/сторис/паём истифода нашуда бошад. Вагарна касе
// метавонист суроғаи акси бегонаро фиристода, онро нест кунонад.
func deleteBlockedMedia(ctx context.Context, uid string, media []modMedia) {
	if ok, _ := r2Configured(); !ok || db.Pool == nil {
		return
	}
	for _, m := range media {
		key := r2KeyOf(m.URL)
		if key == "" {
			continue
		}
		var mine, used bool
		db.Pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM media_uploads WHERE url=$1 AND user_id=$2)`,
			m.URL, uid).Scan(&mine)
		if !mine {
			continue
		}
		db.Pool.QueryRow(ctx, `SELECT
			EXISTS(SELECT 1 FROM post_media WHERE url=$1) OR
			EXISTS(SELECT 1 FROM reels WHERE video_url=$1 OR thumbnail_url=$1) OR
			EXISTS(SELECT 1 FROM stories WHERE media_url=$1) OR
			EXISTS(SELECT 1 FROM messages WHERE media_url=$1)`, m.URL).Scan(&used)
		if used {
			continue
		}
		if err := r2DeleteObject(ctx, key); err != nil {
			log.Printf("[moderation] медиаи манъшуда нест нашуд: %v", err)
			continue
		}
		db.Pool.Exec(ctx, `UPDATE media_uploads SET verdict='block' WHERE url=$1`, m.URL)
		log.Printf("[moderation] медиаи манъшуда аз R2 нест шуд: %s", key)
	}
}

// ── санҷиши файл ҳангоми боргузорӣ ─────────────────────────────────

// screenUpload — расм/видеоро ПЕШ аз навиштан ба R2 месанҷад.
// ok=false — 403 аллакай фиристода шуд.
func screenUpload(c *gin.Context, uid string, data []byte, contentType string) (moderation.Verdict, bool) {
	if !strings.HasPrefix(contentType, "image/") && !strings.HasPrefix(contentType, "video/") {
		return moderation.Verdict{Action: moderation.Allow}, true
	}
	if !ensureNotSuspended(c, uid) {
		return moderation.Verdict{}, false
	}
	kind := moderation.KindImage
	if strings.HasPrefix(contentType, "video/") {
		kind = moderation.KindVideo
	}
	v := moderation.Check(c.Request.Context(), moderation.Item{Kind: kind, Data: data})
	if v.Action != moderation.Block {
		return v, true
	}
	sum := sha256.Sum256(data)
	r := modRequest{Surface: "upload"}
	ctx := context.WithoutCancel(c.Request.Context())
	qid := insertQueue(ctx, uid, "upload", "", "", "", string(kind), v, "block", false, "blocked")
	log.Printf("[moderation] BLOCK upload user=%s cats=%v by=%s (%s) — ба R2 навишта НАШУД",
		uid, v.Categories, v.Provider, v.Reason)
	var until *time.Time
	if v.Strikeable() {
		until = addStrike(ctx, uid, qid, r.Surface, v, hex.EncodeToString(sum[:]))
	}
	body := gin.H{"message": ContentBlockedMessage, "error": ContentBlockedMessage,
		"code": "content_blocked", "categories": v.Categories}
	if until != nil {
		body["suspendedUntil"] = until.UTC().Format(time.RFC3339)
	}
	c.JSON(http.StatusForbidden, body)
	return v, false
}

// recordUpload — қарори санҷиш барои файли навишташуда.
func recordUpload(uid, url, contentType string, v moderation.Verdict) {
	if db.Pool == nil || url == "" {
		return
	}
	kind := "image"
	if strings.HasPrefix(contentType, "video/") {
		kind = "video"
	} else if !strings.HasPrefix(contentType, "image/") {
		return
	}
	held := v.Action == moderation.Review && !v.Unscanned
	cats := v.Categories
	if cats == nil {
		cats = []string{}
	}
	db.Pool.Exec(context.Background(), `
		INSERT INTO media_uploads(url, user_id, kind, verdict, held, categories, score, provider)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT (url) DO NOTHING`,
		url, uid, kind, v.Action.String(), held, cats, v.Score, v.Provider)
}

// ── пинҳон кардан / баргардондан аз рӯи навъ ──────────────────────

// holdContent — мӯҳтавои сохташударо то тасдиқи admin пинҳон мекунад.
func holdContent(surface, id string) bool {
	if id == "" {
		return false
	}
	ctx := context.Background()
	var q string
	switch surface {
	case "post":
		q = `UPDATE posts SET hidden=TRUE WHERE id=$1`
	case "reel":
		// Ҳар рӯйхати Reel аллакай `media_missing`-ро филтр мекунад —
		// ҳамон филтр Reel-и интизории санҷишро низ пинҳон мекунад.
		q = `UPDATE reels SET mod_hold=TRUE, media_missing=TRUE WHERE id=$1`
	case "story":
		// Ҳар рӯйхати сторис `expires_at > NOW()`-ро месанҷад. Мӯҳлати
		// аслӣ нигоҳ дошта мешавад; тасдиқ онро аз нав мекушояд.
		q = `UPDATE stories SET mod_hold_until=expires_at, expires_at=NOW() WHERE id=$1`
	case "comment":
		// Шарҳи намоён (таҳрир) аз ҳисоб хориҷ мешавад; тасдиқ онро
		// баргардонда, ҳисобро боз зиёд мекунад.
		tag, err := db.Pool.Exec(ctx, `UPDATE comments SET hidden=TRUE WHERE id=$1 AND COALESCE(hidden,false)=FALSE`, id)
		if err != nil || tag.RowsAffected() == 0 {
			return false
		}
		unpinOnHide(ctx, "comments", id)
		db.Pool.Exec(ctx, `UPDATE posts SET comments_count=GREATEST(comments_count-1,0)
			WHERE id=(SELECT post_id FROM comments WHERE id=$1)`, id)
		return true
	case "reel_comment":
		tag, err := db.Pool.Exec(ctx, `UPDATE reel_comments SET hidden=TRUE WHERE id=$1 AND COALESCE(hidden,false)=FALSE`, id)
		if err != nil || tag.RowsAffected() == 0 {
			return false
		}
		unpinOnHide(ctx, "reel_comments", id)
		db.Pool.Exec(ctx, `UPDATE reels SET comments_count=GREATEST(comments_count-1,0)
			WHERE id=(SELECT reel_id FROM reel_comments WHERE id=$1)`, id)
		return true
	default:
		return false
	}
	tag, err := db.Pool.Exec(ctx, q, id)
	return err == nil && tag.RowsAffected() > 0
}

// releaseContent — admin тасдиқ кард: мӯҳтаво намоён мешавад.
func releaseContent(surface, id string) {
	ctx := context.Background()
	switch surface {
	case "post":
		db.Pool.Exec(ctx, `UPDATE posts SET hidden=FALSE WHERE id=$1 AND COALESCE(archived,false)=FALSE`, id)
	case "reel":
		db.Pool.Exec(ctx, `UPDATE reels SET mod_hold=FALSE, media_missing=FALSE WHERE id=$1 AND mod_hold=TRUE`, id)
	case "story":
		db.Pool.Exec(ctx, `UPDATE stories SET expires_at=NOW() + INTERVAL '24 hours', mod_hold_until=NULL
			WHERE id=$1 AND mod_hold_until IS NOT NULL`, id)
	case "comment":
		tag, _ := db.Pool.Exec(ctx, `UPDATE comments SET hidden=FALSE WHERE id=$1 AND hidden=TRUE`, id)
		if tag.RowsAffected() > 0 {
			db.Pool.Exec(ctx, `UPDATE posts SET comments_count=comments_count+1
				WHERE id=(SELECT post_id FROM comments WHERE id=$1)`, id)
		}
	case "reel_comment":
		tag, _ := db.Pool.Exec(ctx, `UPDATE reel_comments SET hidden=FALSE WHERE id=$1 AND hidden=TRUE`, id)
		if tag.RowsAffected() > 0 {
			db.Pool.Exec(ctx, `UPDATE reels SET comments_count=comments_count+1
				WHERE id=(SELECT reel_id FROM reel_comments WHERE id=$1)`, id)
		}
	}
	mw.BumpContentEpoch()
}

// removeContent — admin нест кард (нарм: баргардондан мумкин аст).
func removeContent(surface, id string) {
	if id == "" {
		return
	}
	ctx := context.Background()
	switch surface {
	case "post", "caption_edit_post":
		db.Pool.Exec(ctx, `UPDATE posts SET hidden=TRUE, archived=TRUE WHERE id=$1`, id)
	case "reel", "caption_edit_reel":
		db.Pool.Exec(ctx, `UPDATE reels SET mod_hold=TRUE, media_missing=TRUE WHERE id=$1`, id)
	case "story":
		db.Pool.Exec(ctx, `UPDATE stories SET expires_at=NOW(), mod_hold_until=NULL WHERE id=$1`, id)
		// Сториси несткарда дар актуалӣ ҳам намемонад.
		dropStoryFromHighlights(ctx, id)
	case "comment", "reel_comment":
		holdContent(surface, id)
	case "message", "group_message":
		db.Pool.Exec(ctx, `UPDATE messages SET is_deleted=TRUE, text='', media_url=NULL, updated_at=NOW() WHERE id=$1`, id)
	case "bio":
		db.Pool.Exec(ctx, `UPDATE users SET bio='', website='' WHERE id=$1`, id)
	}
	mw.BumpContentEpoch()
}

// holdIfNeeded — пас аз сохтан: пинҳон + навбат. Бармегардонад held.
func holdIfNeeded(uid string, r modRequest, targetID string, out modOutcome) bool {
	if !out.Queue {
		return false
	}
	held := out.Hold && holdContent(r.Surface, targetID)
	queueReview(uid, r, targetID, out, held)
	return held
}

// ═════════════════════════ ADMIN ═════════════════════════════════

var modQueueMu sync.Mutex

// GET /admin/moderation/queue?status=pending&action=all&page=1
func AdminModerationQueue(c *gin.Context) {
	status := c.DefaultQuery("status", "pending")
	action := c.DefaultQuery("action", "all")
	page := clampPage(toInt(c.Query("page"), 1))
	limit := 30
	ctx := c.Request.Context()

	where := []string{"q.status = $1"}
	args := []any{status}
	if action != "all" && action != "" {
		args = append(args, action)
		where = append(where, fmt.Sprintf("q.action = $%d", len(args)))
	}
	if uid := strings.TrimSpace(c.Query("userId")); uid != "" {
		args = append(args, uid)
		where = append(where, fmt.Sprintf("q.user_id = $%d", len(args)))
	}
	args = append(args, limit, (page-1)*limit)
	rows, err := db.Pool.Query(ctx, `
		SELECT q.id, q.user_id, q.surface, q.target_id, q.text, q.media_url, q.media_kind,
		       q.categories, q.score, q.provider, q.reason, q.action, q.held, q.status,
		       q.created_at,
		       COALESCE(u.username,''), COALESCE(u.avatar,''), COALESCE(u.banned,false),
		       u.suspended_until,
		       (SELECT COUNT(*) FROM moderation_strikes s WHERE s.user_id=q.user_id
		          AND s.created_at > NOW() - make_interval(days => `+strconv.Itoa(strikeWindowDays())+`))
		FROM moderation_queue q LEFT JOIN users u ON u.id=q.user_id
		WHERE `+strings.Join(where, " AND ")+`
		ORDER BY (q.action='suspension') DESC, q.created_at DESC
		LIMIT $`+strconv.Itoa(len(args)-1)+` OFFSET $`+strconv.Itoa(len(args)), args...)
	if err != nil {
		log.Printf("[moderation] queue: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Навбат бор нашуд"})
		return
	}
	defer rows.Close()
	items := []gin.H{}
	for rows.Next() {
		var id int64
		var uid, surface, target, text, murl, mkind, provider, reason, act, st, uname, avatar string
		var cats []string
		var score float32
		var held, banned bool
		var created time.Time
		var susp *time.Time
		var strikes int
		if err := rows.Scan(&id, &uid, &surface, &target, &text, &murl, &mkind, &cats, &score,
			&provider, &reason, &act, &held, &st, &created, &uname, &avatar, &banned, &susp, &strikes); err != nil {
			continue
		}
		u := gin.H{"_id": uid, "id": uid, "username": uname, "avatar": avatar,
			"banned": banned, "strikes": strikes}
		if susp != nil && susp.After(time.Now()) {
			u["suspendedUntil"] = susp.UTC().Format(time.RFC3339)
		}
		items = append(items, gin.H{
			"id": id, "surface": surface, "targetId": target, "text": text,
			"mediaUrl": murl, "mediaKind": mkind, "categories": cats, "score": score,
			"provider": provider, "reason": reason, "action": act, "held": held,
			"status": st, "createdAt": created, "user": u,
		})
	}
	var pending int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM moderation_queue WHERE status='pending'`).Scan(&pending)
	c.JSON(http.StatusOK, gin.H{"items": items, "page": page, "pending": pending,
		"status": moderation.CurrentStatus()})
}

func loadQueueItem(ctx context.Context, id string) (uid, surface, target, act, status string, held bool, err error) {
	err = db.Pool.QueryRow(ctx, `
		SELECT user_id, surface, target_id, action, status, held FROM moderation_queue WHERE id=$1`, id).
		Scan(&uid, &surface, &target, &act, &status, &held)
	return
}

func markQueue(ctx context.Context, id, status, admin string) {
	db.Pool.Exec(ctx, `UPDATE moderation_queue SET status=$2, reviewed_by=$3, reviewed_at=NOW()
		WHERE id=$1`, id, status, admin)
}

// POST /admin/moderation/queue/:id/approve — мӯҳтаво дуруст аст.
func AdminModerationApprove(c *gin.Context) {
	modQueueMu.Lock()
	defer modQueueMu.Unlock()
	ctx := c.Request.Context()
	id := c.Param("id")
	uid, surface, target, act, status, held, err := loadQueueItem(ctx, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	if act == "suspension" {
		// «Тасдиқ»-и маҳдудкунӣ = маҳдудкунии муваққатӣ боқӣ мемонад.
		markQueue(ctx, id, "approved", mw.UID(c))
		c.JSON(http.StatusOK, gin.H{"status": "approved"})
		return
	}
	// Танҳо он чи МОДЕРАТСИЯ пинҳон кард, кушода мешавад — шарҳи
	// пинҳоншуда аз рӯи «калимаҳои пинҳон»-и соҳиб пинҳон мемонад.
	if held && status == "pending" {
		releaseContent(surface, target)
	}
	markQueue(ctx, id, "approved", mw.UID(c))
	mw.InvalidateUserCache(uid)
	c.JSON(http.StatusOK, gin.H{"status": "approved"})
}

// POST /admin/moderation/queue/:id/remove — мӯҳтаво вайрон мекунад:
// нест (нарм) + огоҳӣ ба муаллиф.
func AdminModerationRemove(c *gin.Context) {
	modQueueMu.Lock()
	defer modQueueMu.Unlock()
	ctx := c.Request.Context()
	id := c.Param("id")
	uid, surface, target, act, status, _, err := loadQueueItem(ctx, id)
	if err != nil || act == "suspension" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	removeContent(surface, target)
	markQueue(ctx, id, "removed", mw.UID(c))
	var until *time.Time
	if status != "removed" {
		qid, _ := strconv.ParseInt(id, 10, 64)
		until = addStrike(context.WithoutCancel(ctx), uid, qid, surface,
			moderation.Verdict{Action: moderation.Block, Categories: []string{moderation.CatSexual}},
			"admin-remove:"+id)
	}
	mw.InvalidateUserCache(uid)
	out := gin.H{"status": "removed"}
	if until != nil {
		out["suspendedUntil"] = until.UTC().Format(time.RFC3339)
	}
	c.JSON(http.StatusOK, out)
}

// banUserPermanently — бани доимӣ (танҳо admin).
func banUserPermanently(ctx context.Context, uid, admin string) bool {
	tag, err := db.Pool.Exec(ctx, `UPDATE users SET banned=TRUE
		WHERE id=$1 AND username<>'raonson' AND COALESCE(role,'user')<>'admin'`, uid)
	if err != nil || tag.RowsAffected() == 0 {
		return false
	}
	mw.RevokeTokens(uid)
	db.Pool.Exec(ctx, `UPDATE moderation_queue SET status='banned', reviewed_by=$2, reviewed_at=NOW()
		WHERE user_id=$1 AND status='pending' AND action='suspension'`, uid, admin)
	mw.InvalidateUserCache(uid)
	mw.BumpContentEpoch()
	log.Printf("[moderation] корбар %s аз ҷониби admin %s доимӣ бан шуд", uid, admin)
	return true
}

// POST /admin/moderation/queue/:id/ban — мӯҳтаво нест + бани доимӣ.
func AdminModerationBan(c *gin.Context) {
	modQueueMu.Lock()
	defer modQueueMu.Unlock()
	ctx := c.Request.Context()
	id := c.Param("id")
	uid, surface, target, act, _, _, err := loadQueueItem(ctx, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	if act != "suspension" {
		removeContent(surface, target)
	}
	if !banUserPermanently(ctx, uid, mw.UID(c)) {
		c.JSON(http.StatusForbidden, gin.H{"message": "Ин ҳисобро бан кардан мумкин нест"})
		return
	}
	markQueue(ctx, id, "banned", mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"status": "banned", "banned": true})
}

// POST /admin/moderation/users/:id/ban
func AdminModerationBanUser(c *gin.Context) {
	if !banUserPermanently(c.Request.Context(), c.Param("id"), mw.UID(c)) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"banned": true})
}

// POST /admin/moderation/users/:id/restore — маҳдудкунӣ ва бан бекор,
// огоҳиҳо пок (саҳифаи тоза: хатои classifier бар зидди корбар
// намемонад).
func AdminModerationRestore(c *gin.Context) {
	ctx := c.Request.Context()
	uid := c.Param("id")
	tag, err := db.Pool.Exec(ctx, `UPDATE users SET suspended_until=NULL, suspension_reason='',
		banned=FALSE WHERE id=$1`, uid)
	if err != nil || tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	db.Pool.Exec(ctx, `DELETE FROM moderation_strikes WHERE user_id=$1`, uid)
	db.Pool.Exec(ctx, `UPDATE moderation_queue SET status='restored', reviewed_by=$2, reviewed_at=NOW()
		WHERE user_id=$1 AND status='pending' AND action='suspension'`, uid, mw.UID(c))
	mw.ForgetTokenState(uid)
	mw.InvalidateUserCache(uid)
	log.Printf("[moderation] корбар %s аз ҷониби admin барқарор шуд", uid)
	c.JSON(http.StatusOK, gin.H{"restored": true, "banned": false})
}

// GET /admin/moderation/users/:id/strikes
func AdminModerationStrikes(c *gin.Context) {
	ctx := c.Request.Context()
	uid := c.Param("id")
	var uname, reason string
	var banned bool
	var susp *time.Time
	if err := db.Pool.QueryRow(ctx, `SELECT username, COALESCE(banned,false), suspended_until,
		COALESCE(suspension_reason,'') FROM users WHERE id=$1`, uid).
		Scan(&uname, &banned, &susp, &reason); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	rows, err := db.Pool.Query(ctx, `SELECT id, surface, categories, severe, created_at
		FROM moderation_strikes WHERE user_id=$1 ORDER BY created_at DESC LIMIT 100`, uid)
	strikes := []gin.H{}
	recent := 0
	if err == nil {
		defer rows.Close()
		cut := time.Now().AddDate(0, 0, -strikeWindowDays())
		for rows.Next() {
			var id int64
			var surface string
			var cats []string
			var severe bool
			var at time.Time
			if rows.Scan(&id, &surface, &cats, &severe, &at) == nil {
				if at.After(cut) {
					recent++
				}
				strikes = append(strikes, gin.H{"id": id, "surface": surface,
					"categories": cats, "severe": severe, "createdAt": at})
			}
		}
	}
	out := gin.H{"userId": uid, "username": uname, "banned": banned, "strikes": strikes,
		"recentStrikes": recent, "limit": strikeLimit(), "windowDays": strikeWindowDays(),
		"suspensionReason": reason}
	if susp != nil && susp.After(time.Now()) {
		out["suspendedUntil"] = susp.UTC().Format(time.RFC3339)
	}
	c.JSON(http.StatusOK, out)
}
