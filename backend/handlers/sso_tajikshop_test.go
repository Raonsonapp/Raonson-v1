package handlers

// SSO бо TajikShop. TajikShop-и қалбакӣ — httptest (ҳамон шартнома:
// {success,data}, X-Partner-Key, коди якдафъаина, /auth/refresh,
// /sso/code). Қисми база бе RAONSON_TEST_DB + DATABASE_URL гузаронда
// мешавад.

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── TajikShop-и қалбакӣ ────────────────────────────────────────────

type fakeTS struct {
	mu       sync.Mutex
	key      string
	rotate   bool
	codes    map[string]map[string]any // код → user
	refresh  map[string]string         // refresh → user id
	access   map[string]string         // access → user id
	issued   []string                  // кодҳои /sso/code
	n        int
	srv      *httptest.Server
	exchange int
}

func newFakeTS(t *testing.T, key string) *fakeTS {
	f := &fakeTS{key: key, codes: map[string]map[string]any{},
		refresh: map[string]string{}, access: map[string]string{}}
	f.srv = httptest.NewServer(http.HandlerFunc(f.serve))
	t.Cleanup(f.srv.Close)
	t.Setenv("TAJIKSHOP_API", f.srv.URL+"/api/v1")
	t.Setenv("SSO_PARTNER_KEY", key)
	t.Setenv("TAJIKSHOP_PARTNER_KEY", "")
	return f
}

// code — коди нав барои корбари TajikShop (43 аломат, мисли аслӣ).
func (f *fakeTS) code(id, name, email string) string {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.n++
	c := fmt.Sprintf("%043d", f.n)
	c = "C" + c[1:]
	f.codes[c] = map[string]any{"id": id, "name": name, "email": email,
		"role": "user", "avatar_url": "", "is_seller": false, "is_verified": false}
	return c
}

func fakeWrite(w http.ResponseWriter, st int, body map[string]any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(st)
	json.NewEncoder(w).Encode(body)
}

func (f *fakeTS) serve(w http.ResponseWriter, r *http.Request) {
	var in map[string]string
	json.NewDecoder(r.Body).Decode(&in)
	f.mu.Lock()
	defer f.mu.Unlock()
	fail := func(st int, msg string) { fakeWrite(w, st, map[string]any{"success": false, "error": msg}) }
	okd := func(d map[string]any) { fakeWrite(w, 200, map[string]any{"success": true, "data": d}) }
	switch r.URL.Path {
	case "/api/v1/sso/exchange":
		f.exchange++
		if in["app"] != "raonson" {
			fail(400, "Барномаи номаълум")
			return
		}
		if r.Header.Get("X-Partner-Key") != f.key {
			fail(401, "Калиди шарик нодуруст")
			return
		}
		u, ok := f.codes[in["code"]]
		if !ok {
			fail(401, "Код нодуруст ё мӯҳлаташ гузашт")
			return
		}
		delete(f.codes, in["code"])
		f.n++
		acc, ref := fmt.Sprintf("acc-%d", f.n), fmt.Sprintf("ref-%d", f.n)
		f.access[acc] = u["id"].(string)
		f.refresh[ref] = u["id"].(string)
		okd(map[string]any{"access_token": acc, "refresh_token": ref, "user": u})
	case "/api/v1/auth/refresh":
		uid, ok := f.refresh[in["refresh_token"]]
		if !ok {
			fail(401, "token mismatch")
			return
		}
		f.n++
		acc := fmt.Sprintf("acc-%d", f.n)
		f.access[acc] = uid
		out := map[string]any{"access_token": acc}
		if f.rotate {
			delete(f.refresh, in["refresh_token"])
			nr := fmt.Sprintf("ref-%d", f.n)
			f.refresh[nr] = uid
			out["refresh_token"] = nr
		}
		okd(out)
	case "/api/v1/sso/code":
		tok := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if _, ok := f.access[tok]; !ok {
			fail(401, "unauthorized")
			return
		}
		if in["target_app"] != "tajikshop" {
			fail(400, "Барномаи номаълум")
			return
		}
		f.n++
		c := fmt.Sprintf("T%042d", f.n)
		f.issued = append(f.issued, c)
		fakeWrite(w, 201, map[string]any{"success": true, "data": map[string]any{
			"code": c, "expires_in": 120, "deep_link": "tajikshop://sso?code=" + c,
			"fallback": "https://play.google.com/store/apps/details?id=com.tajikshop.app"}})
	default:
		fail(404, "not found")
	}
}

