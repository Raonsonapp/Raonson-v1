package feedai

import (
	"math"
	"testing"
)

func testTopics() []Topic {
	return []Topic{
		{Slug: "gaming", Keywords: []string{"gaming", "бозӣ", "игра", "pubg"}},
		{Slug: "football", Keywords: []string{"football", "футбол", "гол"}},
		{Slug: "news", Keywords: []string{"news", "ахбор", "новости"}},
		{Slug: "anime", Keywords: []string{"anime", "аниме"}},
	}
}

// ── Сигналҳо ─────────────────────────────────────────────────────

func TestEventWeightsHaveIntendedOrder(t *testing.T) {
	// Ният муҳимтар аз осонӣ: сейв ва мубодила аз лайк вазнинтаранд.
	if EventSave.Weight() <= EventLike.Weight() {
		t.Errorf("сейв бояд аз лайк вазнинтар бошад: %v ва %v",
			EventSave.Weight(), EventLike.Weight())
	}
	if EventShare.Weight() <= EventLike.Weight() {
		t.Error("мубодила бояд аз лайк вазнинтар бошад")
	}
	// Дидан қариб чизе намегӯяд.
	if EventImpression.Weight() >= EventOpen.Weight() {
		t.Error("impression бояд аз кушодан сабуктар бошад")
	}
	// Дархости возеҳи корбар аз сигнали ғайримустақим қавитар аст.
	if EventMoreLikeThis.Weight() <= EventLike.Weight() {
		t.Error("«монанди ин бештар» бояд аз лайк қавитар бошад")
	}
	// Хомӯш кардани эҷодкор аз ҳама қавитарин сигнали манфист.
	if EventCreatorMute.Weight() >= EventLessLikeThis.Weight() {
		t.Error("хомӯшкунӣ бояд аз «камтар» манфитар бошад")
	}
}

func TestNegativeEventsAreNegative(t *testing.T) {
	for _, e := range []Event{EventLessLikeThis, EventHide, EventNotInterest,
		EventCreatorMute, EventSkip, EventUnfollow} {
		if !e.IsNegative() {
			t.Errorf("%s бояд манфӣ бошад", e)
		}
	}
	for _, e := range []Event{EventLike, EventSave, EventShare, EventFollow} {
		if e.IsNegative() {
			t.Errorf("%s набояд манфӣ бошад", e)
		}
	}
}

func TestUnknownEventRejected(t *testing.T) {
	if Event("DROP TABLE users").Valid() {
		t.Fatal("ҳодисаи номаълум қабул шуд")
	}
	if Event("").Valid() {
		t.Fatal("ҳодисаи холӣ қабул шуд")
	}
	// Вазни ҳодисаи номаълум бояд сифр бошад — на panic.
	if Event("nope").Weight() != 0 {
		t.Error("вазни ҳодисаи номаълум бояд 0 бошад")
	}
}

func TestApplySignalNeverLeavesRange(t *testing.T) {
	score := 0.0
	// Сад лайк ҳам холро аз ҳудуд намебарорад.
	for i := 0; i < 100; i++ {
		score = ApplySignal(score, EventLike.Weight())
	}
	if score > 1.0 || score < -1.0 {
		t.Fatalf("хол аз ҳудуд баромад: %v", score)
	}
	if score <= 0 {
		t.Fatalf("баъди 100 лайк хол бояд мусбат бошад: %v", score)
	}

	neg := 0.0
	for i := 0; i < 100; i++ {
		neg = ApplySignal(neg, EventCreatorMute.Weight())
	}
	if neg < -1.0 {
		t.Fatalf("холи манфӣ аз ҳудуд баромад: %v", neg)
	}
}

func TestApplySignalHasDiminishingReturns(t *testing.T) {
	// Лайки аввал бояд аз лайки даҳум бештар таъсир кунад — вагарна
	// лента дар як мавзӯъ мечаспад.
	first := ApplySignal(0, EventLike.Weight())
	s := 0.0
	for i := 0; i < 9; i++ {
		s = ApplySignal(s, EventLike.Weight())
	}
	tenth := ApplySignal(s, EventLike.Weight()) - s
	if tenth >= first {
		t.Fatalf("афзоиш коҳиш намеёбад: аввал %v, даҳум %v", first, tenth)
	}
}

func TestDecayForgetsOldInterest(t *testing.T) {
	if got := Decay(1.0, 30, 30); math.Abs(got-0.5) > 0.001 {
		t.Fatalf("баъди як нимумр бояд 0.5 шавад, гирифтем %v", got)
	}
	if got := Decay(1.0, 0, 30); got != 1.0 {
		t.Fatalf("бе гузашти вақт тағйир набояд бошад: %v", got)
	}
	// Муҳофизат аз тақсим ба сифр.
	if got := Decay(1.0, 10, 0); got != 1.0 {
		t.Fatalf("halfLife=0 бояд бетаъсир бошад: %v", got)
	}
}

// ── Таснифи мавзӯъ ───────────────────────────────────────────────

