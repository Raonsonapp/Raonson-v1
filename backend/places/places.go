// Package places — рӯйхати ҷойҳо барои «Ҷой»-и пост (мисли Instagram).
//
// Маълумот (places.json) аз tool/places/build_places.py сохта мешавад ва
// ба худи сервер дохил аст: ҳамаи вилоятҳо, шаҳрҳо ва ноҳияҳои
// Тоҷикистон, баъзе деҳаҳо/шаҳракҳо ва ҷойҳои машҳур, инчунин
// кишварҳо ва шаҳрҳои калони ҷаҳон.
//
// ⚠️ Махфият: координатаҳои корбар ба ҳеҷ хидмати берунӣ (geocoding)
// фиристода намешаванд — ҷойи наздиктарин аз ҳамин рӯйхат ҳисоб мешавад
// ва координатаҳо нигоҳ дошта намешаванд.
package places

import (
	_ "embed"
	"encoding/json"
	"math"
	"sort"
	"strings"
	"unicode"
)

//go:embed places.json
var raw []byte

// Place — як ҷой аз рӯйхат.
type Place struct {
	ID     string   `json:"id"`
	Kind   string   `json:"k"` // country | region | city | district | town | poi
	Parent string   `json:"p"`
	CC     string   `json:"cc"`
	TJ     string   `json:"tj"`
	RU     string   `json:"ru"`
	EN     string   `json:"en"`
	Alt    []string `json:"a"`
	Lat    float64  `json:"lat"`
	Lon    float64  `json:"lon"`
	Weight int      `json:"w"` // аҳамият барои тартиб (0..100)

	keys []string // номҳои муқаррарикардашуда (Normalize)
}

// Result — ҷой бо масофа (агар координата дода шуда бошад).
type Result struct {
	Place      *Place
	DistanceKm float64 // -1 — номаълум
	score      float64
}

var (
	all   []*Place
	byID  = map[string]*Place{}
	exact = map[string][]*Place{} // калиди пурра → ҷойҳо
)

func init() {
	var data struct {
		Places []*Place `json:"places"`
	}
	if err := json.Unmarshal(raw, &data); err != nil {
		panic("places.json: " + err.Error())
	}
	load(data.Places)
}

func load(list []*Place) {
	all = list
	byID = map[string]*Place{}
	exact = map[string][]*Place{}
	for _, p := range all {
		byID[p.ID] = p
		seen := map[string]bool{}
		for _, n := range p.names() {
			k := Normalize(n)
			if k == "" || seen[k] {
				continue
			}
			seen[k] = true
			p.keys = append(p.keys, k)
			exact[k] = append(exact[k], p)
		}
	}
}

func (p *Place) names() []string {
	out := []string{p.TJ, p.RU, p.EN}
	return append(out, p.Alt...)
}

// All — ҳамаи ҷойҳо (танҳо барои хондан).
func All() []*Place { return all }

// Get — ҷой аз рӯи id (nil агар нест).
func Get(id string) *Place {
	if id == "" {
		return nil
	}
	return byID[id]
}

// Name — номи ҷой бо забони lang (tj | ru | en).
func (p *Place) Name(lang string) string {
	switch lang {
	case "ru":
		return p.RU
	case "en":
		return p.EN
	}
	return p.TJ
}

// Region — «вилоят, кишвар»: то ду гузаштагон, мисли Instagram
// («Хуҷанд — Вилояти Суғд, Тоҷикистон»).
func (p *Place) Region(lang string) string {
	parts := []string{}
	cur := Get(p.Parent)
	for i := 0; cur != nil && i < 2; i++ {
		parts = append(parts, cur.Name(lang))
		cur = Get(cur.Parent)
	}
	return strings.Join(parts, ", ")
}

