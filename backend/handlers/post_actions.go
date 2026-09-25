package handlers

import (
	"raonson/utils"
	"strings"
	"context"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── POST /posts/:id/report ────────────────────────────────────────
// Дигар user → жалоб мефиристад
func ReportPost(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Reason      string `json:"reason"`
		Description string `json:"description"`
	}
	c.ShouldBindJSON(&b)
	b.Reason = clampRunes(strings.TrimSpace(b.Reason), 40)
	b.Description = clampRunes(b.Description, 500)
	if b.Reason == "" {
		b.Reason = "spam"
	}

	db.Pool.Exec(context.Background(),
		`INSERT INTO post_reports(post_id, user_id, reason, description, created_at)
		 VALUES($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING`,
		pid, myID, b.Reason, b.Description, time.Now())

	// Пинҳони худкор. ⚠️ Пеш 10 шикояти ҲАР ҳисоб (ҳатто 10 ҳисоби
	// навсохта) ҳар постро абадан пинҳон мекард. Акнун танҳо шикоятҳои
	// ҳисобҳои аз 3 рӯз кӯҳнатар ва на аз муаллиф ҳисоб мешаванд; пост
	// ба баррасии админ меравад ва «рад» онро бармегардонад.
	var count int
	db.Pool.QueryRow(context.Background(), `
		SELECT COUNT(*) FROM post_reports r JOIN users u ON u.id=r.user_id
		WHERE r.post_id=$1 AND u.created_at < NOW() - INTERVAL '3 days'
		  AND r.user_id <> (SELECT user_id FROM posts WHERE id=$1)`, pid).Scan(&count)
	if count >= 10 {
		db.Pool.Exec(context.Background(),
			`UPDATE posts SET hidden=TRUE, auto_hidden=TRUE WHERE id=$1`, pid)
	}

	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /posts/:id/share → мубодила (беназир: 1 корбар = 1 бор) → shares
func SharePost(c *gin.Context) {
	myID := mw.UID(c)
	postID := c.Param("id")
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_shares(user_id, post_id) VALUES($1,$2)
		 ON CONFLICT (user_id, post_id) DO NOTHING`, myID, postID)
	var shares int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM post_shares WHERE post_id=$1`, postID).Scan(&shares)
	c.JSON(http.StatusOK, gin.H{"shares": shares})
}

// ── POST /posts/:id/hide-likes ── (toggle) танҳо соҳиб ──
func TogglePostHideLikes(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	var hide bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET hide_likes = NOT COALESCE(hide_likes,false)
		 WHERE id=$1 AND user_id=$2 RETURNING hide_likes`, pid, myID).Scan(&hide)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"hideLikes": hide})
}

// ── POST /posts/:id/toggle-comments ── (toggle) танҳо соҳиб ──
func TogglePostComments(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	var off bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET comments_off = NOT COALESCE(comments_off,false)
		 WHERE id=$1 AND user_id=$2 RETURNING comments_off`, pid, myID).Scan(&off)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"commentsOff": off})
}

// ── POST /posts/:id/archive ── (toggle) танҳо соҳиб ──
func TogglePostArchive(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	var arch bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE posts SET archived = NOT COALESCE(archived,false)
		 WHERE id=$1 AND user_id=$2 RETURNING archived`, pid, myID).Scan(&arch)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"archived": arch})
}

// ── POST /reels/:id/hide-likes ── (toggle) танҳо соҳиб ──
func ToggleReelHideLikes(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var hide bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE reels SET hide_likes = NOT COALESCE(hide_likes,false)
		 WHERE id=$1 AND user_id=$2::text RETURNING hide_likes`, rid, myID).Scan(&hide)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"hideLikes": hide})
}

// ── POST /reels/:id/toggle-comments ── (toggle) танҳо соҳиб ──
func ToggleReelComments(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var off bool
	err := db.Pool.QueryRow(context.Background(),
		`UPDATE reels SET comments_off = NOT COALESCE(comments_off,false)
		 WHERE id=$1 AND user_id=$2::text RETURNING comments_off`, rid, myID).Scan(&off)
	if err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиб"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"commentsOff": off})
}

