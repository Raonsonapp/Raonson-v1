package handlers

// «Кӯмаки фаврӣ» — тахтаи кӯмаки ҷамъиятӣ аз рӯи шаҳр.
//
//   - Дархости хун (гурӯҳ, беморхона, шаҳр), гумшуда/ёфтшуда (одам,
//     ҳайвон, ҳуҷҷат) ва кӯмаки фаврӣ.
//   - Алоқа ТАНҲО тавассути чати барнома: рақами телефон дар матн
//     қабул намешавад (ҳимоя аз фиреб ва ҷамъоварии рақамҳо).
//   - Донорҳо бо розигии худ гурӯҳи хун ва шаҳрро медиҳанд. Ин маълумот
//     МАХФӢ аст ва танҳо барои мувофиқа истифода мешавад: муаллиф танҳо
//     ШУМОРАи огоҳшудагонро мебинад, на номҳоро. Донор худаш ҷавоб
//     диҳад — танҳо он гоҳ муаллиф ӯро мешиносад.
//   - Ҳар дархост мӯҳлат дорад ва худкор аз рӯйхат мебарояд; муаллиф
//     «Ҳал шуд» мегузорад.
//   - Зидди спам: телефони тасдиқшуда, почтаи тасдиқшуда, галочка ё
//     ҳисоби кӯҳнатар аз HELP_MIN_ACCOUNT_AGE_HOURS; ҳадди рӯзона;
//     модератсия; шикоят → пинҳон то санҷиши admin.

import (
	"context"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/places"

	"github.com/gin-gonic/gin"
)

// Навъҳои дархост.
const (
	HelpBlood        = "blood"
	HelpLostPerson   = "lost_person"
	HelpLostPet      = "lost_pet"
	HelpLostDocument = "lost_document"
	HelpFound        = "found"
	HelpUrgent       = "urgent"
)

var helpKinds = map[string]bool{
	HelpBlood: true, HelpLostPerson: true, HelpLostPet: true,
	HelpLostDocument: true, HelpFound: true, HelpUrgent: true,
}

// bloodGroups — шакли муқаррарӣ.
var bloodGroups = []string{"O-", "O+", "A-", "A+", "B-", "B+", "AB-", "AB+"}

// normalizeBloodGroup «a+», «А+» (кириллӣ), «0+», «ab +» → «A+». "" агар нодуруст.
func normalizeBloodGroup(s string) string {
	s = strings.ToUpper(strings.ReplaceAll(strings.TrimSpace(s), " ", ""))
	s = strings.NewReplacer("А", "A", "В", "B", "О", "O", "0", "O", "−", "-", "–", "-").Replace(s)
	for _, g := range bloodGroups {
		if s == g {
			return g
		}
	}
	return ""
}

// compatibleDonors — гурӯҳҳое, ки ба гирандаи `recipient` хун дода
// метавонанд (эритроситҳо, ABO + Rh). Аввал худи гурӯҳ.
func compatibleDonors(recipient string) []string {
	r := normalizeBloodGroup(recipient)
	if r == "" {
		return nil
	}
	abo, rh := strings.TrimRight(r, "+-"), r[len(r)-1:]
	aboOK := map[string][]string{
		"O": {"O"}, "A": {"A", "O"}, "B": {"B", "O"}, "AB": {"AB", "A", "B", "O"},
	}[abo]
	rhOK := []string{"-"}
	if rh == "+" {
		rhOK = []string{"+", "-"}
	}
	out := []string{r}
	for _, a := range aboOK {
		for _, h := range rhOK {
			if g := a + h; g != r {
				out = append(out, g)
			}
		}
	}
	return out
}

// helpExpiry — мӯҳлат: пешфарз ва ҳадди ҳар навъ.
func helpExpiry(kind string, hours int, now time.Time) time.Time {
	def, max := 336, 720 // гумшуда/ёфтшуда: 14 рӯз, то 30
	switch kind {
	case HelpBlood:
		def, max = 72, 168
	case HelpUrgent:
		def, max = 48, 168
	}
	if hours <= 0 {
		hours = def
	}
	if hours < 6 {
		hours = 6
	}
	if hours > max {
		hours = max
	}
	return now.Add(time.Duration(hours) * time.Hour)
}

