package handlers

import (
	"strings"
	"testing"
)

func TestResolvePostLocation(t *testing.T) {
	// id-и дуруст: ном аз матн, координатаҳо аз ҶОЙ.
	name, id, lat, lon := resolvePostLocation("Хуҷанд, назди дарё", "tj-khujand")
	if name != "Хуҷанд, назди дарё" || id != "tj-khujand" || lat == nil || lon == nil {
		t.Fatalf("got %q %q %v %v", name, id, lat, lon)
	}
	if *lat < 40 || *lat > 40.5 {
		t.Fatalf("lat %v", *lat)
	}
	// Матни холӣ + id → номи тоҷикии ҷой.
	if name, _, _, _ := resolvePostLocation("", "tj-varzob"); name != "Варзоб" {
		t.Fatalf("name %q", name)
	}
	// Барномаи кӯҳна: танҳо матн, ки айнан ба як ҷой мувофиқ аст.
	if _, id, _, _ := resolvePostLocation("Худжанд", ""); id != "tj-khujand" {
		t.Fatalf("legacy text id %q", id)
	}
	// Ҷойи дастӣ: id нест, координата нест.
	name, id, lat, _ = resolvePostLocation("  Чойхонаи Роҳат  ", "")
	if name != "Чойхонаи Роҳат" || id != "" || lat != nil {
		t.Fatalf("custom: %q %q %v", name, id, lat)
	}
	// id-и сохта қабул намешавад.
	if _, id, _, _ := resolvePostLocation("Ҷое", "evil'; DROP TABLE posts"); id != "" {
		t.Fatalf("bogus id kept: %q", id)
	}
	// Матни дароз бурида мешавад.
	if name, _, _, _ := resolvePostLocation(strings.Repeat("ҷ", 500), ""); len([]rune(name)) != 120 {
		t.Fatalf("len %d", len([]rune(name)))
	}
}
