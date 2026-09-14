package ads

// Санҷиши имзо ва зинаҳо.
//
// Хатои ин ҷо гарон аст: он галочкаро ройгон мекунад ва даромадро
// нест.

import (
	"strings"
	"testing"
	"time"
)

const testKey = "test-secret-not-real"

func params(now time.Time) map[string]string {
	return map[string]string{
		"user_id":        "u1",
		"transaction_id": "tx1",
		"ad_network":     "yandex",
		"reward_amount":  "1",
		"timestamp":      itoa(now.Unix()),
	}
}

func itoa(n int64) string {
	if n == 0 {
		return "0"
	}
	neg := n < 0
	if neg {
		n = -n
	}
	var b [24]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	if neg {
		i--
		b[i] = '-'
	}
	return string(b[i:])
}

// Бе сир ҳисоб КОР НАМЕКУНАД.
//
// Ин қасдан аст: беҳтар аст хусусият хомӯш бошад, назар ба он ки ҳар
// кас галочкаро ройгон гирад.
func TestWithoutSecretNothingIsAccepted(t *testing.T) {
	t.Setenv("ADS_CALLBACK_SECRET", "")
	if Configured() {
		t.Fatal("бе сир Configured бояд false бошад")
	}
	now := time.Now()
	p := params(now)
	// Ҳатто имзои «дуруст» бо сирри дигар қабул намешавад.
	sig := Sign(p, "any-key")
	if err := Verify(p, sig, now); err != ErrNotConfigured {
		t.Errorf("бе сир хатои %v, интизори ErrNotConfigured", err)
	}
}

// Имзои дуруст қабул мешавад.
func TestValidSignature(t *testing.T) {
	t.Setenv("ADS_CALLBACK_SECRET", testKey)
	now := time.Now()
	p := params(now)
	if err := Verify(p, Sign(p, testKey), now); err != nil {
		t.Fatalf("имзои дуруст рад шуд: %v", err)
	}
}

// Ҳар тағйири параметр имзоро вайрон мекунад.
//
// Маҳз ин ҷо ҳамла интизор аст: касе user_id-ро иваз мекунад, то
// реклама ба аккаунти дигар навишта шавад.
func TestTamperedParamsAreRejected(t *testing.T) {
	t.Setenv("ADS_CALLBACK_SECRET", testKey)
	now := time.Now()
	orig := params(now)
	sig := Sign(orig, testKey)

	cases := map[string]func(map[string]string){
		"корбари дигар": func(p map[string]string) { p["user_id"] = "u2" },
		"нишони дигар":  func(p map[string]string) { p["transaction_id"] = "tx2" },
		"мукофоти зиёд": func(p map[string]string) { p["reward_amount"] = "1000" },
		"параметри нав": func(p map[string]string) { p["extra"] = "x" },
		"параметр нест": func(p map[string]string) { delete(p, "ad_network") },
	}
	for name, mutate := range cases {
		p := params(now)
		mutate(p)
		if err := Verify(p, sig, now); err == nil {
			t.Errorf("%s: дархости тағйирёфта қабул шуд", name)
		}
	}
}

// Имзои сохта, холӣ ё вайрон.
func TestBadSignatures(t *testing.T) {
	t.Setenv("ADS_CALLBACK_SECRET", testKey)
	now := time.Now()
	p := params(now)
	for _, sig := range []string{
		"", "abc", "zzzz", strings.Repeat("0", 64),
		Sign(p, "wrong-key"),
	} {
		if err := Verify(p, sig, now); err == nil {
			t.Errorf("имзои %q қабул шуд", sig)
		}
	}
}

