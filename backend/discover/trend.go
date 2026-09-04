// Package discover тренд ва кашфиёти Raonson-ро ҳисоб мекунад.
//
// Ин пакет лентаро ИВАЗ НАМЕКУНАД. Он рейтинги мавҷударо истифода
// мебарад ва танҳо саволи дигар медиҳад: «дар платформа чӣ мешавад?»
package discover

import "math"

// Қоидаҳои маънодории тренд.
//
// Бе инҳо як пост дар як мавзӯъ «+100%» медод ва рӯйхати тренд
// шӯхӣ мешуд. Ин ҳудудҳо ошкоро эълон мешаванд, то маълум бошад,
// ки чаро мавзӯъ дар рӯйхат нест.
const (
	// MinCurrentSample — дар давраи ҷорӣ ҳадди ақал чанд мӯҳтаво.
	MinCurrentSample = 5
	// MinPreviousSample — барои ҲИСОБИ ФОИЗ давраи қаблӣ низ бояд
	// намунаи кофӣ дошта бошад: аз 1 ба 2 «+100%» нест, шавқ нест.
	MinPreviousSample = 3
	// MaxReportedGrowth — фоизи нишондодашуда маҳдуд аст. «+4000%»
	// техникӣ дуруст, вале барои корбар бемаъно аст.
	MaxReportedGrowth = 500
)

// Trend — як мавзӯъ ё хэштег дар тренд.
type Trend struct {
	Slug     string `json:"slug"`
	Kind     string `json:"kind"`
	Current  int    `json:"current"`
	Previous int    `json:"previous"`
	// ChangePct — nil вақте маънодор нест. Client дар ин ҳолат
	// танҳо номро нишон медиҳад, бе фоиз.
	ChangePct   *float64 `json:"changePct"`
	Significant bool     `json:"significant"`
}

// ComputeTrend фоизи тағйирро бо қоидаҳои маънодорӣ ҳисоб мекунад.
//
// Натиҷа se ҳолат дорад:
//   - намунаи ҷорӣ кам        → тамоман нишон дода намешавад
//   - намунаи қаблӣ кам       → мавзӯъ нишон дода мешавад, вале БЕ фоиз
//   - ҳарду кофӣ              → фоиз ҳисоб ва маҳдуд карда мешавад
func ComputeTrend(kind, slug string, current, previous int) Trend {
	t := Trend{Slug: slug, Kind: kind, Current: current, Previous: previous}

	if current < MinCurrentSample {
		// Маънодор нест — ҳатто ном нишон дода намешавад.
		return t
	}
	t.Significant = true

	if previous < MinPreviousSample {
		// Мавзӯи нав: воқеан афзоиш дорад, вале фоиз бемаъно мешавад.
		return t
	}
	pct := (float64(current) - float64(previous)) / float64(previous) * 100
	if pct > MaxReportedGrowth {
		pct = MaxReportedGrowth
	}
	rounded := math.Round(pct)
	t.ChangePct = &rounded
	return t
}

// ── Холи «боло рафтани» эҷодкор ──────────────────────────────────

// RisingSignals — сигналҳои хоми як эҷодкор дар давра.
type RisingSignals struct {
	FollowersGained int
	Impressions     int
	Completions     int
	Saves           int
	Shares          int
	ContentCount    int
}

// Вазни сигналҳо.
//
// Обуна аз ҳама муҳимтар аст: он маънои «мехоҳам боз бинам»-ро дорад.
// Намоиш қариб чизе намегӯяд — он натиҷаи алгоритм аст, на сазовории
// эҷодкор, бинобар ин вазни хеле кам дорад.
const (
	wFollow     = 10.0
	wSave       = 4.0
	wShare      = 5.0
	wCompletion = 1.0
	wImpression = 0.02
)

// MinContentForRising — эҷодкор бо ЯК пост дар рӯйхат намеояд.
//
// Бе ин, як пости тасодуфан вирусӣ эҷодкорро то абад дар боло нигоҳ
// медошт ва «боло рафта» маънои худро гум мекард.
const MinContentForRising = 2

// ComputeRisingScore холи эҷодкорро ҳисоб мекунад.
//
// Хол ба МӮҲТАВО тақсим мешавад: касе ки бо ду пост натиҷаи хуб дорад,
// аз касе ки бо панҷоҳ пост ҳамон натиҷа дорад, зудтар боло меравад.
// Ин ҳамчунин спамро бефоида мекунад.
func ComputeRisingScore(s RisingSignals) float64 {
	if s.ContentCount < MinContentForRising {
		return 0
	}
	raw := float64(s.FollowersGained)*wFollow +
		float64(s.Saves)*wSave +
		float64(s.Shares)*wShare +
		float64(s.Completions)*wCompletion +
		float64(s.Impressions)*wImpression

	if raw <= 0 {
		return 0
	}
	// Логарифм: 100 обуна набояд 100 маротиба аз 1 обуна беҳтар
	// ҳисоб шавад — фарқи воқеӣ хеле камтар аст.
	perContent := raw / float64(s.ContentCount)
	return math.Round(math.Log1p(perContent)*100) / 100
}

// DecayScore холро бо гузашти вақт суст мекунад.
//
// Бе ин, як ҳафтаи хуб эҷодкорро моҳҳо дар боло нигоҳ медошт ва
// рӯйхати «боло раванда» ях мекард.
func DecayScore(score float64, daysOld, halfLifeDays float64) float64 {
	if daysOld <= 0 || halfLifeDays <= 0 {
		return score
	}
	return score * math.Pow(0.5, daysOld/halfLifeDays)
}
