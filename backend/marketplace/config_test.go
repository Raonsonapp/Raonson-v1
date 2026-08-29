package marketplace

import "testing"

func TestCommissionPercentToBPS(t *testing.T) {
	cases := map[string]int64{
		"10":   1000,
		"0":    0,
		"100":  10000,
		"12.5": 1250,
		"7.25": 725,
	}
	for in, want := range cases {
		t.Setenv("PLATFORM_COMMISSION_PERCENT", in)
		c, err := LoadConfig()
		if err != nil {
			t.Fatalf("%s: %v", in, err)
		}
		if c.CommissionBPS != want {
			t.Errorf("%s%%: гирифтем %d bps, интизор %d", in, c.CommissionBPS, want)
		}
	}
}

func TestCommissionRejectsOutOfRange(t *testing.T) {
	for _, bad := range []string{"-1", "101", "abc"} {
		t.Setenv("PLATFORM_COMMISSION_PERCENT", bad)
		if _, err := LoadConfig(); err != ErrBadCommission {
			t.Errorf("%q бояд рад шавад, гирифтем %v", bad, err)
		}
	}
}

func TestDefaultsAreSafe(t *testing.T) {
	t.Setenv("PLATFORM_COMMISSION_PERCENT", "")
	t.Setenv("PAYOUT_PROVIDER", "")
	c, err := LoadConfig()
	if err != nil {
		t.Fatal(err)
	}
	// Бе provider-и воқеӣ payout бояд дастӣ бошад — на интиқоли худкор.
	if c.PayoutProvider != "manual" {
		t.Errorf("payout-и пешфарз: %q, бояд manual бошад", c.PayoutProvider)
	}
	if c.CommissionBPS != 1000 {
		t.Errorf("комиссияи пешфарз: %d, интизор 1000", c.CommissionBPS)
	}
}
