package handlers

// Барқарорсозии ҳисоб: ба як шакл овардан, интихоби ҲИСОБИ ДУРУСТ,
// token-и якдафъаина ва бекор шудани сессияҳо.
//
// Қисми база бе RAONSON_TEST_DB + DATABASE_URL гузаронда мешавад.

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"raonson/db"
	mw "raonson/middleware"
)

func TestNormalizePhone(t *testing.T) {
	cases := map[string]string{
		"+992900112233":      "+992900112233",
		"992900112233":       "+992900112233",
		"00992900112233":     "+992900112233",
		"+992 90 011 22 33":  "+992900112233",
		"+992-(90)-011-2233": "+992900112233",
		"900112233":          "+992900112233", // рақами маҳаллии ТҶ
		"0900112233":         "+992900112233",
		"+79161234567":       "+79161234567",
		"79161234567":        "+79161234567",
	}
	for in, want := range cases {
		got, ok := normalizePhone(in)
		if !ok || got != want {
			t.Errorf("normalizePhone(%q) = %q,%v; want %q", in, got, ok, want)
		}
	}
	for _, bad := range []string{"", "ali", "12345", "ali@mail.com", "+99290011223344556",
		"90+0112233", "0000000000"} {
		if got, ok := normalizePhone(bad); ok {
			t.Errorf("normalizePhone(%q) = %q — бояд рад шавад", bad, got)
		}
	}
}

func TestParseRecoverIdent(t *testing.T) {
	id := parseRecoverIdent("  @Ehson.M ")
	if id.Username != "ehson.m" || id.Email != "" || len(id.Phones) != 0 {
		t.Errorf("username: %+v", id)
	}
	id = parseRecoverIdent("Ehson@Gmail.COM")
	if id.Email != "ehson@gmail.com" || id.Username != "" {
		t.Errorf("email: %+v", id)
	}
	id = parseRecoverIdent("+992 90 011 22 33")
	if id.Username != "" || len(id.Phones) == 0 || id.Phones[0] != "992900112233" {
		t.Errorf("phone: %+v", id)
	}
	// Ҳамаи шаклҳое, ки дар база буда метавонанд.
	want := map[string]bool{"992900112233": true, "00992900112233": true,
		"900112233": true, "0900112233": true}
	for _, p := range id.Phones {
		delete(want, p)
	}
	if len(want) != 0 {
		t.Errorf("шаклҳои норасида: %v", want)
	}
	// Номи корбари танҳо рақамӣ ҳам ном аст ҳам телефон — афзалият
	// дар pickRecoverAccount ба ном аст.
	id = parseRecoverIdent("900112233")
	if id.Username == "" || len(id.Phones) == 0 {
		t.Errorf("рақамӣ: %+v", id)
	}
	if !parseRecoverIdent("   ").empty() || parseRecoverIdent("   ").Raw != "" {
		t.Error("холӣ бояд холӣ бошад")
	}
	if parseRecoverIdent(strings.Repeat("a", 300)).Raw != "" {
		t.Error("вуруди дароз бояд рад шавад")
	}
}

func TestPickRecoverAccountPriority(t *testing.T) {
	u := recoverCandidate{ID: "u", ByUsername: true}
	ev := recoverCandidate{ID: "ev", ByEmail: true, EmailVerified: true}
	eu := recoverCandidate{ID: "eu", ByEmail: true}
	p1 := recoverCandidate{ID: "p1", ByPhone: true}
	p2 := recoverCandidate{ID: "p2", ByPhone: true}

	check := func(name string, cands []recoverCandidate, wantID string, wantAmb bool) {
		t.Helper()
		got, amb := pickRecoverAccount(cands)
		gotID := ""
		if got != nil {
			gotID = got.ID
		}
		if gotID != wantID || amb != wantAmb {
			t.Errorf("%s: got (%q,%v) want (%q,%v)", name, gotID, amb, wantID, wantAmb)
		}
	}
	check("холӣ", nil, "", false)
	check("ном аз ҳама болотар", []recoverCandidate{p1, eu, u, ev}, "u", false)
	check("почтаи тасдиқшуда аз тасдиқнашуда болотар", []recoverCandidate{eu, ev, p1}, "ev", false)
	check("почта аз телефон болотар", []recoverCandidate{p1, p2, eu}, "eu", false)
	check("як телефон", []recoverCandidate{p1}, "p1", false)
	// Пеш QueryRow яке аз инҳоро тасодуфан мегирифт.
	check("ду ҳисоб бо як телефон — номуайян", []recoverCandidate{p1, p2}, "", true)
	check("ду почтаи тасдиқнашуда — номуайян",
		[]recoverCandidate{eu, {ID: "eu2", ByEmail: true}}, "", true)
	check("ду телефон, вале ном ҳал мекунад", []recoverCandidate{p1, p2, u}, "u", false)
}

