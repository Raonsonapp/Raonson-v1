package handlers

// «Чаленҷ» — мусобиқаи умумӣ дар атрофи хештег.
//
//   POST   /challenges                    — {tag, title, rules, coverUrl, startsAt, endsAt}
//   GET    /challenges?status=active|upcoming|ended|all
//   GET    /challenges/:id                — маълумот, ҷадвал (20), иштироки ман, ғолибон
//   GET    /challenges/:id/leaderboard    — ?limit=
//   DELETE /challenges/:id                — созанда
//   GET    /users/:id/challenge-badges    — нишонҳои ғолиб дар профил
//
// Иштирок = пост ё Reel бо хештег дар давраи чаленҷ (индекси
// content_hashtags, пакети backend/hashtags). Ҷадвал: аз ҳар корбар танҳо
// беҳтарин иштирок; хол = лайкдиҳандагон + 2×шарҳнависони беназир дар
// давраи чаленҷ, бе худи муаллиф ва бе ҳисобҳои манъшуда; ҳисоби пӯшида
// ва басташуда (нисбат ба тамошобин) хориҷ (ниг. featuredb).

import (
	"context"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	"raonson/featuredb"
	"raonson/features"
	"raonson/hashtags"
	mw "raonson/middleware"
	"raonson/moderation"

	"github.com/gin-gonic/gin"
)

type challengeRow struct {
	ID, Creator, Tag, Title, Rules, Cover string
	StartsAt, EndsAt, CreatedAt           time.Time
	Hidden, Finalized                     bool
}

const challengeCols = `id, creator_id, tag, title, rules, cover_url, starts_at, ends_at, created_at, hidden, finalized`

func scanChallenge(row interface{ Scan(...any) error }) (*challengeRow, error) {
	var r challengeRow
	if err := row.Scan(&r.ID, &r.Creator, &r.Tag, &r.Title, &r.Rules, &r.Cover,
		&r.StartsAt, &r.EndsAt, &r.CreatedAt, &r.Hidden, &r.Finalized); err != nil {
		return nil, err
	}
	return &r, nil
}

func canSeeChallenge(r *challengeRow, viewer string) bool {
	if r == nil {
		return false
	}
	if viewer == r.Creator {
		return true
	}
	return !r.Hidden && !IsBlockedBetween(viewer, r.Creator)
}

func rankedJSON(ctx context.Context, list []features.Ranked) []gin.H {
	ids := make([]string, 0, len(list))
	for _, r := range list {
		ids = append(ids, r.UserID)
	}
	users := miniUsers(ctx, ids)
	out := make([]gin.H, 0, len(list))
	for _, r := range list {
		out = append(out, gin.H{"rank": r.Rank, "score": r.Score, "user": users[r.UserID],
			"contentKind": r.Kind, "contentId": r.ID, "likers": r.Likers,
			"commenters": r.Commenters, "createdAt": r.CreatedAt})
	}
	return out
}