// ── Тестҳои бе база ────────────────────────────────────────────────

func TestSSOTokenSealRoundTrip(t *testing.T) {
	t.Setenv("JWT_SECRET", "jwt-test")
	t.Setenv("SSO_TOKEN_KEY", "")
	s, err := sealSSOToken("refresh-secret-value")
	if err != nil || !strings.HasPrefix(s, "v1:") {
		t.Fatalf("seal: %q %v", s, err)
	}
	if strings.Contains(s, "refresh-secret-value") {
		t.Fatal("token кушода дар сабт")
	}
	s2, _ := sealSSOToken("refresh-secret-value")
	if s == s2 {
		t.Fatal("nonce такрор шуд")
	}
	if p, err := openSSOToken(s); err != nil || p != "refresh-secret-value" {
		t.Fatalf("open: %q %v", p, err)
	}
	// Тағйири як байт → рад.
	b := []byte(s)
	b[len(b)-2] ^= 1
	if _, err := openSSOToken(string(b)); err == nil {
		t.Fatal("сабти тағйирёфта кушода шуд")
	}
	// Калиди дигар (SSO_TOKEN_KEY) → кушода намешавад.
	t.Setenv("SSO_TOKEN_KEY", "other-key")
	if _, err := openSSOToken(s); err == nil {
		t.Fatal("бо калиди дигар кушода шуд")
	}
	if e, _ := sealSSOToken(""); e != "" {
		t.Fatal("холӣ → холӣ")
	}
}

func TestValidSSOCode(t *testing.T) {
	good := []string{strings.Repeat("a", 43), "dX7-_kQ0123456789abcdef", strings.Repeat("Z", 64)}
	bad := []string{"", "short", strings.Repeat("a", 65), "abc def ghijklmnopqrs",
		"abcdefghijklmnop/q", "abcdefghijklmnop=q", "абвгдежзийклмнопр"}
	for _, c := range good {
		if !validSSOCode(c) {
			t.Errorf("%q бояд дуруст бошад", c)
		}
	}
	for _, c := range bad {
		if validSSOCode(c) {
			t.Errorf("%q бояд рад шавад", c)
		}
	}
}

func TestUsernameBaseAndMasks(t *testing.T) {
	cases := map[string]string{
		"Эҳсон Маҳмадмуродов": "ehson_mahmadmurodov",
		"Ali Valiev":          "ali_valiev",
		"  Ҷамшед--Қодирӣ ":   "jamshed_qodiri",
		"!!!":                 "",
		"Ғафур.Ҳасанов":       "ghafur.hasanov",
	}
	for in, want := range cases {
		if got := usernameBase(in); got != want {
			t.Errorf("usernameBase(%q) = %q, want %q", in, got, want)
		}
	}
	if got := usernameBase(strings.Repeat("a", 40)); len(got) != 20 {
		t.Errorf("дарозӣ: %q", got)
	}
	if got := maskPersonName("Ehson Mahmadmurodov"); got != "Ehson M." {
		t.Errorf("maskPersonName = %q", got)
	}
	if got := maskPersonName(""); got != "" {
		t.Errorf("maskPersonName холӣ = %q", got)
	}
}

