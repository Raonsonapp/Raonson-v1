package feedai

import "math"

// Weights — вазни ҳар омили қабати идорашаванда.
//
// Онҳо ошкоро эълон мешаванд ва аз env танзим мешаванд, то мувозинати
// лента бе ҷойивазкунии код тағйир дода шавад.
//
// Миқёс дидаву дониста хурд аст. Формулаи мавҷуда то ~285 балл медиҳад
// (обуна 100, тозагӣ 50, лайк 50, коммент 30, шавқ 40, ҳамдилӣ 45 …).
// Қабати идорашаванда бояд тартибро ТАНЗИМ кунад, на онро аз нав
// нависад: агар афзалияти мавзӯъ 200 балл медод, корбар ба ҷои лента
// як мавзӯъро мегирифт ва обунаҳояшро гум мекард.
type Weights struct {
	Topic     float64 // афзалияти мавзӯъ (-1..1)
	Creator   float64 // афзалияти эҷодкор (-1..1)
	Language  float64 // мувофиқати забон (0/1)
	Local     float64 // эҷодкори маҳаллӣ
	Original  float64 // мӯҳтавои аслӣ
	Following float64 // иловагӣ, вақте корбар обунаҳоро афзал донист
	// FewerRecs — вақте корбар тавсияро кам кардан хост, мӯҳтавои
	// беруни обуна ҷарима мегирад.
	FewerRecs float64
}

// DefaultWeights — мувозинати пешфарз.
func DefaultWeights() Weights {
	return Weights{
		Topic:     45,
		Creator:   40,
		Language:  25,
		Local:     20,
		Original:  15,
		Following: 30,
		FewerRecs: 35,
	}
}

// Candidate — мӯҳтаво бо сигналҳое, ки барои холи иловагӣ лозиманд.
type Candidate struct {
	ContentID string
	CreatorID string
	// BaseScore — холи формулаи МАВҶУДА. Ин ҷо тағйир намеёбад.
	BaseScore float64
	// TopicScores — афзалияти корбар барои мавзӯъҳои ин мӯҳтаво,
	// бо вазни мансубият: slug → (pref, weight).
	Topics []TopicMatch
	// CreatorScore — афзалияти корбар нисбат ба ин эҷодкор (-1..1).
	CreatorScore float64
	LanguageHit  bool
	IsLocal      bool
	IsOriginal   bool
	IsFollowing  bool
}

// TopicMatch — як мавзӯи мӯҳтаво ва афзалияти корбар ба он.
type TopicMatch struct {
	Slug string
	// Pref — афзалияти корбар (-1..1).
	Pref float64
	// Weight — чӣ қадар мӯҳтаво ба ин мавзӯъ мансуб аст (0..1).
	Weight float64
}

// Contribution — саҳми ҳар омил. Барои «Чаро инро мебинам?» ва
// барои санҷиш: ҳеҷ рақам аз ҳеҷ ҷо намеояд.
type Contribution struct {
	Topic     float64 `json:"topic"`
	Creator   float64 `json:"creator"`
	Language  float64 `json:"language"`
	Local     float64 `json:"local"`
	Original  float64 `json:"original"`
	Following float64 `json:"following"`
	FewerRecs float64 `json:"fewerRecommendations"`
}

// Total — ҷамъи саҳмҳо.
func (c Contribution) Total() float64 {
	return c.Topic + c.Creator + c.Language + c.Local +
		c.Original + c.Following + c.FewerRecs
}

// Personalize холи иловагиро ҳисоб мекунад.
//
// BaseScore даст нахӯрда мемонад ва натиҷа base + иловагӣ аст, то
// рафтори мавҷудаи лента ҳамчун асос боқӣ монад.
func Personalize(c Candidate, w Weights, fewerRecs bool, preferFollowing,
	preferLocal, preferOriginal bool) (float64, Contribution) {

	var out Contribution

	// Мавзӯъ: миёнаи вазндор аз афзалиятҳо. Пости бисёрмавзӯъ набояд
	// танҳо аз рӯи шумораи мавзӯъҳояш боло равад.
	var sum, wsum float64
	for _, t := range c.Topics {
		sum += t.Pref * t.Weight
		wsum += t.Weight
	}
	if wsum > 0 {
		out.Topic = round2((sum / wsum) * w.Topic)
	}

	out.Creator = round2(c.CreatorScore * w.Creator)

	if c.LanguageHit {
		out.Language = w.Language
	}
	if preferLocal && c.IsLocal {
		out.Local = w.Local
	}
	if preferOriginal && c.IsOriginal {
		out.Original = w.Original
	}
	if preferFollowing && c.IsFollowing {
		out.Following = w.Following
	}
	// Камтар тавсия: танҳо мӯҳтавои беруни обуна ҷарима мегирад.
	if fewerRecs && !c.IsFollowing {
		out.FewerRecs = -w.FewerRecs
	}

	return round2(c.BaseScore + out.Total()), out
}

// SortKey — калиди тартиб бо шикастани баробарӣ.
//
// Ҳангоми холи баробар тартиб бояд УСТУВОР бошад, вагарна ҳамон лента
// дар ҳар навсозӣ ҷои элементҳоро иваз мекунад ва корбар як постро ду
// бор мебинад.
func SortKey(score float64, contentID string) (float64, string) {
	if math.IsNaN(score) {
		return 0, contentID
	}
	return score, contentID
}