// challengeJSON — full=true: ҷадвал ва иштироки ман ҳам.
func challengeJSON(ctx context.Context, r *challengeRow, viewer string, now time.Time, full bool) gin.H {
	users := miniUsers(ctx, []string{r.Creator})
	out := gin.H{
		"_id": r.ID, "tag": r.Tag, "title": r.Title, "rules": r.Rules,
		"coverUrl": r.Cover, "startsAt": r.StartsAt, "endsAt": r.EndsAt,
		"status":  features.ChallengeStatus(now, r.StartsAt, r.EndsAt),
		"creator": users[r.Creator], "isCreator": viewer == r.Creator,
		"finalized": r.Finalized, "createdAt": r.CreatedAt,
	}
	if viewer == r.Creator && r.Hidden {
		out["pendingReview"] = true
	}
	entries, err := featuredb.ChallengeEntries(ctx, db.Pool, r.Tag, r.StartsAt, r.EndsAt, viewer)
	if err != nil {
		entries = nil
	}
	board := features.Leaderboard(entries, 0)
	out["participantsCount"] = len(board)
	if !full {
		return out
	}
	top := board
	if len(top) > 20 {
		top = top[:20]
	}
	out["leaderboard"] = rankedJSON(ctx, top)
	out["joined"] = false
	for _, b := range board {
		if b.UserID == viewer {
			out["joined"] = true
			out["myEntry"] = gin.H{"rank": b.Rank, "score": b.Score,
				"contentKind": b.Kind, "contentId": b.ID}
			break
		}
	}
	winners := []gin.H{}
	rows, err := db.Pool.Query(ctx, `SELECT user_id, rank, score, content_kind, content_id
		FROM challenge_winners WHERE challenge_id=$1 ORDER BY rank`, r.ID)
	if err == nil {
		var ids []string
		type w struct {
			uid, kind, cid string
			rank, score    int
		}
		var ws []w
		for rows.Next() {
			var x w
			if rows.Scan(&x.uid, &x.rank, &x.score, &x.kind, &x.cid) == nil {
				ws = append(ws, x)
				ids = append(ids, x.uid)
			}
		}
		rows.Close()
		wu := miniUsers(ctx, ids)
		for _, x := range ws {
			if IsBlockedBetween(viewer, x.uid) {
				continue
			}
			winners = append(winners, gin.H{"rank": x.rank, "score": x.score, "user": wu[x.uid],
				"contentKind": x.kind, "contentId": x.cid})
		}
	}
	out["winners"] = winners
	return out
}

