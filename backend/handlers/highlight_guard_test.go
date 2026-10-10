package handlers

import (
	"strings"
	"testing"
)

func TestValidHighlightURL(t *testing.T) {
	for _, tc := range []struct {
		in string
		ok bool
	}{
		{"https://cdn.raonson.tj/a.jpg", true},
		{"http://cdn.raonson.tj/a.jpg", false},
		{"javascript:alert(1)", false},
		{"https://", false},
		{"https://x.tj/a b.jpg", false},
		{"", false},
	} {
		if got := validHighlightURL(tc.in); got != tc.ok {
			t.Errorf("validHighlightURL(%q) = %v, want %v", tc.in, got, tc.ok)
		}
	}
}

func TestCoverForOnlyFromItems(t *testing.T) {
	items := []map[string]interface{}{{"url": "https://a/1.jpg"}, {"url": "https://a/2.jpg"}}
	if got := coverFor("https://a/2.jpg", items); got != "https://a/2.jpg" {
		t.Errorf("own item cover rejected: %q", got)
	}
	if got := coverFor("https://evil/x.jpg", items); got != "https://a/1.jpg" {
		t.Errorf("foreign cover accepted: %q", got)
	}
	if got := coverFor("https://evil/x.jpg", nil); got != "" {
		t.Errorf("cover without items: %q", got)
	}
}

func TestTaggedVisibleLimitedBranchesAreBounded(t *testing.T) {
	sql := taggedVisibleLimited("ch.tag = $2", "$1", false, "$3::int + $4::int")
	for _, want := range []string{
		"ORDER BY ch.created_at DESC, p.id DESC LIMIT $3::int + $4::int",
		"ORDER BY ch.created_at DESC, r.id DESC LIMIT $3::int + $4::int",
	} {
		if !contains(sql, want) {
			t.Errorf("branch limit missing: %s", want)
		}
	}
	if contains(taggedVisibleSQL("ch.tag = $2", "$1", false), "ORDER BY ch.created_at") {
		t.Error("unbounded variant must not carry a LIMIT")
	}
}

func contains(s, sub string) bool { return strings.Contains(s, sub) }