// phoneLike — 7+ рақам паси ҳам (бо фосила, тире, қавс).
var phoneLike = regexp.MustCompile(`\+?\d[\d\s().\-]{5,}\d`)

// containsPhoneNumber — оё дар матн рақами телефон ҳаст? Алоқа танҳо дар
// чат: рақами кушод ҷалби фиребгаронро осон мекунад.
func containsPhoneNumber(s string) bool {
	for _, m := range phoneLike.FindAllString(s, -1) {
		n := 0
		for _, r := range m {
			if r >= '0' && r <= '9' {
				n++
			}
		}
		if n >= 7 {
			return true
		}
	}
	return false
}

// helpCityKey — «шаҳр» барои мувофиқа: шаҳр/ноҳия/деҳа худаш; ҷойи
// мушаххас (poi) — шаҳри волидайн. Вилоят ва кишвар қабул намешаванд.
func helpCityKey(placeID string) *places.Place {
	p := places.Get(strings.TrimSpace(placeID))
	for i := 0; p != nil && i < 3; i++ {
		switch p.Kind {
		case "city", "district", "town":
			return p
		case "poi":
			p = places.Get(p.Parent)
			continue
		}
		return nil
	}
	return nil
}

func helpEnvInt(k string, def int) int {
	if v, err := strconv.Atoi(os.Getenv(k)); err == nil && v > 0 {
		return v
	}
	return def
}

// helpTrusted — нишони эътимод барои нашр дар тахта.
func helpTrusted(ctx context.Context, uid string) bool {
	var ok bool
	db.Pool.QueryRow(ctx, `
		SELECT phone_verified_at IS NOT NULL
		    OR COALESCE(email_verified,false)
		    OR COALESCE(verified,false)
		    OR COALESCE(role,'user')='admin'
		    OR created_at < NOW() - make_interval(hours => $2)
		  FROM users WHERE id=$1`, uid, helpEnvInt("HELP_MIN_ACCOUNT_AGE_HOURS", 72)).Scan(&ok)
	return ok
}

// ── JSON ───────────────────────────────────────────────────────────

const helpSelect = `
	SELECT h.id, h.user_id, h.kind, h.title, h.body, h.blood_group, h.units,
	       h.hospital, h.city_id, h.place_id, h.photo_url, h.status, h.hidden,
	       h.expires_at, h.resolved_at, h.notified_count, h.responses_count, h.created_at,
	       u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
	       EXISTS(SELECT 1 FROM help_responses r WHERE r.request_id=h.id AND r.user_id=$1)
	  FROM help_requests h JOIN users u ON u.id=h.user_id `

type helpRow interface{ Scan(dest ...any) error }

func scanHelp(row helpRow, me, lang string) (gin.H, error) {
	var id, uid, kind, title, body, bg, hospital, cityID, placeID, photo, status string
	var units, notified, responses int
	var hidden, verified, responded bool
	var expires, created time.Time
	var resolved *time.Time
	var uname, avatar string
	if err := row.Scan(&id, &uid, &kind, &title, &body, &bg, &units, &hospital, &cityID,
		&placeID, &photo, &status, &hidden, &expires, &resolved, &notified, &responses,
		&created, &uname, &avatar, &verified, &responded); err != nil {
		return nil, err
	}
	if status == "open" && time.Now().After(expires) {
		status = "expired"
	}
	mine := uid == me
	out := gin.H{
		"_id": id, "kind": kind, "title": title, "body": body,
		"bloodGroup": bg, "units": units, "hospital": hospital,
		"photoUrl": photo, "status": status,
		"expiresAt":      expires.UTC().Format(time.RFC3339),
		"createdAt":      created.UTC().Format(time.RFC3339),
		"responsesCount": responses, "isMine": mine, "responded": responded,
		"user": gin.H{"_id": uid, "id": uid, "username": uname, "avatar": avatar, "verified": verified},
	}
	if resolved != nil {
		out["resolvedAt"] = resolved.UTC().Format(time.RFC3339)
	}
	if p := places.Get(cityID); p != nil {
		out["city"] = gin.H{"id": p.ID, "name": p.Name(lang)}
	} else {
		out["city"] = gin.H{"id": cityID, "name": ""}
	}
	if p := places.Get(placeID); p != nil {
		out["place"] = placeJSON(p, lang, -1)
	}
	if mine {
		// Танҳо шумора — на кӣ. Донор худаш ҷавоб диҳад, ном пайдо мешавад.
		out["notifiedCount"] = notified
		out["pendingReview"] = hidden
	}
	return out, nil
}