// TextVariants — шаклҳои матни кӯҳна (майдони озоди `location`), ки ба
// ин ҷой мувофиқанд. Номҳое, ки ба якчанд ҷой тааллуқ доранд
// («Москва» — ҳам пойтахт, ҳам деҳа дар Хатлон), истисно мешаванд.
func (p *Place) TextVariants() []string {
	seen := map[string]bool{}
	out := []string{}
	add := func(s string) {
		s = strings.TrimSpace(s)
		if s != "" && !seen[s] {
			seen[s] = true
			out = append(out, s)
		}
	}
	for _, n := range p.names() {
		if len(exact[Normalize(n)]) != 1 {
			continue
		}
		add(n)
		add(strings.ToLower(n))
		add(strings.ToUpper(n))
		r := []rune(strings.ToLower(n))
		if len(r) > 0 {
			r[0] = unicode.ToUpper(r[0])
			add(string(r))
		}
	}
	return out
}

// MatchExact — ҷое, ки номаш ба матн пурра мувофиқ аст, агар танҳо
// ЯК чунин ҷой бошад (nil — нест ё дуполаҳлу).
func MatchExact(text string) *Place {
	m := exact[Normalize(text)]
	if len(m) == 1 {
		return m[0]
	}
	return nil
}

// ── Муқаррарсозӣ ──────────────────────────────────────────────────
//
// Ҷустуҷӯ бояд «Хуҷанд», «Худжанд», «Khujand» ва «xujand»-ро як донад.
// Ҳама чиз ба лотинии соддакардашуда табдил дода мешавад, пас ҷуфтҳое,
// ки дар забонҳо гуногун навишта мешаванд, якхела карда мешаванд
// (kh/x → h, dzh/dj/zh → j, q → k, gh → g, y → i, ҳарфҳои дукарата → як).
//
// ⚠️ Ҳамин алгоритм дар lib/core/places/place_normalize.dart ҳаст —
// ҳар тағйир бояд дар ҳарду ҷо бошад (тестҳо ҳамон мисолҳоро месанҷанд).

var runeMap = map[rune]string{
	'а': "a", 'б': "b", 'в': "v", 'г': "g", 'ғ': "g", 'ґ': "g", 'д': "d",
	'е': "e", 'ё': "io", 'є': "e", 'ж': "j", 'з': "z", 'и': "i", 'ӣ': "i",
	'і': "i", 'ї': "i", 'й': "i", 'к': "k", 'қ': "k", 'л': "l", 'м': "m",
	'н': "n", 'ң': "n", 'о': "o", 'ө': "o", 'п': "p", 'р': "r", 'с': "s",
	'т': "t", 'у': "u", 'ӯ': "u", 'ў': "u", 'ү': "u", 'ф': "f", 'х': "h",
	'ҳ': "h", 'һ': "h", 'ц': "s", 'ч': "ch", 'ҷ': "j", 'ш': "sh", 'щ': "sh",
	'ъ': "", 'ы': "i", 'ь': "", 'э': "e", 'ә': "a", 'ю': "iu", 'я': "ia",
	'à': "a", 'á': "a", 'â': "a", 'ã': "a", 'ä': "a", 'å': "a", 'ā': "a",
	'ă': "a", 'ą': "a", 'æ': "ae", 'ç': "ch", 'č': "ch", 'ć': "ch", 'ď': "d",
	'đ': "d", 'è': "e", 'é': "e", 'ê': "e", 'ë': "e", 'ē': "e", 'ė': "e",
	'ę': "e", 'ě': "e", 'ğ': "g", 'ì': "i", 'í': "i", 'î': "i", 'ï': "i",
	'ī': "i", 'ı': "i", 'ł': "l", 'ñ': "n", 'ń': "n", 'ň': "n", 'ò': "o",
	'ó': "o", 'ô': "o", 'õ': "o", 'ö': "o", 'ō': "o", 'ő': "o", 'ø': "o",
	'ř': "r", 'ś': "s", 'š': "sh", 'ş': "sh", 'ș': "sh", 'ß': "ss", 'ť': "t",
	'ţ': "t", 'ț': "t", 'ù': "u", 'ú': "u", 'û': "u", 'ü': "u", 'ū': "u",
	'ŭ': "u", 'ű': "u", 'ů': "u", 'ý': "i", 'ÿ': "i", 'ž': "j", 'ź': "z",
	'ż': "z", '\u0307': "", // «İzmir»: нуқтаи иловагии ToLower
}