func TestMasks(t *testing.T) {
	if got := maskEmailHint("ehson@gmail.com"); got != "e***n@gmail.com" {
		t.Errorf("maskEmailHint = %q", got)
	}
	if got := maskEmailHint("ab@x.tj"); got != "a***@x.tj" {
		t.Errorf("maskEmailHint short = %q", got)
	}
	if got := maskPhoneHint("+992900112233"); got != "+992 *** ** 33" {
		t.Errorf("maskPhoneHint = %q", got)
	}
	if got := maskUsername("ehsonmurod"); got != "eh*******d" {
		t.Errorf("maskUsername = %q", got)
	}
	for _, u := range []string{"ab", "abc", "abcd", "abcde", "раонсон"} {
		m := maskUsername(u)
		if m == u || !strings.Contains(m, "*") {
			t.Errorf("maskUsername(%q) = %q — пӯшида нест", u, m)
		}
	}
}

func TestAvailableChannels(t *testing.T) {
	c := &recoverCandidate{Email: "ali@mail.tj", Phone: "992 90 011 22 33"}
	none := map[string]bool{}
	if got := availableChannels(c, none, false); len(got) != 0 {
		t.Errorf("бе провайдер канал набояд бошад: %v", got)
	}
	got := availableChannels(c, map[string]bool{"email": true, "telegram": true}, false)
	if len(got) != 2 || got[0].Type != "email" || got[1].Type != "telegram" ||
		got[1].To != "+992 *** ** 33" {
		t.Errorf("каналҳо: %+v", got)
	}
	// Телефони нодуруст — канали телефон нест.
	c2 := &recoverCandidate{Phone: "abc"}
	if got := availableChannels(c2, map[string]bool{"sms": true}, false); len(got) != 0 {
		t.Errorf("телефони нодуруст: %v", got)
	}
	// Бе почта — канали почта нест.
	if got := availableChannels(&recoverCandidate{}, map[string]bool{"email": true}, true); len(got) != 0 {
		t.Errorf("бе почта: %v", got)
	}
}

func TestCanonicalResetToken(t *testing.T) {
	code, err := genHelpCode()
	if err != nil || len(code) != 12 {
		t.Fatalf("genHelpCode: %q %v", code, err)
	}
	f := formatHelpCode(code)
	for _, v := range []string{code, f, strings.ToLower(f), " " + strings.ToLower(code) + " "} {
		if hashResetToken(v) != hashResetToken(code) {
			t.Errorf("шакли %q бояд ҳамон рамз бошад", v)
		}
	}
	// Token-и base64 ҳарфҳои калон/хурдро нигоҳ медорад.
	long := "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-abcd"
	if canonicalResetToken(long) != long {
		t.Error("token-и дароз набояд тағйир ёбад")
	}
	if hashResetToken(long) == hashResetToken(strings.ToLower(long)) {
		t.Error("token-и дароз ба ҳарф ҳассос аст")
	}
	a, _ := genHelpCode()
	b, _ := genHelpCode()
	if a == b {
		t.Error("рамзҳо такрор шуданд")
	}
}

func TestPasswordProblem(t *testing.T) {
	for _, bad := range []string{"", "short", "1234567", "        ", strings.Repeat("a", 73)} {
		if passwordProblem(bad) == "" {
			t.Errorf("рамзи %q бояд рад шавад", bad)
		}
	}
	for _, good := range []string{"Test12345!", "раонсон1", "12345678"} {
		if p := passwordProblem(good); p != "" {
			t.Errorf("рамзи %q рад шуд: %s", good, p)
		}
	}
}

func TestCheckOTPDetailedLocksAfterFive(t *testing.T) {
	key := fmt.Sprintf("otp:test:%d", time.Now().UnixNano())
	storeOTP(key, "123456", time.Minute)
	for i := 1; i <= 4; i++ {
		st, left := checkOTPDetailed(key, "000000")
		if st != otpWrong || left != otpMaxAttempts-i {
			t.Fatalf("кӯшиши %d: %v left=%d", i, st, left)
		}
	}
	if st, _ := checkOTPDetailed(key, "000000"); st != otpLocked {
		t.Fatalf("кӯшиши 5 бояд қуфл кунад: %v", st)
	}
	if st, _ := checkOTPDetailed(key, "123456"); st != otpMissing {
		t.Fatalf("баъди қуфл рамз бояд нест бошад: %v", st)
	}
	storeOTP(key, "654321", time.Minute)
	if st, _ := checkOTPDetailed(key, "654321"); st != otpOK {
		t.Fatal("рамзи нав бояд кор кунад")
	}
	if st, _ := checkOTPDetailed(key, "654321"); st != otpMissing {
		t.Fatal("рамз бояд як бор кор кунад")
	}
}

// ── Бо база ─────────────────────────────────────────────────────────

