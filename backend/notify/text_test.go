package notify

import (
	"strings"
	"testing"
)

// Матн дар СЕРВЕР тарҷума мешавад: барнома ҳангоми push кор карда
// наметавонад. Агар забон гум шавад, корбар матни бегона мебинад.
func TestEveryActorKindHasAllThreeLanguages(t *testing.T) {
	for k, m := range bodies {
		for _, lang := range []Lang{TJ, RU, EN} {
			if s, ok := m[lang]; !ok || strings.TrimSpace(s) == "" {
				t.Errorf("%s: забони %s нест", k, lang)
			}
		}
	}
	for k, m := range standalone {
		for _, lang := range []Lang{TJ, RU, EN} {
			v, ok := m[lang]
			if !ok || v[0] == "" || v[1] == "" {
				t.Errorf("%s: забони %s нопурра", k, lang)
			}
		}
	}
	for k, m := range grouped {
		for _, lang := range []Lang{TJ, RU, EN} {
			s, ok := m[lang]
			if !ok || !strings.Contains(s, "{n}") {
				t.Errorf("%s гурӯҳӣ: забони %s бе {n}", k, lang)
			}
		}
	}
}

func TestTextUsesActorAndLanguage(t *testing.T) {
	title, body := Text(Like, RU, "ali", 0)
	if title != "@ali" {
		t.Errorf("сарлавҳа: %q", title)
	}
	if !strings.Contains(body, "пост") {
		t.Errorf("матни русӣ: %q", body)
	}
	_, tjBody := Text(Like, TJ, "ali", 0)
	if tjBody == body {
		t.Error("тоҷикӣ ва русӣ бояд фарқ кунанд")
	}
}

// Забони номаълум ба тоҷикӣ мебарояд, на ба сатри холӣ.
func TestUnknownLanguageFallsBack(t *testing.T) {
	_, body := Text(Like, Lang("de"), "ali", 0)
	if body == "" {
		t.Error("забони номаълум матни холӣ дод")
	}
}

// Гурӯҳбандӣ: «Ali ва 4 нафари дигар».
func TestGroupedTextCountsOthers(t *testing.T) {
	_, body := Text(Like, EN, "ali", 4)
	if !strings.Contains(body, "4") {
		t.Errorf("шумора дар матн нест: %q", body)
	}
	if strings.Contains(body, "{n}") {
		t.Errorf("ҷойгир пур нашуд: %q", body)
	}
	// Як нафар — матни оддӣ, бе рақам.
	_, single := Text(Like, EN, "ali", 0)
	if strings.Contains(single, "4") || single == body {
		t.Errorf("як нафар матни гурӯҳӣ гирифт: %q", single)
	}
}

// Намуде, ки матн надорад, набояд рамзи техникиро ба корбар нишон
// диҳад.
func TestUnknownKindProducesNoText(t *testing.T) {
	title, body := Text(Kind("SOMETHING_NEW"), TJ, "ali", 0)
	if title != "" || body != "" {
		t.Errorf("намуди номаълум матн дод: %q / %q", title, body)
	}
}

// Огоҳиномаи барнома муаллиф надорад ва бояд бе он кор кунад.
func TestStandaloneNeedsNoActor(t *testing.T) {
	title, body := Text(WeeklyRecap, TJ, "", 0)
	if title == "" || body == "" {
		t.Errorf("ҷамъбаст бе муаллиф матн надод: %q / %q", title, body)
	}
}

// Матн набояд фишор орад ё саросемагии сохта эҷод кунад.
func TestNoManipulativeCopy(t *testing.T) {
	bad := []string{"!!!", "ҲОЗИР", "СРОЧНО", "NOW!", "HURRY", "ФАВРАН!"}
	check := func(s string, where string) {
		up := strings.ToUpper(s)
		for _, b := range bad {
			if strings.Contains(up, strings.ToUpper(b)) {
				t.Errorf("%s: матни фишоровар %q дар %q", where, b, s)
			}
		}
	}
	for k, m := range bodies {
		for _, s := range m {
			check(s, string(k))
		}
	}
	for k, m := range standalone {
		for _, v := range m {
			check(v[0], string(k))
			check(v[1], string(k))
		}
	}
}

