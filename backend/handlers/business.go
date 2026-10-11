package handlers

// «Профили тиҷоратӣ» — дӯкон, қаҳвахона, сартарошхона ва ғ.
//
//   - Корбар ҳисобашро ба тиҷоратӣ мегузаронад: категория, соатҳои кор
//     барои ҳар рӯзи ҳафта, суроға (ҷой аз рӯйхати /places), тугмаҳои
//     алоқа (занг, WhatsApp, чат, роҳ), сатҳи нарх.
//   - «Кушода/Пӯшида ҳозир» дар вақти Тоҷикистон (Asia/Dushanbe, UTC+5,
//     бе соати тобистона) ҳисоб мешавад — на дар вақти телефони бинанда.
//   - Омори содда барои соҳиб: боздиди профил ва пахши тугмаҳо (як
//     одам — як бор дар рӯз барои ҳар амал).
//   - Ҷустуҷӯ аз рӯи категория ва шаҳр. Ҳисоби пӯшида тиҷоратӣ шуда
//     наметавонад (мисли Instagram).

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/places"

	"github.com/gin-gonic/gin"
)

// tjZone — вақти Тоҷикистон. Ҷадвали tzdata дар контейнери хурд метавонад
// набошад, вале Тоҷикистон соати тобистона надорад: UTC+5 ҳамеша дуруст.
var tjZone = time.FixedZone("Asia/Dushanbe", 5*3600)

// businessDays — тартиби рӯзҳо (душанбе аввал).
var businessDays = []string{"mon", "tue", "wed", "thu", "fri", "sat", "sun"}

// businessCategory — категория бо номҳо.
type businessCategory struct {
	ID, TJ, RU, EN string
}

var businessCategories = []businessCategory{
	{"cafe", "Қаҳвахона", "Кафе", "Cafe"},
	{"restaurant", "Тарабхона", "Ресторан", "Restaurant"},
	{"bakery", "Нонвойхона", "Пекарня", "Bakery"},
	{"grocery", "Мағозаи хӯрокворӣ", "Продукты", "Grocery"},
	{"clothing", "Либос", "Одежда", "Clothing"},
	{"beauty", "Салони ҳусн", "Салон красоты", "Beauty salon"},
	{"barber", "Сартарошхона", "Барбершоп", "Barber"},
	{"pharmacy", "Дорухона", "Аптека", "Pharmacy"},
	{"clinic", "Клиника", "Клиника", "Clinic"},
	{"dentist", "Дандонпизишк", "Стоматология", "Dentist"},
	{"education", "Курсҳо ва таълим", "Курсы и обучение", "Education"},
	{"auto", "Автосервис", "Автосервис", "Car service"},
	{"electronics", "Электроника", "Электроника", "Electronics"},
	{"phone_repair", "Таъмири телефон", "Ремонт телефонов", "Phone repair"},
	{"home", "Хона ва таъмир", "Дом и ремонт", "Home & repair"},
	{"hotel", "Меҳмонхона", "Гостиница", "Hotel"},
	{"travel", "Сайёҳӣ", "Туризм", "Travel"},
	{"photo", "Аксбардорӣ", "Фотостудия", "Photo studio"},
	{"events", "Тӯй ва чорабиниҳо", "Свадьбы и мероприятия", "Weddings & events"},
	{"fitness", "Варзиш", "Фитнес", "Fitness"},
	{"delivery", "Расонидан", "Доставка", "Delivery"},
	{"services", "Хизматрасонии дигар", "Другие услуги", "Other services"},
}

func businessCategoryByID(id string) *businessCategory {
	for i := range businessCategories {
		if businessCategories[i].ID == id {
			return &businessCategories[i]
		}
	}
	return nil
}

func (b businessCategory) label(lang string) string {
	switch lang {
	case "ru":
		return b.RU
	case "en":
		return b.EN
	}
	return b.TJ
}

// businessHours — {"mon": [["09:00","18:00"]], ...}; рӯйхати холӣ — рӯзи истироҳат.
type businessHours map[string][][2]string

var hhmm = regexp.MustCompile(`^([01]\d|2[0-3]):[0-5]\d$|^24:00$`)

func minutesOf(s string) int {
	h, _ := strconv.Atoi(s[:2])
	m, _ := strconv.Atoi(s[3:])
	return h*60 + m
}

