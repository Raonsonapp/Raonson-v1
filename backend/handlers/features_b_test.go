package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	ntf "raonson/notify"

	"github.com/gin-gonic/gin"
)

// ── «Кӯмаки фаврӣ» ─────────────────────────────────────────────────

func TestNormalizeBloodGroup(t *testing.T) {
	cases := map[string]string{
		"a+": "A+", " AB - ": "AB-", "0+": "O+", "О-": "O-", "А+": "A+", "ab+": "AB+",
		"C+": "", "": "", "A": "", "B−": "B-",
	}
	for in, want := range cases {
		if got := normalizeBloodGroup(in); got != want {
			t.Errorf("%q → %q, интизори %q", in, got, want)
		}
	}
}

func TestCompatibleDonors(t *testing.T) {
	set := func(xs []string) map[string]bool {
		m := map[string]bool{}
		for _, x := range xs {
			m[x] = true
		}
		return m
	}
	if got := compatibleDonors("O-"); len(got) != 1 || got[0] != "O-" {
		t.Errorf("O- танҳо аз O- мегирад: %v", got)
	}
	ab := compatibleDonors("AB+")
	if len(ab) != 8 || ab[0] != "AB+" {
		t.Errorf("AB+ аз ҳама мегирад, аввал худаш: %v", ab)
	}
	aNeg := set(compatibleDonors("A-"))
	if !aNeg["A-"] || !aNeg["O-"] || aNeg["A+"] || aNeg["O+"] || len(aNeg) != 2 {
		t.Errorf("A- → %v", aNeg)
	}
	bPos := set(compatibleDonors("B+"))
	for _, g := range []string{"B+", "B-", "O+", "O-"} {
		if !bPos[g] {
			t.Errorf("B+ бояд аз %s гирад", g)
		}
	}
	if bPos["A+"] || bPos["AB+"] {
		t.Error("B+ аз A/AB намегирад")
	}
	if compatibleDonors("X") != nil {
		t.Error("гурӯҳи нодуруст")
	}
}

func TestHelpExpiryClamps(t *testing.T) {
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	if d := helpExpiry(HelpBlood, 0, now).Sub(now); d != 72*time.Hour {
		t.Errorf("пешфарзи хун 72 соат: %v", d)
	}
	if d := helpExpiry(HelpBlood, 10000, now).Sub(now); d != 168*time.Hour {
		t.Errorf("ҳадди хун 7 рӯз: %v", d)
	}
	if d := helpExpiry(HelpLostPet, 0, now).Sub(now); d != 336*time.Hour {
		t.Errorf("гумшуда 14 рӯз: %v", d)
	}
	if d := helpExpiry(HelpUrgent, 1, now).Sub(now); d != 6*time.Hour {
		t.Errorf("ҳадди поён 6 соат: %v", d)
	}
}

func TestContainsPhoneNumber(t *testing.T) {
	yes := []string{"занг занед +992 93 123 45 67", "937-12-34-56", "(93) 1234567", "992931234567"}
	no := []string{"гурӯҳи A+ 2 шиша", "беморхонаи №3, ҳуҷраи 205", "соли 2026", "", "1 2 3"}
	for _, s := range yes {
		if !containsPhoneNumber(s) {
			t.Errorf("рақам ёфт нашуд: %q", s)
		}
	}
	for _, s := range no {
		if containsPhoneNumber(s) {
			t.Errorf("рақами телефон нест, вале ёфт: %q", s)
		}
	}
}

func TestHelpCityKey(t *testing.T) {
	if p := helpCityKey("tj-dushanbe"); p == nil || p.ID != "tj-dushanbe" {
		t.Errorf("Душанбе шаҳр аст: %v", p)
	}
	if helpCityKey("tj") != nil || helpCityKey("tj-sughd") != nil {
		t.Error("кишвар ва вилоят шаҳр нестанд")
	}
	if helpCityKey("no-such-place") != nil || helpCityKey("") != nil {
		t.Error("ҷойи номаълум")
	}
}