// Дархости кӯҳна қабул намешавад.
//
// Бе ин, як дархости гирифташуда абадӣ такрор мешуд.
func TestStaleRequestRejected(t *testing.T) {
	t.Setenv("ADS_CALLBACK_SECRET", testKey)
	now := time.Now()

	old := params(now.Add(-time.Hour))
	if err := Verify(old, Sign(old, testKey), now); err != ErrStale {
		t.Errorf("дархости кӯҳна: %v, интизори ErrStale", err)
	}
	future := params(now.Add(time.Hour))
	if err := Verify(future, Sign(future, testKey), now); err != ErrStale {
		t.Errorf("дархости оянда: %v, интизори ErrStale", err)
	}
	// Фарқи хурд қобили қабул: соатҳои серверҳо якхела нестанд.
	near := params(now.Add(-30 * time.Second))
	if err := Verify(near, Sign(near, testKey), now); err != nil {
		t.Errorf("фарқи 30 сония рад шуд: %v", err)
	}
}

// Бе вақт умуман қабул намешавад.
func TestMissingTimestamp(t *testing.T) {
	t.Setenv("ADS_CALLBACK_SECRET", testKey)
	p := map[string]string{"user_id": "u1", "transaction_id": "tx1"}
	if err := Verify(p, Sign(p, testKey), time.Now()); err != ErrStale {
		t.Error("дархости бе вақт қабул шуд")
	}
}

// ── Зинаҳо ──────────────────────────────────────────────────────

// Зинаҳо бояд маънодор бошанд: реклама бештар — рӯз бештар.
func TestTiersIncrease(t *testing.T) {
	ts := Tiers()
	if len(ts) != 3 {
		t.Fatalf("%d зина, интизори 3", len(ts))
	}
	for i := 1; i < len(ts); i++ {
		if ts[i].Ads <= ts[i-1].Ads {
			t.Errorf("зинаи %s реклама камтар дорад", ts[i].Code)
		}
		if ts[i].Days <= ts[i-1].Days {
			t.Errorf("зинаи %s рӯз камтар дорад", ts[i].Code)
		}
	}
}

// Зинаи баландтар бояд АРЗОНТАР бошад барои як рӯз — вагарна он
// маъно надорад.
func TestBiggerTierIsBetterValue(t *testing.T) {
	ts := Tiers()
	for i := 1; i < len(ts); i++ {
		prev := float64(ts[i-1].Ads) / float64(ts[i-1].Days)
		cur := float64(ts[i].Ads) / float64(ts[i].Days)
		if cur > prev {
			t.Errorf("зинаи %s барои як рӯз %.0f реклама мехоҳад, "+
				"зинаи %s бошад %.0f — зинаи калон бояд арзонтар бошад",
				ts[i].Code, cur, ts[i-1].Code, prev)
		}
	}
}

func TestTierByCode(t *testing.T) {
	if _, ok := TierByCode("3d"); !ok {
		t.Error("зинаи 3d ёфт нашуд")
	}
	for _, bad := range []string{"", "1d", "365d", "3D", "abc"} {
		if _, ok := TierByCode(bad); ok {
			t.Errorf("зинаи бегонаи %q қабул шуд", bad)
		}
	}
}

// Рақамҳо аз env танзим мешаванд: шабакаи реклама метавонад ҳаҷми
// зиёдро маҳдуд кунад ва он вақт зинаҳо бе ҷойгиркунӣ тағйир ёбанд.
func TestTiersConfigurable(t *testing.T) {
	t.Setenv("ADS_TIER_3D", "50")
	tr, _ := TierByCode("3d")
	if tr.Ads != 50 {
		t.Errorf("зина аз env гирифта нашуд: %d", tr.Ads)
	}
	// Арзиши бемаънӣ ба пешфарз бармегардад.
	t.Setenv("ADS_TIER_3D", "-5")
	tr, _ = TierByCode("3d")
	if tr.Ads != 300 {
		t.Errorf("арзиши манфӣ қабул шуд: %d", tr.Ads)
	}
}

func TestDailyCapIsPositive(t *testing.T) {
	if DailyCap() <= 0 {
		t.Error("ҳадди рӯзона бояд мусбат бошад")
	}
}