// ── HANDLERS ───────────────────────────────────────────────────────

type helpInput struct {
	Kind           string `json:"kind"`
	Title          string `json:"title"`
	Body           string `json:"body"`
	BloodGroup     string `json:"bloodGroup"`
	Units          int    `json:"units"`
	Hospital       string `json:"hospital"`
	CityID         string `json:"cityId"`
	PlaceID        string `json:"placeId"`
	PhotoURL       string `json:"photoUrl"`
	ExpiresInHours int    `json:"expiresInHours"`
}

// validate — паёми хато ва код ("" — дуруст).
func (in *helpInput) validate() (string, string) {
	in.Kind = strings.TrimSpace(in.Kind)
	in.Title = strings.TrimSpace(in.Title)
	in.Body = strings.TrimSpace(in.Body)
	in.Hospital = clampRunes(strings.TrimSpace(in.Hospital), 160)
	in.PhotoURL = strings.TrimSpace(in.PhotoURL)
	if !helpKinds[in.Kind] {
		return "Навъи дархост нодуруст аст", "help_bad_kind"
	}
	if n := utf8.RuneCountInString(in.Title); n < 5 || n > 140 {
		return "Сарлавҳа бояд аз 5 то 140 аломат бошад", "help_bad_title"
	}
	if utf8.RuneCountInString(in.Body) > 1500 {
		return "Матн то 1500 аломат", "help_bad_body"
	}
	if in.Kind == HelpBlood {
		in.BloodGroup = normalizeBloodGroup(in.BloodGroup)
		if in.BloodGroup == "" {
			return "Гурӯҳи хунро интихоб кунед", "help_bad_blood_group"
		}
		if in.Units < 0 || in.Units > 20 {
			return "Миқдор аз 0 то 20", "help_bad_units"
		}
	} else {
		in.BloodGroup, in.Units = "", 0
	}
	if in.PhotoURL != "" && !strings.HasPrefix(in.PhotoURL, "https://") &&
		!strings.HasPrefix(in.PhotoURL, "http://") {
		return "Суроғаи акс нодуруст", "help_bad_photo"
	}
	if containsPhoneNumber(in.Title + "\n" + in.Body + "\n" + in.Hospital) {
		return "Рақами телефонро нанависед — одамон тавассути чати Raonson бо шумо алоқа мегиранд",
			"help_no_contacts"
	}
	return "", ""
}

