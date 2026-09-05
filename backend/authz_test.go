package main

// Санҷиши иҷозат: корбари A набояд ба маълумоти корбари B бирасад.
//
// Ин тест ба сервери ЗИНДА муроҷиат мекунад, чунки ҳадаф маҳз занҷири
// пурраи HTTP аст: middleware, токен ва худи handler. Санҷиши воҳидӣ
// метавонад дуруст бошад, вале роҳ дар router нодуруст пайваст шавад.
//
// Иҷро:
//   RAONSON_TEST_URL=http://localhost:8099 go test -run TestAuthz ./...
//
// Бе RAONSON_TEST_URL тест гузаронда мешавад.

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"
)

type testUser struct {
	ID       string
	Username string
	Token    string
}

func baseURL(t *testing.T) string {
	t.Helper()
	u := os.Getenv("RAONSON_TEST_URL")
	if u == "" {
		t.Skip("RAONSON_TEST_URL гузошта нашудааст")
	}
	return strings.TrimRight(u, "/")
}

var httpc = &http.Client{Timeout: 20 * time.Second}

func do(t *testing.T, method, url, token string, body any) (int, map[string]any) {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, url, rdr)
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := httpc.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	out := map[string]any{}
	json.Unmarshal(raw, &out)
	return resp.StatusCode, out
}

// newUser корбари синтетикӣ месозад.
func newUser(t *testing.T, base, prefix string) testUser {
	t.Helper()
	name := fmt.Sprintf("%s%d", prefix, time.Now().UnixNano()%1e12)
	email := name + "@test.invalid"
	const pw = "Passw0rd!23"

	code, _ := do(t, "POST", base+"/auth/register", "", map[string]any{
		"username": name, "email": email, "password": pw,
	})
	if code != http.StatusCreated && code != http.StatusOK {
		t.Fatalf("бақайдгирӣ нашуд: HTTP %d", code)
	}
	code, body := do(t, "POST", base+"/auth/login", "", map[string]any{
		"email": email, "password": pw,
	})
	if code != http.StatusOK {
		t.Fatalf("вуруд нашуд: HTTP %d", code)
	}
	tok, _ := body["accessToken"].(string)
	u, _ := body["user"].(map[string]any)
	id, _ := u["id"].(string)
	if tok == "" || id == "" {
		t.Fatal("токен ё id гирифта нашуд")
	}
	return testUser{ID: id, Username: name, Token: tok}
}

// Бе токен ҳеҷ маълумоти шахсӣ дода намешавад.
func TestAuthzRequiresToken(t *testing.T) {
	base := baseURL(t)
	private := []string{
		"/profile/me",
		"/creator/studio",
		"/creator/analytics",
		"/creator/achievements",
		"/creator/recap/week",
		"/recap/week",
		"/referrals/me",
		"/collabs/pending",
		"/notifications",
		"/profile/notifications",
		"/posts/smart-feed",
		"/feed/preferences",
		"/discover",
	}
	for _, p := range private {
		code, _ := do(t, "GET", base+p, "", nil)
		if code != http.StatusUnauthorized && code != http.StatusForbidden {
			t.Errorf("%s бе токен HTTP %d дод, интизори 401/403", p, code)
		}
	}
}

// Токени сохта ё вайрон қабул намешавад.
func TestAuthzRejectsBadTokens(t *testing.T) {
	base := baseURL(t)
	bad := []string{
		"invalid",
		"Bearer",
		"eyJhbGciOiJIUzI1NiJ9.eyJpZCI6ImhhY2tlciJ9.forged",
		strings.Repeat("a", 500),
	}
	for _, tok := range bad {
		code, _ := do(t, "GET", base+"/profile/me", tok, nil)
		if code != http.StatusUnauthorized && code != http.StatusForbidden {
			t.Errorf("токени %q HTTP %d дод", tok[:min(12, len(tok))], code)
		}
	}
}