func TestClassifyTextFindsTopics(t *testing.T) {
	got := ClassifyText("Имрӯз PUBG бозӣ кардам ва як гол задам", testTopics())
	if _, ok := got["gaming"]; !ok {
		t.Errorf("gaming ёфт нашуд: %+v", got)
	}
	if _, ok := got["football"]; !ok {
		t.Errorf("football ёфт нашуд: %+v", got)
	}
	if _, ok := got["anime"]; ok {
		t.Errorf("anime набояд ёфт мешуд: %+v", got)
	}
}

func TestClassifyTextMatchesHashtags(t *testing.T) {
	got := ClassifyText("Салом #gaming #anime", testTopics())
	if len(got) != 2 {
		t.Fatalf("интизори 2 мавзӯъ, гирифтем %+v", got)
	}
}

func TestClassifyTextAvoidsSubstringFalsePositives(t *testing.T) {
	// "engaging" калимаи "gaming"-ро дар бар надорад ҳамчун калимаи алоҳида.
	got := ClassifyText("This is an engaging conversation", testTopics())
	if _, ok := got["gaming"]; ok {
		t.Errorf("мувофиқати бардурӯғ дар «engaging»: %+v", got)
	}
}

func TestClassifyTextEmpty(t *testing.T) {
	if got := ClassifyText("", testTopics()); len(got) != 0 {
		t.Errorf("матни холӣ бояд ҳеҷ мавзӯъ надиҳад: %+v", got)
	}
	if got := ClassifyText("   ", testTopics()); len(got) != 0 {
		t.Errorf("матни фосилавӣ: %+v", got)
	}
}

func TestClassifyWeightGrowsButIsBounded(t *testing.T) {
	one := ClassifyText("бозӣ", testTopics())["gaming"]
	many := ClassifyText("бозӣ игра gaming pubg", testTopics())["gaming"]
	if many <= one {
		t.Errorf("мувофиқати бештар бояд вазни бештар диҳад: %v ва %v", one, many)
	}
	if many > 1.0 {
		t.Errorf("вазн аз 1 гузашт: %v", many)
	}
}

// ── Таҷзияи забони табиӣ ─────────────────────────────────────────

func TestParseIntentPositive(t *testing.T) {
	in, err := ParseIntent("Ман мехоҳам бештар gaming ва футбол бинам", testTopics())
	if err != nil {
		t.Fatalf("хато: %v", err)
	}
	if !contains(in.PositiveTopics, "gaming") ||
		!contains(in.PositiveTopics, "football") {
		t.Fatalf("мавзӯъҳои мусбат: %+v", in.PositiveTopics)
	}
	if len(in.NegativeTopics) != 0 {
		t.Fatalf("мавзӯи манфӣ набояд бошад: %+v", in.NegativeTopics)
	}
}

func TestParseIntentNegative(t *testing.T) {
	in, err := ParseIntent("Камтар ахбор нишон деҳ", testTopics())
	if err != nil {
		t.Fatalf("хато: %v", err)
	}
	if !contains(in.NegativeTopics, "news") {
		t.Fatalf("news бояд манфӣ бошад: %+v", in)
	}
	if contains(in.PositiveTopics, "news") {
		t.Fatal("news набояд ҳамзамон мусбат бошад")
	}
}

func TestParseIntentMixedClauses(t *testing.T) {
	// «Камтар» набояд ба банди дигар гузарад.
	in, err := ParseIntent("Бештар gaming, камтар news", testTopics())
	if err != nil {
		t.Fatalf("хато: %v", err)
	}
	if !contains(in.PositiveTopics, "gaming") {
		t.Errorf("gaming бояд мусбат бошад: %+v", in)
	}
	if !contains(in.NegativeTopics, "news") {
		t.Errorf("news бояд манфӣ бошад: %+v", in)
	}
	if contains(in.NegativeTopics, "gaming") {
		t.Error("«камтар» ба банди gaming гузашт")
	}
}

func TestParseIntentEnglishAndRussian(t *testing.T) {
	en, err := ParseIntent("Show me more gaming, less news", testTopics())
	if err != nil || !contains(en.PositiveTopics, "gaming") ||
		!contains(en.NegativeTopics, "news") {
		t.Fatalf("англисӣ: %+v (%v)", en, err)
	}
	ru, err := ParseIntent("Меньше новости, больше футбол", testTopics())
	if err != nil || !contains(ru.NegativeTopics, "news") ||
		!contains(ru.PositiveTopics, "football") {
		t.Fatalf("русӣ: %+v (%v)", ru, err)
	}
}

func TestParseIntentLanguagesAndFlags(t *testing.T) {
	in, err := ParseIntent(
		"Танҳо creator-ҳои тоҷикро нишон деҳ, забони тоҷикӣ", testTopics())
	if err != nil {
		t.Fatalf("хато: %v", err)
	}
	if !in.PreferLocal {
		t.Error("preferLocal бояд рост бошад")
	}
	if !contains(in.Languages, "tj") {
		t.Errorf("забони tj: %+v", in.Languages)
	}
}