func TestTajikshopClientAgainstFake(t *testing.T) {
	f := newFakeTS(t, "test-key")
	ctx := context.Background()

	// Муваффақ.
	c := f.code("ts-1", "Ali", "ali@example.com")
	ex, err := tsExchangeCode(ctx, c)
	if err != nil || ex.User.ID != "ts-1" || ex.RefreshToken == "" || ex.AccessToken == "" {
		t.Fatalf("exchange: %+v %v", ex, err)
	}
	// Код якдафъаина: такрор → invalid_code (401).
	_, err = tsExchangeCode(ctx, c)
	if fl := mapExchangeError(err); fl.HTTP != 401 || fl.Code != "invalid_code" || fl.Message != msgSSOInvalidCode {
		t.Fatalf("коди истифодашуда: %+v", fl)
	}
	// Калиди нодуруст → 503 (хатои танзими мо).
	t.Setenv("SSO_PARTNER_KEY", "wrong")
	_, err = tsExchangeCode(ctx, f.code("ts-2", "B", ""))
	if fl := mapExchangeError(err); fl.HTTP != 503 || fl.Message != msgSSONotConfigured {
		t.Fatalf("калиди нодуруст: %+v", fl)
	}
	// Ном аз TAJIKSHOP_PARTNER_KEY (alias) ҳам хонда мешавад.
	t.Setenv("SSO_PARTNER_KEY", "")
	t.Setenv("TAJIKSHOP_PARTNER_KEY", "test-key")
	if tajikshopPartnerKey() != "test-key" {
		t.Fatal("alias хонда нашуд")
	}
	// Барномаи номаълум → 503.
	if fl := mapExchangeError(&tsError{Status: 400, Msg: "Барномаи номаълум"}); fl.HTTP != 503 {
		t.Fatalf("барномаи номаълум: %+v", fl)
	}
	// Шабака → 502.
	if fl := mapExchangeError(&tsError{Status: 0, Msg: "network"}); fl.HTTP != 502 {
		t.Fatalf("шабака: %+v", fl)
	}

	// Refresh бе ротатсия ва бо ротатсия.
	acc, nr, err := tsRefresh(ctx, ex.RefreshToken)
	if err != nil || acc == "" || nr != "" {
		t.Fatalf("refresh: %q %q %v", acc, nr, err)
	}
	f.rotate = true
	acc2, nr2, err := tsRefresh(ctx, ex.RefreshToken)
	if err != nil || acc2 == "" || nr2 == "" || nr2 == ex.RefreshToken {
		t.Fatalf("ротатсия: %q %q %v", acc2, nr2, err)
	}
	if _, _, err := tsRefresh(ctx, ex.RefreshToken); tsErrStatus(err) != 401 {
		t.Fatalf("refresh-и кӯҳна бояд 401 диҳад: %v", err)
	}

	// Коди гузариш ба TajikShop.
	dl, fb, err := tsIssueCode(ctx, acc2)
	if err != nil || !strings.HasPrefix(dl, "tajikshop://sso?code=T") || !strings.HasPrefix(fb, "https://play.google.com/") {
		t.Fatalf("code: %q %q %v", dl, fb, err)
	}
	if _, _, err := tsIssueCode(ctx, "bad"); err == nil {
		t.Fatal("access-и нодуруст код гирифт")
	}
}

// ── Тестҳои база ───────────────────────────────────────────────────

func ssoDB(t *testing.T) {
	t.Helper()
	adsTestDB(t)
	// recordLogin дар goroutine менависад — пеш аз баргардонидани
	// db.Pool (adsTestDB) интизор мешавем, то он ба nil наафтад.
	t.Cleanup(func() { time.Sleep(300 * time.Millisecond) })
	if _, err := db.Pool.Exec(context.Background(), db.SSOSchema); err != nil {
		t.Fatal(err)
	}
	t.Setenv("JWT_SECRET", "sso-test-secret")
	t.Setenv("JWT_REFRESH_SECRET", "sso-test-secret-2")
}

func ssoRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/auth/sso/tajikshop", mw.OptionalAuth(), TajikshopSSOLogin)
	r.POST("/auth/sso/tajikshop/link", mw.Auth(), TajikshopSSOLink)
	g := r.Group("/sso/tajikshop", mw.Auth())
	g.GET("/status", TajikshopSSOStatus)
	g.DELETE("/link", TajikshopSSOUnlink)
	g.POST("/handoff", TajikshopSSOHandoff)
	return r
}

func ssoDo(t *testing.T, r *gin.Engine, method, path, tok string, body any) (int, map[string]any) {
	t.Helper()
	var rd *strings.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rd = strings.NewReader(string(b))
	} else {
		rd = strings.NewReader("")
	}
	req := httptest.NewRequest(method, path, rd)
	req.Header.Set("Content-Type", "application/json")
	if tok != "" {
		req.Header.Set("Authorization", "Bearer "+tok)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	var out map[string]any
	json.Unmarshal(w.Body.Bytes(), &out)
	return w.Code, out
}

func ssoUser(t *testing.T, email, password string) (string, string) {
	t.Helper()
	n := fmt.Sprintf("ssot_%d", time.Now().UnixNano())
	var id string
	if err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO users(username, email, password) VALUES ($1,$2,$3) RETURNING id`,
		n, email, password).Scan(&id); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, id) })
	return id, makeJWT(id, mw.JWTSecret(), time.Hour)
}

func uniqTS(p string) string { return fmt.Sprintf("%s-%d", p, time.Now().UnixNano()) }

func cleanupExt(t *testing.T, extID string) {
	t.Cleanup(func() {
		ctx := context.Background()
		var uid string
		db.Pool.QueryRow(ctx, `SELECT user_id FROM external_accounts WHERE external_id=$1`, extID).Scan(&uid)
		db.Pool.Exec(ctx, `DELETE FROM external_accounts WHERE external_id=$1`, extID)
		db.Pool.Exec(ctx, `DELETE FROM sso_pending_links WHERE external_id=$1`, extID)
		if uid != "" {
			db.Pool.Exec(ctx, `DELETE FROM users WHERE id=$1 AND password=''`, uid)
		}
	})
}

func TestSSONewAccountThenAlreadyLinkedLogin(t *testing.T) {
	ssoDB(t)
	f := newFakeTS(t, "test-key")
	r := ssoRouter()
	ext := uniqTS("ts-new")
	cleanupExt(t, ext)
	email := strings.ToLower(ext) + "@shop.test"

	st, b := ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": f.code(ext, "Эҳсон Тест", email)})
	if st != 200 || b["status"] != "created" || b["needsProfileSetup"] != true || b["accessToken"] == nil {
		t.Fatalf("ҳисоби нав: %d %v", st, b)
	}
	uid := b["user"].(map[string]any)["id"].(string)
	uname := b["user"].(map[string]any)["username"].(string)
	if !strings.HasPrefix(uname, "ehson_test") {
		t.Errorf("номи корбар: %q", uname)
	}
	var dbEmail, pw, sealed string
	var verified bool
	db.Pool.QueryRow(context.Background(), `SELECT COALESCE(email,''), password, COALESCE(email_verified,false)
		FROM users WHERE id=$1`, uid).Scan(&dbEmail, &pw, &verified)
	if dbEmail != email || pw != "" || verified {
		t.Errorf("корбар: email=%q pw=%q verified=%v", dbEmail, pw, verified)
	}
	db.Pool.QueryRow(context.Background(), `SELECT ts_refresh_token FROM external_accounts
		WHERE provider='tajikshop' AND external_id=$1`, ext).Scan(&sealed)
	if !strings.HasPrefix(sealed, "v1:") || strings.Contains(sealed, "ref-") {
		t.Fatalf("token рамзгузорӣ нашуд: %q", sealed)
	}

	// Дафъаи дуюм — ҳамон корбар, бе ҳисоби нав.
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": f.code(ext, "Эҳсон Тест", email)})
	if st != 200 || b["status"] != "logged_in" || b["user"].(map[string]any)["id"] != uid {
		t.Fatalf("вуруди дуюм: %d %v", st, b)
	}
	// Token-и додашуда бо middleware-и мо кор мекунад (token_version).
	st, s := ssoDo(t, r, "GET", "/sso/tajikshop/status", b["accessToken"].(string), nil)
	if st != 200 || s["linked"] != true || s["hasPassword"] != false {
		t.Fatalf("status: %d %v", st, s)
	}
	if em := s["tajikshop"].(map[string]any)["email"].(string); em == email || !strings.Contains(em, "***") {
		t.Errorf("почта пӯшида нест: %q", em)
	}
	// Бе рамз ҷудо кардан манъ аст.
	st, u := ssoDo(t, r, "DELETE", "/sso/tajikshop/link", b["accessToken"].(string), nil)
	if st != 409 || u["code"] != "password_required" {
		t.Fatalf("ҷудо бе рамз: %d %v", st, u)
	}
}

func TestSSOEmailCollisionRequiresLink(t *testing.T) {
	ssoDB(t)
	f := newFakeTS(t, "test-key")
	r := ssoRouter()
	ext := uniqTS("ts-col")
	cleanupExt(t, ext)
	email := strings.ToLower(ext) + "@victim.test"
	victim, vtok := ssoUser(t, email, "$2a$10$hash")

	st, b := ssoDo(t, r, "POST", "/auth/sso/tajikshop", "",
		gin.H{"code": f.code(ext, "Attacker", strings.ToUpper(email))})
	if st != 409 || b["code"] != "link_required" || b["accessToken"] != nil {
		t.Fatalf("бояд link_required бошад: %d %v", st, b)
	}
	if m, _ := b["email"].(string); m == email || !strings.Contains(m, "***") {
		t.Errorf("почта пӯшида нест: %q", m)
	}
	pending, _ := b["pendingToken"].(string)
	if len(pending) != 43 {
		t.Fatalf("pendingToken: %q", pending)
	}
	if l, _ := ssoLinkByExt(context.Background(), ext); l != nil {
		t.Fatal("худкор пайваст шуд!")
	}
	// Бе ворид /link кор намекунад.
	if st, _ := ssoDo(t, r, "POST", "/auth/sso/tajikshop/link", "", gin.H{"pendingToken": pending}); st != 401 {
		t.Fatalf("бе ворид: %d", st)
	}
	// Баъди вуруд бо рамзи Raonson — пайваст.
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop/link", vtok, gin.H{"pendingToken": pending})
	if st != 200 || b["linked"] != true {
		t.Fatalf("тасдиқ: %d %v", st, b)
	}
	// Token якдафъаина.
	if st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop/link", vtok, gin.H{"pendingToken": pending}); st != 401 {
		t.Fatalf("token дубора кор кард: %d %v", st, b)
	}
	// Акнун TajikShop → ҳамон ҳисоби Raonson.
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": f.code(ext, "Attacker", email)})
	if st != 200 || b["user"].(map[string]any)["id"] != victim {
		t.Fatalf("вуруди баъди пайванд: %d %v", st, b)
	}
}

func TestSSOPendingExpires(t *testing.T) {
	ssoDB(t)
	ctx := context.Background()
	ext := uniqTS("ts-exp")
	cleanupExt(t, ext)
	tok, err := ssoCreatePending(ctx, ext, "N", "", "")
	if err != nil {
		t.Fatal(err)
	}
	var n int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM sso_pending_links WHERE token_hash=$1`, tok).Scan(&n)
	if n != 0 {
		t.Fatal("token кушода дар база")
	}
	db.Pool.Exec(ctx, `UPDATE sso_pending_links SET expires_at=NOW()-INTERVAL '1 second' WHERE external_id=$1`, ext)
	if _, _, _, _, err := ssoConsumePending(ctx, tok); err == nil {
		t.Fatal("token-и гузашта кор кард")
	}
}

