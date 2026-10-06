package moderation

import (
	"bufio"
	"context"
	_ "embed"
	"strings"
	"sync"
	"time"
	"unicode"

	"golang.org/x/text/unicode/norm"

	"raonson/utils"
)

//go:embed data/keywords.txt
var keywordsData string

// wordPat — як калимаи намуна.
type wordPat struct {
	text   string
	prefix bool // «калима*»
	sub    bool // «*калима*»
}

func (w wordPat) match(tok string) bool {
	switch {
	case w.sub:
		return strings.Contains(tok, w.text)
	case w.prefix:
		return strings.HasPrefix(tok, w.text)
	}
	return tok == w.text
}

// rule — як сатри рӯйхат.
type rule struct {
	cat   string
	words []wordPat
	raw   string
}

var (
	rulesOnce sync.Once
	rules     []rule
	allows    []rule
)

func keywordRules() []rule {
	rulesOnce.Do(func() { rules, allows = parseRules(keywordsData) })
	return rules
}

func allowRules() []rule {
	keywordRules()
	return allows
}

// parseRules — файли data/keywords.txt-ро мехонад.
func parseRules(data string) (out, allow []rule) {
	sc := bufio.NewScanner(strings.NewReader(data))
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		cat, pat, ok := strings.Cut(line, "|")
		if !ok {
			continue
		}
		cat = strings.TrimSpace(cat)
		var words []wordPat
		for _, w := range strings.Fields(pat) {
			wp := wordPat{}
			if strings.HasPrefix(w, "*") && strings.HasSuffix(w, "*") && len(w) > 2 {
				wp.sub = true
				w = w[1 : len(w)-1]
			} else if strings.HasSuffix(w, "*") {
				wp.prefix = true
				w = strings.TrimSuffix(w, "*")
			}
			// Намуна ҳамон нормализатсияро мегузарад, ки матн —
			// вагарна «ҷалаб» дар файл бо «чалаб»-и матн мувофиқ намеояд.
			w = strings.ReplaceAll(w, "*", "")
			toks := tokenize(w)
			if len(toks) != 1 {
				// «sex-видео» → ду калима.
				for i, t := range toks {
					p := wordPat{text: t.text}
					if i == len(toks)-1 {
						p.prefix, p.sub = wp.prefix, wp.sub
					}
					words = append(words, p)
				}
				continue
			}
			wp.text = toks[0].text
			words = append(words, wp)
		}
		if len(words) == 0 {
			continue
		}
		r := rule{cat: cat, words: words, raw: pat}
		if cat == "allow" {
			allow = append(allow, r)
		} else {
			out = append(out, r)
		}
	}
	return out, allow
}

// ── нормализатсия ─────────────────────────────────────────────────

// Ҳарфҳои ҳамшакл: кириллӣ/юнонӣ → лотинӣ.
var toLatin = map[rune]rune{
	'а': 'a', 'е': 'e', 'о': 'o', 'р': 'p', 'с': 'c', 'х': 'x', 'у': 'y',
	'к': 'k', 'м': 'm', 'т': 't', 'н': 'h', 'в': 'b', 'і': 'i', 'ј': 'j',
	'ѕ': 's', 'ԁ': 'd', 'ɡ': 'g', 'ɑ': 'a', 'ο': 'o', 'α': 'a', 'ν': 'v',
	'ρ': 'p', 'ε': 'e', 'τ': 't', 'κ': 'k', 'χ': 'x', 'ι': 'i', 'υ': 'u',
}

// Лотинӣ → кириллӣ (барои «пoрно» бо o-и лотинӣ).
var toCyr = map[rune]rune{
	'a': 'а', 'e': 'е', 'o': 'о', 'p': 'р', 'c': 'с', 'x': 'х', 'y': 'у',
	'k': 'к', 'm': 'м', 't': 'т', 'h': 'н', 'b': 'в', 'i': 'и', 'n': 'п',
	'u': 'и',
}

var leetLatin = map[rune]rune{
	'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '8': 'b',
	'@': 'a', '$': 's', '!': 'i',
}

var leetCyr = map[rune]rune{
	'0': 'о', '3': 'з', '4': 'ч', '6': 'б', '@': 'а', '$': 'с',
}

// Ҳарфҳои махсуси тоҷикӣ ва форсӣ → шакли умумӣ.
var foldMap = map[rune]rune{
	'ҳ': 'х', 'ҷ': 'ч', 'қ': 'к', 'ғ': 'г', 'ӯ': 'у', 'ӣ': 'и', 'ё': 'е',
	'й': 'и', 'ъ': 0, 'ь': 0,
	'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ة': 'ه', 'أ': 'ا', 'إ': 'ا', 'آ': 'ا',
	'ۀ': 'ه', 'ؤ': 'و',
}

// invisible — аломатҳое, ки дида намешаванд ва калимаро «мешикананд».
func invisible(r rune) bool {
	switch r {
	case '\u200b', '\u200c', '\u200d', '\u2060', '\ufeff', '\u00ad', '\u180e', '\u0640':
		return true
	}
	return false
}

type script int

const (
	scNone script = iota
	scLatin
	scCyr
	scOther
)