// POST /challenges
func CreateChallenge(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var b struct {
		Tag      string `json:"tag"`
		Title    string `json:"title"`
		Rules    string `json:"rules"`
		CoverURL string `json:"coverUrl"`
		StartsAt string `json:"startsAt"`
		EndsAt   string `json:"endsAt"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "Маълумот нодуруст")
		return
	}
	tag, ok := hashtags.Normalize(b.Tag)
	if !ok {
		badRequest(c, "Хештеги нодуруст")
		return
	}
	if moderation.HashtagBlocked(tag) {
		c.JSON(http.StatusForbidden, gin.H{"message": ContentBlockedMessage, "code": "content_blocked"})
		return
	}
	now := time.Now().UTC()
	start, ok1 := parseTimeField(b.StartsAt)
	if !ok1 {
		start = now
	}
	end, ok2 := parseTimeField(b.EndsAt)
	if !ok2 {
		badRequest(c, "Санаи анҷом лозим аст")
		return
	}
	title := strings.TrimSpace(b.Title)
	rules := strings.TrimSpace(b.Rules)
	if err := features.ValidateChallenge(now, title, rules, start, end); err != nil {
		badRequest(c, err.Error())
		return
	}
	var exists bool
	db.Pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM challenges WHERE tag=$1)`, tag).Scan(&exists)
	if exists {
		c.JSON(http.StatusConflict, gin.H{"message": "Барои ин хештег аллакай чаленҷ ҳаст"})
		return
	}
	if !otpSendAllowed("challenge:"+me, features.ChallengesPerDay, 24*time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{"message": "Имрӯз чаленҷ бисёр сохтед — фардо боз"})
		return
	}
	cover := strings.TrimSpace(b.CoverURL)
	modReq := modRequest{Surface: "challenge", AI: true, Texts: []string{title, rules, "#" + tag}}
	if cover != "" {
		modReq.Media = []modMedia{{URL: cover}}
	}
	mod, okMod := screenContent(c, me, modReq)
	if !okMod {
		return
	}
	r, err := scanChallenge(db.Pool.QueryRow(ctx, `
		INSERT INTO challenges(creator_id, tag, title, rules, cover_url, starts_at, ends_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING `+challengeCols,
		me, tag, title, rules, cover, start, end))
	if err != nil {
		if isUnique(err) {
			c.JSON(http.StatusConflict, gin.H{"message": "Барои ин хештег аллакай чаленҷ ҳаст"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сохта нашуд"})
		return
	}
	if holdIfNeeded(me, modReq, r.ID, mod) {
		r.Hidden = true
	}
	c.JSON(http.StatusCreated, challengeJSON(ctx, r, me, now, true))
}

// GET /challenges?status=
func ListChallenges(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	status := c.DefaultQuery("status", "active")
	var cond, order string
	switch status {
	case "upcoming":
		cond, order = `starts_at > NOW()`, `starts_at ASC`
	case "ended":
		cond, order = `ends_at <= NOW()`, `ends_at DESC`
	case "all":
		cond, order = `TRUE`, `ends_at DESC`
	default:
		status = "active"
		cond, order = `starts_at <= NOW() AND ends_at > NOW()`, `ends_at ASC`
	}
	rows, err := db.Pool.Query(ctx, `SELECT `+challengeCols+` FROM challenges c
		WHERE `+cond+` AND (c.hidden=FALSE OR c.creator_id=$1)
		  AND NOT EXISTS (SELECT 1 FROM blocks b
		      WHERE (b.blocker_id=$1 AND b.blocked_id=c.creator_id)
		         OR (b.blocker_id=c.creator_id AND b.blocked_id=$1))
		ORDER BY `+order+` LIMIT 30`, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	var list []*challengeRow
	for rows.Next() {
		if r, err := scanChallenge(rows); err == nil {
			list = append(list, r)
		}
	}
	rows.Close()
	now := time.Now().UTC()
	out := []gin.H{}
	for _, r := range list {
		out = append(out, challengeJSON(ctx, r, me, now, false))
	}
	c.JSON(http.StatusOK, gin.H{"challenges": out, "status": status})
}

func challengeForViewer(c *gin.Context) (*challengeRow, bool) {
	r, err := scanChallenge(db.Pool.QueryRow(c.Request.Context(),
		`SELECT `+challengeCols+` FROM challenges WHERE id=$1`, c.Param("id")))
	if err != nil || !canSeeChallenge(r, mw.UID(c)) {
		notFound(c)
		return nil, false
	}
	return r, true
}

// GET /challenges/:id
func GetChallenge(c *gin.Context) {
	r, ok := challengeForViewer(c)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, challengeJSON(c.Request.Context(), r, mw.UID(c), time.Now().UTC(), true))
}

// GET /challenges/:id/leaderboard?limit=
func GetChallengeLeaderboard(c *gin.Context) {
	r, ok := challengeForViewer(c)
	if !ok {
		return
	}
	ctx := c.Request.Context()
	limit := clampLimit(toInt(c.Query("limit"), 50))
	entries, _ := featuredb.ChallengeEntries(ctx, db.Pool, r.Tag, r.StartsAt, r.EndsAt, mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"leaderboard": rankedJSON(ctx, features.Leaderboard(entries, limit))})
}

// DELETE /challenges/:id — созанда пинҳон мекунад.
func DeleteChallenge(c *gin.Context) {
	tag, err := db.Pool.Exec(c.Request.Context(),
		`UPDATE challenges SET hidden=TRUE WHERE id=$1 AND creator_id=$2`, c.Param("id"), mw.UID(c))
	if err != nil || tag.RowsAffected() == 0 {
		notFound(c)
		return
	}
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

// GET /users/:id/challenge-badges
func GetChallengeBadges(c *gin.Context) {
	me := mw.UID(c)
	owner := c.Param("id")
	if ok, _ := CanSeeProfileContent(me, owner); !ok {
		c.JSON(http.StatusOK, gin.H{"badges": []gin.H{}})
		return
	}
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT w.rank, w.score, ch.id, ch.tag, ch.title, ch.ends_at
		  FROM challenge_winners w JOIN challenges ch ON ch.id = w.challenge_id
		 WHERE w.user_id=$1 AND ch.hidden=FALSE
		 ORDER BY ch.ends_at DESC LIMIT 30`, owner)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"badges": []gin.H{}})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var rank, score int
		var id, tag, title string
		var ends time.Time
		if rows.Scan(&rank, &score, &id, &tag, &title, &ends) == nil {
			out = append(out, gin.H{"rank": rank, "score": score, "challengeId": id,
				"tag": tag, "title": title, "endedAt": ends})
		}
	}
	c.JSON(http.StatusOK, gin.H{"badges": out})
}