func TestSSOLinkWhileLoggedIn(t *testing.T) {
	ssoDB(t)
	f := newFakeTS(t, "test-key")
	r := ssoRouter()
	ext := uniqTS("ts-link")
	cleanupExt(t, ext)
	me, tok := ssoUser(t, uniqTS("me")+"@raonson.test", "$2a$10$hash")
	other, otok := ssoUser(t, uniqTS("other")+"@raonson.test", "$2a$10$hash")

	// Бе интихоби «Пайваст кардан» — тасдиқ пурсида мешавад.
	st, b := ssoDo(t, r, "POST", "/auth/sso/tajikshop", tok, gin.H{"code": f.code(ext, "Me", "")})
	if st != 200 || b["status"] != "confirm_link" || b["pendingToken"] == nil || b["accessToken"] != nil {
		t.Fatalf("confirm_link: %d %v", st, b)
	}
	// Бо link:true — фавран.
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", tok, gin.H{"code": f.code(ext, "Me", ""), "link": true})
	if st != 200 || b["status"] != "linked" {
		t.Fatalf("link: %d %v", st, b)
	}
	if l, _ := ssoLinkByUser(context.Background(), me); l == nil || l.ExtID != ext {
		t.Fatal("пайванд сабт нашуд")
	}
	// Корбари дигар ҳамин TajikShop-ро пайваст карда наметавонад.
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", otok, gin.H{"code": f.code(ext, "Me", ""), "link": true})
	if st != 409 || b["code"] != "linked_other" {
		t.Fatalf("linked_other: %d %v", st, b)
	}
	// Ман TajikShop-и дуюмро пайваст карда наметавонам.
	ext2 := uniqTS("ts-link2")
	cleanupExt(t, ext2)
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop/link", tok, gin.H{"code": f.code(ext2, "X", "")})
	if st != 409 || b["code"] != "already_linked" {
		t.Fatalf("already_linked: %d %v", st, b)
	}
	_ = other

	// Ҷудо кардан (рамз ҳаст).
	st, b = ssoDo(t, r, "DELETE", "/sso/tajikshop/link", tok, nil)
	if st != 200 || b["linked"] != false {
		t.Fatalf("unlink: %d %v", st, b)
	}
	var n int
	db.Pool.QueryRow(context.Background(), `SELECT COUNT(*) FROM external_accounts WHERE user_id=$1`, me).Scan(&n)
	if n != 0 {
		t.Fatal("сабт пок нашуд")
	}
}