// POST /help
func CreateHelpRequest(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var in helpInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	if msg, code := in.validate(); msg != "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": msg, "code": code})
		return
	}
	city := helpCityKey(in.CityID)
	if city == nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Шаҳрро интихоб кунед", "code": "help_bad_city"})
		return
	}
	if in.PlaceID != "" && places.Get(in.PlaceID) == nil {
		in.PlaceID = ""
	}
	if !helpTrusted(ctx, me) {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Барои нашр дар «Кӯмаки фаврӣ» телефон ё почтаро тасдиқ кунед " +
				"(ё ҳисоб бояд аз 3 рӯз кӯҳнатар бошад)",
			"code": "help_trust_required"})
		return
	}
	var today int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM help_requests
		WHERE user_id=$1 AND created_at > NOW() - INTERVAL '24 hours'`, me).Scan(&today)
	if today >= helpEnvInt("HELP_DAILY_CAP", 3) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"message": "Имрӯз дархост зиёд шуд — фардо боз кӯшиш кунед", "code": "help_daily_cap"})
		return
	}
	modReq := modRequest{Surface: "help", AI: true, Texts: []string{in.Title, in.Body, in.Hospital}}
	if in.PhotoURL != "" {
		modReq.Media = []modMedia{{URL: in.PhotoURL}}
	}
	mod, ok := screenContent(c, me, modReq)
	if !ok {
		return
	}
	expires := helpExpiry(in.Kind, in.ExpiresInHours, time.Now())
	var id string
	if err := db.Pool.QueryRow(ctx, `
		INSERT INTO help_requests(user_id, kind, title, body, blood_group, units, hospital,
		    city_id, place_id, photo_url, expires_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING id`,
		me, in.Kind, in.Title, in.Body, in.BloodGroup, in.Units, in.Hospital,
		city.ID, in.PlaceID, in.PhotoURL, expires).Scan(&id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	held := holdIfNeeded(me, modReq, id, mod)
	notified := 0
	if !held && in.Kind == HelpBlood {
		notified = notifyMatchingDonors(context.WithoutCancel(ctx), id, me, city.ID, in.BloodGroup)
	}
	row := db.Pool.QueryRow(ctx, helpSelect+` WHERE h.id=$2`, me, id)
	out, err := scanHelp(row, me, placeLang(c))
	if err != nil {
		c.JSON(http.StatusCreated, gin.H{"_id": id, "notifiedCount": notified, "pendingReview": held})
		return
	}
	c.JSON(http.StatusCreated, out)
}

// notifyMatchingDonors — донорҳои мувофиқи ҳамон шаҳрро огоҳ мекунад.
//
// Ҳудуд: то HELP_MAX_NOTIFY нафар барои як дархост; ҳар донор на
// бештар аз як бор дар HELP_DONOR_COOLDOWN_HOURS (то хаста нашавад ва
// ҳисоби спам донорҳоро «сӯзонда» натавонад). Аввал гурӯҳи айнан.
func notifyMatchingDonors(ctx context.Context, reqID, author, cityID, group string) int {
	groups := compatibleDonors(group)
	if len(groups) == 0 {
		return 0
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT d.user_id FROM help_donors d JOIN users u ON u.id=d.user_id
		 WHERE d.active AND d.city_id=$1 AND d.blood_group = ANY($2)
		   AND d.user_id <> $3 AND COALESCE(u.banned,false)=FALSE
		   AND (d.last_notified_at IS NULL
		        OR d.last_notified_at < NOW() - make_interval(hours => $4))
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=d.user_id AND b.blocked_id=$3)
		           OR (b.blocker_id=$3 AND b.blocked_id=d.user_id))
		 ORDER BY (d.blood_group=$5) DESC, random()
		 LIMIT $6`,
		cityID, groups, author, helpEnvInt("HELP_DONOR_COOLDOWN_HOURS", 24), groups[0],
		helpEnvInt("HELP_MAX_NOTIFY", 30))
	if err != nil {
		return 0
	}
	var ids []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()
	n := 0
	for _, uid := range ids {
		tag, err := db.Pool.Exec(ctx, `INSERT INTO help_notified(request_id, user_id)
			VALUES($1,$2) ON CONFLICT DO NOTHING`, reqID, uid)
		if err != nil || tag.RowsAffected() == 0 {
			continue
		}
		db.Pool.Exec(ctx, `UPDATE help_donors SET last_notified_at=NOW() WHERE user_id=$1`, uid)
		notify(uid, author, "help_blood", reqID)
		pushNotify(uid, author, "help_blood", reqID, "")
		n++
	}
	if n > 0 {
		db.Pool.Exec(ctx, `UPDATE help_requests SET notified_count=notified_count+$2 WHERE id=$1`, reqID, n)
	}
	return n
}