func recoverTestUser(t *testing.T, phone string) string {
	t.Helper()
	n := fmt.Sprintf("rcvt_%d", time.Now().UnixNano())
	var id string
	if err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO users(username, email, password, phone)
		VALUES ($1,$2,'x',$3) RETURNING id`, n, n+"@test.invalid", phone).Scan(&id); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		db.Pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, id)
	})
	return id
}

func recoverDB(t *testing.T) {
	t.Helper()
	adsTestDB(t)
	if _, err := db.Pool.Exec(context.Background(), db.RecoverySchema); err != nil {
		t.Fatal(err)
	}
}

func TestResetTokenSingleUseAndRevokes(t *testing.T) {
	recoverDB(t)
	ctx := context.Background()
	uid := recoverTestUser(t, "")
	oldTV, _ := mw.TokenState(uid)

	tok, err := issueResetToken(ctx, uid, purposeOTP, time.Minute, "")
	if err != nil {
		t.Fatal(err)
	}
	var stored int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM password_reset_tokens WHERE token_hash=$1`, tok).Scan(&stored)
	if stored != 0 {
		t.Fatal("token дар база кушода нигоҳ дошта шудааст — бояд танҳо hash бошад")
	}
	got, err := completeReset(ctx, tok, "NewPass123!")
	if err != nil || got != uid {
		t.Fatalf("completeReset: %q %v", got, err)
	}
	if _, err := completeReset(ctx, tok, "Other123!"); err != errResetTokenInvalid {
		t.Fatalf("token дубора кор кард: %v", err)
	}
	newTV, _ := mw.TokenState(uid)
	if newTV != oldTV+1 {
		t.Fatalf("token_version %d → %d: сессияҳо бекор нашуданд", oldTV, newTV)
	}
	if mw.TokenAllowed(uid, float64(oldTV)) {
		t.Fatal("token-и кӯҳна ҳоло ҳам эътибор дорад")
	}
	var left int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM password_reset_tokens WHERE user_id=$1`, uid).Scan(&left)
	if left != 0 {
		t.Fatalf("token-ҳо нест нашуданд: %d", left)
	}
}

func TestResetTokenExpiry(t *testing.T) {
	recoverDB(t)
	ctx := context.Background()
	uid := recoverTestUser(t, "")
	tok, err := issueResetToken(ctx, uid, purposeOTP, time.Minute, "")
	if err != nil {
		t.Fatal(err)
	}
	db.Pool.Exec(ctx, `UPDATE password_reset_tokens SET expires_at = NOW() - INTERVAL '1 second'
		WHERE user_id=$1`, uid)
	if _, err := completeReset(ctx, tok, "NewPass123!"); err != errResetTokenInvalid {
		t.Fatalf("token-и кӯҳна кор кард: %v", err)
	}
	// Token-и нав пешинаро бекор мекунад.
	t1, _ := issueResetToken(ctx, uid, purposeOTP, time.Minute, "")
	t2, _ := issueResetToken(ctx, uid, purposeOTP, time.Minute, "")
	if _, err := completeReset(ctx, t1, "NewPass123!"); err != errResetTokenInvalid {
		t.Fatal("token-и пешина бояд бекор шавад")
	}
	if _, err := completeReset(ctx, t2, "NewPass123!"); err != nil {
		t.Fatalf("token-и охирин бояд кор кунад: %v", err)
	}
}

func TestFindRecoverAccountAmbiguousPhone(t *testing.T) {
	recoverDB(t)
	ctx := context.Background()
	suffix := fmt.Sprintf("%07d", time.Now().UnixNano()%10000000)
	a := recoverTestUser(t, "+99298"+suffix)
	b := recoverTestUser(t, "99298 "+suffix) // ҳамон рақам, шакли дигар
	c := recoverTestUser(t, "+99297"+suffix)

	acc, amb, err := findRecoverAccount(ctx, parseRecoverIdent("98"+suffix))
	if err != nil || acc != nil || !amb {
		t.Fatalf("ду ҳисоб бо як рақам: acc=%v amb=%v err=%v", acc, amb, err)
	}
	acc, amb, err = findRecoverAccount(ctx, parseRecoverIdent("+992 97 "+suffix))
	if err != nil || amb || acc == nil || acc.ID != c {
		t.Fatalf("рақами ягона: acc=%v amb=%v err=%v", acc, amb, err)
	}
	var uname string
	db.Pool.QueryRow(ctx, `SELECT username FROM users WHERE id=$1`, a).Scan(&uname)
	acc, amb, _ = findRecoverAccount(ctx, parseRecoverIdent(strings.ToUpper(uname)))
	if acc == nil || amb || acc.ID != a {
		t.Fatalf("бо номи корбар бояд ҳисоби аниқ ёфт шавад: %v %v", acc, amb)
	}
	_ = b
	// Ҳисоби басташуда барқарор намешавад.
	db.Pool.Exec(ctx, `UPDATE users SET banned=TRUE WHERE id=$1`, c)
	mw.ForgetTokenState(c)
	acc, amb, _ = findRecoverAccount(ctx, parseRecoverIdent("+99297"+suffix))
	if acc != nil || amb {
		t.Fatalf("ҳисоби басташуда баргашт: %v %v", acc, amb)
	}
}