func TestParseIntentRejectsMeaninglessInput(t *testing.T) {
	for _, s := range []string{"", "   ", "асдфгҳ", "12345"} {
		if _, err := ParseIntent(s, testTopics()); err == nil {
			t.Errorf("матни %q бояд рад шавад", s)
		}
	}
}

func TestParseIntentOnlyReturnsKnownTopics(t *testing.T) {
	// Мавзӯи ихтироъшуда набояд пайдо шавад — танҳо slug-и воқеӣ.
	in, err := ParseIntent("бештар gaming ва квантовая физика", testTopics())
	if err != nil {
		t.Fatalf("хато: %v", err)
	}
	known := map[string]bool{"gaming": true, "football": true,
		"news": true, "anime": true}
	for _, s := range append(in.PositiveTopics, in.NegativeTopics...) {
		if !known[s] {
			t.Fatalf("мавзӯи номаълум баргашт: %q", s)
		}
	}
}

// ── Рейтинг ──────────────────────────────────────────────────────

func TestPersonalizeKeepsBaseScoreAsFoundation(t *testing.T) {
	w := DefaultWeights()
	c := Candidate{ContentID: "p1", BaseScore: 100}
	score, contrib := Personalize(c, w, false, false, false, false)
	if score != 100 {
		t.Fatalf("бе сигнал хол бояд base монад: %v", score)
	}
	if contrib.Total() != 0 {
		t.Fatalf("саҳм бояд сифр бошад: %+v", contrib)
	}
}

func TestPersonalizeTopicAffinityMovesScore(t *testing.T) {
	w := DefaultWeights()
	liked := Candidate{BaseScore: 100,
		Topics: []TopicMatch{{Slug: "gaming", Pref: 1, Weight: 1}}}
	disliked := Candidate{BaseScore: 100,
		Topics: []TopicMatch{{Slug: "news", Pref: -1, Weight: 1}}}

	up, _ := Personalize(liked, w, false, false, false, false)
	down, _ := Personalize(disliked, w, false, false, false, false)

	if up <= 100 {
		t.Errorf("мавзӯи дӯстдошта бояд боло барад: %v", up)
	}
	if down >= 100 {
		t.Errorf("мавзӯи нохуш бояд поён барад: %v", down)
	}
	// Қабати идорашаванда набояд асосро ғарқ кунад: обуна 100 балл аст.
	if up-100 > 100 {
		t.Errorf("саҳми мавзӯъ хеле калон: %v", up-100)
	}
}

func TestPersonalizeMultiTopicUsesWeightedAverage(t *testing.T) {
	w := DefaultWeights()
	// Пост бо ду мавзӯъ — яке дӯстдошта, дигаре нохуш — бояд
	// тақрибан бетараф бошад, на ҷамъи ду.
	c := Candidate{BaseScore: 100, Topics: []TopicMatch{
		{Slug: "gaming", Pref: 1, Weight: 1},
		{Slug: "news", Pref: -1, Weight: 1},
	}}
	score, contrib := Personalize(c, w, false, false, false, false)
	if math.Abs(contrib.Topic) > 0.01 {
		t.Fatalf("саҳми мавзӯъ бояд тақрибан 0 бошад: %v", contrib.Topic)
	}
	if math.Abs(score-100) > 0.01 {
		t.Fatalf("хол: %v", score)
	}
}

func TestPersonalizeFewerRecommendationsOnlyPenalisesNonFollowing(t *testing.T) {
	w := DefaultWeights()
	followed := Candidate{BaseScore: 100, IsFollowing: true}
	stranger := Candidate{BaseScore: 100, IsFollowing: false}

	f, fc := Personalize(followed, w, true, false, false, false)
	s, sc := Personalize(stranger, w, true, false, false, false)

	if fc.FewerRecs != 0 {
		t.Errorf("мӯҳтавои обуна набояд ҷарима гирад: %v", fc.FewerRecs)
	}
	if sc.FewerRecs >= 0 {
		t.Errorf("мӯҳтавои беруна бояд ҷарима гирад: %v", sc.FewerRecs)
	}
	if f <= s {
		t.Errorf("обуна бояд болотар бошад: %v ва %v", f, s)
	}
}

func TestPersonalizeOptionalBoostsOnlyWhenRequested(t *testing.T) {
	w := DefaultWeights()
	c := Candidate{BaseScore: 100, IsLocal: true, IsOriginal: true,
		IsFollowing: true, LanguageHit: true}

	_, off := Personalize(c, w, false, false, false, false)
	if off.Local != 0 || off.Original != 0 || off.Following != 0 {
		t.Fatalf("бе дархости корбар бонус набояд бошад: %+v", off)
	}
	// Забон афзалияти алоҳида надорад — он ҳамеша ҳисоб мешавад.
	if off.Language != w.Language {
		t.Errorf("мувофиқати забон бояд ҳисоб шавад: %v", off.Language)
	}

	_, on := Personalize(c, w, false, true, true, true)
	if on.Local == 0 || on.Original == 0 || on.Following == 0 {
		t.Fatalf("бо дархост бонус бояд бошад: %+v", on)
	}
}

func contains(list []string, want string) bool {
	for _, v := range list {
		if v == want {
			return true
		}
	}
	return false
}
