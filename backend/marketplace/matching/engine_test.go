package matching

import (
	"testing"

	"raonson/marketplace/money"
)

func baseCand(id string) Candidate {
	return Candidate{
		CreatorID: id, Categories: []string{"gaming"},
		AudienceCountry: "TJ", AudienceLanguage: "tg",
		AverageViews: 20000, EngagementRate: 0.06,
		CreatorScore: 70, ScoreConfidence: 0.9,
		CampaignCount: 4, SuccessfulCampaigns: 4, AverageCampaignResult: 0.9,
		Price: money.MustNew(30000, money.TJS), Available: true,
	}
}

func baseCriteria() Criteria {
	return Criteria{
		Category: "gaming", TargetCountry: "TJ", TargetLanguage: "tg",
		PerCreatorBudget: money.MustNew(50000, money.TJS),
	}
}

func TestRankIsDeterministic(t *testing.T) {
	e := NewEngine()
	cands := []Candidate{baseCand("c1"), baseCand("c2"), baseCand("c3")}
	first := e.Rank(cands, baseCriteria())
	for i := 0; i < 50; i++ {
		got := e.Rank(cands, baseCriteria())
		if len(got) != len(first) {
			t.Fatalf("дарозии натиҷа тағйир ёфт")
		}
		for j := range got {
			if got[j].CreatorID != first[j].CreatorID || got[j].MatchScore != first[j].MatchScore {
				t.Fatalf("натиҷа тағйир ёфт дар такрори %d", i)
			}
		}
	}
}

func TestTiesBreakByIDForStableOrder(t *testing.T) {
	e := NewEngine()
	// Се номзади комилан якхела — тартиб бояд аз рӯи id бошад.
	got := e.Rank([]Candidate{baseCand("c3"), baseCand("c1"), baseCand("c2")}, baseCriteria())
	want := []string{"c1", "c2", "c3"}
	for i, w := range want {
		if got[i].CreatorID != w {
			t.Errorf("ҷои %d: гирифтем %s, интизор %s", i, got[i].CreatorID, w)
		}
	}
}

func TestUnavailableCreatorExcluded(t *testing.T) {
	e := NewEngine()
	c := baseCand("c1")
	c.Available = false
	if got := e.Rank([]Candidate{c}, baseCriteria()); len(got) != 0 {
		t.Errorf("эҷодкори дастнорас бояд хориҷ шавад, гирифтем %d", len(got))
	}
}

func TestOverBudgetCreatorExcluded(t *testing.T) {
	e := NewEngine()
	c := baseCand("c1")
	c.Price = money.MustNew(90000, money.TJS) // аз буҷет зиёд
	if got := e.Rank([]Candidate{c}, baseCriteria()); len(got) != 0 {
		t.Errorf("нархи аз буҷет зиёд бояд хориҷ шавад")
	}
}

func TestHighFraudExcluded(t *testing.T) {
	e := NewEngine()
	c := baseCand("c1")
	c.FraudScore = 0.9
	if got := e.Rank([]Candidate{c}, baseCriteria()); len(got) != 0 {
		t.Errorf("аломати баланди фиреб бояд хориҷ кунад")
	}
}

func TestFraudLowersScore(t *testing.T) {
	e := NewEngine()
	clean := e.Rank([]Candidate{baseCand("c1")}, baseCriteria())
	dirty := baseCand("c1")
	dirty.FraudScore = 0.4
	flagged := e.Rank([]Candidate{dirty}, baseCriteria())
	if !(flagged[0].MatchScore < clean[0].MatchScore) {
		t.Errorf("аломати фиреб бояд холро паст кунад: %v vs %v",
			flagged[0].MatchScore, clean[0].MatchScore)
	}
}

func TestCountryMismatchScoresLower(t *testing.T) {
	e := NewEngine()
	match := e.Rank([]Candidate{baseCand("c1")}, baseCriteria())
	off := baseCand("c1")
	off.AudienceCountry = "RU"
	mismatch := e.Rank([]Candidate{off}, baseCriteria())
	if !(mismatch[0].MatchScore < match[0].MatchScore) {
		t.Errorf("кишвари номувофиқ бояд холро паст кунад")
	}
}

func TestReasonsAreGiven(t *testing.T) {
	e := NewEngine()
	got := e.Rank([]Candidate{baseCand("c1")}, baseCriteria())
	if len(got[0].Reasons) == 0 {
		t.Fatal("мувофиқат бояд сабабҳо дошта бошад")
	}
	// Сабаб бояд шарҳдиҳанда бошад, на холӣ.
	for _, r := range got[0].Reasons {
		if r == "" {
			t.Error("сабаби холӣ")
		}
	}
}

func TestScoreInRange(t *testing.T) {
	e := NewEngine()
	extreme := Candidate{
		CreatorID: "x", Available: true,
		AverageViews: 1 << 40, EngagementRate: 5, CreatorScore: 500,
		CampaignCount: 1, SuccessfulCampaigns: 100, AverageCampaignResult: 9,
	}
	got := e.Rank([]Candidate{extreme}, Criteria{})
	if got[0].MatchScore < 0 || got[0].MatchScore > 100 {
		t.Errorf("хол аз 0..100 берун: %v", got[0].MatchScore)
	}
}

func TestMinScoreFilter(t *testing.T) {
	e := NewEngine()
	c := baseCand("c1")
	c.CreatorScore = 30
	crit := baseCriteria()
	crit.MinCreatorScore = 50
	if got := e.Rank([]Candidate{c}, crit); len(got) != 0 {
		t.Error("холи аз ҳадди ақал паст бояд хориҷ шавад")
	}
}

func TestWeightsAreSwappable(t *testing.T) {
	// Алгоритмро бе тағйири мантиқ иваз кардан мумкин бошад.
	e := NewEngine()
	e.W = Weights{Country: 1} // танҳо кишвар муҳим
	match := e.Rank([]Candidate{baseCand("c1")}, baseCriteria())
	off := baseCand("c2")
	off.AudienceCountry = "RU"
	off.EngagementRate = 0.99 // ин дигар аҳамият надорад
	mismatch := e.Rank([]Candidate{off}, baseCriteria())
	if !(mismatch[0].MatchScore < match[0].MatchScore) {
		t.Error("бо вазни танҳо-кишвар, кишвар бояд ҳал кунад")
	}
}