func TestHelpInputValidate(t *testing.T) {
	in := helpInput{Kind: "blood", Title: "Хуни гурӯҳи A+ лозим", BloodGroup: "a+", Units: 2}
	if msg, _ := in.validate(); msg != "" || in.BloodGroup != "A+" {
		t.Fatalf("дархости дуруст рад шуд: %s", msg)
	}
	bad := []helpInput{
		{Kind: "party", Title: "Ҳамаро даъват"},
		{Kind: "blood", Title: "Хун", BloodGroup: "A+"},
		{Kind: "blood", Title: "Хуни фаврӣ лозим", BloodGroup: ""},
		{Kind: "urgent", Title: "Ёрӣ диҳед", Body: "занг занед 935551234"},
		{Kind: "found", Title: "Ҳамён ёфтам", PhotoURL: "javascript:alert(1)"},
	}
	codes := []string{"help_bad_kind", "help_bad_title", "help_bad_blood_group",
		"help_no_contacts", "help_bad_photo"}
	for i, b := range bad {
		if _, code := b.validate(); code != codes[i] {
			t.Errorf("%d: код %q, интизори %q", i, code, codes[i])
		}
	}
	lost := helpInput{Kind: "lost_pet", Title: "Гурбаи сафед гум шуд", BloodGroup: "A+", Units: 3}
	lost.validate()
	if lost.BloodGroup != "" || lost.Units != 0 {
		t.Error("гурӯҳи хун танҳо барои дархости хун")
	}
}

func TestHelpNotificationKinds(t *testing.T) {
	for _, k := range []ntf.Kind{ntf.HelpBlood, ntf.HelpResponse} {
		if !ntf.Known(k) {
			t.Errorf("%s дар ҷадвал нест", k)
		}
		for _, l := range []ntf.Lang{ntf.TJ, ntf.RU, ntf.EN} {
			if _, body := ntf.Text(k, l, "ali", 0); body == "" {
				t.Errorf("%s/%s матн надорад", k, l)
			}
		}
		if ntf.Link(k, "r1", "ali") != "/help/r1" {
			t.Errorf("%s бояд ба /help/r1 барад", k)
		}
	}
}

// ── «Овоз» ─────────────────────────────────────────────────────────

func TestParseVoiceMedia(t *testing.T) {
	img := []map[string]interface{}{{"url": "https://x/a.jpg", "type": "image"}}
	if _, isVoice, msg := parseVoiceMedia(img); isVoice || msg != "" {
		t.Error("пости оддӣ овозӣ нест")
	}
	ok := []map[string]interface{}{{"url": "https://x/a.m4a", "type": "audio",
		"durationMs": 60800.0, "waveform": []interface{}{10.0, 250.0, -3.0}, "cover": "https://x/c.jpg"}}
	vm, isVoice, msg := parseVoiceMedia(ok)
	if !isVoice || msg != "" {
		t.Fatalf("овози дуруст рад шуд: %s", msg)
	}
	if vm.DurationMs != 60000 || vm.Waveform != "10,100,0" || vm.Cover != "https://x/c.jpg" {
		t.Errorf("тоза нашуд: %+v", vm)
	}
	bad := [][]map[string]interface{}{
		{{"url": "https://x/a.m4a", "type": "audio", "durationMs": 90000.0}},
		{{"url": "https://x/a.m4a", "type": "audio", "durationMs": 300.0}},
		{{"url": "file:///a.m4a", "type": "audio", "durationMs": 5000.0}},
		{{"url": "https://x/a.m4a", "type": "audio", "durationMs": 5000.0}, img[0]},
	}
	for i, b := range bad {
		if _, _, msg := parseVoiceMedia(b); msg == "" {
			t.Errorf("%d: бояд рад шавад", i)
		}
	}
}