// ── Линкҳо ──────────────────────────────────────────────────────

// Линк бояд ба роҳҳое ишора кунад, ки DeepLinks дар барнома
// мефаҳмад — routing-и дуюм сохта намешавад.
func TestLinksUseKnownPrefixes(t *testing.T) {
	known := []string{"/post/", "/reel/", "/profile/", "/topic/"}
	for _, k := range AllKinds() {
		l := Link(k, "obj1", "ali")
		if l == "" {
			continue
		}
		ok := false
		for _, p := range known {
			if strings.HasPrefix(l, p) {
				ok = true
			}
		}
		if !ok {
			t.Errorf("%s: роҳи ношинос %q", k, l)
		}
	}
}

func TestLinkTargets(t *testing.T) {
	cases := map[Kind]string{
		Like:          "/post/obj1",
		Comment:       "/post/obj1",
		ReelLike:      "/reel/obj1",
		Follow:        "/profile/ali",
		CollabInvite:  "/post/obj1",
		TrendingTopic: "/topic/obj1",
	}
	for k, want := range cases {
		if got := Link(k, "obj1", "ali"); got != want {
			t.Errorf("%s → %q, интизори %q", k, got, want)
		}
	}
}

// Бе объект линки вайрон сохта намешавад.
func TestLinkEmptyWhenNoTarget(t *testing.T) {
	if l := Link(Like, "", "ali"); l != "" {
		t.Errorf("бе объект линк сохта шуд: %q", l)
	}
	if l := Link(Follow, "obj", ""); l != "" {
		t.Errorf("бе ном линки профил сохта шуд: %q", l)
	}
}

// ── Қоидаҳо ─────────────────────────────────────────────────────

// Аҳамияти баланд танҳо барои чизи воқеан фаврӣ. Сӯиистифода аз он
// боиси маҳдудкунии FCM мешавад.
func TestHighPriorityIsRare(t *testing.T) {
	high := 0
	for _, k := range AllKinds() {
		if RuleFor(k).Priority == High {
			high++
		}
	}
	if high > len(AllKinds())/3 {
		t.Errorf("%d аз %d намуд HIGH аст — хеле зиёд",
			high, len(AllKinds()))
	}
	// Паём бояд ҳатман фаврӣ бошад.
	if RuleFor(Message).Priority != High {
		t.Error("паём бояд аҳамияти баланд дошта бошад")
	}
	// Тавсия ҳаргиз фаврӣ нест.
	for _, k := range []Kind{RecommendedCreator, TrendingTopic, WeeklyRecap} {
		if RuleFor(k).Priority == High {
			t.Errorf("%s набояд фаврӣ бошад", k)
		}
	}
}

// Паём ҳеҷ гоҳ гурӯҳбандӣ намешавад: он таъхирро таҳаммул намекунад.
func TestMessagesAreNeverGrouped(t *testing.T) {
	if RuleFor(Message).Groupable {
		t.Error("паём набояд гурӯҳбандӣ шавад")
	}
}

// Ҳар канал бояд аз рӯйхати маҳдуд бошад.
func TestChannelsAreLimited(t *testing.T) {
	valid := map[Channel]bool{
		ChannelMessages: true, ChannelSocial: true, ChannelCreator: true,
		ChannelDiscovery: true, ChannelMarketplace: true,
	}
	for _, k := range AllKinds() {
		if c := RuleFor(k).Channel; !valid[c] {
			t.Errorf("%s канали ношинос дорад: %q", k, c)
		}
	}
}

// Намуди номаълум набояд телефонро бедор кунад.
func TestUnknownKindGetsSafestRule(t *testing.T) {
	r := RuleFor(Kind("BRAND_NEW"))
	if r.Priority != Low {
		t.Errorf("аҳамияти пешфарз: %v", r.Priority)
	}
	if r.Groupable {
		t.Error("намуди номаълум набояд гурӯҳбандӣ шавад")
	}
}