// Ҷуфтҳо бо ҳамин тартиб иваз мешаванд.
var pairRules = [][2]string{
	{"kh", "h"}, {"zh", "j"}, {"dj", "j"}, {"gh", "g"}, {"ph", "f"},
	{"ts", "s"}, {"x", "h"}, {"q", "k"}, {"w", "v"}, {"y", "i"},
}

// Normalize — калиди ҷустуҷӯ (ниг. боло).
func Normalize(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		if m, ok := runeMap[r]; ok {
			b.WriteString(m)
			continue
		}
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '\'' || r == '’' || r == '‘' || r == '`' || r == 'ʼ' || r == 'ʻ':
			// апостроф: «Mu'minobod» = «Мӯъминобод»
		default:
			b.WriteByte(' ')
		}
	}
	out := b.String()
	for _, p := range pairRules {
		out = strings.ReplaceAll(out, p[0], p[1])
	}
	// «c» бе «h» → «k» (Cancun = Канкун).
	cs := []byte(out)
	for i := range cs {
		if cs[i] == 'c' && (i+1 >= len(cs) || cs[i+1] != 'h') {
			cs[i] = 'k'
		}
	}
	words := strings.Fields(string(cs))
	for i, w := range words {
		// «Ёвон» (iovon) = «Yovon» (iovon→ovon) = «Evon»; «Ереван» = «Yerevan».
		if len(w) > 1 && w[0] == 'i' && strings.IndexByte("aeiou", w[1]) >= 0 {
			w = w[1:]
		}
		// Ҳарфҳои дукарата: «Таллинн» = «Таллин», «Гиссар» ≈ «Гисар».
		var c strings.Builder
		for j := 0; j < len(w); j++ {
			if j > 0 && w[j] == w[j-1] {
				continue
			}
			c.WriteByte(w[j])
		}
		words[i] = c.String()
	}
	return strings.Join(words, " ")
}

// ── Ҷустуҷӯ ───────────────────────────────────────────────────────

// Дараҷаҳои мувофиқат. Фосила (200) аз ҳадди аҳамият+наздикӣ (100+95)
// калонтар аст, бинобар ин дараҷа ҳамеша аввал меояд:
// пурра > аз сар > аз сари калима > дар мобайн.
const (
	tierExact    = 1000
	tierPrefix   = 800
	tierWord     = 600
	tierContains = 400
	nearbyMax    = 95.0 // ~0 баъд аз 150 км
)

func matchTier(keys []string, q string) int {
	best := 0
	for _, k := range keys {
		t := 0
		switch {
		case k == q:
			t = tierExact
		case strings.HasPrefix(k, q):
			t = tierPrefix
		case strings.Contains(k, " "+q):
			t = tierWord
		case len(q) >= 3 && strings.Contains(k, q):
			t = tierContains
		}
		if t > best {
			best = t
		}
	}
	return best
}

// Search — ҷустуҷӯи ҷойҳо. hasLoc — агар lat/lon дода шуда бошанд,
// ҷойҳои наздик боло мебароянд (дар ҳамон дараҷаи мувофиқат).
// Матни холӣ: бо координата — ҷойҳои наздик; бе он — шаҳрҳои калони
// Тоҷикистон.
func Search(q string, lat, lon float64, hasLoc bool, limit int) []Result {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	nq := Normalize(q)
	if nq == "" {
		if hasLoc {
			return Nearby(lat, lon, limit)
		}
		return popular(limit)
	}
	out := []Result{}
	for _, p := range all {
		t := matchTier(p.keys, nq)
		if t == 0 {
			continue
		}
		r := Result{Place: p, DistanceKm: -1, score: float64(t + p.Weight)}
		if hasLoc {
			d := DistanceKm(lat, lon, p.Lat, p.Lon)
			r.DistanceKm = d
			r.score += nearbyMax * math.Exp(-d/50)
		}
		out = append(out, r)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].score != out[j].score {
			return out[i].score > out[j].score
		}
		return out[i].Place.ID < out[j].Place.ID
	})
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

