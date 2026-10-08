package hashtags

import (
	"encoding/json"
	"os"
	"reflect"
	"strings"
	"testing"
)

// Ҳамин файл дар test/hashtag_parser_test.dart (Flutter) низ хонда
// мешавад — ду тараф бояд ҳамон натиҷаро диҳанд.
type casesFile struct {
	Extract []struct {
		Name string   `json:"name"`
		Text string   `json:"text"`
		Tags []string `json:"tags"`
	} `json:"extract"`
	Normalize []struct {
		In  string  `json:"in"`
		Out *string `json:"out"`
	} `json:"normalize"`
}

func loadCases(t *testing.T) casesFile {
	t.Helper()
	b, err := os.ReadFile("testdata/hashtag_cases.json")
	if err != nil {
		t.Fatalf("fixture: %v", err)
	}
	var c casesFile
	if err := json.Unmarshal(b, &c); err != nil {
		t.Fatalf("fixture json: %v", err)
	}
	if len(c.Extract) < 15 || len(c.Normalize) < 5 {
		t.Fatalf("fixture too small: %d/%d", len(c.Extract), len(c.Normalize))
	}
	return c
}

func TestExtractSharedCases(t *testing.T) {
	for _, tc := range loadCases(t).Extract {
		got := Extract(tc.Text)
		if len(got) == 0 && len(tc.Tags) == 0 {
			continue
		}
		if !reflect.DeepEqual(got, tc.Tags) {
			t.Errorf("%s: Extract(%q) = %q, want %q", tc.Name, tc.Text, got, tc.Tags)
		}
	}
}

func TestNormalizeSharedCases(t *testing.T) {
	for _, tc := range loadCases(t).Normalize {
		got, ok := Normalize(tc.In)
		switch {
		case tc.Out == nil && ok:
			t.Errorf("Normalize(%q) = %q, want invalid", tc.In, got)
		case tc.Out != nil && (!ok || got != *tc.Out):
			t.Errorf("Normalize(%q) = %q,%v want %q", tc.In, got, ok, *tc.Out)
		}
	}
}

func TestTajikLettersAreTagRunes(t *testing.T) {
	for _, r := range "ҳҷқӯғӣҲҶҚӮҒӢёЁ" {
		if !IsTagRune(r) {
			t.Errorf("%q must be a hashtag letter", r)
		}
	}
	// Регекси кӯҳнаи `#(\w+)` инҳоро намегирифт.
	if got := Extract("#ҷашни_наврӯз"); !reflect.DeepEqual(got, []string{"ҷашни_наврӯз"}) {
		t.Fatalf("got %q", got)
	}
}

func TestFindOffsets(t *testing.T) {
	text := "Салом #Душанбе!"
	ms := Find(text)
	if len(ms) != 1 {
		t.Fatalf("got %d matches", len(ms))
	}
	if text[ms[0].Start:ms[0].End] != "#Душанбе" || ms[0].Raw != "Душанбе" || ms[0].Tag != "душанбе" {
		t.Fatalf("bad match %+v", ms[0])
	}
}

func TestLimits(t *testing.T) {
	var b strings.Builder
	for i := 0; i < 40; i++ {
		b.WriteString("#t")
		b.WriteString(strings.Repeat("x", i%5+1))
		b.WriteString(string(rune('a' + i%26)))
		b.WriteString(string(rune('a' + i/26)))
		b.WriteString(" ")
	}
	if got := Extract(b.String()); len(got) != MaxPerText {
		t.Fatalf("want %d tags, got %d", MaxPerText, len(got))
	}
	if got := Extract("#" + strings.Repeat("ҷ", MaxLen)); len(got) != 1 {
		t.Fatalf("50-letter tag must be accepted")
	}
	if got := Extract("#" + strings.Repeat("ҷ", MaxLen+1)); len(got) != 0 {
		t.Fatalf("51-letter tag must be rejected")
	}
}

func TestNormalizePrefix(t *testing.T) {
	cases := map[string]string{"#Ду": "ду", "20": "20", "ҲИ": "ҳи"}
	for in, want := range cases {
		if got, ok := NormalizePrefix(in); !ok || got != want {
			t.Errorf("NormalizePrefix(%q)=%q,%v", in, got, ok)
		}
	}
	for _, in := range []string{"", "#", "a b", "a%"} {
		if _, ok := NormalizePrefix(in); ok {
			t.Errorf("NormalizePrefix(%q) must fail", in)
		}
	}
}