// validate — паёми хато ("" — дуруст). Ҳадди 3 фосила дар рӯз.
func (h businessHours) validate() string {
	for day, list := range h {
		known := false
		for _, d := range businessDays {
			if d == day {
				known = true
			}
		}
		if !known {
			return "Рӯзи номаълум: " + day
		}
		if len(list) > 3 {
			return "Дар як рӯз то 3 фосила"
		}
		for _, iv := range list {
			if !hhmm.MatchString(iv[0]) || !hhmm.MatchString(iv[1]) || iv[0] == iv[1] {
				return "Вақт нодуруст: " + iv[0] + "–" + iv[1]
			}
		}
	}
	return ""
}

// openStatus — ҳолати ҳозира дар вақти Тоҷикистон.
type openStatus struct {
	Known    bool   // соатҳо дода шудаанд
	Open     bool   // ҳозир кушода
	ClosesAt string // агар кушода: кай пӯшида мешавад
	OpensAt  string // агар пӯшида: кай кушода мешавад
	OpensDay string // ва дар кадом рӯз (mon..sun)
}

// dayIndex — 0=душанбе … 6=якшанбе.
func dayIndex(t time.Time) int { return (int(t.Weekday()) + 6) % 7 }

// computeOpen — аз рӯи соатҳо ва вақти `now` (ҳар минтақа — ба UTC+5 табдил мешавад).
//
// Фосилаи шабона (22:00–02:00) то субҳи рӯзи дигар идома дорад.
func computeOpen(h businessHours, now time.Time) openStatus {
	if len(h) == 0 {
		return openStatus{}
	}
	t := now.In(tjZone)
	di := dayIndex(t)
	cur := t.Hour()*60 + t.Minute()
	st := openStatus{Known: true}

	// Фосилаи шабонаи дирӯза, ки ҳоло идома дорад.
	for _, iv := range h[businessDays[(di+6)%7]] {
		o, c := minutesOf(iv[0]), minutesOf(iv[1])
		if c < o && cur < c {
			st.Open, st.ClosesAt = true, iv[1]
			return st
		}
	}
	for _, iv := range h[businessDays[di]] {
		o, c := minutesOf(iv[0]), minutesOf(iv[1])
		if c < o { // шабона
			if cur >= o {
				st.Open, st.ClosesAt = true, iv[1]
				return st
			}
			continue
		}
		if cur >= o && cur < c {
			st.Open, st.ClosesAt = true, iv[1]
			if iv[1] == "24:00" {
				st.ClosesAt = "00:00"
			}
			return st
		}
	}
	// Пӯшида: кушодани навбатӣ дар 7 рӯзи оянда.
	for add := 0; add < 8; add++ {
		day := businessDays[(di+add)%7]
		list := append([][2]string(nil), h[day]...)
		sort.Slice(list, func(i, j int) bool { return list[i][0] < list[j][0] })
		for _, iv := range list {
			if add == 0 && minutesOf(iv[0]) <= cur {
				continue
			}
			st.OpensAt, st.OpensDay = iv[0], day
			return st
		}
	}
	return st
}

var bizPhoneRe = regexp.MustCompile(`^\+?[0-9]{7,15}$`)

// cleanBizPhone — фосила/тире/қавс тоза; "" ва ok=true агар холӣ.
func cleanBizPhone(s string) (string, bool) {
	s = strings.NewReplacer(" ", "", "-", "", "(", "", ")", "").Replace(strings.TrimSpace(s))
	if s == "" {
		return "", true
	}
	return s, bizPhoneRe.MatchString(s)
}

// ── маълумот ───────────────────────────────────────────────────────

const businessSelect = `
	SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
	       COALESCE(u.full_name,''), COALESCE(u.is_business,false),
	       b.category, b.hours, b.address, b.place_id, b.city_id, b.lat, b.lon,
	       b.phone, b.whatsapp, b.price_range, b.show_chat,
	       (SELECT COUNT(*) FROM posts p WHERE p.user_id=u.id AND COALESCE(p.is_product,false)
	          AND COALESCE(p.hidden,false)=FALSE AND COALESCE(p.archived,false)=FALSE)
	  FROM business_profiles b JOIN users u ON u.id=b.user_id `

