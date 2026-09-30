package handlers

import "testing"

func TestAutoDMMatches(t *testing.T) {
	kw := []string{"1", "Салом", "нарх чанд"}
	cases := []struct {
		text string
		want bool
	}{
		{"1", true},
		{"10", false},
		{"салом!", true},
		{"САЛОМ бародар", true},
		{"саломат бошед", false},
		{"Нарх   чанд?", true},
		{"нарх", false},
		{"", false},
		{"👍", false},
	}
	for _, c := range cases {
		if got := autoDMMatches(c.text, kw, false); got != c.want {
			t.Errorf("%q: got %v want %v", c.text, got, c.want)
		}
	}
	if !autoDMMatches("ҳар чиз", nil, true) || autoDMMatches("!!!", nil, true) {
		t.Error("anyWord")
	}
}

func TestAutoDMLinkAndKeywords(t *testing.T) {
	for _, l := range []string{"", "https://raonson.tj/x"} {
		if !validAutoDMLink(l) {
			t.Errorf("%q should be valid", l)
		}
	}
	for _, l := range []string{"http://a.b", "javascript:alert(1)", "https://", "ftp://x"} {
		if validAutoDMLink(l) {
			t.Errorf("%q should be invalid", l)
		}
	}
	got := cleanKeywords([]string{" Салом ", "салом", "", "!!", "1"})
	if len(got) != 2 {
		t.Errorf("cleanKeywords = %v", got)
	}
}
