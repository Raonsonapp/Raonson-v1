package places

import (
	"strings"
	"testing"
)

// Ҳамин мисолҳо дар test/places_test.dart низ ҳастанд — ду
// муқаррарсозӣ (Go ва Dart) бояд якхела бошанд.
func TestNormalizeVariantsAgree(t *testing.T) {
	groups := [][]string{
		{"Хуҷанд", "Худжанд", "Khujand", "XUJAND", "khudzhand"},
		{"Душанбе", "dushanbe", "DUSHANBE"},
		{"Варзоб", "Varzob", "варзоб"},
		{"Кӯлоб", "Kulob", "Kŭlob"},
		{"Ғафуров", "Гафуров", "Ghafurov", "Gafurov"},
		{"Қубодиён", "Qubodiyon", "Кубодиён"},
		{"Ёвон", "Yovon"},
		{"Мӯъминобод", "Mu'minobod", "Mu’minobod"},
		{"Ереван", "Yerevan"},
		{"Таллинн", "Таллин", "Tallinn"},
		{"Eskişehir", "Эскишехир"},
		{"Ҳисор", "Hisor", "hisor"},
		{"İzmir", "Izmir", "Измир"},
	}
	for _, g := range groups {
		want := Normalize(g[0])
		if want == "" {
			t.Fatalf("empty key for %q", g[0])
		}
		for _, s := range g[1:] {
			if got := Normalize(s); got != want {
				t.Errorf("Normalize(%q)=%q, want %q (as %q)", s, got, want, g[0])
			}
		}
	}
}

func TestNormalizeExact(t *testing.T) {
	cases := map[string]string{
		"Хуҷанд":            "hujand",
		"Khujand":           "hujand",
		"  Бохтар  ":        "bohtar",
		"Ҷалолиддини Балхӣ": "jalolidini balhi",
		"Rostov-on-Don":     "rostov on don",
		"Ёвон":              "ovon",
		"":                  "",
	}
	for in, want := range cases {
		if got := Normalize(in); got != want {
			t.Errorf("Normalize(%q)=%q, want %q", in, got, want)
		}
	}
}

func firstID(r []Result) string {
	if len(r) == 0 {
		return ""
	}
	return r[0].Place.ID
}

func TestSearchScriptsAndLanguages(t *testing.T) {
	for _, q := range []string{"Хуҷанд", "Khujand", "Худжанд", "хуҷ", "khu", "Ходжент"} {
		if got := firstID(Search(q, 0, 0, false, 10)); got != "tj-khujand" {
			t.Errorf("Search(%q) first=%q, want tj-khujand", q, got)
		}
	}
	for _, q := range []string{"Варзоб", "varzob", "Варзобский"} {
		if got := firstID(Search(q, 0, 0, false, 10)); got != "tj-varzob" {
			t.Errorf("Search(%q) first=%q, want tj-varzob", q, got)
		}
	}
	for _, q := range []string{"Душанбе", "dushanbe", "Душ"} {
		if got := firstID(Search(q, 0, 0, false, 10)); got != "tj-dushanbe" {
			t.Errorf("Search(%q) first=%q, want tj-dushanbe", q, got)
		}
	}
	// Номҳои кӯҳна/русӣ.
	cases := map[string]string{
		"Курган-Тюбе": "tj-bokhtar", "Ленинабад": "tj-khujand",
		"Куляб": "tj-kulob", "Гиссар": "tj-hisor", "Чкаловск": "tj-buston",
		"Маскав": "w-ru-moscow", "Moscow": "w-ru-moscow", "Тошканд": "w-uz-tashkent",
		"Олмон": "c-de", "Germany": "c-de", "Русия": "c-ru",
	}
	for q, want := range cases {
		if got := firstID(Search(q, 0, 0, false, 10)); got != want {
			t.Errorf("Search(%q) first=%q, want %q", q, got, want)
		}
	}
}

func TestSearchRankingPrefixBeforeContains(t *testing.T) {
	// «обод» дар мобайни бисёр номҳо ҳаст; номе, ки бо «обод» сар
	// мешавад, нест — пас ҳама «contains» мебошанд. «Зафар» — аз сар.
	res := Search("зафар", 0, 0, false, 20)
	if firstID(res) != "tj-zafarobod" {
		t.Fatalf("first=%q", firstID(res))
	}
	// Тартиб: дараҷаи мувофиқат ҳеҷ гоҳ паст намешавад.
	res = Search("бод", 0, 0, false, 50)
	prev := tierExact + 1000
	for _, r := range res {
		tier := matchTier(r.Place.keys, Normalize("бод"))
		if tier > prev {
			t.Fatalf("%s (tier %d) after a lower tier %d", r.Place.ID, tier, prev)
		}
		prev = tier
	}
	// Пурра пеш аз аз-сар: «Нов» (деҳа) пеш аз «Новосибирск».
	res = Search("Нов", 0, 0, false, 10)
	if firstID(res) != "tj-nov" {
		t.Fatalf("Нов first=%q", firstID(res))
	}
}

