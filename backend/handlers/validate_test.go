package handlers

import "testing"

func TestClampRunes(t *testing.T) {
	cases := []struct {
		name string
		in   string
		max  int
		want string
	}{
		{"short kept", "hello", 10, "hello"},
		{"exact kept", "hello", 5, "hello"},
		{"ascii truncated", "hello world", 5, "hello"},
		// Кириллӣ: ҳар ҳарф 1 руна (вале 2 байт) — бояд аз рӯи руна бурида шавад.
		{"cyrillic truncated", "Салом дунё", 5, "Салом"},
		// Эмоҷӣ: ҳар яке 1 руна (вале 4 байт) — буридани байтӣ онро вайрон мекард.
		{"emoji truncated", "😀😀😀😀😀", 3, "😀😀😀"},
		{"zero max", "abc", 0, ""},
		{"negative max", "abc", -5, ""},
	}
	for _, tc := range cases {
		if got := clampRunes(tc.in, tc.max); got != tc.want {
			t.Errorf("%s: clampRunes(%q,%d) = %q, want %q", tc.name, tc.in, tc.max, got, tc.want)
		}
	}
}