// GET /help?city=&kind=&page=&mine=1
func ListHelpRequests(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	page := clampPage(toInt(c.Query("page"), 1))
	limit := 20
	args := []any{me}
	where := []string{}
	if c.Query("mine") == "1" {
		where = append(where, "h.user_id=$1", "h.status<>'removed'")
	} else {
		where = append(where,
			"h.status='open'", "h.hidden=FALSE", "h.expires_at > NOW()",
			"COALESCE(u.banned,false)=FALSE",
			`NOT EXISTS (SELECT 1 FROM blocks b
			   WHERE (b.blocker_id=$1 AND b.blocked_id=h.user_id)
			      OR (b.blocker_id=h.user_id AND b.blocked_id=$1))`)
		if city := strings.TrimSpace(c.Query("city")); city != "" {
			key := city
			if p := helpCityKey(city); p != nil {
				key = p.ID
			}
			args = append(args, key)
			where = append(where, "h.city_id=$"+strconv.Itoa(len(args)))
		}
	}
	switch k := c.Query("kind"); {
	case k == "lost":
		where = append(where, "h.kind LIKE 'lost_%'")
	case helpKinds[k]:
		args = append(args, k)
		where = append(where, "h.kind=$"+strconv.Itoa(len(args)))
	}
	args = append(args, limit, (page-1)*limit)
	rows, err := db.Pool.Query(ctx, helpSelect+" WHERE "+strings.Join(where, " AND ")+
		` ORDER BY (h.kind IN ('blood','urgent')) DESC, h.created_at DESC
		  LIMIT $`+strconv.Itoa(len(args)-1)+` OFFSET $`+strconv.Itoa(len(args)), args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Бор нашуд"})
		return
	}
	defer rows.Close()
	lang := placeLang(c)
	items := []gin.H{}
	for rows.Next() {
		if h, err := scanHelp(rows, me, lang); err == nil {
			items = append(items, h)
		}
	}
	c.JSON(http.StatusOK, gin.H{"items": items, "page": page, "hasMore": len(items) == limit})
}

// loadHelpVisible — дархост, агар ба `me` намоён бошад (404 — не).
func loadHelpVisible(c *gin.Context, me, id string) (gin.H, bool) {
	row := db.Pool.QueryRow(c.Request.Context(), helpSelect+`
		WHERE h.id=$2 AND (h.user_id=$1 OR (h.hidden=FALSE AND h.status<>'removed'
		      AND COALESCE(u.banned,false)=FALSE))`, me, id)
	h, err := scanHelp(row, me, placeLang(c))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return nil, false
	}
	owner, _ := h["user"].(gin.H)["_id"].(string)
	if denyIfBlocked(c, me, owner) {
		return nil, false
	}
	return h, true
}

// GET /help/:id
func GetHelpRequest(c *gin.Context) {
	if h, ok := loadHelpVisible(c, mw.UID(c), c.Param("id")); ok {
		c.JSON(http.StatusOK, h)
	}
}

// POST /help/:id/respond — «Ман кӯмак карда метавонам».
//
// Ҷавобдиҳанда ба муаллиф маълум мешавад (огоҳинома) ва барнома чатро
// бо муаллиф мекушояд. Такрор — бе огоҳиномаи дуюм.
func RespondHelpRequest(c *gin.Context) {
	me := mw.UID(c)
	h, ok := loadHelpVisible(c, me, c.Param("id"))
	if !ok {
		return
	}
	if h["isMine"] == true {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ин дархости худи шумост"})
		return
	}
	if h["status"] != "open" {
		c.JSON(http.StatusConflict, gin.H{"message": "Дархост дигар фаъол нест", "code": "help_closed"})
		return
	}
	if !ensureNotSuspended(c, me) {
		return
	}
	id := h["_id"].(string)
	author := h["user"].(gin.H)
	tag, err := db.Pool.Exec(c.Request.Context(), `INSERT INTO help_responses(request_id, user_id)
		VALUES($1,$2) ON CONFLICT DO NOTHING`, id, me)
	if err == nil && tag.RowsAffected() > 0 {
		db.Pool.Exec(c.Request.Context(),
			`UPDATE help_requests SET responses_count=responses_count+1 WHERE id=$1`, id)
		authorID, _ := author["_id"].(string)
		notify(authorID, me, "help_response", id)
		pushNotify(authorID, me, "help_response", id, "")
	}
	c.JSON(http.StatusOK, gin.H{"responded": true, "author": author})
}

// POST /help/:id/resolve — танҳо муаллиф.
func ResolveHelpRequest(c *gin.Context) {
	tag, err := db.Pool.Exec(c.Request.Context(), `UPDATE help_requests
		SET status='resolved', resolved_at=NOW() WHERE id=$1 AND user_id=$2 AND status='open'`,
		c.Param("id"), mw.UID(c))
	if err != nil || tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "resolved"})
}

