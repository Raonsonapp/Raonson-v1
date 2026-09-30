package handlers

// Рекламаи дохилӣ: VIP ҳеҷ чиз намегирад, «in_review» ба корбар
// намеравад, намоиш як бор дар рӯз ҳисоб мешавад.
//
// Тестҳои база бе RAONSON_TEST_DB гузаронда мешаванд.

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	mw "raonson/middleware"
)

func TestCtaForGoal(t *testing.T) {
	cases := map[string]string{
		"website":  "Бештар",
		"install":  "Насб кардан",
		"messages": "Паём фиристед",
		"profile":  "Дидани профил",
		"":         "Дидани профил",
	}
	for goal, want := range cases {
		if got := ctaFor(goal); got != want {
			t.Errorf("ctaFor(%q)=%q, бояд %q", goal, got, want)
		}
	}
}

func TestSponsoredLimitIsBounded(t *testing.T) {
	// Ҳадди боло — то барнома садҳо рекламаро якбора напурсад.
	for raw, want := range map[string]int{"": 6, "x": 6, "-1": 6, "3": 3, "999": 10} {
		if got := sponsoredLimit(raw); got != want {
			t.Errorf("sponsoredLimit(%q)=%d, бояд %d", raw, got, want)
		}
	}
}

func TestOwnerIsAlwaysAdsFree(t *testing.T) {
	for _, u := range []string{"raonson", "RaonSon", " raonson "} {
		if !IsAdsFreeUsername(u) {
			t.Errorf("%q бояд бе реклама бошад", u)
		}
	}
	if IsAdsFreeUsername("raonson2") {
		t.Error("raonson2 соҳиб нест")
	}
}

// ── База ─────────────────────────────────────────────────────────

func sponsoredRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/ads", mw.Auth())
	g.GET("/sponsored", GetSponsored)
	g.POST("/sponsored/:id/impression", SponsoredImpression)
	g.POST("/sponsored/:id/hide", HideSponsored)
	return r
}

// promo — пости видеоӣ бо промоушн дар ҳолати додашуда.
func promo(t *testing.T, pool *pgxpool.Pool, owner, status string) string {
	t.Helper()
	ctx := context.Background()
	var postID, id string
	if err := pool.QueryRow(ctx,
		`INSERT INTO posts(user_id, caption) VALUES ($1,'ad') RETURNING id`,
		owner).Scan(&postID); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx,
		`INSERT INTO post_media(post_id,url,type) VALUES ($1,'https://x/v.mp4','video')`,
		postID); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `
		INSERT INTO promotions(user_id,post_id,goal,status,ends_at)
		VALUES ($1,$2,'website',$3,NOW()+INTERVAL '1 day') RETURNING id`,
		owner, postID, status).Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

func getSponsored(t *testing.T, r *gin.Engine, token string) (bool, []string) {
	t.Helper()
	req := httptest.NewRequest(http.MethodGet,
		"/ads/sponsored?placement=reels&limit=10", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Fatalf("status %d: %s", w.Code, w.Body.String())
	}
	var body struct {
		AdsFree bool `json:"adsFree"`
		Items   []struct {
			ID string `json:"id"`
		} `json:"items"`
	}
	json.Unmarshal(w.Body.Bytes(), &body)
	ids := []string{}
	for _, it := range body.Items {
		ids = append(ids, it.ID)
	}
	return body.AdsFree, ids
}

func containsID(ids []string, id string) bool {
	for _, x := range ids {
		if x == id {
			return true
		}
	}
	return false
}

func TestSponsoredRespectsVipAndReview(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	r := sponsoredRouter()

	advertiser := adsUser(t, pool)
	viewer := adsUser(t, pool)
	vip := adsUser(t, pool)
	pool.Exec(context.Background(), `UPDATE users SET is_vip=TRUE WHERE id=$1`, vip)

	active := promo(t, pool, advertiser, "active")
	pending := promo(t, pool, advertiser, "in_review")

	free, ids := getSponsored(t, r, tokenFor(t, viewer))
	if free {
		t.Fatal("корбари оддӣ VIP ҳисоб шуд")
	}
	if !containsID(ids, active) {
		t.Fatal("промоушни тасдиқшуда намеояд")
	}
	if containsID(ids, pending) {
		t.Fatal("промоушни «in_review» ба корбар рафт")
	}

	free, ids = getSponsored(t, r, tokenFor(t, vip))
	if !free || len(ids) != 0 {
		t.Fatalf("VIP реклама гирифт: adsFree=%v items=%v", free, ids)
	}

	// Пинҳон кардан — дигар намеояд.
	do(t, r, "/ads/sponsored/"+active+"/hide", tokenFor(t, viewer), nil)
	_, ids = getSponsored(t, r, tokenFor(t, viewer))
	if containsID(ids, active) {
		t.Fatal("рекламаи пинҳоншуда боз омад")
	}
}

func TestSponsoredImpressionCountsOncePerDay(t *testing.T) {
	pool := adsTestDB(t)
	adsHTTPSetup(t)
	r := sponsoredRouter()

	advertiser := adsUser(t, pool)
	viewer := adsUser(t, pool)
	vip := adsUser(t, pool)
	pool.Exec(context.Background(), `UPDATE users SET is_vip=TRUE WHERE id=$1`, vip)
	id := promo(t, pool, advertiser, "active")

	for i := 0; i < 3; i++ {
		do(t, r, "/ads/sponsored/"+id+"/impression", tokenFor(t, viewer), nil)
	}
	// VIP рекламаро намебинад — ҳисоб ҳам намешавад.
	do(t, r, "/ads/sponsored/"+id+"/impression", tokenFor(t, vip), nil)

	var n int
	pool.QueryRow(context.Background(),
		`SELECT impressions FROM promotions WHERE id=$1`, id).Scan(&n)
	if n != 1 {
		t.Fatalf("impressions=%d, бояд 1", n)
	}
}
