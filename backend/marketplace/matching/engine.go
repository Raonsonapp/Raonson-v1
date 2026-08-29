// Package matching эҷодкорони мувофиқро барои кампания меёбад.
//
// Ду хосияти муҳим:
//   - ДЕТЕРМИНИСТӢ: ҳамон вуруд ҳамеша ҳамон натиҷа медиҳад. Ҳеҷ
//     rand, ҳеҷ вобастагӣ ба вақт. Ин онро санҷиданашаванда мекард.
//   - ШАРҲДИҲАНДА: ҳар мувофиқат сабабҳои худро бо худ мебарад, то
//     рекламадиҳанда бифаҳмад, чаро ин эҷодкор пешниҳод шудааст.
//
// Вазнҳо дар Weights ҷамъоварӣ шудаанд — алгоритмро бе тағйири
// мантиқи ҳисоб иваз кардан мумкин аст.
package matching

import (
	"sort"
	"strings"

	"raonson/marketplace/money"
)

// Candidate — эҷодкор ҳамчун номзад.
type Candidate struct {
	CreatorID             string
	Categories            []string
	AudienceCountry       string
	AudienceLanguage      string
	AverageViews          int64
	EngagementRate        float64 // 0..1
	CreatorScore          float64 // 0..100
	ScoreConfidence       float64 // 0..1
	CampaignCount         int64
	SuccessfulCampaigns   int64
	AverageCampaignResult float64 // 0..1
	Price                 money.Amount
	Available             bool
	// FraudScore 0..1 — аз аломатҳои воқеӣ. Баланд = шубҳанок.
	FraudScore float64
}

// Criteria — талаботи кампания.
type Criteria struct {
	Category        string
	TargetCountry   string
	TargetLanguage  string
	TargetInterests []string
	// PerCreatorBudget — маблағе, ки барои як эҷодкор ҷудо шудааст.
	PerCreatorBudget money.Amount
	MinCreatorScore  float64
}

// Weights — вазни ҳар омил. Ҷамъашон 1.0 набояд бошад; хол ба
// фоиз нормализа мешавад.
type Weights struct {
	Category    float64
	Country     float64
	Language    float64
	Interests   float64
	Engagement  float64
	Reach       float64
	Score       float64
	TrackRecord float64
}

// DefaultWeights — вазнҳои пешфарз. Мувофиқати аудитория аз ҳама
// муҳимтар аст: реклама ба одамони нодуруст бефоида аст.
func DefaultWeights() Weights {
	return Weights{
		Category:    0.20,
		Country:     0.18,
		Language:    0.10,
		Interests:   0.07,
		Engagement:  0.15,
		Reach:       0.10,
		Score:       0.12,
		TrackRecord: 0.08,
	}
}

// Match — натиҷаи як эҷодкор.
type Match struct {
	CreatorID  string   `json:"creatorId"`
	MatchScore float64  `json:"matchScore"` // 0..100
	Reasons    []string `json:"reasons"`
	// Confidence аз эҷодкор мегирад — маълумоти кам = боварии кам.
	Confidence float64 `json:"confidence"`
}

// Engine мувофиқатро ҳисоб мекунад.
type Engine struct {
	W Weights
	// MaxFraudScore — аз ин боло эҷодкор тамоман пешниҳод намешавад.
	MaxFraudScore float64
}

func NewEngine() *Engine {
	return &Engine{W: DefaultWeights(), MaxFraudScore: 0.7}
}

// Rank номзадҳоро баҳо медиҳад ва мураттаб бармегардонад.
//
// Тартиб: хол камшаванда, баъд аз рӯи CreatorID — то натиҷа ҳангоми
// холҳои баробар ҳам устувор бошад (детерминизм).
func (e *Engine) Rank(cands []Candidate, c Criteria) []Match {
	out := make([]Match, 0, len(cands))
	for _, cand := range cands {
		if !cand.Available {
			continue
		}
		if cand.FraudScore >= e.MaxFraudScore {
			continue
		}
		if c.MinCreatorScore > 0 && cand.CreatorScore < c.MinCreatorScore {
			continue
		}
		// Буҷет: агар нархи эҷодкор аз буҷети як эҷодкор зиёд бошад.
		if c.PerCreatorBudget.Minor > 0 && cand.Price.Minor > 0 {
			if cand.Price.Currency == c.PerCreatorBudget.Currency &&
				cand.Price.Minor > c.PerCreatorBudget.Minor {
				continue
			}
		}
		m := e.scoreOne(cand, c)
		out = append(out, m)
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].MatchScore != out[j].MatchScore {
			return out[i].MatchScore > out[j].MatchScore
		}
		return out[i].CreatorID < out[j].CreatorID
	})
	return out
}