func TestSearchNearbyBoost(t *testing.T) {
	// «Бӯстон» — ду ҷой (шаҳр дар назди Хуҷанд ва деҳа дар Мастчоҳ).
	// Дар назди Мастчоҳ деҳа бояд пеш бошад.
	res := Search("Бӯстон", 40.52, 69.33, true, 5)
	if len(res) < 2 {
		t.Fatalf("want both Bustons, got %d", len(res))
	}
	if res[0].Place.ID != "tj-mastchoh-buston" {
		t.Fatalf("first=%q", res[0].Place.ID)
	}
	far := Search("Бӯстон", 37.9, 69.8, true, 5)
	if far[0].Place.ID != "tj-buston" {
		t.Fatalf("far first=%q", far[0].Place.ID)
	}
	if res[0].DistanceKm < 0 {
		t.Fatal("distance missing")
	}
}

func TestSearchEmptyQuery(t *testing.T) {
	if firstID(Search("", 0, 0, false, 5)) != "tj-dushanbe" {
		t.Fatal("popular list should start with Dushanbe")
	}
	near := Search("  ", 40.28, 69.62, true, 5)
	if firstID(near) != "tj-khujand" {
		t.Fatalf("nearby first=%q", firstID(near))
	}
}

func TestNearest(t *testing.T) {
	cases := []struct {
		lat, lon float64
		want     string
	}{
		{38.5598, 68.7870, "tj-dushanbe"}, // маркази Душанбе
		{38.5800, 68.7300, "tj-dushanbe"}, // ноҳияи Сино — ҳамоно Душанбе
		{40.2826, 69.6222, "tj-khujand"},
		{38.7737, 68.8178, "tj-varzob"},
		{37.4904, 71.5534, "tj-khorugh"},
		{55.7558, 37.6173, "w-ru-moscow"},
	}
	for _, c := range cases {
		p, _ := Nearest(c.lat, c.lon)
		if p == nil || p.ID != c.want {
			got := "<nil>"
			if p != nil {
				got = p.ID
			}
			t.Errorf("Nearest(%v,%v)=%s, want %s", c.lat, c.lon, got, c.want)
		}
	}
	// Мобайни уқёнус — ҳеҷ чиз.
	if p, _ := Nearest(-40, -140); p != nil {
		t.Errorf("ocean: got %s", p.ID)
	}
}

func TestDatasetIntegrity(t *testing.T) {
	if len(All()) < 600 {
		t.Fatalf("only %d places", len(All()))
	}
	kinds := map[string]int{}
	for _, p := range All() {
		if p.TJ == "" || p.RU == "" || p.EN == "" {
			t.Errorf("%s: missing name", p.ID)
		}
		if p.Parent != "" && Get(p.Parent) == nil {
			t.Errorf("%s: unknown parent %s", p.ID, p.Parent)
		}
		if !ValidCoords(p.Lat, p.Lon) {
			t.Errorf("%s: bad coords", p.ID)
		}
		if p.CC == "TJ" {
			kinds[p.Kind]++
		}
	}
	// Суғд, Хатлон, ВМКБ, НТҶ (+ Душанбе ҳамчун шаҳр); 4 ноҳияи
	// Душанбе + 10 + 21 + 7 + 9 ноҳияи вилоятҳо.
	if kinds["region"] != 4 || kinds["district"] < 51 || kinds["city"] < 18 {
		t.Errorf("Tajikistan coverage: %v", kinds)
	}
	for _, id := range []string{"tj-sughd", "tj-khatlon", "tj-gbao", "tj-rrp", "tj-dushanbe"} {
		if Get(id) == nil {
			t.Errorf("missing %s", id)
		}
	}
}

func TestRegionAndVariants(t *testing.T) {
	p := Get("tj-khujand")
	if got := p.Region("tj"); got != "Вилояти Суғд, Тоҷикистон" {
		t.Errorf("Region=%q", got)
	}
	if got := Get("w-ru-moscow").Region("ru"); got != "Россия" {
		t.Errorf("Moscow region=%q", got)
	}
	v := strings.Join(p.TextVariants(), "|")
	for _, want := range []string{"Хуҷанд", "Khujand", "Худжанд", "хуҷанд"} {
		if !strings.Contains(v, want) {
			t.Errorf("variants %q missing %q", v, want)
		}
	}
	// «Бӯстон» дуполаҳлу аст (шаҳр ва деҳа дар Мастчоҳ) — на дар вариантҳо.
	for _, s := range Get("tj-buston").TextVariants() {
		if s == "Бӯстон" {
			t.Errorf("ambiguous name kept: %s", s)
		}
	}
	if MatchExact("худжанд") != p {
		t.Error("MatchExact Худжанд")
	}
	if MatchExact("Бӯстон") != nil {
		t.Error("MatchExact Бӯстон must be ambiguous")
	}
}
