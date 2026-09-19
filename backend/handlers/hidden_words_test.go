package handlers

import (
	"strings"
	"testing"
)

// Калимаҳои пинҳон — ҳимояи худи корбар аз шарҳи нохуш.
//
// Ду хатари муқобил ҳаст ва ҳарду бад:
//
//   • хеле ВАСЕЪ: «кор» дар «корбар» мувофиқ ояд → нимаи шарҳҳои
//     беғараз пинҳон мешаванд ва корбар намефаҳмад, ки чаро;
//   • хеле ТОР: «Бад» бо ҳарфи калон нагирифта шавад → ҳимоя
//     бемаъно мешавад.

func TestHiddenWordMatchesWholeWordOnly(t *testing.T) {
	words := []string{"кор"}

	yes := []string{
		"кор",
		"ин кор бад аст",
		"КОР",        // ҳарфи калон
		"бад, кор!",  // аломат дар паҳлӯ
		"кор.",
	}
	for _, s := range yes {
		if !containsHiddenWord(s, words) {
			t.Errorf("бояд мувофиқ меомад: %q", s)
		}
	}

	no := []string{
		"корбар",  // калимаи дигар
		"ҳамкор",  // калимаи дигар
		"коргар",
		"",
	}
	for _, s := range no {
		if containsHiddenWord(s, words) {
			t.Errorf("набояд мувофиқ меомад: %q — нимаи шарҳҳои "+
				"беғараз пинҳон мешаванд", s)
		}
	}
}

func TestHiddenPhraseMatchesAnywhere(t *testing.T) {
	// Ибора бо фосила — ҳамчун порчаи матн ҷустуҷӯ мешавад.
	words := []string{"хеле бад"}
	if !containsHiddenWord("ин хеле бад аст", words) {
		t.Error("ибора ёфт нашуд")
	}
	if containsHiddenWord("хеле хуб аст", words) {
		t.Error("ибораи мавҷуднабуда мувофиқ омад")
	}
}

func TestHiddenWordWorksAcrossAlphabets(t *testing.T) {
	// Корбарони мо ба се забон менависанд.
	cases := []struct {
		word, text string
		want       bool
	}{
		{"плохо", "это плохо", true},
		{"плохо", "неплохой", false},
		{"bad", "this is bad", true},
		{"bad", "badge", false},
		{"бад", "бад аст", true},
	}
	for _, c := range cases {
		got := containsHiddenWord(c.text, []string{c.word})
		if got != c.want {
			t.Errorf("«%s» дар «%s»: %v, интизор %v",
				c.word, c.text, got, c.want)
		}
	}
}

func TestEmptyListHidesNothing(t *testing.T) {
	// Бе ин ҳар шарҳ пинҳон мешуд.
	if containsHiddenWord("ҳар чӣ бошад", nil) {
		t.Error("рӯйхати холӣ шарҳро пинҳон мекунад")
	}
	if containsHiddenWord("матн", []string{""}) {
		t.Error("калимаи холӣ ба ҳама мувофиқ меояд")
	}
}

// Шарҳи пинҳон набояд РАД шавад ва набояд огоҳинома диҳад.
func TestHiddenCommentIsHiddenNotRejected(t *testing.T) {
	body := funcBody(t, "other.go", "AddComment")

	if !strings.Contains(body, "containsHiddenWord(") {
		t.Fatal("калимаҳои пинҳон санҷида намешаванд")
	}
	// Калимаҳои СОҲИБИ ПОСТ, на нависанда.
	if !strings.Contains(body, "hiddenWordsOf(context.Background(), postOwner)") {
		t.Error("рӯйхати нависанда истифода мешавад, на соҳиби пост")
	}
	// Пинҳон ≠ рад. Нависанда набояд бифаҳмад.
	if strings.Contains(body, `StatusForbidden, gin.H{"message": "Шарҳ пинҳон`) {
		t.Error("шарҳ рад мешавад — нависанда фавран мефаҳмад ва " +
			"роҳи гузаштанро меҷӯяд")
	}
	if !strings.Contains(body, "if hidden {") {
		t.Error("шарҳи пинҳон аз ҷараёни огоҳинома бароварда намешавад")
	}
}

// Нависанда шарҳи ХУДро мебинад; дигарон не.
func TestHiddenCommentVisibleOnlyToAuthor(t *testing.T) {
	body := funcBody(t, "other.go", "GetComments")

	if !strings.Contains(body, "COALESCE(c.hidden,false) = FALSE") {
		t.Error("шарҳи пинҳон ба ҳама намоён аст")
	}
	if !strings.Contains(body, "c.user_id = $2::text") {
		t.Error("нависанда шарҳи худро намебинад — ӯ фавран " +
			"мефаҳмад, ки пинҳон шуд")
	}
}
