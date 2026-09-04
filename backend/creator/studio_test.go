package creator

import (
	"testing"
	"time"
)

// Давраи номаълум набояд ба ҳисоб таъсир расонад: ҳар вуруди
// ғайримунтазир ба давраи пешфарз меафтад ва ҳудуди он маҳдуд аст.
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
	now := time.Date(2026, 3, 12, 15, 4, 0, 0, time.UTC)
	for _, in := range malicious {
		got := ParseWindow(in)
		// Ҳар вуруди номаълум бояд ба давраи пешфарз афтад.
		if got != Window30d {
			t.Errorf("вуруди %q ба %q рафт, интизори 30d", in, got)
		}
		// Ва ҳудуди ҳосилшуда бояд маҳдуд бошад — на «999 сол».
		from, to := got.bounds(now)
		if d := to.Sub(from); d != 30*24*time.Hour {
			t.Fatalf("вуруди %q давраи %v дод, интизори 30 рӯз", in, d)
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

func TestEveryWindowHasExpectedBounds(t *testing.T) {
	now := time.Date(2026, 3, 12, 15, 4, 0, 0, time.UTC)
	want := map[Window]time.Duration{
		WindowToday: 24 * time.Hour,
		Window7d:    7 * 24 * time.Hour,
		Window30d:   30 * 24 * time.Hour,
	}
	for w, d := range want {
		from, to := w.bounds(now)
		if !to.Equal(now) {
			t.Errorf("%q: анҷоми давра %v, интизори %v", w, to, now)
		}
		if got := to.Sub(from); got != d {
			t.Errorf("%q: давомнокӣ %v, интизори %v", w, got, d)
		}
	}
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
