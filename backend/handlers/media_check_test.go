package handlers

import (
	"testing"
	"time"
)

// Санҷиши ҳимоя: сервер танҳо ба анбори ХУДИ МО дархост мефиристад.
func TestOnOurStorage(t *testing.T) {
	base := "https://media.example-cdn.com"
	cases := []struct {
		url  string
		want bool
	}{
		{"https://media.example-cdn.com/reels/a.mp4", true},
		{"https://MEDIA.example-cdn.com/reels/a.mp4", true},
		// SSRF: суроғаҳои дохилӣ ва бегона
		{"http://media.example-cdn.com/reels/a.mp4", false},
		{"https://169.254.169.254/latest/meta-data", false},
		{"https://localhost/x.mp4", false},
		{"https://media.example-cdn.com.evil.com/a.mp4", false},
		{"https://evil.com/?h=media.example-cdn.com", false},
		{"", false},
		{"not a url", false},
	}
	for _, c := range cases {
		if got := onOurStorage(c.url, base); got != c.want {
			t.Errorf("onOurStorage(%q) = %v, мебоист %v", c.url, got, c.want)
		}
	}
	// Бе танзими анбор — ҳеҷ дархост.
	if onOurStorage("https://media.example-cdn.com/a.mp4", "") {
		t.Error("CF_R2_PUBLIC_URL холӣ аст, вале санҷиш иҷозат дода шуд")
	}
}

// Танҳо «нест»-и возеҳ reel-ро пинҳон мекунад. Хатои муваққатӣ
// (403, 500, timeout) набояд видеои ҳақиқиро нест кунад.
func TestMediaGoneOnlyDefinite(t *testing.T) {
	for _, s := range []int{404, 410} {
		if !mediaGone(s) {
			t.Errorf("%d бояд «нест» ҳисоб шавад", s)
		}
	}
	for _, s := range []int{0, 200, 206, 301, 403, 429, 500, 502, 503} {
		if mediaGone(s) {
			t.Errorf("%d «нест» ҳисоб шуд — видеои ҳақиқӣ пинҳон мешуд", s)
		}
	}
}

func TestMediaCheckThrottled(t *testing.T) {
	now := time.Now()
	id := "throttle-test-reel"
	if !mediaCheckDue(id, now) {
		t.Fatal("санҷиши аввал бояд иҷозат дошта бошад")
	}
	if mediaCheckDue(id, now.Add(time.Minute)) {
		t.Error("санҷиши такрорӣ дар 1 дақиқа иҷозат ёфт — spam ба анбор")
	}
	if !mediaCheckDue(id, now.Add(mediaCheckEvery+time.Second)) {
		t.Error("баъди фосила санҷиш бояд боз иҷозат дошта бошад")
	}
}

// Вуруд бо «@ном» — ҳамон тавре ки ном дар барнома нишон дода мешавад.
func TestNormalizeLoginID(t *testing.T) {
	cases := map[string]string{
		"@tajikshop":       "tajikshop",
		"  @TajikShop  ":   "tajikshop",
		"tajikshop":        "tajikshop",
		"User@Example.com": "user@example.com",
		"+992900000000":    "+992900000000",
		"@":                "",
	}
	for in, want := range cases {
		if got := normalizeLoginID(in); got != want {
			t.Errorf("normalizeLoginID(%q) = %q, мебоист %q", in, got, want)
		}
	}
}
