package handlers

import (
	"strings"
	"testing"
)

// +992 90 123 4567, 0901234567 ва 992901234567 — як рақам.
func TestContactPhoneNormalization(t *testing.T) {
	a := normalizeContactPhone("+992 90 123-45-67")
	b := normalizeContactPhone("992901234567")
	c := normalizeContactPhone("901234567")
	if a == "" || a != b || b != c {
		t.Fatalf("рақамҳо якхела нашуданд: %q %q %q", a, b, c)
	}
	if normalizeContactPhone("12345") != "" {
		t.Error("рақами кӯтоҳ бояд рад шавад")
	}
}

// Хеш рақамро ошкор намекунад ва бо намак вобаста аст.
func TestContactHashHidesNumber(t *testing.T) {
	n := normalizeContactPhone("+992901234567")
	h := contactHash(n)
	if len(h) != 64 || strings.Contains(h, n) {
		t.Fatalf("хеши нодуруст: %q", h)
	}
	if contactHash(n) != h {
		t.Error("хеш бояд муайян бошад")
	}
	t.Setenv("CONTACTS_HASH_PEPPER", "another-secret")
	if contactHash(n) == h {
		t.Error("хеш бояд аз намак вобаста бошад")
	}
}
