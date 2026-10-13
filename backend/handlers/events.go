package handlers

// «Даъватнома» — даъват ба тӯй, зодрӯз ё вохӯрӣ.
//
//   POST   /events                     — сохтан (ном, муқова, вақт, ҷой, тавсиф, ҳамкор-мизбон)
//   GET    /events?tab=upcoming|past|public
//   GET    /events/:id[?code=]         — бо коди линки мизбон даъват худкор илова мешавад
//   PUT    /events/:id                 — таҳрир (мизбонон)
//   DELETE /events/:id                 — бекор кардан (танҳо мизбони асосӣ)
//   POST   /events/:id/invite          — даъват {userIds}
//   DELETE /events/:id/guests/:userId  — хориҷ (мизбон) ё худ рафтан
//   POST   /events/:id/rsvp            — {status: going|maybe|declined, plus}
//   GET    /events/:id/guests          — рӯйхати меҳмонон (танҳо мизбонон)
//   GET    /events/:id/photos          — албоми муштарак
//   POST   /events/:id/photos          — {url} пас аз оғоз, мизбон ё «Меоям»
//   DELETE /events/:id/photos/:photoId
//
// Махфият: пешфарз — танҳо даъватшудагон. Бастан бо мизбон ҳамеша 404
// (ҳатто агар даъват шуда бошад). Чорабинии пинҳоншуда (модератсия) ба
// ҷуз мизбонон ба касе намоён нест.

