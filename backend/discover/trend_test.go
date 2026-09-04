package discover

import (
	"math"
	"testing"
)

// ── Тренд ────────────────────────────────────────────────────────

func TestTinySampleIsNotATrend(t *testing.T) {
	// Як пост набояд «тренд» шавад.
	for _, cur := range []int{0, 1, 2, 4} {
		got := ComputeTrend("topic", "gaming", cur, 0)
		if got.Significant {
			t.Errorf("%d мӯҳтаво набояд тренд бошад", cur)
		}
		if got.ChangePct != nil {
			t.Errorf("%d мӯҳтаво набояд фоиз диҳад", cur)
		}
	}
}

func TestNewTopicShowsWithoutPercentage(t *testing.T) {
	// Аз 1 ба 8: воқеан афзоиш, вале «+700%» бемаъно аст.
	got := ComputeTrend("topic", "gaming", 8, 1)
	if !got.Significant {
		t.Fatal("8 мӯҳтаво бояд маънодор бошад")
	}
	if got.ChangePct != nil {
		t.Fatalf("бо намунаи қаблии кам фоиз набояд бошад: %v", *got.ChangePct)
	}
}

func TestRealGrowthIsReported(t *testing.T) {
	got := ComputeTrend("topic", "gaming", 20, 10)
	if got.ChangePct == nil {
		t.Fatal("фоиз бояд ҳисоб шавад")
	}
	if *got.ChangePct != 100 {
		t.Fatalf("аз 10 ба 20 = +100%%, гирифтем %v", *got.ChangePct)
	}
}

func TestDeclineIsReportedToo(t *testing.T) {
	got := ComputeTrend("topic", "news", 10, 20)
	if got.ChangePct == nil || *got.ChangePct != -50 {
		t.Fatalf("паст рафтан бояд нишон дода шавад: %+v", got.ChangePct)
	}
}

func TestExtremeGrowthIsCapped(t *testing.T) {
	got := ComputeTrend("topic", "x", 10000, 3)
	if got.ChangePct == nil {
		t.Fatal("фоиз бояд бошад")
	}
	if *got.ChangePct > MaxReportedGrowth {
		t.Fatalf("фоиз маҳдуд нашуд: %v", *got.ChangePct)
	}
}

// ── Эҷодкорони боло раванда ──────────────────────────────────────

func TestSingleContentCreatorIsNotRising(t *testing.T) {
	// Як пости вирусӣ набояд эҷодкорро «боло раванда» кунад.
	s := RisingSignals{
		FollowersGained: 500, Impressions: 100000,
		Completions: 5000, Saves: 400, Shares: 300, ContentCount: 1,
	}
	if got := ComputeRisingScore(s); got != 0 {
		t.Fatalf("бо як мӯҳтаво хол бояд 0 бошад, гирифтем %v", got)
	}
}

func TestFollowsOutweighImpressions(t *testing.T) {
	// Намоиш натиҷаи алгоритм аст, на сазовории эҷодкор.
	manyImpressions := ComputeRisingScore(RisingSignals{
		Impressions: 10000, ContentCount: 5})
	fewFollows := ComputeRisingScore(RisingSignals{
		FollowersGained: 40, Impressions: 100, ContentCount: 5})
	if fewFollows <= manyImpressions {
		t.Errorf("обуна бояд аз намоиш вазнинтар бошад: %v ва %v",
			fewFollows, manyImpressions)
	}
}

func TestScoreIsPerContentNotTotal(t *testing.T) {
	// Ҳамон натиҷа бо мӯҳтавои камтар = холи баландтар.
	efficient := ComputeRisingScore(RisingSignals{
		FollowersGained: 20, Saves: 20, ContentCount: 2})
	spammy := ComputeRisingScore(RisingSignals{
		FollowersGained: 20, Saves: 20, ContentCount: 50})
	if efficient <= spammy {
		t.Errorf("сифат бояд аз шумора боло бошад: %v ва %v", efficient, spammy)
	}
}

func TestNoSignalsMeansNoScore(t *testing.T) {
	if got := ComputeRisingScore(RisingSignals{ContentCount: 10}); got != 0 {
		t.Fatalf("бе сигнал хол бояд 0 бошад: %v", got)
	}
}

func TestScoreGrowsSublinearly(t *testing.T) {
	// 100 обуна набояд 100 маротиба аз 1 обуна беҳтар бошад.
	one := ComputeRisingScore(RisingSignals{FollowersGained: 1, ContentCount: 2})
	hundred := ComputeRisingScore(RisingSignals{FollowersGained: 100, ContentCount: 2})
	if hundred <= one {
		t.Fatal("бештар обуна бояд холи баландтар диҳад")
	}
	if hundred > one*100 {
		t.Fatalf("афзоиш бояд зерхаттӣ бошад: %v ва %v", one, hundred)
	}
}

func TestDecayReducesOldScores(t *testing.T) {
	if got := DecayScore(100, 7, 7); math.Abs(got-50) > 0.001 {
		t.Fatalf("баъди як нимумр бояд нисф шавад: %v", got)
	}
	if got := DecayScore(100, 0, 7); got != 100 {
		t.Fatalf("бе гузашти вақт тағйир набояд бошад: %v", got)
	}
	// Муҳофизат аз тақсим ба сифр.
	if got := DecayScore(100, 5, 0); got != 100 {
		t.Fatalf("halfLife=0 бояд бетаъсир бошад: %v", got)
	}
}

func TestDecayPreventsPermanentDomination(t *testing.T) {
	// Эҷодкори як ҳафта пеш вирусӣ бар зидди эҷодкори имрӯзаи ором.
	oldViral := DecayScore(100, 21, 7) // се нимумр → ~12.5
	steadyNew := DecayScore(20, 0, 7)
	if oldViral >= steadyNew {
		t.Fatalf("холи кӯҳна бояд ҷои худро диҳад: кӯҳна %v, нав %v",
			oldViral, steadyNew)
	}
}