func scriptOf(r rune) script {
	switch {
	case r >= 'a' && r <= 'z':
		return scLatin
	case unicode.Is(unicode.Cyrillic, r):
		return scCyr
	case unicode.Is(unicode.Greek, r):
		return scCyr // юнонӣ танҳо ҳамчун ҳамшакл
	case unicode.IsLetter(r):
		return scOther
	}
	return scNone
}

// token — як калимаи матн бо ду шакли имконпазир.
type token struct {
	text string // шакли асосӣ
	alt  string // шакли дигар барои калимаҳои омехта (лотинӣ+кириллӣ)
}

// fold — ҳарфи хурд, NFKC (𝐩𝐨𝐫𝐧 → porn, ｐｏｒｎ → porn), нишонаҳои
// болоӣ хориҷ (ӣ → и), ҳарфҳои тоҷикӣ/форсӣ ба шакли умумӣ.
func fold(s string) string {
	s = norm.NFKC.String(strings.ToLower(s))
	s = norm.NFD.String(s)
	var b strings.Builder
	for _, r := range s {
		if unicode.Is(unicode.Mn, r) || invisible(r) {
			continue
		}
		if m, ok := foldMap[r]; ok {
			if m == 0 {
				continue
			}
			r = m
		}
		b.WriteRune(unicode.ToLower(r))
	}
	return norm.NFC.String(b.String())
}

func isTokenRune(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsDigit(r)
}

func isLeetSym(r rune) bool { return r == '@' || r == '$' || r == '!' }

// tokenize — матнро ба калимаҳо ҷудо мекунад.
func tokenize(s string) []token {
	s = fold(s)
	rs := []rune(s)
	var raw []string
	var cur []rune
	flush := func() {
		if len(cur) > 0 {
			raw = append(raw, string(cur))
			cur = cur[:0]
		}
	}
	for i, r := range rs {
		if isTokenRune(r) {
			cur = append(cur, r)
			continue
		}
		// «$ex», «s@x», «p!ss» — аломат танҳо вақте ҳарф ҳисоб
		// мешавад, ки дар байни ҳарфҳо (ё «$»-и аввали калима) бошад.
		// «@user» (зикр) ва «sex!» (нидо) калима намешаванд.
		if isLeetSym(r) {
			nextLetter := i+1 < len(rs) && unicode.IsLetter(rs[i+1])
			prevLetter := len(cur) > 0
			if nextLetter && (prevLetter || r == '$') {
				cur = append(cur, r)
				continue
			}
		}
		flush()
	}
	flush()

	// «p o r n», «p.o.r.n», «с-е-к-с» — 3+ ҳарфи танҳо пайдарпай → як калима.
	var merged []string
	for i := 0; i < len(raw); {
		j := i
		for j < len(raw) && len([]rune(raw[j])) == 1 {
			j++
		}
		if j-i >= 3 {
			merged = append(merged, strings.Join(raw[i:j], ""))
			i = j
			continue
		}
		if j == i {
			merged = append(merged, raw[i])
			i++
			continue
		}
		merged = append(merged, raw[i:j]...)
		i = j
	}

	out := make([]token, 0, len(merged))
	for _, w := range merged {
		out = append(out, normalizeToken(w))
	}
	return out
}

// normalizeToken — leet ва ҳарфҳои ҳамшакл.
//
// Калимаи пурра лотинӣ ё пурра кириллӣ ҲАМЧУН ҲАСТ мемонад: «kyc»
// (Know Your Customer) набояд ба «кус» табдил ёбад. Танҳо калимаи
// ОМЕХТА («pоrn» бо о-и кириллӣ) ду шакл мегирад — ин ҳамон ҳилаест,
// ки барои гузаштан аз филтр истифода мешавад.
func normalizeToken(w string) token {
	var hasLatin, hasCyr, hasLetter bool
	for _, r := range w {
		switch scriptOf(r) {
		case scLatin:
			hasLatin, hasLetter = true, true
		case scCyr:
			hasCyr, hasLetter = true, true
		case scOther:
			hasLetter = true
		}
	}
	if !hasLetter {
		return token{text: w}
	}
	mapRunes := func(m map[rune]rune, leet map[rune]rune) string {
		var b strings.Builder
		for _, r := range w {
			if x, ok := leet[r]; ok {
				r = x
			} else if x, ok := m[r]; ok {
				r = x
			}
			b.WriteRune(r)
		}
		return b.String()
	}
	switch {
	case hasLatin && hasCyr:
		return token{text: mapRunes(toLatin, leetLatin), alt: mapRunes(toCyr, leetCyr)}
	case hasCyr:
		return token{text: mapRunes(nil, leetCyr)}
	case hasLatin:
		return token{text: mapRunes(nil, leetLatin)}
	}
	return token{text: w}
}

// squeeze — 3+ ҳарфи якхела → як ҳарф («pooorn» → «porn»).
func squeeze(s string) string {
	rs := []rune(s)
	var b strings.Builder
	for i := 0; i < len(rs); {
		j := i
		for j < len(rs) && rs[j] == rs[i] {
			j++
		}
		if j-i >= 3 {
			b.WriteRune(rs[i])
		} else {
			b.WriteString(string(rs[i:j]))
		}
		i = j
	}
	return b.String()
}

