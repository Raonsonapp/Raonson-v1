package handlers

import (
	"context"
	"math"
	"net/http"
	"strconv"
	"strings"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/places"

	"github.com/gin-gonic/gin"
)

// ═══════════════════════ ҶОЙҲО («Ҷой»-и пост) ═══════════════════════
//
// Рӯйхат дар худи сервер аст (backend/places/places.json) — ба хидмати
// берунии geocoding ҳеҷ координата фиристода намешавад ва координатаҳои
// корбар нигоҳ дошта намешаванд.

func placeLang(c *gin.Context) string {
	switch l := c.Query("lang"); l {
	case "ru", "en":
		return l
	}
	return "tj"
}

func placeJSON(p *places.Place, lang string, dist float64) gin.H {
	out := gin.H{
		"id": p.ID, "name": p.Name(lang), "kind": p.Kind,
		"nameTj": p.TJ, "nameRu": p.RU, "nameEn": p.EN,
		"region": p.Region(lang), "countryCode": p.CC,
		"lat": p.Lat, "lon": p.Lon,
	}
	if dist >= 0 {
		out["distanceKm"] = math.Round(dist*10) / 10
	}
	return out
}

// queryCoords — lat/lon аз query. ok=false агар нестанд ё нодурустанд.
func queryCoords(c *gin.Context) (lat, lon float64, ok bool) {
	ls, ns := c.Query("lat"), c.Query("lon")
	if ls == "" || ns == "" {
		return 0, 0, false
	}
	lat, e1 := strconv.ParseFloat(ls, 64)
	lon, e2 := strconv.ParseFloat(ns, 64)
	if e1 != nil || e2 != nil || !places.ValidCoords(lat, lon) {
		return 0, 0, false
	}
	return lat, lon, true
}

// GET /places/search?q=&lat=&lon=&limit=&lang=
func SearchPlaces(c *gin.Context) {
	lang := placeLang(c)
	lat, lon, hasLoc := queryCoords(c)
	q := strings.TrimSpace(c.Query("q"))
	if len([]rune(q)) > 80 {
		q = string([]rune(q)[:80])
	}
	res := places.Search(q, lat, lon, hasLoc, toInt(c.Query("limit"), 20))
	out := make([]gin.H, 0, len(res))
	for _, r := range res {
		out = append(out, placeJSON(r.Place, lang, r.DistanceKm))
	}
	c.JSON(http.StatusOK, gin.H{"places": out})
}

// GET /places/nearest?lat=&lon= — «Ҷойи ҳозираи ман».
func NearestPlace(c *gin.Context) {
	lat, lon, ok := queryCoords(c)
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"message": "lat ва lon лозиманд"})
		return
	}
	lang := placeLang(c)
	nearby := []gin.H{}
	for _, r := range places.Nearby(lat, lon, 15) {
		nearby = append(nearby, placeJSON(r.Place, lang, r.DistanceKm))
	}
	var place interface{}
	if p, d := places.Nearest(lat, lon); p != nil {
		place = placeJSON(p, lang, d)
	}
	c.JSON(http.StatusOK, gin.H{"place": place, "nearby": nearby})
}

// GET /places/:id
func GetPlace(c *gin.Context) {
	p := places.Get(c.Param("id"))
	if p == nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ҷой ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"place": placeJSON(p, placeLang(c), -1)})
}

// Шарти умумии саҳифаи ҷой: мисли саҳифаи ҳаштаг — кашф аст, бинобар
// ин танҳо ҳисобҳои кушода, бе бастшуда/манъшуда, бе пинҳон/бойгонӣ/
// ҳанӯз нашрнашуда.
var placePostsFilter = `
	  AND COALESCE(p.hidden,false)=false
	  AND COALESCE(p.archived,false)=false
	  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())
	  AND ` + publicAuthorSQL("p.user_id", "u", "$1") + `
	ORDER BY p.created_at DESC LIMIT $3 OFFSET $4`

// GET /places/:id/posts — саҳифаи ҷой (мисли Instagram).
//
// Постҳои нав аз рӯи location_id; постҳои кӯҳна (танҳо матн) — агар
// матнашон айнан яке аз номҳои ҳамин ҷой бошад.
func PlacePosts(c *gin.Context) {
	p := places.Get(c.Param("id"))
	if p == nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ҷой ёфт нашуд", "posts": []gin.H{}})
		return
	}
	myID := mw.UID(c)
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 24))
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE (p.location_id = $2
		       OR (COALESCE(p.location_id,'') = '' AND p.location = ANY($5::text[])))`+
			placePostsFilter,
		myID, p.ID, limit, (page-1)*limit, p.TextVariants())
	posts := []gin.H{}
	if err == nil {
		posts = scanFeedPosts(rows)
	}
	c.JSON(http.StatusOK, gin.H{"place": placeJSON(p, placeLang(c), -1), "posts": posts})
}

// GET /places/text/posts?name= — ҷойи дастӣ (берун аз рӯйхат): постҳое,
// ки ҳамин матнро доранд. Агар матн ба як ҷойи рӯйхат мувофиқ бошад,
// он ҷой низ бармегардад, то барнома ба саҳифаи пурра гузарад.
func PlaceTextPosts(c *gin.Context) {
	name := strings.TrimSpace(c.Query("name"))
	if name == "" || len([]rune(name)) > 120 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "name лозим аст", "posts": []gin.H{}})
		return
	}
	lang := placeLang(c)
	var place interface{}
	if p := places.MatchExact(name); p != nil {
		place = placeJSON(p, lang, -1)
	}
	myID := mw.UID(c)
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 24))
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE COALESCE(p.location_id,'') = '' AND p.location = $2`+placePostsFilter,
		myID, name, limit, (page-1)*limit)
	posts := []gin.H{}
	if err == nil {
		posts = scanFeedPosts(rows)
	}
	c.JSON(http.StatusOK, gin.H{"place": place, "name": name, "posts": posts})
}

// resolvePostLocation — «Ҷой»-и пости нав: id-и дуруст аз рӯйхат →
// ном (агар холӣ), id ва координатаҳои ҶОЙ. Бе id — агар матн айнан ба
// як ҷой мувофиқ бошад, ҳамон ҷой (то пост дар саҳифаи ҷой бошад).
func resolvePostLocation(text, id string) (name, placeID string, lat, lon *float64) {
	name = clampRunes(strings.TrimSpace(text), 120)
	p := places.Get(strings.TrimSpace(id))
	if p == nil && name != "" {
		p = places.MatchExact(name)
	}
	if p == nil {
		return name, "", nil, nil
	}
	if name == "" {
		name = p.TJ
	}
	la, lo := p.Lat, p.Lon
	return name, p.ID, &la, &lo
}
