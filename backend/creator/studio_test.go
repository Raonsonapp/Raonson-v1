package creator

import "testing"

// Давра ба SQL ҳамчун сатри тайёр дохил мешавад, бинобар ин вуруди
// корбар набояд ҳеҷ гоҳ ба он бирасад. Ин муҳимтарин тести ин пакет аст.
func TestParseWindowRejectsEverythingUnknown(t *testing.T) {
	malicious := []string{
		"1 day'; DROP TABLE users; --",
		"30 days OR 1=1",
		"'; DELETE FROM posts; --",
		"999 years",
		"",
		"   ",
		"TODAY",
		"7D",
	}
	for _, in := range malicious {
		got := ParseWindow(in)
		// Ҳар вуруди номаълум бояд ба давраи пешфарз афтад.
		if got != Window30d {
			t.Errorf("вуруди %q ба %q рафт, интизори 30d", in, got)
		}
		// Ва интервали ҳосилшуда бояд аз рӯйхати сафед бошад.
		if !isSafeInterval(got.interval()) {
			t.Fatalf("интервали хатарнок аз вуруди %q: %q", in, got.interval())
		}
	}
}

func TestParseWindowAcceptsKnownValues(t *testing.T) {
	cases := map[string]Window{
		"today": WindowToday,
		"7d":    Window7d,
		"30d":   Window30d,
	}
	for in, want := range cases {
		if got := ParseWindow(in); got != want {
			t.Errorf("%q → %q, интизори %q", in, got, want)
		}
	}
}

func TestEveryWindowIntervalIsWhitelisted(t *testing.T) {
	for _, w := range []Window{WindowToday, Window7d, Window30d} {
		if !isSafeInterval(w.interval()) {
			t.Errorf("%q интервали ғайримунтазир дорад: %q", w, w.interval())
		}
	}
}

// isSafeInterval — танҳо ҳамин се сатр ба SQL мераванд.
func isSafeInterval(s string) bool {
	return s == "1 day" || s == "7 days" || s == "30 days"
}

func TestRound3(t *testing.T) {
	cases := map[float64]float64{
		0.123456: 0.123,
		0.5:      0.5,
		0:        0,
		0.9999:   1,
	}
	for in, want := range cases {
		if got := round3(in); got != want {
			t.Errorf("round3(%v) = %v, интизори %v", in, got, want)
		}
	}
}

// Ҳадди ақали маълумот бояд маънодор бошад — вагарна хулоса аз як
// пости тасодуфӣ сохта мешавад.
func TestInsightThresholdsAreMeaningful(t *testing.T) {
	if minContentForTopicClaim < 2 {
		t.Error("бо як мӯҳтаво «мавзӯи беҳтарин» маъно надорад")
	}
	if minImpressionsForClaim < 10 {
		t.Error("бо намоиши кам фоизи анҷом бемаъно аст")
	}
	if minFollowsForClaim < 1 {
		t.Error("ҳадди обуна бояд ҳадди ақал 1 бошад")
	}
}