func TestSSOBannedUserCannotSignIn(t *testing.T) {
	ssoDB(t)
	f := newFakeTS(t, "test-key")
	r := ssoRouter()
	ext := uniqTS("ts-ban")
	cleanupExt(t, ext)
	uid, _ := ssoUser(t, uniqTS("ban")+"@raonson.test", "$2a$10$hash")
	if err := ssoLinkAccount(context.Background(), uid, ext, "B", "", ""); err != nil {
		t.Fatal(err)
	}
	db.Pool.Exec(context.Background(), `UPDATE users SET banned=TRUE WHERE id=$1`, uid)
	mw.ForgetTokenState(uid)
	st, b := ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": f.code(ext, "B", "")})
	if st != 403 || b["accessToken"] != nil {
		t.Fatalf("баста ворид шуд: %d %v", st, b)
	}
}

func TestSSOConfigAndCodeErrors(t *testing.T) {
	ssoDB(t)
	f := newFakeTS(t, "test-key")
	r := ssoRouter()

	st, b := ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": "x"})
	if st != 400 || b["message"] != msgSSOInvalidCode {
		t.Fatalf("формат: %d %v", st, b)
	}
	before := f.exchange
	ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": "bad code with spaces!!"})
	if f.exchange != before {
		t.Fatal("коди нодуруст ба TajikShop рафт")
	}
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": strings.Repeat("Q", 43)})
	if st != 401 || b["code"] != "invalid_code" {
		t.Fatalf("коди номаълум: %d %v", st, b)
	}
	t.Setenv("SSO_PARTNER_KEY", "wrong-key")
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": f.code("x", "x", "")})
	if st != 503 || b["message"] != msgSSONotConfigured {
		t.Fatalf("калиди нодуруст: %d %v", st, b)
	}
	t.Setenv("SSO_PARTNER_KEY", "")
	st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", "", gin.H{"code": f.code("x", "x", "")})
	if st != 503 || b["code"] != "sso_not_configured" {
		t.Fatalf("бе калид: %d %v", st, b)
	}
}

