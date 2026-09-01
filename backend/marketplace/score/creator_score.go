// Package score Creator Score-ро аз метрикаҳои ВОҚЕӢ ҳисоб мекунад.
//
// Ҳеҷ рақами тасодуфӣ ва ҳеҷ маълумоти сохта истифода намешавад.
// Вақте маълумот кам аст, хол ҳисоб мешавад, вале confidence паст
// нишон дода мешавад — то истифодабаранда бидонад, ки ба он чӣ қадар
// бовар кардан мумкин аст.
package score

import "math"

// Version — нусхаи алгоритми ҳисоб.
//
// Дар ҳар сатри creator_metrics нигоҳ дошта мешавад. Вақте вазнҳо ё
// формула тағйир меёбад, ин рақам боло меравад ва холи кӯҳна ҳамчун
// холи алгоритми кӯҳна боқӣ мемонад — вагарна 87-и имрӯза ва 87-и
// панҷ моҳ пеш як чиз ҳисоб мешаванд, ҳол он ки маънои гуногун доранд.
//
// Таърих:
//
//	1 — engagement 40 / reach 25 / audience 15 / track record 20
const Version = 1

// Параметрҳои танзим. Онҳо ошкоро эълон мешаванд, то ҳисоб
// шарҳдиҳанда бошад ва тағйирашон дар як ҷо дида шавад.
const (
	// excellentEngagement — 8% ҳамчун «хеле хуб» гирифта мешавад.
	excellentEngagement = 0.08
	// maxAverageViews — аз ин боло холи reach зиёд намешавад.
	maxAverageViews = 100_000
	// maxFollowers — аз ин боло холи audience зиёд намешавад.
	maxFollowers = 500_000

	weightEngagement  = 40.0
	weightReach       = 25.0
	weightAudience    = 15.0
	weightTrackRecord = 20.0
)

// Metrics — вуруди ҳисоб. Ҳама аз ҷадвалҳои воқеӣ меоянд.
type Metrics struct {
	Followers           int64
	TotalViews          int64
	AverageViews        int64
	Likes               int64
	Comments            int64
	Shares              int64
	Saves               int64
	ContentCount        int64 // чанд пост/рилс — асоси sample size
	CampaignCount       int64
	SuccessfulCampaigns int64
	// AverageCampaignResult — 0..1, ҳиссаи миёнаи иҷрои талаботи кампания.
	AverageCampaignResult float64
}

// Result — натиҷаи ҳисоб.
type Result struct {
	// Score 0..100.
	Score float64
	// Confidence 0..1 — чӣ қадар маълумот кофӣ буд.
	Confidence float64
	// SampleSize — шумораи мӯҳтаво, ки хол ба он такя мекунад.
	SampleSize int64
	// EngagementRate 0..1.
	EngagementRate float64
	// Breakdown — саҳми ҳар омил, барои шаффофият.
	Breakdown map[string]float64
	// Version — кадом нусхаи алгоритм ин холро сохт.
	Version int
	// Params — параметрҳои истифодашуда. Бо холи захирашуда нигоҳ
	// дошта мешаванд, то баъдтар маълум бошад, ки хол чӣ гуна ҳисоб шуд.
	Params map[string]float64
}

// minContentForFullConfidence — аз ин шумора боло маълумот кофӣ ҳисоб мешавад.
const minContentForFullConfidence = 10

// Compute Creator Score-ро ҳисоб мекунад.
//
// Хол аз чор омил иборат аст:
//   - engagement (0..40)  — сифати аудитория, муҳимтарин
//   - reach      (0..25)  — миёнаи бинандаҳо (логарифмӣ)
//   - audience   (0..15)  — андозаи аудитория (логарифмӣ)
//   - track record (0..20)— натиҷаи кампанияҳои гузашта
//
// Логарифм барои он аст, ки 1M пайрав набояд 100 маротиба беҳтар аз
// 10k ҳисоб шавад — фарқи воқеии арзиш хеле камтар аст.
func Compute(m Metrics) Result {
	er := EngagementRate(m)

	// 1) Engagement — сифати аудитория.
	engagement := clamp(er/excellentEngagement, 0, 1) * weightEngagement

	// 2) Reach — миёнаи бинандаҳо, логарифмӣ.
	reach := logScore(m.AverageViews, maxAverageViews) * weightReach

	// 3) Audience — андозаи аудитория, логарифмӣ.
	audience := logScore(m.Followers, maxFollowers) * weightAudience

	// 4) Track record: танҳо вақте кампания доштааст.
	var track float64
	if m.CampaignCount > 0 {
		successRate := float64(m.SuccessfulCampaigns) / float64(m.CampaignCount)
		// Натиҷаи миёна ва ҳиссаи муваффақият баробар вазн доранд.
		track = (successRate*0.5 + clamp(m.AverageCampaignResult, 0, 1)*0.5) * weightTrackRecord
	}

	total := engagement + reach + audience + track

	return Result{
		Score:          math.Round(clamp(total, 0, 100)*100) / 100,
		Confidence:     confidence(m),
		SampleSize:     m.ContentCount,
		EngagementRate: er,
		Breakdown: map[string]float64{
			"engagement":   math.Round(engagement*100) / 100,
			"reach":        math.Round(reach*100) / 100,
			"audience":     math.Round(audience*100) / 100,
			"track_record": math.Round(track*100) / 100,
		},
		Version: Version,
		Params: map[string]float64{
			"excellentEngagement": excellentEngagement,
			"maxAverageViews":     maxAverageViews,
			"maxFollowers":        maxFollowers,
			"weightEngagement":    weightEngagement,
			"weightReach":         weightReach,
			"weightAudience":      weightAudience,
			"weightTrackRecord":   weightTrackRecord,
		},
	}
}

// EngagementRate — (лайк+коммент+share+save) / бинандаҳо.
//
// Агар бинанда набошад, ба пайравон такя мекунем; агар он ҳам набошад,
// сифр — на рақами сохта.
func EngagementRate(m Metrics) float64 {
	interactions := float64(m.Likes + m.Comments + m.Shares + m.Saves)
	if interactions == 0 {
		return 0
	}
	base := float64(m.TotalViews)
	if base <= 0 {
		base = float64(m.Followers)
	}
	if base <= 0 {
		return 0
	}
	return clamp(interactions/base, 0, 1)
}

// confidence нишон медиҳад, ки хол ба чӣ қадар маълумот такя мекунад.
//
// Ду омил: шумораи мӯҳтаво ва мавҷудияти таърихи кампания. Эҷодкоре бо
// 2 пост метавонад холи баланд гирад, вале ба он бовар кардан мумкин нест.
func confidence(m Metrics) float64 {
	c := clamp(float64(m.ContentCount)/minContentForFullConfidence, 0, 1)
	// Бе ягон бинанда маълумот амалан нест.
	if m.TotalViews == 0 && m.Followers == 0 {
		return 0
	}
	// Таърихи кампания боварро тақвият медиҳад (то +0.2, вале на болои 1).
	if m.CampaignCount > 0 {
		c = clamp(c+0.2, 0, 1)
	}
	return math.Round(c*100) / 100
}

// logScore арзишро логарифмӣ ба 0..1 меорад.
func logScore(v int64, max float64) float64 {
	if v <= 0 {
		return 0
	}
	return clamp(math.Log10(float64(v)+1)/math.Log10(max+1), 0, 1)
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