// DELETE /help/:id — танҳо муаллиф (нарм).
func DeleteHelpRequest(c *gin.Context) {
	tag, err := db.Pool.Exec(c.Request.Context(), `UPDATE help_requests
		SET status='removed' WHERE id=$1 AND user_id=$2 AND status<>'removed'`,
		c.Param("id"), mw.UID(c))
	if err != nil || tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

// POST /help/:id/report {reason}
//
// HELP_REPORT_HIDE (3) шикояти одамони гуногун → пинҳон то санҷиши
// admin (навбати модератсия, surface "help"; «тасдиқ» бармегардонад).
func ReportHelpRequest(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	h, ok := loadHelpVisible(c, me, c.Param("id"))
	if !ok {
		return
	}
	if h["isMine"] == true {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ба худ шикоят карда намешавад"})
		return
	}
	var b struct {
		Reason string `json:"reason"`
	}
	c.ShouldBindJSON(&b)
	reason := clampRunes(strings.TrimSpace(b.Reason), 40)
	if reason == "" {
		reason = "spam"
	}
	id := h["_id"].(string)
	db.Pool.Exec(ctx, `INSERT INTO help_reports(request_id, user_id, reason)
		VALUES($1,$2,$3) ON CONFLICT DO NOTHING`, id, me, reason)
	var n int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM help_reports WHERE request_id=$1`, id).Scan(&n)
	if n >= helpEnvInt("HELP_REPORT_HIDE", 3) {
		tag, _ := db.Pool.Exec(ctx, `UPDATE help_requests SET hidden=TRUE
			WHERE id=$1 AND hidden=FALSE`, id)
		if tag.RowsAffected() > 0 {
			authorID, _ := h["user"].(gin.H)["_id"].(string)
			title, _ := h["title"].(string)
			body, _ := h["body"].(string)
			out := modOutcome{Queue: true, Hold: true}
			out.Verdict.Reason = "reports"
			out.Verdict.Categories = []string{"reports"}
			queueReview(authorID, modRequest{Surface: "help", Texts: []string{title, body}}, id, out, true)
		}
	}
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// GET /help/donor/me — танзимоти донор (танҳо худи корбар мебинад).
func GetHelpDonor(c *gin.Context) {
	var group, cityID string
	var active bool
	err := db.Pool.QueryRow(c.Request.Context(),
		`SELECT blood_group, city_id, active FROM help_donors WHERE user_id=$1`, mw.UID(c)).
		Scan(&group, &cityID, &active)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"enabled": false, "bloodGroup": "", "city": nil})
		return
	}
	var city any
	if p := places.Get(cityID); p != nil {
		city = gin.H{"id": p.ID, "name": p.Name(placeLang(c))}
	}
	c.JSON(http.StatusOK, gin.H{"enabled": active, "bloodGroup": group, "city": city})
}

// PUT /help/donor/me {enabled, bloodGroup, cityId}
func SetHelpDonor(c *gin.Context) {
	var b struct {
		Enabled    bool   `json:"enabled"`
		BloodGroup string `json:"bloodGroup"`
		CityID     string `json:"cityId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	me := mw.UID(c)
	if !b.Enabled {
		db.Pool.Exec(c.Request.Context(), `UPDATE help_donors SET active=FALSE, updated_at=NOW()
			WHERE user_id=$1`, me)
		c.JSON(http.StatusOK, gin.H{"enabled": false})
		return
	}
	g := normalizeBloodGroup(b.BloodGroup)
	city := helpCityKey(b.CityID)
	if g == "" || city == nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Гурӯҳи хун ва шаҳрро интихоб кунед",
			"code": "help_bad_donor"})
		return
	}
	if _, err := db.Pool.Exec(c.Request.Context(), `
		INSERT INTO help_donors(user_id, blood_group, city_id, active) VALUES($1,$2,$3,TRUE)
		ON CONFLICT (user_id) DO UPDATE SET blood_group=EXCLUDED.blood_group,
		    city_id=EXCLUDED.city_id, active=TRUE, updated_at=NOW()`, me, g, city.ID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"enabled": true, "bloodGroup": g,
		"city": gin.H{"id": city.ID, "name": city.Name(placeLang(c))}})
}

// DELETE /help/donor/me — маълумоти донор пурра нест мешавад.
func DeleteHelpDonor(c *gin.Context) {
	db.Pool.Exec(c.Request.Context(), `DELETE FROM help_donors WHERE user_id=$1`, mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}