// ── мувофиқат ─────────────────────────────────────────────────────

// variants — шаклҳои матн барои санҷиш.
func variants(toks []token) [][]string {
	base := make([]string, len(toks))
	alt := make([]string, len(toks))
	hasAlt := false
	for i, t := range toks {
		base[i] = t.text
		alt[i] = t.text
		if t.alt != "" {
			alt[i] = t.alt
			hasAlt = true
		}
	}
	out := [][]string{base}
	if hasAlt {
		out = append(out, alt)
	}
	// Ҳарфҳои такрорӣ: «pooorn», «сееекс».
	for _, v := range append([][]string{}, out...) {
		sq := make([]string, len(v))
		changed := false
		for i, w := range v {
			sq[i] = squeeze(w)
			if sq[i] != w {
				changed = true
			}
		}
		if changed {
			out = append(out, sq)
		}
	}
	return out
}

// matchAt — оё намуна аз мавқеи i сар мешавад?
func matchAt(words []wordPat, toks []string, i int) bool {
	if i+len(words) > len(toks) {
		return false
	}
	for k, w := range words {
		if !w.match(toks[i+k]) {
			return false
		}
	}
	return true
}

// TextHit — як мувофиқат.
type TextHit struct {
	Category string
	Pattern  string
}

// ScanText — ҳамаи мувофиқатҳо дар матн (барои санҷиш ва log).
func ScanText(text string) []TextHit {
	if strings.TrimSpace(text) == "" {
		return nil
	}
	toks := tokenize(text)
	if len(toks) == 0 {
		return nil
	}
	var hits []TextHit
	seen := map[string]bool{}
	for _, v := range variants(toks) {
		// Истисноҳо («food porn») аввал хориҷ мешаванд.
		masked := make([]string, len(v))
		copy(masked, v)
		for _, a := range allowRules() {
			for i := range v {
				if matchAt(a.words, v, i) {
					for k := range a.words {
						masked[i+k] = "\x00"
					}
				}
			}
		}
		for _, r := range keywordRules() {
			if seen[r.raw] {
				continue
			}
			for i := range masked {
				if matchAt(r.words, masked, i) {
					hits = append(hits, TextHit{Category: r.cat, Pattern: r.raw})
					seen[r.raw] = true
					break
				}
			}
		}
	}
	return hits
}

// verdictFromHits — категорияҳо → қарор.
func verdictFromHits(hits []TextHit) Verdict {
	v := Verdict{Action: Allow}
	for _, h := range hits {
		switch h.Category {
		case CatMinors:
			v = Merge(v, Verdict{Action: Block, Categories: []string{CatMinors, CatSexual},
				Severe: true, Score: 1, Provider: "keywords", Reason: h.Pattern})
		case CatSexual, CatProfanity:
			v = Merge(v, Verdict{Action: Block, Categories: []string{h.Category},
				Score: 1, Provider: "keywords", Reason: h.Pattern})
		case CatSuggestive:
			v = Merge(v, Verdict{Action: Review, Categories: []string{CatSuggestive},
				Score: 0.6, Provider: "keywords", Reason: h.Pattern})
		}
	}
	return v
}

// CheckTextKeywords — танҳо рӯйхати калимаҳо ва линкҳо (бе AI).
func CheckTextKeywords(ctx context.Context, text string) Verdict {
	v := verdictFromHits(ScanText(text))
	if v.Action == Block {
		return v
	}
	return Merge(v, CheckLinksInText(ctx, text))
}

// aiModerate — иваз карда мешавад дар санҷишҳо.
var aiModerate = utils.ModerateText

// checkText — калимаҳо + линкҳо + (ихтиёрӣ) AI.
func checkText(ctx context.Context, text string, useAI bool) Verdict {
	if strings.TrimSpace(text) == "" {
		return Verdict{Action: Allow}
	}
	v := CheckTextKeywords(ctx, text)
	if v.Action == Block || !useAI {
		return v
	}
	actx, cancel := timeoutCtx(ctx, 12*time.Second)
	defer cancel()
	flagged, cats := aiModerate(actx, text)
	if !flagged {
		return v
	}
	ai := Verdict{Action: Block, Score: 1, Provider: "ai", Reason: strings.Join(cats, ",")}
	for _, c := range cats {
		lc := strings.ToLower(c)
		switch {
		case strings.Contains(lc, "minor"):
			ai.Categories = append(ai.Categories, CatMinors, CatSexual)
			ai.Severe = true
		case strings.Contains(lc, "sexual"):
			ai.Categories = append(ai.Categories, CatSexual)
		default:
			// Зӯроварӣ, нафрат ва ғ. — рад мешавад (ҳамон рафтори
			// пешина), вале ба strike намеравад.
			ai.Categories = append(ai.Categories, lc)
		}
	}
	if len(ai.Categories) == 0 {
		ai.Categories = []string{"flagged"}
	}
	ai.Categories = mergeCats(ai.Categories, nil)
	return Merge(v, ai)
}