func scanBusiness(row helpRow, me, lang string, now time.Time) (gin.H, error) {
	var uid, uname, avatar, fullName, cat, hoursRaw, addr, placeID, cityID, phone, wa string
	var verified, enabled, showChat bool
	var lat, lon *float64
	var price int16
	var products int
	if err := row.Scan(&uid, &uname, &avatar, &verified, &fullName, &enabled, &cat, &hoursRaw,
		&addr, &placeID, &cityID, &lat, &lon, &phone, &wa, &price, &showChat, &products); err != nil {
		return nil, err
	}
	hours := businessHours{}
	_ = json.Unmarshal([]byte(hoursRaw), &hours)
	st := computeOpen(hours, now)
	out := gin.H{
		"userId": uid, "username": uname, "avatar": avatar, "verified": verified,
		"fullName": fullName, "enabled": enabled,
		"category": cat, "categoryLabel": "",
		"hours": hours, "address": addr, "phone": phone, "whatsapp": wa,
		"priceRange": price, "showChat": showChat, "productsCount": products,
		"hoursKnown": st.Known, "openNow": st.Open,
		"closesAt": st.ClosesAt, "opensAt": st.OpensAt, "opensDay": st.OpensDay,
		"isMine": uid == me, "lat": lat, "lon": lon,
	}
	if bc := businessCategoryByID(cat); bc != nil {
		out["categoryLabel"] = bc.label(lang)
	}
	if p := places.Get(placeID); p != nil {
		out["place"] = placeJSON(p, lang, -1)
		if lat == nil || lon == nil {
			out["lat"], out["lon"] = p.Lat, p.Lon
		}
	}
	if p := places.Get(cityID); p != nil {
		out["city"] = gin.H{"id": p.ID, "name": p.Name(lang)}
	}
	return out, nil
}

// GET /business/categories
func GetBusinessCategories(c *gin.Context) {
	lang := placeLang(c)
	out := make([]gin.H, 0, len(businessCategories))
	for _, b := range businessCategories {
		out = append(out, gin.H{"id": b.ID, "label": b.label(lang)})
	}
	c.JSON(http.StatusOK, gin.H{"categories": out})
}

// GET /business/me
func GetMyBusiness(c *gin.Context) {
	me := mw.UID(c)
	row := db.Pool.QueryRow(c.Request.Context(), businessSelect+` WHERE b.user_id=$1`, me)
	out, err := scanBusiness(row, me, placeLang(c), time.Now())
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"enabled": false})
		return
	}
	c.JSON(http.StatusOK, out)
}