func (e *Engine) scoreOne(cand Candidate, c Criteria) Match {
	var total, maxTotal float64
	reasons := make([]string, 0, 6)

	add := func(w, got float64, reason string) {
		total += w * got
		maxTotal += w
		if got >= 0.999 && reason != "" {
			reasons = append(reasons, reason)
		}
	}

	// Категория
	catHit := 0.0
	if c.Category != "" {
		if containsFold(cand.Categories, c.Category) {
			catHit = 1
		}
	} else {
		catHit = 1 // талабот нест — ҷарима нест
	}
	add(e.W.Category, catHit, "Категория мувофиқ: "+c.Category)

	// Кишвари аудитория
	countryHit := 0.0
	if c.TargetCountry != "" {
		if strings.EqualFold(cand.AudienceCountry, c.TargetCountry) {
			countryHit = 1
		}
	} else {
		countryHit = 1
	}
	add(e.W.Country, countryHit, "Аудитория аз "+c.TargetCountry)

	// Забон
	langHit := 0.0
	if c.TargetLanguage != "" {
		if strings.EqualFold(cand.AudienceLanguage, c.TargetLanguage) {
			langHit = 1
		}
	} else {
		langHit = 1
	}
	add(e.W.Language, langHit, "Забони аудитория мувофиқ")

	// Шавқҳо — ҳиссаи мувофиқат
	interestHit := 1.0
	if len(c.TargetInterests) > 0 {
		hits := 0
		for _, want := range c.TargetInterests {
			if containsFold(cand.Categories, want) {
				hits++
			}
		}
		interestHit = float64(hits) / float64(len(c.TargetInterests))
	}
	add(e.W.Interests, interestHit, "Шавқҳо мувофиқанд")

	// Engagement: 8% = ҳадди боло
	eng := clamp(cand.EngagementRate/0.08, 0, 1)
	add(e.W.Engagement, eng, "")
	if cand.EngagementRate >= 0.05 {
		reasons = append(reasons, "Engagement-и қавӣ")
	}

	// Reach: 100k бинандаи миёна = ҳадди боло
	reach := clamp(float64(cand.AverageViews)/100_000, 0, 1)
	add(e.W.Reach, reach, "")

	// Creator score
	add(e.W.Score, clamp(cand.CreatorScore/100, 0, 1), "")

	// Таърихи кампания
	track := 0.0
	if cand.CampaignCount > 0 {
		sr := float64(cand.SuccessfulCampaigns) / float64(cand.CampaignCount)
		track = clamp(sr*0.5+clamp(cand.AverageCampaignResult, 0, 1)*0.5, 0, 1)
		if track >= 0.8 {
			reasons = append(reasons, "Натиҷаи хуби кампанияҳои гузашта")
		}
	}
	add(e.W.TrackRecord, track, "")

	pct := 0.0
	if maxTotal > 0 {
		pct = total / maxTotal * 100
	}
	// Ҷаримаи фиреб — то тамоман хориҷ нашуда бошад, вале холро паст мекунад.
	pct *= (1 - clamp(cand.FraudScore, 0, 1))

	return Match{
		CreatorID:  cand.CreatorID,
		MatchScore: round2(clamp(pct, 0, 100)),
		Reasons:    reasons,
		Confidence: clamp(cand.ScoreConfidence, 0, 1),
	}
}

func containsFold(list []string, want string) bool {
	for _, v := range list {
		if strings.EqualFold(strings.TrimSpace(v), strings.TrimSpace(want)) {
			return true
		}
	}
	return false
}

func clamp(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func round2(v float64) float64 {
	return float64(int64(v*100+0.5)) / 100
}
