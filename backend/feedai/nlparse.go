package feedai

import (
	"errors"
	"strings"
)

// ErrNoPreference — аз матн ҳеҷ афзалият ёфт нашуд.
var ErrNoPreference = errors.New("feedai: аз матн афзалият ёфт нашуд")

// Intent — натиҷаи таҷзияи фармони забони табиӣ.
//
// Ин сохтор ҳамеша ТАФТИШШУДА аст: танҳо slug-ҳои воқеан мавҷуд ва
// забонҳои дастгиришаванда дохил мешаванд. Ҷавоби хоми AI ҳеҷ гоҳ
// мустақиман ҳамчун конфигуратсия захира намешавад.
type Intent struct {
	PositiveTopics []string `json:"positiveTopics"`
	NegativeTopics []string `json:"negativeTopics"`
	Languages      []string `json:"languagePreferences"`
	PreferLocal    bool     `json:"preferLocal"`
	PreferOriginal bool     `json:"preferOriginal"`
}

// IsEmpty — оё ният холист?
func (i Intent) IsEmpty() bool {
	return len(i.PositiveTopics) == 0 && len(i.NegativeTopics) == 0 &&
		len(i.Languages) == 0 && !i.PreferLocal && !i.PreferOriginal
}

// Калимаҳои «камтар» дар се забон. Агар яке аз инҳо дар ҷумла бошад,
// мавзӯъҳои он ҷумла манфӣ ҳисоб мешаванд.
var lessWords = []string{
	"камтар", "кам ", "нахоҳам", "намехоҳам", "нест кун", "накун",
	"меньше", "не хочу", "убрать", "хватит",
	"less", "fewer", "stop", "hide", "don't", "dont", "no more",
}

// Калимаҳои «бештар» — барои возеҳӣ; пешфарз ҳам мусбат аст.
var moreWords = []string{
	"бештар", "зиёдтар", "мехоҳам", "нишон деҳ",
	"больше", "хочу", "покажи",
	"more", "show", "want",
}

var localWords = []string{
	"тоҷик", "точик", "маҳаллӣ", "махалли",
	"таджик", "местн",
	"tajik", "local",
}

var originalWords = []string{
	"аслӣ", "асли", "оригинал",
	"original", "authentic",
}

// languageAliases — номи забон дар матн → рамзи забон.
var languageAliases = map[string]string{
	"тоҷикӣ": "tj", "точики": "tj", "тоҷики": "tj", "таджикск": "tj", "tajik": "tj",
	"русӣ": "ru", "руси": "ru", "русск": "ru", "russian": "ru",
	"англисӣ": "en", "англиси": "en", "английск": "en", "english": "en",
}

// ParseIntent фармони корбарро ба афзалиятҳои сохтор табдил медиҳад.
//
// Ин таҷзия ДЕТЕРМИНИСТӢ аст ва ҳеҷ LLM намехоҳад: барои «бештар
// gaming» даъвати AI гарон ва нолозим аст. Ҷумла ба қисмҳо ҷудо
// мешавад, то «бештар gaming, камтар news» ҳар ду ниятро дуруст диҳад.
func ParseIntent(text string, topics []Topic) (Intent, error) {
	var out Intent
	if strings.TrimSpace(text) == "" {
		return out, ErrNoPreference
	}
	lower := strings.ToLower(text)

	// Ҷумларо аз рӯи аломатҳои ҷудокунӣ ва пайвандакҳо мешиканем, то
	// «камтар» аз як банд ба банди дигар нагузарад.
	clauses := splitClauses(lower)

	seenPos := map[string]bool{}
	seenNeg := map[string]bool{}

	for _, cl := range clauses {
		negative := containsAny(cl, lessWords)
		found := ClassifyText(cl, topics)
		for slug := range found {
			if negative {
				if !seenNeg[slug] {
					seenNeg[slug] = true
					out.NegativeTopics = append(out.NegativeTopics, slug)
				}
			} else if !seenPos[slug] {
				seenPos[slug] = true
				out.PositiveTopics = append(out.PositiveTopics, slug)
			}
		}
	}

	// Мавзӯе, ки ҳам мусбат ҳам манфӣ гуфта шуд — манфӣ бартарӣ дорад.
	// Дархости «камтар»-и возеҳ аз мусбати тасодуфӣ муҳимтар аст.
	if len(out.NegativeTopics) > 0 {
		filtered := out.PositiveTopics[:0]
		for _, s := range out.PositiveTopics {
			if !seenNeg[s] {
				filtered = append(filtered, s)
			}
		}
		out.PositiveTopics = filtered
	}

	// Забонҳо.
	seenLang := map[string]bool{}
	for alias, code := range languageAliases {
		if strings.Contains(lower, alias) && !seenLang[code] {
			seenLang[code] = true
			out.Languages = append(out.Languages, code)
		}
	}

	out.PreferLocal = containsAny(lower, localWords)
	out.PreferOriginal = containsAny(lower, originalWords)

	if out.IsEmpty() {
		return out, ErrNoPreference
	}
	return out, nil
}

// splitClauses ҷумларо ба бандҳо ҷудо мекунад.
func splitClauses(s string) []string {
	seps := []string{",", ".", ";", "!", "?", "\n",
		" вале ", " аммо ", " лекин ", " но ", " but "}
	parts := []string{s}
	for _, sep := range seps {
		var next []string
		for _, p := range parts {
			next = append(next, strings.Split(p, sep)...)
		}
		parts = next
	}
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if strings.TrimSpace(p) != "" {
			out = append(out, p)
		}
	}
	if len(out) == 0 {
		return []string{s}
	}
	return out
}

func containsAny(s string, words []string) bool {
	for _, w := range words {
		if strings.Contains(s, w) {
			return true
		}
	}
	return false
}

// HasExplicitDirection — оё корбар «бештар»/«камтар» гуфт?
//
// Барои паём ба корбар: агар ӯ танҳо номи мавзӯъро нависад, мо онро
// мусбат мегирем, вале беҳтар аст, ки инро возеҳ нишон диҳем.
func HasExplicitDirection(text string) bool {
	lower := strings.ToLower(text)
	return containsAny(lower, lessWords) || containsAny(lower, moreWords)
}