// PUT /business/me — ба тиҷоратӣ гузаштан ё таҳрир.
func UpdateMyBusiness(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var b struct {
		Category   string        `json:"category"`
		Hours      businessHours `json:"hours"`
		Address    string        `json:"address"`
		PlaceID    string        `json:"placeId"`
		Lat        *float64      `json:"lat"`
		Lon        *float64      `json:"lon"`
		Phone      string        `json:"phone"`
		WhatsApp   string        `json:"whatsapp"`
		PriceRange int           `json:"priceRange"`
		ShowChat   *bool         `json:"showChat"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст", "code": "business_invalid"})
		return
	}
	bad := func(msg string) {
		c.JSON(http.StatusBadRequest, gin.H{"message": msg, "code": "business_invalid"})
	}
	if businessCategoryByID(b.Category) == nil {
		bad("Категорияро интихоб кунед")
		return
	}
	if b.Hours == nil {
		b.Hours = businessHours{}
	}
	if msg := b.Hours.validate(); msg != "" {
		bad(msg)
		return
	}
	if b.PriceRange < 0 || b.PriceRange > 4 {
		bad("Сатҳи нарх аз 0 то 4")
		return
	}
	phone, ok1 := cleanBizPhone(b.Phone)
	wa, ok2 := cleanBizPhone(b.WhatsApp)
	if !ok1 || !ok2 {
		bad("Рақами телефон нодуруст аст")
		return
	}
	b.Address = clampRunes(strings.TrimSpace(b.Address), 200)
	var lat, lon *float64
	if b.Lat != nil && b.Lon != nil && places.ValidCoords(*b.Lat, *b.Lon) {
		lat, lon = b.Lat, b.Lon
	}
	placeID, cityID := "", ""
	if p := places.Get(strings.TrimSpace(b.PlaceID)); p != nil {
		placeID = p.ID
		if cp := helpCityKey(p.ID); cp != nil {
			cityID = cp.ID
		}
	}
	showChat := true
	if b.ShowChat != nil {
		showChat = *b.ShowChat
	}
	var private bool
	db.Pool.QueryRow(ctx, `SELECT COALESCE(is_private,false) FROM users WHERE id=$1`, me).Scan(&private)
	if private {
		c.JSON(http.StatusConflict, gin.H{
			"message": "Ҳисоби пӯшида тиҷоратӣ шуда наметавонад — аввал онро кушода кунед",
			"code":    "business_private"})
		return
	}
	// Суроға ҳам ба тахтаи ҷамъиятӣ мебарояд — модератсия.
	if _, _, ok := captionAllowed(c, "business", b.Address); !ok {
		return
	}
	hoursJSON, _ := json.Marshal(b.Hours)
	if _, err := db.Pool.Exec(ctx, `
		INSERT INTO business_profiles(user_id, category, hours, address, place_id, city_id,
		    lat, lon, phone, whatsapp, price_range, show_chat)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)
		ON CONFLICT (user_id) DO UPDATE SET category=EXCLUDED.category, hours=EXCLUDED.hours,
		    address=EXCLUDED.address, place_id=EXCLUDED.place_id, city_id=EXCLUDED.city_id,
		    lat=EXCLUDED.lat, lon=EXCLUDED.lon, phone=EXCLUDED.phone, whatsapp=EXCLUDED.whatsapp,
		    price_range=EXCLUDED.price_range, show_chat=EXCLUDED.show_chat, updated_at=NOW()`,
		me, b.Category, string(hoursJSON), b.Address, placeID, cityID, lat, lon, phone, wa,
		b.PriceRange, showChat); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	db.Pool.Exec(ctx, `UPDATE users SET is_business=TRUE, business_category=$2 WHERE id=$1`,
		me, b.Category)
	mw.InvalidateUserCache(me)
	GetMyBusiness(c)
}

// DELETE /business/me — бозгашт ба ҳисоби шахсӣ (маълумот нигоҳ дошта
// мешавад, то бозгашти дубора ҳамаро аз нав пур накунад).
func DisableMyBusiness(c *gin.Context) {
	me := mw.UID(c)
	db.Pool.Exec(c.Request.Context(), `UPDATE users SET is_business=FALSE WHERE id=$1`, me)
	mw.InvalidateUserCache(me)
	c.JSON(http.StatusOK, gin.H{"enabled": false})
}

// trackBusiness — як сатр барои (тиҷорат, амал, тамошобин, рӯз).
func trackBusiness(ctx context.Context, bizID, action, viewer string) {
	if viewer == "" || viewer == bizID {
		return
	}
	day := time.Now().In(tjZone).Format("2006-01-02")
	db.Pool.Exec(ctx, `INSERT INTO business_events(business_id, action, viewer_id, day)
		VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`, bizID, action, viewer, day)
}

// loadPublicBusiness — тиҷорати фаъол, агар ба `me` намоён бошад.
func loadPublicBusiness(c *gin.Context, me, uid string) (gin.H, bool) {
	if ok, _ := CanSeeProfileContent(me, uid); !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return nil, false
	}
	row := db.Pool.QueryRow(c.Request.Context(), businessSelect+`
		WHERE b.user_id=$1 AND u.is_business=TRUE AND COALESCE(u.banned,false)=FALSE`, uid)
	out, err := scanBusiness(row, me, placeLang(c), time.Now())
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Профили тиҷоратӣ нест"})
		return nil, false
	}
	return out, true
}

// GET /business/:userId — маълумоти сарлавҳаи профил + сабти боздид.
func GetBusiness(c *gin.Context) {
	me, uid := mw.UID(c), c.Param("userId")
	out, ok := loadPublicBusiness(c, me, uid)
	if !ok {
		return
	}
	trackBusiness(context.WithoutCancel(c.Request.Context()), uid, "visit", me)
	c.JSON(http.StatusOK, out)
}

var businessTapActions = map[string]bool{"call": true, "whatsapp": true, "chat": true, "directions": true}

// POST /business/:userId/tap {action}
func TapBusiness(c *gin.Context) {
	me, uid := mw.UID(c), c.Param("userId")
	var b struct {
		Action string `json:"action"`
	}
	c.ShouldBindJSON(&b)
	if !businessTapActions[b.Action] {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Амали номаълум"})
		return
	}
	if _, ok := loadPublicBusiness(c, me, uid); !ok {
		return
	}
	trackBusiness(context.WithoutCancel(c.Request.Context()), uid, b.Action, me)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /business/me/insights?days=7|30
func GetBusinessInsights(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	days := toInt(c.Query("days"), 7)
	if days != 30 {
		days = 7
	}
	since := time.Now().In(tjZone).AddDate(0, 0, -(days - 1)).Format("2006-01-02")
	rows, err := db.Pool.Query(ctx, `
		SELECT day, action, COUNT(*) FROM business_events
		 WHERE business_id=$1 AND day >= $2::date
		 GROUP BY day, action`, me, since)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Бор нашуд"})
		return
	}
	defer rows.Close()
	totals := map[string]int{"visit": 0, "call": 0, "whatsapp": 0, "chat": 0, "directions": 0}
	daily := map[string]gin.H{}
	for rows.Next() {
		var day time.Time
		var action string
		var n int
		if rows.Scan(&day, &action, &n) != nil {
			continue
		}
		totals[action] += n
		k := day.Format("2006-01-02")
		d := daily[k]
		if d == nil {
			d = gin.H{"date": k, "visits": 0, "taps": 0}
			daily[k] = d
		}
		if action == "visit" {
			d["visits"] = d["visits"].(int) + n
		} else {
			d["taps"] = d["taps"].(int) + n
		}
	}
	var unique int
	db.Pool.QueryRow(ctx, `SELECT COUNT(DISTINCT viewer_id) FROM business_events
		WHERE business_id=$1 AND action='visit' AND day >= $2::date`, me, since).Scan(&unique)
	series := []gin.H{}
	start, _ := time.ParseInLocation("2006-01-02", since, tjZone)
	for i := 0; i < days; i++ {
		k := start.AddDate(0, 0, i).Format("2006-01-02")
		if d := daily[k]; d != nil {
			series = append(series, d)
		} else {
			series = append(series, gin.H{"date": k, "visits": 0, "taps": 0})
		}
	}
	taps := totals["call"] + totals["whatsapp"] + totals["chat"] + totals["directions"]
	c.JSON(http.StatusOK, gin.H{
		"days": days, "visits": totals["visit"], "uniqueVisitors": unique,
		"taps": gin.H{"call": totals["call"], "whatsapp": totals["whatsapp"],
			"chat": totals["chat"], "directions": totals["directions"], "total": taps},
		"daily": series,
	})
}

// GET /business/search?category=&city=&q=&page=
func SearchBusinesses(c *gin.Context) {
	me := mw.UID(c)
	page := clampPage(toInt(c.Query("page"), 1))
	limit := 20
	args := []any{me}
	where := []string{"u.is_business=TRUE", "COALESCE(u.banned,false)=FALSE",
		"COALESCE(u.is_private,false)=FALSE",
		`NOT EXISTS (SELECT 1 FROM blocks bl
		   WHERE (bl.blocker_id=$1 AND bl.blocked_id=u.id)
		      OR (bl.blocker_id=u.id AND bl.blocked_id=$1))`}
	if cat := strings.TrimSpace(c.Query("category")); cat != "" {
		args = append(args, cat)
		where = append(where, fmt.Sprintf("b.category=$%d", len(args)))
	}
	if city := strings.TrimSpace(c.Query("city")); city != "" {
		key := city
		if p := helpCityKey(city); p != nil {
			key = p.ID
		}
		args = append(args, key)
		where = append(where, fmt.Sprintf("b.city_id=$%d", len(args)))
	}
	if q := strings.TrimSpace(c.Query("q")); q != "" {
		args = append(args, "%"+strings.ToLower(clampRunes(q, 60))+"%")
		n := len(args)
		where = append(where, fmt.Sprintf(
			"(lower(u.username) LIKE $%d OR lower(COALESCE(u.full_name,'')) LIKE $%d OR lower(b.address) LIKE $%d)",
			n, n, n))
	}
	args = append(args, limit, (page-1)*limit)
	rows, err := db.Pool.Query(c.Request.Context(), businessSelect+" WHERE "+
		strings.Join(where, " AND ")+fmt.Sprintf(
		" ORDER BY COALESCE(u.followers_count,0) DESC, u.username LIMIT $%d OFFSET $%d",
		len(args)-1, len(args)), args...)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Ҷустуҷӯ нашуд"})
		return
	}
	defer rows.Close()
	lang, now := placeLang(c), time.Now()
	items := []gin.H{}
	for rows.Next() {
		if b, err := scanBusiness(rows, me, lang, now); err == nil {
			items = append(items, b)
		}
	}
	c.JSON(http.StatusOK, gin.H{"items": items, "page": page, "hasMore": len(items) == limit})
}