// Маркази маълумоти шахсӣ ҲАМЕША маълумоти худи соҳиби токенро
// медиҳад — новобаста аз он, ки client чӣ мепурсад.
//
// Ин муҳимтарин тест аст: агар handler id-ро аз параметр гирад,
// ҳар кас метавонист таҳлили каси дигарро бинад.
func TestAuthzPrivateDataIsAlwaysOwn(t *testing.T) {
	base := baseURL(t)
	a := newUser(t, base, "authza")
	b := newUser(t, base, "authzb")

	// A кӯшиш мекунад маълумоти B-ро бо ҳар роҳи имконпазир бигирад.
	attempts := []string{
		"/referrals/me?userId=" + b.ID,
		"/referrals/me?user_id=" + b.ID,
		"/creator/studio?userId=" + b.ID,
		"/creator/achievements?userId=" + b.ID,
		"/recap/week?userId=" + b.ID,
		"/notifications?userId=" + b.ID,
	}
	for _, p := range attempts {
		code, _ := do(t, "GET", base+p, a.Token, nil)
		if code >= 500 {
			t.Errorf("%s HTTP %d — сервер афтод", p, code)
		}
	}

	// Коди даъвати A ва B бояд ФАРҚ кунанд. Агар A бо параметр коди
	// B-ро гирифта тавонад, ин тафтиш инро мегирад.
	_, ra := do(t, "GET", base+"/referrals/me?userId="+b.ID, a.Token, nil)
	_, rb := do(t, "GET", base+"/referrals/me", b.Token, nil)
	ca, _ := ra["code"].(string)
	cb, _ := rb["code"].(string)
	if ca == "" || cb == "" {
		t.Fatal("коди даъват гирифта нашуд")
	}
	if ca == cb {
		t.Error("A коди даъвати B-ро гирифт")
	}
}

// Танзимоти огоҳиномаи A ба B таъсир намерасонад.
func TestAuthzPreferencesAreIsolated(t *testing.T) {
	base := baseURL(t)
	a := newUser(t, base, "prefa")
	b := newUser(t, base, "prefb")

	code, _ := do(t, "PUT", base+"/profile/notifications", a.Token,
		map[string]any{"likes": false, "marker": "A"})
	if code != http.StatusOK {
		t.Fatalf("сабти танзимот HTTP %d", code)
	}

	_, got := do(t, "GET", base+"/profile/notifications", b.Token, nil)
	if v, ok := got["marker"]; ok {
		t.Errorf("танзимоти A ба B расид: %v", v)
	}
	if v, ok := got["likes"].(bool); ok && !v {
		t.Error("танзимоти A танзимоти B-ро тағйир дод")
	}
}

// Танҳо администратор ба ташхис дастрасӣ дорад.
func TestAuthzAdminEndpointsAreClosed(t *testing.T) {
	base := baseURL(t)
	a := newUser(t, base, "notadmin")
	adminOnly := []string{
		"/admin/system/health",
		"/admin/notifications/health",
		"/admin/ai/health",
	}
	for _, p := range adminOnly {
		code, _ := do(t, "GET", base+p, a.Token, nil)
		if code == http.StatusOK {
			t.Errorf("%s ба корбари оддӣ кушода аст", p)
		}
		// Бе токен ҳам.
		code, _ = do(t, "GET", base+p, "", nil)
		if code == http.StatusOK {
			t.Errorf("%s бе токен кушода аст", p)
		}
	}
}

// Даъвати ҳамкории каси дигар қабул карда намешавад.
func TestAuthzCannotAnswerOthersCollabInvite(t *testing.T) {
	base := baseURL(t)
	a := newUser(t, base, "colla")
	stranger := newUser(t, base, "collx")

	// A пост бо «ҳамкор» B месозад — вале B-ро даъват намекунем,
	// балки бегона кӯшиш мекунад онро қабул кунад.
	code, body := do(t, "POST", base+"/posts/", a.Token, map[string]any{
		"caption": "authz",
		"media":   []any{map[string]any{"url": "https://t.invalid/1.jpg", "type": "image"}},
	})
	if code != http.StatusCreated && code != http.StatusOK {
		t.Fatalf("пост сохта нашуд: HTTP %d", code)
	}
	postID, _ := body["_id"].(string)
	if postID == "" {
		if p, ok := body["post"].(map[string]any); ok {
			postID, _ = p["_id"].(string)
		}
	}
	if postID == "" {
		t.Fatal("шиносаи пост гирифта нашуд")
	}

	code, _ = do(t, "POST",
		base+"/posts/"+postID+"/collab/accept", stranger.Token, nil)
	if code == http.StatusOK {
		t.Error("бегона даъвати нестро қабул кард")
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