import (
	"context"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	"raonson/features"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

type eventRow struct {
	ID, HostID, Title, Kind, Desc, Cover string
	PlaceName, PlaceID                   string
	Lat, Lon                             *float64
	StartsAt                             time.Time
	EndsAt                               *time.Time
	IsPublic, Cancelled, Hidden          bool
	MaxPlus                              int
	InviteCode                           string
	CreatedAt                            time.Time
}

const eventCols = `id, host_id, title, kind, description, cover_url, place_name, place_id,
	place_lat, place_lon, starts_at, ends_at, is_public, cancelled, hidden, max_plus,
	invite_code, created_at`

func scanEvent(row interface{ Scan(...any) error }) (*eventRow, error) {
	var e eventRow
	err := row.Scan(&e.ID, &e.HostID, &e.Title, &e.Kind, &e.Desc, &e.Cover,
		&e.PlaceName, &e.PlaceID, &e.Lat, &e.Lon, &e.StartsAt, &e.EndsAt,
		&e.IsPublic, &e.Cancelled, &e.Hidden, &e.MaxPlus, &e.InviteCode, &e.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &e, nil
}

func loadEvent(ctx context.Context, id string) *eventRow {
	e, err := scanEvent(db.Pool.QueryRow(ctx, `SELECT `+eventCols+` FROM invite_events WHERE id=$1`, id))
	if err != nil {
		return nil
	}
	return e
}

// endTime — анҷоми чорабинӣ (бе ends_at — 12 соат пас аз оғоз).
func (e *eventRow) endTime() time.Time {
	if e.EndsAt != nil {
		return *e.EndsAt
	}
	return e.StartsAt.Add(12 * time.Hour)
}

func (e *eventRow) status(now time.Time) string {
	switch {
	case e.Cancelled:
		return "cancelled"
	case !now.Before(e.endTime()):
		return "past"
	case !now.Before(e.StartsAt):
		return "live"
	}
	return "upcoming"
}

// eventAccess — нақши тамошобин дар чорабинӣ.
type eventAccess struct {
	Owner   bool // мизбони асосӣ
	Host    bool // мизбон ё ҳамкор-мизбон
	Invited bool
	RSVP    string
	Plus    int
}

func eventAccessFor(ctx context.Context, e *eventRow, viewer string) eventAccess {
	a := eventAccess{Owner: viewer == e.HostID, RSVP: features.RSVPPending}
	a.Host = a.Owner
	if !a.Host {
		db.Pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM event_cohosts WHERE event_id=$1 AND user_id=$2)`,
			e.ID, viewer).Scan(&a.Host)
	}
	if err := db.Pool.QueryRow(ctx,
		`SELECT rsvp, plus FROM event_guests WHERE event_id=$1 AND user_id=$2`,
		e.ID, viewer).Scan(&a.RSVP, &a.Plus); err == nil {
		a.Invited = true
	}
	return a
}

// canSeeEvent — қоидаи ягонаи намоёнӣ.
func canSeeEvent(e *eventRow, a eventAccess, viewer string) bool {
	if e == nil || viewer == "" {
		return false
	}
	if a.Owner {
		return true
	}
	if IsBlockedBetween(viewer, e.HostID) {
		return false
	}
	if a.Host {
		return true
	}
	if e.Hidden {
		return false
	}
	return a.Invited || e.IsPublic
}

type eventCounts struct {
	Going, Maybe, Declined, Pending, Guests int
}

func countEventGuests(ctx context.Context, id string) eventCounts {
	var c eventCounts
	db.Pool.QueryRow(ctx, `
		SELECT COUNT(*) FILTER (WHERE rsvp='going'),
		       COUNT(*) FILTER (WHERE rsvp='maybe'),
		       COUNT(*) FILTER (WHERE rsvp='declined'),
		       COUNT(*) FILTER (WHERE rsvp='pending'),
		       COALESCE(SUM(1 + plus) FILTER (WHERE rsvp='going'), 0)
		  FROM event_guests WHERE event_id=$1`, id).
		Scan(&c.Going, &c.Maybe, &c.Declined, &c.Pending, &c.Guests)
	return c
}

func eventCohosts(ctx context.Context, id string) []string {
	ids := []string{}
	rows, err := db.Pool.Query(ctx, `SELECT user_id FROM event_cohosts WHERE event_id=$1`, id)
	if err != nil {
		return ids
	}
	defer rows.Close()
	for rows.Next() {
		var u string
		if rows.Scan(&u) == nil {
			ids = append(ids, u)
		}
	}
	return ids
}

func eventJSON(ctx context.Context, e *eventRow, a eventAccess, now time.Time) gin.H {
	cohosts := eventCohosts(ctx, e.ID)
	users := miniUsers(ctx, append([]string{e.HostID}, cohosts...))
	coList := []gin.H{}
	for _, id := range cohosts {
		if u, ok := users[id]; ok {
			coList = append(coList, u)
		}
	}
	cnt := countEventGuests(ctx, e.ID)
	place := gin.H{"name": e.PlaceName, "id": e.PlaceID}
	if e.Lat != nil && e.Lon != nil {
		place["lat"], place["lon"] = *e.Lat, *e.Lon
	}
	out := gin.H{
		"_id": e.ID, "title": e.Title, "kind": e.Kind, "description": e.Desc,
		"coverUrl": e.Cover, "startsAt": e.StartsAt, "endsAt": e.EndsAt,
		"place": place, "isPublic": e.IsPublic, "cancelled": e.Cancelled,
		"status": e.status(now), "maxPlus": e.MaxPlus,
		"host": users[e.HostID], "cohosts": coList,
		"isHost": a.Host, "isOwner": a.Owner, "invited": a.Invited,
		"myRsvp": a.RSVP, "myPlus": a.Plus,
		"counts": gin.H{"going": cnt.Going, "maybe": cnt.Maybe, "declined": cnt.Declined,
			"pending": cnt.Pending, "guests": cnt.Guests},
		"albumOpen": features.AlbumOpen(now, e.StartsAt) && !e.Cancelled,
		"canUpload": features.AlbumOpen(now, e.StartsAt) && !e.Cancelled &&
			features.CanUploadToAlbum(a.Host, a.RSVP),
		"canRsvp":   !a.Host && !e.Cancelled && now.Before(e.endTime()),
		"createdAt": e.CreatedAt,
	}
	if a.Host {
		// Танҳо мизбон линки даъватро бо код мегирад.
		out["shareCode"] = e.InviteCode
		out["pendingReview"] = e.Hidden
	}
	return out
}

// eventForViewer — чорабинӣ ва нақш; false — 404 аллакай фиристода шуд.
func eventForViewer(c *gin.Context) (*eventRow, eventAccess, bool) {
	ctx := c.Request.Context()
	me := mw.UID(c)
	e := loadEvent(ctx, c.Param("id"))
	if e == nil {
		notFound(c)
		return nil, eventAccess{}, false
	}
	a := eventAccessFor(ctx, e, me)
	if !canSeeEvent(e, a, me) {
		notFound(c)
		return nil, eventAccess{}, false
	}
	return e, a, true
}

type eventInput struct {
	Title       *string  `json:"title"`
	Kind        *string  `json:"kind"`
	Description *string  `json:"description"`
	CoverURL    *string  `json:"coverUrl"`
	StartsAt    *string  `json:"startsAt"`
	EndsAt      *string  `json:"endsAt"`
	PlaceName   *string  `json:"placeName"`
	PlaceID     *string  `json:"placeId"`
	IsPublic    *bool    `json:"isPublic"`
	MaxPlus     *int     `json:"maxPlus"`
	Cohosts     []string `json:"cohosts"`
	Invite      []string `json:"invite"`
}

func strOr(p *string, def string) string {
	if p == nil {
		return def
	}
	return *p
}

// POST /events
func CreateEvent(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var b eventInput
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "Маълумот нодуруст")
		return
	}
	title := clampRunes(strings.TrimSpace(strOr(b.Title, "")), 200)
	desc := clampRunes(strings.TrimSpace(strOr(b.Description, "")), features.EventDescMax)
	start, ok := parseTimeField(strOr(b.StartsAt, ""))
	if !ok {
		badRequest(c, "Вақти оғоз лозим аст")
		return
	}
	var end *time.Time
	if t, ok := parseTimeField(strOr(b.EndsAt, "")); ok {
		end = &t
	}
	now := time.Now().UTC()
	if err := features.ValidateEvent(now, title, start, end); err != nil {
		badRequest(c, err.Error())
		return
	}
	if len(b.Cohosts) > features.EventMaxCohosts {
		badRequest(c, "То 3 ҳамкор-мизбон")
		return
	}
	if !otpSendAllowed("event:"+me, 10, 24*time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{"message": "Имрӯз чорабинӣ бисёр сохтед — фардо боз"})
		return
	}
	placeName, placeID, lat, lon := resolvePostLocation(strOr(b.PlaceName, ""), strOr(b.PlaceID, ""))
	cover := strings.TrimSpace(strOr(b.CoverURL, ""))
	modReq := modRequest{Surface: "event", AI: true, Texts: []string{title, desc, placeName}}
	if cover != "" {
		modReq.Media = []modMedia{{URL: cover}}
	}
	mod, okMod := screenContent(c, me, modReq)
	if !okMod {
		return
	}
	maxPlus := 3
	if b.MaxPlus != nil {
		maxPlus = features.ClampPlus(features.RSVPGoing, *b.MaxPlus, features.EventMaxPlus)
	}
	isPublic := b.IsPublic != nil && *b.IsPublic
	var id string
	if err := db.Pool.QueryRow(ctx, `
		INSERT INTO invite_events(host_id, title, kind, description, cover_url, starts_at, ends_at,
		                   place_name, place_id, place_lat, place_lon, is_public, max_plus)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING id`,
		me, title, features.NormalizeEventKind(strOr(b.Kind, "")), desc, cover, start, end,
		placeName, placeID, lat, lon, isPublic, maxPlus).Scan(&id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сохта нашуд"})
		return
	}
	for _, uid := range b.Cohosts {
		if uid == "" || uid == me || !activeUserExists(ctx, uid) || IsBlockedBetween(me, uid) {
			continue
		}
		db.Pool.Exec(ctx, `INSERT INTO event_cohosts(event_id, user_id) VALUES ($1,$2)
			ON CONFLICT DO NOTHING`, id, uid)
	}
	held := holdIfNeeded(me, modReq, id, mod)
	e := loadEvent(ctx, id)
	if !held && len(b.Invite) > 0 {
		inviteToEvent(ctx, e, me, b.Invite)
	}
	if !held {
		for _, uid := range eventCohosts(ctx, id) {
			notify(uid, me, "event_invite", id)
			pushNotify(uid, me, "event_invite", id, "")
		}
	}
	out := eventJSON(ctx, e, eventAccessFor(ctx, e, me), now)
	c.JSON(http.StatusCreated, out)
}

// GET /events?tab=upcoming|past|public
func ListEvents(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	tab := c.DefaultQuery("tab", "upcoming")
	now := time.Now().UTC()
	var where, order string
	switch tab {
	case "past":
		where = `(e.host_id=$1 OR EXISTS(SELECT 1 FROM event_cohosts h WHERE h.event_id=e.id AND h.user_id=$1)
		          OR EXISTS(SELECT 1 FROM event_guests g WHERE g.event_id=e.id AND g.user_id=$1))
		         AND COALESCE(e.ends_at, e.starts_at + INTERVAL '12 hours') < NOW()`
		order = `e.starts_at DESC`
	case "public":
		where = `e.is_public AND NOT e.cancelled AND NOT e.hidden
		         AND COALESCE(e.ends_at, e.starts_at + INTERVAL '12 hours') >= NOW()
		         AND EXISTS(SELECT 1 FROM users hu WHERE hu.id=e.host_id AND COALESCE(hu.banned,false)=FALSE)`
		order = `e.starts_at ASC`
	default:
		tab = "upcoming"
		where = `(e.host_id=$1 OR EXISTS(SELECT 1 FROM event_cohosts h WHERE h.event_id=e.id AND h.user_id=$1)
		          OR EXISTS(SELECT 1 FROM event_guests g WHERE g.event_id=e.id AND g.user_id=$1))
		         AND COALESCE(e.ends_at, e.starts_at + INTERVAL '12 hours') >= NOW()`
		order = `e.starts_at ASC`
	}
	rows, err := db.Pool.Query(ctx, `SELECT `+prefixCols(eventCols, "e.")+` FROM invite_events e
		WHERE `+where+`
		  AND (e.host_id=$1 OR NOT EXISTS(SELECT 1 FROM blocks b
		       WHERE (b.blocker_id=$1 AND b.blocked_id=e.host_id)
		          OR (b.blocker_id=e.host_id AND b.blocked_id=$1)))
		ORDER BY `+order+` LIMIT 60`, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	var list []*eventRow
	for rows.Next() {
		if e, err := scanEvent(rows); err == nil {
			list = append(list, e)
		}
	}
	rows.Close()
	out := []gin.H{}
	for _, e := range list {
		a := eventAccessFor(ctx, e, me)
		if !canSeeEvent(e, a, me) {
			continue
		}
		out = append(out, eventJSON(ctx, e, a, now))
	}
	c.JSON(http.StatusOK, gin.H{"events": out, "tab": tab})
}

// prefixCols — "a, b" → "e.a, e.b".
func prefixCols(cols, p string) string {
	parts := strings.Split(cols, ",")
	for i, s := range parts {
		parts[i] = p + strings.TrimSpace(s)
	}
	return strings.Join(parts, ", ")
}

// GET /events/:id[?code=]
func GetEvent(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	e := loadEvent(ctx, c.Param("id"))
	if e == nil {
		notFound(c)
		return
	}
	a := eventAccessFor(ctx, e, me)
	// Линки мизбон бо код: касе, ки онро дорад, даъват мешавад.
	if code := strings.TrimSpace(c.Query("code")); code != "" && !a.Host && !a.Invited &&
		code == e.InviteCode && !e.Hidden && !e.Cancelled && !IsBlockedBetween(me, e.HostID) {
		db.Pool.Exec(ctx, `INSERT INTO event_guests(event_id, user_id, invited_by)
			VALUES ($1,$2,'link') ON CONFLICT DO NOTHING`, e.ID, me)
		a = eventAccessFor(ctx, e, me)
	}
	if !canSeeEvent(e, a, me) {
		notFound(c)
		return
	}
	c.JSON(http.StatusOK, eventJSON(ctx, e, a, time.Now().UTC()))
}

// PUT /events/:id
func UpdateEvent(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	if !a.Host {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо мизбон таҳрир мекунад"})
		return
	}
	if e.Cancelled {
		c.JSON(http.StatusConflict, gin.H{"message": "Чорабинӣ бекор шудааст"})
		return
	}
	var b eventInput
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "Маълумот нодуруст")
		return
	}
	title := e.Title
	if b.Title != nil {
		title = clampRunes(strings.TrimSpace(*b.Title), 200)
	}
	desc := e.Desc
	if b.Description != nil {
		desc = clampRunes(strings.TrimSpace(*b.Description), features.EventDescMax)
	}
	start := e.StartsAt
	if b.StartsAt != nil {
		t, ok := parseTimeField(*b.StartsAt)
		if !ok {
			badRequest(c, "Вақти оғоз нодуруст")
			return
		}
		start = t
	}
	end := e.EndsAt
	if b.EndsAt != nil {
		if t, ok := parseTimeField(*b.EndsAt); ok {
			end = &t
		} else {
			end = nil
		}
	}
	now := time.Now().UTC()
	// Вақти оғози бетағйир (ҳатто гузашта) дубора санҷида намешавад:
	// «ҳозир» ҳамон оғоз ҳисоб мешавад, то танҳо ном ва анҷом санҷида шаванд.
	vnow := now
	if start.Equal(e.StartsAt) {
		vnow = start
	}
	if err := features.ValidateEvent(vnow, title, start, end); err != nil {
		badRequest(c, err.Error())
		return
	}
	placeName, placeID, lat, lon := e.PlaceName, e.PlaceID, e.Lat, e.Lon
	if b.PlaceName != nil || b.PlaceID != nil {
		placeName, placeID, lat, lon = resolvePostLocation(strOr(b.PlaceName, ""), strOr(b.PlaceID, ""))
	}
	cover := e.Cover
	if b.CoverURL != nil {
		cover = strings.TrimSpace(*b.CoverURL)
	}
	modReq := modRequest{Surface: "event", AI: true, Texts: []string{title, desc, placeName}}
	if cover != "" && cover != e.Cover {
		modReq.Media = []modMedia{{URL: cover}}
	}
	mod, okMod := screenContent(c, me, modReq)
	if !okMod {
		return
	}
	isPublic := e.IsPublic
	if b.IsPublic != nil {
		isPublic = *b.IsPublic
	}
	maxPlus := e.MaxPlus
	if b.MaxPlus != nil {
		maxPlus = features.ClampPlus(features.RSVPGoing, *b.MaxPlus, features.EventMaxPlus)
	}
	kind := e.Kind
	if b.Kind != nil {
		kind = features.NormalizeEventKind(*b.Kind)
	}
	timeChanged := !start.Equal(e.StartsAt)
	placeChanged := placeName != e.PlaceName
	db.Pool.Exec(ctx, `
		UPDATE invite_events SET title=$2, description=$3, cover_url=$4, starts_at=$5, ends_at=$6,
		       place_name=$7, place_id=$8, place_lat=$9, place_lon=$10, is_public=$11,
		       max_plus=$12, kind=$13, updated_at=NOW(),
		       reminded_day = CASE WHEN $14 THEN FALSE ELSE reminded_day END,
		       reminded_2h  = CASE WHEN $14 THEN FALSE ELSE reminded_2h END
		 WHERE id=$1`,
		e.ID, title, desc, cover, start, end, placeName, placeID, lat, lon, isPublic,
		maxPlus, kind, timeChanged)
	held := holdIfNeeded(me, modReq, e.ID, mod)
	if (timeChanged || placeChanged) && !held && !e.Hidden {
		notifyEventGuests(ctx, e.ID, me, "event_update")
	}
	e = loadEvent(ctx, e.ID)
	c.JSON(http.StatusOK, eventJSON(ctx, e, eventAccessFor(ctx, e, me), now))
}

// notifyEventGuests — ба ҳамаи даъватшудагони ҷавобнагуфта/меояндагон.
func notifyEventGuests(ctx context.Context, eventID, actor, kind string) {
	rows, err := db.Pool.Query(ctx, `
		SELECT user_id FROM event_guests WHERE event_id=$1 AND rsvp <> 'declined'
		UNION SELECT user_id FROM event_cohosts WHERE event_id=$1
		LIMIT 1000`, eventID)
	if err != nil {
		return
	}
	var ids []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()
	for _, id := range ids {
		switch kind {
		case "event_update":
			notify(id, actor, "event_update", eventID)
			pushNotify(id, actor, "event_update", eventID, "")
		}
	}
}

// DELETE /events/:id — бекор кардан.
func CancelEvent(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	if !a.Owner {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо мизбони асосӣ бекор мекунад"})
		return
	}
	if !e.Cancelled {
		db.Pool.Exec(ctx, `UPDATE invite_events SET cancelled=TRUE, updated_at=NOW() WHERE id=$1`, e.ID)
		if !e.Hidden && time.Now().Before(e.endTime()) {
			notifyEventGuests(ctx, e.ID, me, "event_update")
		}
	}
	c.JSON(http.StatusOK, gin.H{"cancelled": true})
}

// inviteToEvent — даъват; бармегардонад (даъватшуда, рад).
func inviteToEvent(ctx context.Context, e *eventRow, inviter string, ids []string) (int, int) {
	if e == nil {
		return 0, len(ids)
	}
	var total int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM event_guests WHERE event_id=$1`, e.ID).Scan(&total)
	cohosts := map[string]bool{}
	for _, id := range eventCohosts(ctx, e.ID) {
		cohosts[id] = true
	}
	invited, skipped := 0, 0
	seen := map[string]bool{}
	for _, uid := range ids {
		uid = strings.TrimSpace(uid)
		if uid == "" || seen[uid] {
			continue
		}
		seen[uid] = true
		if uid == e.HostID || cohosts[uid] || total >= features.EventMaxGuests ||
			!activeUserExists(ctx, uid) || IsBlockedBetween(inviter, uid) ||
			IsBlockedBetween(e.HostID, uid) {
			skipped++
			continue
		}
		if !otpSendAllowed("event_invite:"+inviter, 300, 24*time.Hour) {
			skipped++
			continue
		}
		tag, err := db.Pool.Exec(ctx, `INSERT INTO event_guests(event_id, user_id, invited_by)
			VALUES ($1,$2,$3) ON CONFLICT DO NOTHING`, e.ID, uid, inviter)
		if err != nil || tag.RowsAffected() == 0 {
			skipped++
			continue
		}
		total++
		invited++
		notify(uid, inviter, "event_invite", e.ID)
		pushNotify(uid, inviter, "event_invite", e.ID, "")
	}
	return invited, skipped
}

// POST /events/:id/invite {userIds}
func InviteToEvent(c *gin.Context) {
	me := mw.UID(c)
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	if !a.Host {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо мизбон даъват мекунад"})
		return
	}
	if e.Cancelled || e.Hidden || !time.Now().Before(e.endTime()) {
		c.JSON(http.StatusConflict, gin.H{"message": "Ба ин чорабинӣ дигар даъват намешавад"})
		return
	}
	var b struct {
		UserIDs []string `json:"userIds"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || len(b.UserIDs) == 0 || len(b.UserIDs) > 50 {
		badRequest(c, "Аз 1 то 50 нафар дар як бор")
		return
	}
	n, skipped := inviteToEvent(c.Request.Context(), e, me, b.UserIDs)
	c.JSON(http.StatusOK, gin.H{"invited": n, "skipped": skipped})
}

// DELETE /events/:id/guests/:userId — мизбон хориҷ мекунад ё худ мераванд.
func RemoveEventGuest(c *gin.Context) {
	me := mw.UID(c)
	_, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	uid := c.Param("userId")
	if uid != me && !a.Host {
		c.JSON(http.StatusForbidden, gin.H{"message": "Иҷозат нест"})
		return
	}
	db.Pool.Exec(c.Request.Context(),
		`DELETE FROM event_guests WHERE event_id=$1 AND user_id=$2`, c.Param("id"), uid)
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

// POST /events/:id/rsvp {status, plus}
func RSVPEvent(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	var b struct {
		Status string `json:"status"`
		Plus   int    `json:"plus"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || !features.ValidRSVP(b.Status) {
		badRequest(c, "Ҷавоб: going, maybe ё declined")
		return
	}
	if a.Host {
		badRequest(c, "Шумо мизбони ин чорабинӣ ҳастед")
		return
	}
	now := time.Now().UTC()
	if e.Cancelled || !now.Before(e.endTime()) {
		c.JSON(http.StatusConflict, gin.H{"message": "Чорабинӣ тамом ё бекор шудааст"})
		return
	}
	if !a.Invited {
		// Танҳо чорабинии оммавӣ ҷавоби бедаъватро қабул мекунад.
		if !e.IsPublic {
			notFound(c)
			return
		}
		db.Pool.Exec(ctx, `INSERT INTO event_guests(event_id, user_id, invited_by)
			VALUES ($1,$2,'public') ON CONFLICT DO NOTHING`, e.ID, me)
	}
	plus := features.ClampPlus(b.Status, b.Plus, e.MaxPlus)
	db.Pool.Exec(ctx, `UPDATE event_guests SET rsvp=$3, plus=$4, responded_at=NOW()
		WHERE event_id=$1 AND user_id=$2`, e.ID, me, b.Status, plus)
	if b.Status != a.RSVP {
		notify(e.HostID, me, "event_rsvp", e.ID)
		pushNotify(e.HostID, me, "event_rsvp", e.ID, "")
	}
	a = eventAccessFor(ctx, e, me)
	c.JSON(http.StatusOK, eventJSON(ctx, e, a, now))
}

// GET /events/:id/guests?status= — танҳо мизбонон.
func GetEventGuests(c *gin.Context) {
	ctx := c.Request.Context()
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	if !a.Host {
		c.JSON(http.StatusForbidden, gin.H{"message": "Рӯйхати меҳмонон танҳо барои мизбон"})
		return
	}
	status := c.Query("status")
	rows, err := db.Pool.Query(ctx, `
		SELECT g.user_id, g.rsvp, g.plus, g.invited_by, g.responded_at,
		       u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		  FROM event_guests g JOIN users u ON u.id=g.user_id
		 WHERE g.event_id=$1 AND ($2='' OR g.rsvp=$2)
		 ORDER BY CASE g.rsvp WHEN 'going' THEN 0 WHEN 'maybe' THEN 1
		          WHEN 'pending' THEN 2 ELSE 3 END, u.username
		 LIMIT 1000`, e.ID, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var uid, rsvp, by, uname, avatar string
		var plus int
		var verified bool
		var at *time.Time
		if rows.Scan(&uid, &rsvp, &plus, &by, &at, &uname, &avatar, &verified) != nil {
			continue
		}
		list = append(list, gin.H{
			"user": gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": verified},
			"rsvp": rsvp, "plus": plus, "via": by, "respondedAt": at,
		})
	}
	cnt := countEventGuests(ctx, e.ID)
	c.JSON(http.StatusOK, gin.H{"guests": list, "counts": gin.H{
		"going": cnt.Going, "maybe": cnt.Maybe, "declined": cnt.Declined,
		"pending": cnt.Pending, "guests": cnt.Guests}})
}

// GET /events/:id/photos
func GetEventPhotos(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT p.id, p.url, p.user_id, p.created_at, p.hidden,
		       u.username, COALESCE(u.avatar,'')
		  FROM event_photos p JOIN users u ON u.id=p.user_id
		 WHERE p.event_id=$1 AND (p.hidden=FALSE OR p.user_id=$2)
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$2 AND b.blocked_id=p.user_id)
		           OR (b.blocker_id=p.user_id AND b.blocked_id=$2))
		 ORDER BY p.created_at DESC LIMIT 300`, e.ID, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var id, url, uid, uname, avatar string
		var at time.Time
		var hidden bool
		if rows.Scan(&id, &url, &uid, &at, &hidden, &uname, &avatar) != nil {
			continue
		}
		list = append(list, gin.H{"_id": id, "url": url, "createdAt": at,
			"pendingReview": hidden,
			"user":          gin.H{"_id": uid, "username": uname, "avatar": avatar},
			"canDelete":     uid == me || a.Host})
	}
	c.JSON(http.StatusOK, gin.H{"photos": list,
		"albumOpen": features.AlbumOpen(time.Now(), e.StartsAt) && !e.Cancelled})
}

// POST /events/:id/photos {url}
func AddEventPhoto(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	e, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	var b struct {
		URL string `json:"url"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || strings.TrimSpace(b.URL) == "" {
		badRequest(c, "url лозим аст")
		return
	}
	now := time.Now().UTC()
	if e.Cancelled || !features.AlbumOpen(now, e.StartsAt) {
		c.JSON(http.StatusConflict, gin.H{"message": "Албом пас аз оғози чорабинӣ кушода мешавад"})
		return
	}
	if !features.CanUploadToAlbum(a.Host, a.RSVP) {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо иштирокчиён акс мегузоранд"})
		return
	}
	if !otpSendAllowed("event_photo:"+me+":"+e.ID, 50, 24*time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{"message": "Имрӯз акс бисёр шуд — фардо боз"})
		return
	}
	url := strings.TrimSpace(b.URL)
	modReq := modRequest{Surface: "event_photo", Media: []modMedia{{URL: url}}}
	mod, okMod := screenContent(c, me, modReq)
	if !okMod {
		return
	}
	var id string
	if err := db.Pool.QueryRow(ctx, `INSERT INTO event_photos(event_id, user_id, url)
		VALUES ($1,$2,$3) RETURNING id`, e.ID, me, url).Scan(&id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	held := holdIfNeeded(me, modReq, id, mod)
	c.JSON(http.StatusCreated, gin.H{"_id": id, "url": url, "pendingReview": held})
}

// DELETE /events/:id/photos/:photoId
func DeleteEventPhoto(c *gin.Context) {
	me := mw.UID(c)
	_, a, ok := eventForViewer(c)
	if !ok {
		return
	}
	tag, err := db.Pool.Exec(c.Request.Context(), `
		DELETE FROM event_photos WHERE id=$1 AND event_id=$2 AND (user_id=$3 OR $4)`,
		c.Param("photoId"), c.Param("id"), me, a.Host)
	if err != nil || tag.RowsAffected() == 0 {
		notFound(c)
		return
	}
	c.JSON(http.StatusOK, gin.H{"removed": true})
}