// ── POST /posts/:id/interest ──────────────────────────────────────
// "Интересно" — алгоритм бештар нишон медиҳад
func MarkInterest(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	setInterest(pid, myID, true)

	c.JSON(http.StatusOK, gin.H{"interested": true})
}

// ── POST /posts/:id/not_interest ─────────────────────────────────
// "Неинтересно" — пост аз feed пинҳон мешавад ба ин user
func MarkNotInterest(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	setInterest(pid, myID, false)

	c.JSON(http.StatusOK, gin.H{"not_interested": true, "hidden": true})
}

// ── POST /posts/:id/not-interested ────────────────────────────────
// Пост аз feed-и алгоритмии ин корбар доимӣ пинҳон мешавад.
func PostNotInterested(c *gin.Context) {
	pid := c.Param("id")
	myID := mw.UID(c)
	if pid == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "bad post"})
		return
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_not_interested(post_id, user_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING`, pid, myID)
	mw.CacheDel("feed:"+myID+":1", "feed:"+myID+":2",
		"smartfeed:"+myID+":1", "smartfeed:"+myID+":2")
	c.JSON(http.StatusOK, gin.H{"not_interested": true})
}

// ── PUT /posts/:id/caption ────────────────────────────────────────
// Соҳиби пост → тавсифро тағир медиҳад
func UpdatePostCaption(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Caption string `json:"caption"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "caption required"})
		return
	}
	// Ҳамон қоидаҳои сохтани пост. Пеш таҳрир модератсияро давр мезад:
	// матни бегуноҳ нашр мешуд ва баъд ба таҳқир иваз мешуд.
	b.Caption = clampRunes(b.Caption, 2200)
	if !captionAllowed(c, b.Caption) {
		return
	}
	var oldCaption string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(caption,'') FROM posts WHERE id=$1 AND user_id=$2`,
		pid, myID).Scan(&oldCaption)

	res, err := db.Pool.Exec(context.Background(),
		`UPDATE posts SET caption=$1, updated_at=NOW() WHERE id=$2 AND user_id=$3`,
		b.Caption, pid, myID)
	if err != nil || res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found or not owner"})
		return
	}

	// Cache-ро тоза кун
	mw.CacheDel("feed:"+myID+":1", "smartfeed:"+myID+":1")
	mw.InvalidateUserCache(myID)

	// Танҳо зикрҳои НАВ огоҳ мешаванд — пеш ҳар таҳрир ба ҳамаи
	// зикршудагон боз push мефиристод (спам бо таҳрири такрорӣ).
	notifyMentions(myID, "mention", pid, newMentions(oldCaption, b.Caption),
		"шуморо дар публикатсия зикр кард")
	c.JSON(http.StatusOK, gin.H{"updated": true, "caption": b.Caption})
}

// ── PUT /posts/:id/music ──────────────────────────────────────────
// Соҳиби пост → мусиқаро тағир медиҳад
func UpdatePostMusic(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		// Шакли кӯҳна (майдонҳои алоҳида) — то барномаҳои насбшуда
		// кор кунанд.
		MusicTitle  string `json:"musicTitle"`
		MusicArtist string `json:"musicArtist"`
		MusicUrl    string `json:"musicUrl"`
		// Шакли нав: порчаи пурра бо ҷои оғоз.
		Song *songInfo `json:"song"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "music data required"})
		return
	}

	song := b.Song
	if song == nil {
		song = &songInfo{
			Title:  b.MusicTitle,
			Artist: b.MusicArtist,
			URL:    b.MusicUrl,
			EndMs:  15000,
		}
	}
	// `clean` суроғаи бегонаро мепартояд ва тирезаро ба ҳудуд меорад.
	// Натиҷаи `false` маънои «музика тоза шуд» дорад — ин иҷозат аст.
	song.clean()

	res, _ := db.Pool.Exec(context.Background(),
		`UPDATE posts SET music_title=$1, music_artist=$2, music_url=$3,
		                  music_art=$4, music_track_ms=$5,
		                  music_start_ms=$6, music_end_ms=$7, updated_at=NOW()
		 WHERE id=$8 AND user_id=$9`,
		song.Title, song.Artist, song.URL, song.ArtURL,
		song.TrackMs, song.StartMs, song.EndMs, pid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found or not owner"})
		return
	}
	mw.InvalidateUserCache(myID)

	c.JSON(http.StatusOK, gin.H{"updated": true})
}