func TestNormalizeWaveformDownsamples(t *testing.T) {
	in := make([]interface{}, 200)
	for i := range in {
		in[i] = float64(i % 50)
	}
	out := strings.Split(normalizeWaveform(in), ",")
	if len(out) != voiceWaveformMax {
		t.Fatalf("бояд %d нуқта бошад: %d", voiceWaveformMax, len(out))
	}
	if normalizeWaveform(nil) != "" || normalizeWaveform([]interface{}{"x"}) != "" {
		t.Error("мавҷи холӣ")
	}
}

// ── Тарҷума ────────────────────────────────────────────────────────

func TestNormalizeTargetLang(t *testing.T) {
	cases := map[string]string{"tj": "tj", "tg": "tj", "RU": "ru", "en-US": "en",
		"fa": "fa", "uz": "uz", "de": "", "": ""}
	for in, want := range cases {
		if got := normalizeTargetLang(in); got != want {
			t.Errorf("%q → %q, интизори %q", in, got, want)
		}
	}
}

func TestCleanTranslationAndKey(t *testing.T) {
	if got := cleanTranslation(" <text>Салом</text> "); got != "Салом" {
		t.Errorf("тег: %q", got)
	}
	if got := cleanTranslation(`"Hello"`); got != "Hello" {
		t.Errorf("нохунак: %q", got)
	}
	if translationKey(" салом ") != translationKey("салом") {
		t.Error("фосила набояд калидро иваз кунад")
	}
	if translationKey("a") == translationKey("b") {
		t.Error("матни гуногун — калиди гуногун")
	}
}

func doJSON(h gin.HandlerFunc, body string) *httptest.ResponseRecorder {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodPost, "/translate", bytes.NewBufferString(body))
	c.Request.Header.Set("Content-Type", "application/json")
	h(c)
	return w
}

func TestTranslateGuardsWithoutDB(t *testing.T) {
	old := translateEnabled
	defer func() { translateEnabled = old }()

	translateEnabled = func() bool { return false }
	if w := doJSON(Translate, `{"text":"салом","target":"en"}`); w.Code != 503 ||
		!strings.Contains(w.Body.String(), "translate_disabled") {
		t.Errorf("бе провайдер 503: %d %s", w.Code, w.Body)
	}
	translateEnabled = func() bool { return true }
	if w := doJSON(Translate, `{"text":""}`); w.Code != 400 {
		t.Errorf("матни холӣ: %d", w.Code)
	}
	long := strings.Repeat("я", translateMaxRunes()+1)
	if w := doJSON(Translate, `{"text":"`+long+`","target":"en"}`); w.Code != 413 {
		t.Errorf("матни дароз: %d", w.Code)
	}
	if w := doJSON(Translate, `{"text":"салом","target":"de"}`); w.Code != 400 ||
		!strings.Contains(w.Body.String(), "translate_bad_target") {
		t.Errorf("забони номаълум: %d %s", w.Code, w.Body)
	}
}

func TestFeaturesFlagFollowsProvider(t *testing.T) {
	old := translateEnabled
	defer func() { translateEnabled = old }()
	for _, on := range []bool{false, true} {
		translateEnabled = func() bool { return on }
		gin.SetMode(gin.TestMode)
		w := httptest.NewRecorder()
		c, _ := gin.CreateTestContext(w)
		c.Request = httptest.NewRequest(http.MethodGet, "/features", nil)
		GetFeatures(c)
		var out map[string]any
		json.Unmarshal(w.Body.Bytes(), &out)
		if out["translate"] != on || out["voiceMaxSeconds"] != float64(60) {
			t.Errorf("парчам: %v", out)
		}
	}
}

// ── Профили тиҷоратӣ ───────────────────────────────────────────────