func TestSSOHandoff(t *testing.T) {
	ssoDB(t)
	f := newFakeTS(t, "test-key")
	f.rotate = true
	r := ssoRouter()
	ext := uniqTS("ts-hand")
	cleanupExt(t, ext)
	_, tok := ssoUser(t, uniqTS("hand")+"@raonson.test", "$2a$10$hash")

	st, b := ssoDo(t, r, "POST", "/sso/tajikshop/handoff", tok, nil)
	if st != 200 || b["linked"] != false || b["deep_link"] != "tajikshop://" ||
		!strings.HasPrefix(b["fallback"].(string), "https://play.google.com/") {
		t.Fatalf("бе пайванд: %d %v", st, b)
	}
	if st, b = ssoDo(t, r, "POST", "/auth/sso/tajikshop", tok, gin.H{"code": f.code(ext, "H", ""), "link": true}); st != 200 {
		t.Fatalf("link: %d %v", st, b)
	}
	ctx := context.Background()
	l1, _ := ssoLinkByExt(ctx, ext)

	st, b = ssoDo(t, r, "POST", "/sso/tajikshop/handoff", tok, nil)
	dl, _ := b["deep_link"].(string)
	if st != 200 || b["handoff"] != true || !strings.HasPrefix(dl, "tajikshop://sso?code=") {
		t.Fatalf("handoff: %d %v", st, b)
	}
	if code := strings.TrimPrefix(dl, "tajikshop://sso?code="); code != f.issued[len(f.issued)-1] {
		t.Fatalf("код: %q", code)
	}
	// Ротатсия: token-и нав (рамзгузоришуда) сабт шуд.
	l2, _ := ssoLinkByExt(ctx, ext)
	if l2.Sealed == l1.Sealed || !strings.HasPrefix(l2.Sealed, "v1:") {
		t.Fatal("refresh-и нав сабт нашуд")
	}
	if st, b = ssoDo(t, r, "POST", "/sso/tajikshop/handoff", tok, nil); b["handoff"] != true {
		t.Fatalf("handoff-и дуюм бо token-и нав: %d %v", st, b)
	}

	// Сессияи TajikShop бекор → «tajikshop://» ва token пок.
	f.mu.Lock()
	f.refresh = map[string]string{}
	f.mu.Unlock()
	st, b = ssoDo(t, r, "POST", "/sso/tajikshop/handoff", tok, nil)
	if st != 200 || b["handoff"] != false || b["reason"] != "session_expired" || b["deep_link"] != "tajikshop://" {
		t.Fatalf("сессияи гузашта: %d %v", st, b)
	}
	l3, _ := ssoLinkByExt(ctx, ext)
	if l3.Sealed != "" {
		t.Fatal("token-и мурда пок нашуд")
	}
}

func TestSSODeleteAccountRemovesLink(t *testing.T) {
	ssoDB(t)
	ctx := context.Background()
	ext := uniqTS("ts-del")
	cleanupExt(t, ext)
	uid, _ := ssoUser(t, uniqTS("del")+"@raonson.test", "$2a$10$hash")
	s, _ := sealSSOToken("ref-x")
	if err := ssoLinkAccount(ctx, uid, ext, "D", "", s); err != nil {
		t.Fatal(err)
	}
	if err := deleteAccount(uid); err != nil {
		t.Fatal(err)
	}
	if l, _ := ssoLinkByExt(ctx, ext); l != nil {
		t.Fatal("пайванд баъди нест кардани ҳисоб монд")
	}
}
