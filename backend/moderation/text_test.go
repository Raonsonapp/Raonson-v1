package moderation

import (
	"context"
	"testing"
)

func noAI(t *testing.T) {
	t.Helper()
	old := aiModerate
	aiModerate = func(context.Context, string) (bool, []string) { return false, nil }
	t.Cleanup(func() { aiModerate = old })
}

func TestRulesLoadFromDataFile(t *testing.T) {
	if n := len(keywordRules()); n < 100 {
		t.Fatalf("рӯйхати калимаҳо хеле кӯтоҳ: %d", n)
	}
	if len(allowRules()) == 0 {
		t.Fatal("истисноҳо (allow) хонда нашуданд")
	}
	if len(adultDomains()) < 50 {
		t.Fatalf("доменҳои 18+ хонда нашуданд: %d", len(adultDomains()))
	}
}

func TestNormalization(t *testing.T) {
	cases := map[string]string{
		"P0RN":    "porn",
		"s3x":     "sex",
		"$ex":     "sex",
		"ПОРНО":   "порно",
		"𝐩𝐨𝐫𝐧":    "porn",    // math bold → NFKC
		"ｐｏｒｎ":    "porn",    // fullwidth
		"por​n":   "porn",    // zero-width space
		"ҷалаб":   "чалаб",   // тоҷикӣ ҷ → ч
		"кӯдакон": "кудакон", // ӯ → у
		"алоқаи":  "алокаи",
	}
	for in, want := range cases {
		toks := tokenize(in)
		if len(toks) != 1 || toks[0].text != want {
			t.Errorf("tokenize(%q) = %+v, want %q", in, toks, want)
		}
	}
	// Ҳарфҳои ҷудо: «p o r n», «p.o.r.n», «с-е-к-с».
	for _, in := range []string{"p o r n", "p.o.r.n", "p_o_r_n", "p-o-r-n"} {
		toks := tokenize(in)
		if len(toks) != 1 || toks[0].text != "porn" {
			t.Errorf("tokenize(%q) = %+v", in, toks)
		}
	}
	// Калимаи омехта: о-и кириллӣ дар «porn».
	toks := tokenize("pоrn")
	if len(toks) != 1 || toks[0].text != "porn" {
		t.Errorf("омехта: %+v", toks)
	}
	// «пoрно» бо o-и лотинӣ → шакли кириллӣ.
	toks = tokenize("пoрно")
	if len(toks) != 1 || toks[0].alt != "порно" {
		t.Errorf("омехтаи кириллӣ: %+v", toks)
	}
	// Зикр ва нидо калимаро тағйир намедиҳанд.
	toks = tokenize("@ali салом!")
	if len(toks) != 2 || toks[0].text != "ali" || toks[1].text != "салом" {
		t.Errorf("зикр/нидо: %+v", toks)
	}
}

func catOf(text string) (Action, []string) {
	v := verdictFromHits(ScanText(text))
	return v.Action, v.Categories
}

func TestKeywordHits(t *testing.T) {
	block := []string{
		"free porn here",
		"watch P0RN now",
		"p o r n o",
		"pоrnhub",       // о-и кириллӣ
		"pooorn videos", // ҳарфҳои такрорӣ
		"смотри порно",
		"ПОРНУХА",
		"пoрно",       // o-и лотинӣ
		"видеои урён", // тоҷикӣ
		"sex video link",
		"секс видео",
		"#xvideos",
		"send nudes",
		"فیلم سکس جدید",
		"پورن",
		"иди нахуй", // дашном
		"fucking idiot",
		"ты сука",
		"ҷалаб", // тоҷикӣ
	}
	for _, s := range block {
		if a, cats := catOf(s); a != Block {
			t.Errorf("бояд BLOCK шавад: %q → %v %v", s, a, cats)
		}
	}
	review := []string{"sexy dress", "she is naked", "nude lipstick", "секс", "XXX"}
	for _, s := range review {
		if a, cats := catOf(s); a != Review {
			t.Errorf("бояд REVIEW шавад: %q → %v %v", s, a, cats)
		}
	}
}