// tjTime — вақти маҳаллии Душанбе ба UTC.
func tjTime(weekday time.Weekday, hh, mm int) time.Time {
	// 2026-01-05 душанбе аст.
	base := time.Date(2026, 1, 5, hh, mm, 0, 0, tjZone)
	return base.AddDate(0, 0, (int(weekday)+6)%7).UTC()
}

func TestComputeOpen(t *testing.T) {
	h := businessHours{
		"mon": {{"09:00", "13:00"}, {"14:00", "18:00"}},
		"fri": {{"22:00", "02:00"}},
		"sun": {},
	}
	if st := computeOpen(h, tjTime(time.Monday, 10, 0)); !st.Open || st.ClosesAt != "13:00" {
		t.Errorf("душанбе 10:00 кушода: %+v", st)
	}
	if st := computeOpen(h, tjTime(time.Monday, 13, 30)); st.Open || st.OpensAt != "14:00" || st.OpensDay != "mon" {
		t.Errorf("танаффус: %+v", st)
	}
	if st := computeOpen(h, tjTime(time.Monday, 19, 0)); st.Open || st.OpensDay != "fri" || st.OpensAt != "22:00" {
		t.Errorf("пас аз кор → ҷумъа: %+v", st)
	}
	if st := computeOpen(h, tjTime(time.Saturday, 1, 30)); !st.Open || st.ClosesAt != "02:00" {
		t.Errorf("фосилаи шабонаи ҷумъа то шанбе 02:00: %+v", st)
	}
	if st := computeOpen(h, tjTime(time.Friday, 23, 0)); !st.Open {
		t.Errorf("ҷумъа 23:00 кушода: %+v", st)
	}
	// 04:30 UTC = 09:30 дар Душанбе (на дар вақти сервер).
	utc := time.Date(2026, 1, 5, 4, 30, 0, 0, time.UTC)
	if st := computeOpen(h, utc); !st.Open {
		t.Errorf("вақти Тоҷикистон: 09:30 кушода аст: %+v", st)
	}
	if st := computeOpen(businessHours{}, utc); st.Known {
		t.Error("бе соатҳо — номаълум")
	}
	all := businessHours{"mon": {{"00:00", "24:00"}}}
	if st := computeOpen(all, tjTime(time.Monday, 23, 59)); !st.Open {
		t.Errorf("шабонарӯзӣ: %+v", st)
	}
}

func TestBusinessHoursValidate(t *testing.T) {
	if msg := (businessHours{"mon": {{"09:00", "18:00"}}}).validate(); msg != "" {
		t.Errorf("дуруст: %s", msg)
	}
	bad := []businessHours{
		{"xyz": {{"09:00", "18:00"}}},
		{"mon": {{"9:00", "18:00"}}},
		{"mon": {{"09:00", "25:00"}}},
		{"mon": {{"09:00", "09:00"}}},
		{"mon": {{"01:00", "02:00"}, {"03:00", "04:00"}, {"05:00", "06:00"}, {"07:00", "08:00"}}},
	}
	for i, b := range bad {
		if b.validate() == "" {
			t.Errorf("%d: бояд рад шавад", i)
		}
	}
}

func TestBizPhoneAndCategories(t *testing.T) {
	if p, ok := cleanBizPhone("+992 (93) 123-45-67"); !ok || p != "+992931234567" {
		t.Errorf("телефон: %q %v", p, ok)
	}
	if _, ok := cleanBizPhone("abc"); ok {
		t.Error("ҳарф телефон нест")
	}
	if p, ok := cleanBizPhone(""); !ok || p != "" {
		t.Error("холӣ иҷозат аст")
	}
	seen := map[string]bool{}
	for _, c := range businessCategories {
		if seen[c.ID] || c.TJ == "" || c.RU == "" || c.EN == "" {
			t.Errorf("категорияи нопурра ё такрорӣ: %+v", c)
		}
		seen[c.ID] = true
	}
	if businessCategoryByID("cafe").label("ru") != "Кафе" {
		t.Error("тарҷумаи категория")
	}
}