func popular(limit int) []Result {
	list := []*Place{}
	for _, p := range all {
		if p.CC == "TJ" && p.Kind == "city" {
			list = append(list, p)
		}
	}
	sort.SliceStable(list, func(i, j int) bool { return list[i].Weight > list[j].Weight })
	out := []Result{}
	for _, p := range list {
		if len(out) == limit {
			break
		}
		out = append(out, Result{Place: p, DistanceKm: -1})
	}
	return out
}

// settlement — ҷое, ки «ман ин ҷо ҳастам» буда метавонад.
func settlement(p *Place) bool {
	switch p.Kind {
	case "city", "district", "town", "poi":
		return true
	}
	return false
}

// radiusKm — тақрибан андозаи шаҳр: нуқта дар дохили ин доира ба худи
// шаҳр тааллуқ дорад, на ба ноҳияҳо ё деҳаҳои атроф.
func radiusKm(p *Place) float64 {
	if p.Kind != "city" {
		return 0
	}
	switch {
	case p.ID == "tj-dushanbe":
		return 12
	case p.CC == "TJ" && p.Weight >= 82:
		return 6
	case p.CC == "TJ":
		return 3
	case p.Weight >= 48:
		return 20
	default:
		return 8
	}
}

// MaxNearestKm — аз ин дуртар «ҷойи ҳозира» муайян карда намешавад.
const MaxNearestKm = 150.0

// Nearest — ҷойи ҳозира барои координатаҳо: шаҳре, ки нуқта дар дохилаш
// аст, вагарна наздиктарин шаҳр/ноҳия/деҳа. nil — ҳеҷ чиз дар 150 км нест.
func Nearest(lat, lon float64) (*Place, float64) {
	var best *Place
	bestEff, bestD := math.MaxFloat64, 0.0
	for _, p := range all {
		if !settlement(p) || p.Kind == "poi" {
			continue
		}
		d := DistanceKm(lat, lon, p.Lat, p.Lon)
		eff := d - radiusKm(p)
		if eff < bestEff || (eff == bestEff && best != nil && p.Weight > best.Weight) {
			best, bestEff, bestD = p, eff, d
		}
	}
	if best == nil || bestD > MaxNearestKm+radiusKm(best) {
		return nil, 0
	}
	return best, bestD
}

// Nearby — ҷойҳои наздик аз рӯи масофа (бо ҷойҳои машҳур).
func Nearby(lat, lon float64, limit int) []Result {
	out := []Result{}
	for _, p := range all {
		if !settlement(p) {
			continue
		}
		d := DistanceKm(lat, lon, p.Lat, p.Lon)
		if d > MaxNearestKm*2 {
			continue
		}
		out = append(out, Result{Place: p, DistanceKm: d, score: -(d - radiusKm(p))})
	}
	sort.SliceStable(out, func(i, j int) bool { return out[i].score > out[j].score })
	if len(out) > limit {
		out = out[:limit]
	}
	return out
}

// DistanceKm — масофа дар рӯи Замин (haversine).
func DistanceKm(lat1, lon1, lat2, lon2 float64) float64 {
	const R = 6371.0
	rad := math.Pi / 180
	dLat := (lat2 - lat1) * rad
	dLon := (lon2 - lon1) * rad
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(lat1*rad)*math.Cos(lat2*rad)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 2 * R * math.Asin(math.Min(1, math.Sqrt(a)))
}

// ValidCoords — оё lat/lon дурустанд.
func ValidCoords(lat, lon float64) bool {
	return !math.IsNaN(lat) && !math.IsNaN(lon) &&
		lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
}