// ── GET /posts/:id/stats ──────────────────────────────────────────
// Соҳиби пост → статистика мебинад
func GetPostStats(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	// Танҳо соҳиб мебинад
	var ownerID string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM posts WHERE id=$1`, pid).Scan(&ownerID)
	if ownerID != myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Not your post"})
		return
	}

	var likes, comments, views, saves, reports int
	db.Pool.QueryRow(context.Background(),
		`SELECT likes_count, comments_count,
		        (SELECT COUNT(*) FROM post_views   WHERE post_id=$1),
		        (SELECT COUNT(*) FROM post_saves   WHERE post_id=$1),
		        (SELECT COUNT(*) FROM post_reports WHERE post_id=$1)
		 FROM posts WHERE id=$1`, pid).Scan(&likes, &comments, &views, &saves, &reports)

	// Аудитория: бинандагоне, ки ба муаллиф обуна шудаанд vs дигарон.
	var fromFollowers, fromOthers int
	db.Pool.QueryRow(context.Background(),
		`SELECT
		   COUNT(*) FILTER (WHERE f.follower_id IS NOT NULL),
		   COUNT(*) FILTER (WHERE f.follower_id IS NULL)
		 FROM post_views pv
		 LEFT JOIN follows f
		   ON f.follower_id = pv.user_id AND f.following_id = $2
		 WHERE pv.post_id = $1`, pid, myID).Scan(&fromFollowers, &fromOthers)

	var shares int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM post_shares WHERE post_id=$1`, pid).Scan(&shares)

	c.JSON(http.StatusOK, gin.H{
		"likes":         likes,
		"comments":      comments,
		"views":         views,
		"saves":         saves,
		"reports":       reports,
		"shares":        shares,
		"fromFollowers": fromFollowers,
		"fromOthers":    fromOthers,
	})
}

// setInterest — «Ҷолиб / Ҷолиб нест». Хол танҳо вақте тағйир меёбад, ки
// ҳолати корбар ВОҚЕАН иваз шуд. Пеш ҳар дархост +1 ё −1 мекард — як
// нафар метавонист постро (ё рақибро) беохир боло/поён барад.
func setInterest(pid, uid string, want bool) {
	var old *bool
	db.Pool.QueryRow(context.Background(),
		`SELECT interested FROM post_interests WHERE post_id=$1 AND user_id=$2`,
		pid, uid).Scan(&old)
	db.Pool.Exec(context.Background(),
		`INSERT INTO post_interests(post_id, user_id, interested, created_at)
		 VALUES($1,$2,$3,$4)
		 ON CONFLICT(post_id, user_id) DO UPDATE SET interested=$3`,
		pid, uid, want, time.Now())
	delta := 0
	switch {
	case old == nil && want:
		delta = 1
	case old == nil && !want:
		delta = -1
	case *old != want && want:
		delta = 2
	case *old != want && !want:
		delta = -2
	}
	if delta != 0 {
		db.Pool.Exec(context.Background(),
			`UPDATE posts SET interest_score = COALESCE(interest_score,0) + $2 WHERE id=$1`,
			pid, delta)
	}
}

// captionAllowed — модератсияи матн (ҳамон қоидаҳои сохтан).
func captionAllowed(c *gin.Context, text string) bool {
	if text == "" {
		return true
	}
	if flagged, cats := utils.ModerateText(context.Background(), text); flagged {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Матн қоидаҳои ҷамъиятиро вайрон мекунад", "categories": cats})
		return false
	}
	if !moderateText(text) {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Матн аз тарафи AI рад шуд. Лутфан онро тағйир диҳед."})
		return false
	}
	return true
}

// newMentions — @номҳое, ки дар матни нав ҳастанд, вале дар кӯҳна набуданд.
func newMentions(oldText, newText string) string {
	had := map[string]bool{}
	for _, m := range mentionRe.FindAllStringSubmatch(oldText, -1) {
		had[strings.ToLower(m[1])] = true
	}
	var sb strings.Builder
	for _, m := range mentionRe.FindAllStringSubmatch(newText, -1) {
		if !had[strings.ToLower(m[1])] {
			sb.WriteString("@" + m[1] + " ")
		}
	}
	return sb.String()
}
