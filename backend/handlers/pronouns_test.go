package handlers

import "testing"

func TestNormalizePronouns(t *testing.T) {
	cases := map[string]string{
		"":                       "",
		"she/her":                "she/her",
		"ӯ, вай":                 "ӯ/вай",
		" he / him ":             "he/him",
		"a/b/c/d/e":              "a/b/c/d",
		"he/He/HE":               "he",
		"verylongpronounword":    "verylongpron",
	}
	for in, want := range cases {
		if got := normalizePronouns(in); got != want {
			t.Errorf("normalizePronouns(%q) = %q, мебоист %q", in, got, want)
		}
	}
}
