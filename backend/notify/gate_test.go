package notify

import (
	"encoding/json"
	"testing"
	"time"
)

func parsePrefs(t *testing.T, raw string) Prefs {
	t.Helper()
	var p Prefs
	if err := json.Unmarshal([]byte(raw), &p); err != nil {
		t.Fatal(err)
	}
	return p
}

// Пешфарз: ҳама чиз фаъол. Корбари нав набояд огоҳиномаро аз даст
// диҳад танҳо аз он сабаб, ки чизе танзим накардааст.
func TestDefaultsAreOn(t *testing.T) {
	var p Prefs
	for _, k := range AllKinds() {
		if !p.Allows(k) {
			t.Errorf("бе танзимот %s рад шуд", k)
		}
	}
}

func TestPreferenceTurnsOffOnlyItsOwnKind(t *testing.T) {
	p := parsePrefs(t, `{"likes":false}`)
	if p.Allows(Like) {
		t.Error("лайк бояд хомӯш бошад")
	}
	if p.Allows(ReelLike) {
		t.Error("лайки рилс низ ба ҳамон танзим тааллуқ дорад")
	}
	// Дигар намудҳо бояд кор кунанд.
	for _, k := range []Kind{Comment, Follow, Message, Mention} {
		if !p.Allows(k) {
			t.Errorf("%s набояд аз танзими лайк таъсир бинад", k)
		}
	}
}

func TestMasterSwitchOffStopsEverything(t *testing.T) {
	p := parsePrefs(t, `{"push":false}`)
	for _, k := range AllKinds() {
		if p.Allows(k) {
			t.Errorf("push хомӯш аст, вале %s гузашт", k)
		}
	}
}

// Пул ва ӯҳдадорӣ бо танзими иҷтимоӣ хомӯш намешаванд.
func TestMoneyKindsCannotBeSilencedByCategory(t *testing.T) {
	p := parsePrefs(t, `{"likes":false,"comments":false,"followers":false,
		"recommendations":false,"creator":false,"achievements":false}`)
	for _, k := range []Kind{CampaignInvite, CampaignPayout, Order,
		CollabInvite, CampaignResponse} {
		if !p.Allows(k) {
			t.Errorf("%s набояд бо танзими категория хомӯш шавад", k)
		}
	}
}

// ── Соатҳои ором ────────────────────────────────────────────────

func at(hourUTC int) time.Time {
	return time.Date(2026, 9, 5, hourUTC, 30, 0, 0, time.UTC)
}

func TestQuietHoursOffByDefault(t *testing.T) {
	var p Prefs
	for h := 0; h < 24; h++ {
		if p.InQuietHours(at(h)) {
			t.Fatalf("бе танзимот соати %d ором ҳисоб шуд", h)
		}
	}
}

// Бе минтақаи вақт вақти маҳаллӣ маълум нест — тахмин намезанем.
func TestQuietHoursNeedTimezone(t *testing.T) {
	p := parsePrefs(t, `{"quietHours":{"enabled":true,"startHour":23,"endHour":8}}`)
	for h := 0; h < 24; h++ {
		if p.InQuietHours(at(h)) {
			t.Fatalf("бе фарқи вақт соати %d ором шуд", h)
		}
	}
}

func TestQuietHoursCrossMidnight(t *testing.T) {
	p := parsePrefs(t, `{"quietHours":{"enabled":true,"startHour":23,
		"endHour":8,"tzOffsetMinutes":0}}`)
	for _, h := range []int{23, 0, 3, 7} {
		if !p.InQuietHours(at(h)) {
			t.Errorf("соати %d бояд ором бошад", h)
		}
	}
	for _, h := range []int{8, 12, 18, 22} {
		if p.InQuietHours(at(h)) {
			t.Errorf("соати %d набояд ором бошад", h)
		}
	}
}

// Душанбе UTC+5: 19:30 UTC = 00:30 маҳаллӣ.
func TestQuietHoursUseLocalTime(t *testing.T) {
	p := parsePrefs(t, `{"quietHours":{"enabled":true,"startHour":23,
		"endHour":8,"tzOffsetMinutes":300}}`)
	if !p.InQuietHours(at(19)) {
		t.Error("нимишаби маҳаллӣ бояд ором бошад")
	}
	if p.InQuietHours(at(5)) {
		t.Error("субҳи маҳаллӣ набояд ором бошад")
	}
}

func TestQuietHoursIgnoreNonsense(t *testing.T) {
	for _, raw := range []string{
		`{"quietHours":{"enabled":true,"startHour":-1,"endHour":8,"tzOffsetMinutes":0}}`,
		`{"quietHours":{"enabled":true,"startHour":23,"endHour":99,"tzOffsetMinutes":0}}`,
		`{"quietHours":{"enabled":true,"startHour":8,"endHour":8,"tzOffsetMinutes":0}}`,
		`{"quietHours":{"enabled":true,"startHour":23,"endHour":8,"tzOffsetMinutes":100000}}`,
	} {
		p := parsePrefs(t, raw)
		for h := 0; h < 24; h++ {
			if p.InQuietHours(at(h)) {
				t.Fatalf("%s: соати %d бе асос ором шуд", raw, h)
			}
		}
	}
}

// ── Маҳдудияти шумора ───────────────────────────────────────────

type memCounter map[string][]byte

func (m memCounter) Get(k string) ([]byte, bool)             { v, ok := m[k]; return v, ok }
func (m memCounter) Set(k string, v []byte, _ time.Duration) { m[k] = v }

func TestBudgetResetsEachHour(t *testing.T) {
	c := memCounter{}
	for i := 0; i < MaxPushPerHour; i++ {
		if !budgetLeft(c, "u1", at(10)) {
			t.Fatalf("push-и %d рад шуд", i+1)
		}
	}
	if budgetLeft(c, "u1", at(10)) {
		t.Error("аз ҳад зиёд иҷозат дода шуд")
	}
	if !budgetLeft(c, "u1", at(11)) {
		t.Error("соати нав бояд буҷети нав диҳад")
	}
}

func TestBudgetIsPerUser(t *testing.T) {
	c := memCounter{}
	for i := 0; i < MaxPushPerHour; i++ {
		budgetLeft(c, "noisy", at(14))
	}
	if !budgetLeft(c, "quiet", at(14)) {
		t.Error("корбари дигар набояд аз ҳисоби каси дигар маҳрум шавад")
	}
}

// Бе кэш хато бояд ба ФИРИСТОДАН афтад, на ба хомӯшӣ.
func TestBudgetWithoutCounterAllows(t *testing.T) {
	for i := 0; i < 100; i++ {
		if !budgetLeft(nil, "u1", at(9)) {
			t.Fatal("бе кэш push бояд иҷозат дода шавад")
		}
	}
}
