package score

import "testing"

func TestEmptyMetricsGiveZeroScoreAndZeroConfidence(t *testing.T) {
	// Эҷодкори бе ягон маълумот бояд 0 гирад — на рақами сохта.
	r := Compute(Metrics{})
	if r.Score != 0 {
		t.Errorf("холи эҷодкори холӣ: %v, бояд 0", r.Score)
	}
	if r.Confidence != 0 {
		t.Errorf("confidence: %v, бояд 0", r.Confidence)
	}
}

func TestScoreIsDeterministic(t *testing.T) {
	// Ҳамон вуруд → ҳамон натиҷа. Ҳеҷ тасодуф.
	m := Metrics{
		Followers: 12000, TotalViews: 300000, AverageViews: 8000,
		Likes: 21000, Comments: 1400, Shares: 700, Saves: 900,
		ContentCount: 40, CampaignCount: 5, SuccessfulCampaigns: 4,
		AverageCampaignResult: 0.9,
	}
	first := Compute(m)
	for i := 0; i < 50; i++ {
		if got := Compute(m); got.Score != first.Score || got.Confidence != first.Confidence {
			t.Fatalf("натиҷа тағйир ёфт: %v != %v", got, first)
		}
	}
}

func TestScoreInRange(t *testing.T) {
	cases := []Metrics{
		{},
		{Followers: 1},
		{Followers: 10_000_000, TotalViews: 900_000_000, AverageViews: 5_000_000,
			Likes: 800_000_000, Comments: 50_000_000, ContentCount: 5000,
			CampaignCount: 100, SuccessfulCampaigns: 100, AverageCampaignResult: 1},
		{Likes: 100, TotalViews: 10}, // engagement > 1 — бояд маҳдуд шавад
	}
	for i, m := range cases {
		r := Compute(m)
		if r.Score < 0 || r.Score > 100 {
			t.Errorf("ҳолати %d: хол %v аз 0..100 берун", i, r.Score)
		}
		if r.Confidence < 0 || r.Confidence > 1 {
			t.Errorf("ҳолати %d: confidence %v аз 0..1 берун", i, r.Confidence)
		}
		if r.EngagementRate < 0 || r.EngagementRate > 1 {
			t.Errorf("ҳолати %d: ER %v аз 0..1 берун", i, r.EngagementRate)
		}
	}
}

func TestLowDataGivesLowConfidence(t *testing.T) {
	// Ду пост — хол шояд баланд бошад, вале confidence бояд паст.
	few := Compute(Metrics{
		Followers: 5000, TotalViews: 20000, AverageViews: 10000,
		Likes: 3000, ContentCount: 2,
	})
	many := Compute(Metrics{
		Followers: 5000, TotalViews: 20000, AverageViews: 10000,
		Likes: 3000, ContentCount: 50,
	})
	if !(few.Confidence < many.Confidence) {
		t.Errorf("маълумоти кам бояд confidence-и пасттар диҳад: %v vs %v",
			few.Confidence, many.Confidence)
	}
	if few.Confidence > 0.5 {
		t.Errorf("бо 2 пост confidence %v — хеле баланд", few.Confidence)
	}
}

func TestEngagementDominatesOverRawFollowers(t *testing.T) {
	// Эҷодкори хурд бо engagement-и қавӣ бояд аз калони сусттар боло бошад.
	small := Compute(Metrics{
		Followers: 5000, TotalViews: 50000, AverageViews: 5000,
		Likes: 4000, Comments: 400, ContentCount: 30,
	})
	big := Compute(Metrics{
		Followers: 500000, TotalViews: 500000, AverageViews: 5000,
		Likes: 500, Comments: 10, ContentCount: 30,
	})
	if small.Score <= big.Score {
		t.Errorf("engagement бояд бартарӣ дошта бошад: хурд=%v калон=%v",
			small.Score, big.Score)
	}
}

func TestTrackRecordOnlyCountsWithCampaigns(t *testing.T) {
	base := Metrics{Followers: 10000, TotalViews: 100000, AverageViews: 5000,
		Likes: 5000, ContentCount: 20}
	without := Compute(base)
	with := base
	with.CampaignCount = 10
	with.SuccessfulCampaigns = 10
	with.AverageCampaignResult = 1
	got := Compute(with)
	if got.Score <= without.Score {
		t.Errorf("таърихи хуби кампания бояд холро боло барад: %v vs %v",
			got.Score, without.Score)
	}
	if without.Breakdown["track_record"] != 0 {
		t.Errorf("бе кампания track_record бояд 0 бошад, гирифтем %v",
			without.Breakdown["track_record"])
	}
}

func TestEngagementRateFallsBackToFollowers(t *testing.T) {
	// Бе бинанда — ба пайравон такя мекунад, на 0-и кӯр.
	er := EngagementRate(Metrics{Followers: 1000, Likes: 100})
	if er != 0.1 {
		t.Errorf("ER: гирифтем %v, интизор 0.1", er)
	}
}
