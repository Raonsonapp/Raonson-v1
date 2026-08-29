package money

import "testing"

func TestSplitPercentNeverLosesMinorUnits(t *testing.T) {
	// Ҳар тақсим бояд дақиқ ҷамъ шавад — ягон дирам гум ё зиёд нашавад.
	cases := []struct {
		total Minor
		bps   int64
	}{
		{50000, 1000}, // 500.00 TJS, 10%
		{1, 1000},     // 1 дирам, 10% — round-half-up
		{333, 3333},   // рақамҳои нобаробар
		{999999, 1},   // 0.01%
		{0, 1000},     // сифр
		{100, 10000},  // 100%
		{100, 0},      // 0%
	}
	for _, c := range cases {
		a := MustNew(c.total, TJS)
		fee, rest, err := a.SplitPercent(c.bps)
		if err != nil {
			t.Fatalf("SplitPercent(%d, %d): %v", c.total, c.bps, err)
		}
		if fee.Minor+rest.Minor != c.total {
			t.Errorf("total=%d bps=%d: fee=%d rest=%d, ҷамъ=%d — бояд %d бошад",
				c.total, c.bps, fee.Minor, rest.Minor, fee.Minor+rest.Minor, c.total)
		}
		if fee.Currency != TJS || rest.Currency != TJS {
			t.Errorf("асъор гум шуд: %v / %v", fee.Currency, rest.Currency)
		}
	}
}

func TestSplitPercentKnownValues(t *testing.T) {
	a := MustNew(50000, TJS) // 500.00
	fee, rest, err := a.SplitPercent(1000)
	if err != nil {
		t.Fatal(err)
	}
	if fee.Minor != 5000 {
		t.Errorf("комиссия: гирифтем %d, интизор 5000", fee.Minor)
	}
	if rest.Minor != 45000 {
		t.Errorf("боқимонда: гирифтем %d, интизор 45000", rest.Minor)
	}
}

func TestSplitPercentRejectsBadBps(t *testing.T) {
	a := MustNew(1000, TJS)
	if _, _, err := a.SplitPercent(-1); err == nil {
		t.Error("bps манфӣ бояд рад шавад")
	}
	if _, _, err := a.SplitPercent(10001); err == nil {
		t.Error("bps > 10000 бояд рад шавад")
	}
}

func TestAddRejectsCurrencyMismatch(t *testing.T) {
	a := MustNew(100, TJS)
	b := MustNew(100, USD)
	if _, err := a.Add(b); err != ErrCurrencyMismatch {
		t.Errorf("интизор ErrCurrencyMismatch, гирифтем %v", err)
	}
}

func TestNewRejectsNegativeAndUnknown(t *testing.T) {
	if _, err := New(-1, TJS); err != ErrNegative {
		t.Errorf("маблағи манфӣ бояд рад шавад, гирифтем %v", err)
	}
	if _, err := New(1, Currency("XXX")); err != ErrUnknownCurrency {
		t.Errorf("асъори номаълум бояд рад шавад, гирифтем %v", err)
	}
}

func TestString(t *testing.T) {
	if got := MustNew(150000, TJS).String(); got != "1500.00 TJS" {
		t.Errorf("гирифтем %q, интизор \"1500.00 TJS\"", got)
	}
	if got := (Amount{Minor: -5, Currency: TJS}).String(); got != "-0.05 TJS" {
		t.Errorf("гирифтем %q, интизор \"-0.05 TJS\"", got)
	}
}