// Калимаҳое, ки филтри содда нодуруст манъ мекард.
func TestKeywordFalsePositiveGuards(t *testing.T) {
	clean := []string{
		"Essex is a county in England",
		"Middlesex University",
		"Sussex and Wessex",
		"an old brass sextant",
		"the sexton rang the bell",
		"#foodporn so tasty",
		"food porn of the day", // истисно
		"#earthporn mountains",
		"KYC verification required", // ≠ «кус»
		"Ассалому алайкум, дӯстон!",
		"Салом, чӣ хел шумо?",
		"Сегодня хорошая погода",
		"небо голубое",    // «еба» дар дохил
		"трахея и бронхи", // ≠ «трахать»
		"скупка и продажа",
		"analysis of data",  // ≠ «anal»
		"Scunthorpe United", // ≠ «cunt»
		"Cockburn street",
		"hello @sexy_name_not_here", // зикр бе калимаи манъ ҳам бояд кор кунад
		"Кирилл пришёл",
		"кирпич и цемент",
		"Душанбе 2024",
		"I a m here",
		"هر کس می‌داند", // форсӣ «кас» ≠ дашном
		"کسی آمد",
	}
	for _, s := range clean {
		a, cats := catOf(s)
		if s == "hello @sexy_name_not_here" {
			// «sexy» дар номи корбар — REVIEW мумкин, BLOCK не.
			if a == Block {
				t.Errorf("BLOCK-и нодуруст: %q %v", s, cats)
			}
			continue
		}
		if a != Allow {
			t.Errorf("матни бегуноҳ манъ шуд: %q → %v %v (%v)", s, a, cats, ScanText(s))
		}
	}
}

func TestMinorsSevere(t *testing.T) {
	for _, s := range []string{"child porn", "детское порно", "порнографияи кӯдакон", "kiddie p0rn"} {
		v := verdictFromHits(ScanText(s))
		if v.Action != Block || !v.Severe || !hasCat(v.Categories, CatMinors) {
			t.Errorf("%q: бояд severe бошад: %+v", s, v)
		}
		if !v.Strikeable() {
			t.Errorf("%q: бояд strike диҳад", s)
		}
	}
	// Дар бораи кӯдакон гап задан — мушкил нест.
	if v := verdictFromHits(ScanText("Китобҳо барои кӯдакон")); v.Action != Allow {
		t.Errorf("бегуноҳ: %+v", v)
	}
}

func TestProfanityNotStrikeable(t *testing.T) {
	v := verdictFromHits(ScanText("иди нахуй"))
	if v.Action != Block || v.Strikeable() {
		t.Fatalf("дашном: BLOCK бе strike: %+v", v)
	}
	v = verdictFromHits(ScanText("watch porn"))
	if !v.Strikeable() {
		t.Fatalf("порно бояд strike диҳад: %+v", v)
	}
}

func TestCheckTextWithAI(t *testing.T) {
	old := aiModerate
	defer func() { aiModerate = old }()
	aiModerate = func(context.Context, string) (bool, []string) { return true, []string{"sexual"} }
	v := Check(context.Background(), Item{Kind: KindText, Text: "innocent looking text", AI: true})
	if v.Action != Block || !v.Strikeable() || v.Provider != "ai" {
		t.Fatalf("AI sexual → BLOCK+strike: %+v", v)
	}
	aiModerate = func(context.Context, string) (bool, []string) { return true, []string{"violence"} }
	v = Check(context.Background(), Item{Kind: KindText, Text: "innocent looking text", AI: true})
	if v.Action != Block || v.Strikeable() {
		t.Fatalf("AI violence → BLOCK бе strike: %+v", v)
	}
	// AI хомӯш (AI:false) — ба provider намеравад.
	called := false
	aiModerate = func(context.Context, string) (bool, []string) { called = true; return true, nil }
	v = Check(context.Background(), Item{Kind: KindText, Text: "hello", AI: false})
	if called || v.Action != Allow {
		t.Fatalf("AI:false набояд provider-ро ҷеғ занад: %+v", v)
	}
}

func TestCheckAllMergesStrictest(t *testing.T) {
	noAI(t)
	v := CheckAll(context.Background(),
		Item{Kind: KindText, Text: "hello"},
		Item{Kind: KindText, Text: "sexy"},
		Item{Kind: KindText, Text: "watch porn"},
	)
	if v.Action != Block || !hasCat(v.Categories, CatSexual) {
		t.Fatalf("сахттарин бояд ғолиб шавад: %+v", v)
	}
}
