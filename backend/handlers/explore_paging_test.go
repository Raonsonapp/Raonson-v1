package handlers

import (
	"strings"
	"testing"
)

func TestExploreSeedSanitized(t *testing.T) {
	cases := map[string]string{
		"":                      "",
		"abc123":                "abc123",
		"  abc  ":               "abc",
		"a'b":                   "",
		"x;DROP TABLE posts":    "",
		"кирилл":                "",
		strings.Repeat("a", 50): strings.Repeat("a", 32),
	}
	for in, want := range cases {
		if got := exploreSeed(in); got != want {
			t.Errorf("exploreSeed(%q) = %q, want %q", in, got, want)
		}
	}
}

// Саҳифабандӣ бо OFFSET танҳо вақте бе такрор аст, ки тартиб пурра
// муайян бошад: калиди охирин бояд аз id вобаста бошад.
func TestExploreOrderIsTotal(t *testing.T) {
	sql := exploreOrderSQL("p.id", "p.likes_count", "p.comments_count", "p.created_at", "$2")
	if !strings.HasSuffix(strings.TrimSpace(sql), "md5(p.id::text || $2::text)") {
		t.Errorf("тартиб бо id тамом намешавад — саҳифаҳо метавонанд такрор шаванд:\n%s", sql)
	}
	if !strings.Contains(sql, "$2::text = ''") {
		t.Error("бе seed тартиби маъмулият нест")
	}
}

// Explore бояд `page`-ро воқеан истифода барад (пеш нодида мегирифт).
func TestExploreUsesPage(t *testing.T) {
	body := exploreSQL(t)
	for _, want := range []string{`c.Query("page")`, "OFFSET $4", `"hasMore"`,
		"post_not_interested", "reel_not_interested"} {
		if !strings.Contains(body, want) {
			t.Errorf("ExploreGrid %q надорад", want)
		}
	}
}
