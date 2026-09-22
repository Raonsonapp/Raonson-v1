package handlers

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// Тасдиқи почта — ду роҳе, ки барнома кайҳо даъват мекард, вале
// сервер надошт.

func TestEmailRegexp(t *testing.T) {
	ok := []string{
		"a@b.co",
		"ehson.m@gmail.com",
		"user+tag@mail.example.org",
	}
	for _, e := range ok {
		if !emailRe.MatchString(e) {
			t.Errorf("почтаи дуруст рад шуд: %q", e)
		}
	}

	bad := []string{
		"",
		"gmail.com",      // бе @
		"a@b",            // бе домен
		"a@b.c",          // домени як ҳарфа
		"a b@c.com",      // фосила
		"a@@b.com",       // ду @
		"a@b.com\nc@d.e", // сатри дуюм — кӯшиши сохтакорӣ
	}
	for _, e := range bad {
		if emailRe.MatchString(e) {
			t.Errorf("почтаи нодуруст қабул шуд: %q", e)
		}
	}
}

func TestEmailOTPKeyBindsToUser(t *testing.T) {
	// Калид бояд ҲАМ корбар ва ҲАМ почтаро дар бар гирад.
	//
	// Агар танҳо почта мебуд, корбари А метавонист рамзи барои
	// корбари Б фиристодашударо истифода барад.
	a := emailOTPKey("user-1", "x@mail.com")
	b := emailOTPKey("user-2", "x@mail.com")
	if a == b {
		t.Fatal("калид ба корбар вобаста нест — "+
			"рамзи корбари дигар кор мекунад:", a)
	}

	c := emailOTPKey("user-1", "y@mail.com")
	if a == c {
		t.Fatal("калид ба почта вобаста нест")
	}
	if !strings.HasPrefix(a, "otp:email:") {
		t.Fatalf("префикси нодуруст: %q", a)
	}
}

// Роҳҳо воқеан сабт шудаанд?
//
// Бе ин санҷиш handler навишта мешуд, вале ҳеҷ гоҳ даъват намешуд —
// маҳз ҳамон ҳолате, ки дар барнома буд: экран ҳасту роҳ нест.
func TestVerifyRoutesRegistered(t *testing.T) {
	path := filepath.Join("..", "main_optimized.go")
	src, err := os.ReadFile(path)
	if err != nil {
		t.Skipf("%s хонда нашуд: %v", path, err)
	}
	s := string(src)

	for _, want := range []string{
		`a.POST("/verify-email"`,
		`a.POST("/verify-otp"`,
		"handlers.SendEmailVerify",
		"handlers.VerifyEmailOTP",
	} {
		if !strings.Contains(s, want) {
			t.Errorf("дар router нест: %s", want)
		}
	}

	// Вуруд ҳатмӣ: бе он ҳар кас барои почтаи бегона рамз
	// дархост карда метавонист.
	for _, line := range strings.Split(s, "\n") {
		if strings.Contains(line, `"/verify-email"`) ||
			strings.Contains(line, `"/verify-otp"`) {
			if !strings.Contains(line, "auth") {
				t.Errorf("роҳ бе вуруд кушода аст: %s",
					strings.TrimSpace(line))
			}
		}
	}
}

// Сутуни базаи додаҳо ҳаст?
func TestEmailVerifiedColumn(t *testing.T) {
	src, err := os.ReadFile(filepath.Join("..", "schema.sql"))
	if err != nil {
		t.Skipf("schema.sql хонда нашуд: %v", err)
	}
	if !strings.Contains(string(src), "email_verified") {
		t.Error("сутуни users.email_verified дар schema.sql нест — " +
			"UPDATE ҳангоми кор хато медиҳад")
	}
}
