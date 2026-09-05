package referral

import (
	"strings"
	"testing"
)

// Код бо забон гуфта ва бо даст навишта мешавад: аломатҳои ба ҳам
// монанд корбарро ба даъвати каси ДИГАР мебаранд.
func TestCodeHasNoAmbiguousCharacters(t *testing.T) {
	for _, ch := range "OIL01" {
		if strings.ContainsRune(codeAlphabet, ch) {
			t.Errorf("аломати печида дар алифбо: %q", ch)
		}
	}
	for i := 0; i < 200; i++ {
		c, err := NewCode()
		if err != nil {
			t.Fatal(err)
		}
		if len(c) != codeLength {
			t.Fatalf("дарозии код %d, интизори %d", len(c), codeLength)
		}
		for _, ch := range c {
			if !strings.ContainsRune(codeAlphabet, ch) {
				t.Fatalf("аломати бегона %q дар %q", ch, c)
			}
		}
	}
}

func TestCodesDiffer(t *testing.T) {
	seen := map[string]bool{}
	for i := 0; i < 500; i++ {
		c, err := NewCode()
		if err != nil {
			t.Fatal(err)
		}
		if seen[c] {
			t.Fatalf("коди такрорӣ дар 500 кӯшиш: %q", c)
		}
		seen[c] = true
	}
}

// Корбар кодро чунон ки шунид менависад — бо ҳарфи хурд ё бо фосила.
func TestNormalizeCode(t *testing.T) {
	cases := map[string]string{
		"abc23xyz":  "ABC23XYZ",
		"  ABC23  ": "ABC23",
		"AbC23":     "ABC23",
		"":          "",
		"   ":       "",
	}
	for in, want := range cases {
		if got := NormalizeCode(in); got != want {
			t.Errorf("%q → %q, интизори %q", in, got, want)
		}
	}
}
