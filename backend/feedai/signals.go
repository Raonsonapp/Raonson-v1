// Package feedai қабати идорашавандаи тавсияи «Лентаи AI»-ро таъмин
// мекунад.
//
// Ин пакет рейтинги мавҷударо ИВАЗ НАМЕКУНАД. GetSmartFeed ва
// GetSmartReels ҳамон формулаи худро нигоҳ медоранд; ин ҷо танҳо
// вазни иловагӣ ҳисоб мешавад, ки аз афзалиятҳои ХУДИ корбар меояд.
package feedai

import (
	"math"
	"strings"
)

// Event — намуди ҳодисаи тавсия.
type Event string

const (
	EventImpression   Event = "FEED_IMPRESSION"
	EventOpen         Event = "POST_OPEN"
	EventVideo25      Event = "VIDEO_25_PERCENT"
	EventVideo50      Event = "VIDEO_50_PERCENT"
	EventVideo75      Event = "VIDEO_75_PERCENT"
	EventVideoDone    Event = "VIDEO_COMPLETE"
	EventLike         Event = "LIKE"
	EventComment      Event = "COMMENT"
	EventShare        Event = "SHARE"
	EventSave         Event = "SAVE"
	EventFollow       Event = "FOLLOW"
	EventProfileView  Event = "PROFILE_VIEW"
	EventMoreLikeThis Event = "MORE_LIKE_THIS"
	EventLessLikeThis Event = "LESS_LIKE_THIS"
	EventHide         Event = "HIDE_RECOMMENDATION"
	EventNotInterest  Event = "NOT_INTERESTED"
	EventCreatorMute  Event = "CREATOR_MUTE"
	EventSkip         Event = "SKIP"
	EventUnfollow     Event = "UNFOLLOW"
)

// eventWeights — саҳми ҳар ҳодиса дар афзалият.
//
// Вазнҳо ният (intent)-ро инъикос мекунанд, на осонии амалро: сейв ва
// мубодила аз лайк вазнинтаранд, зеро кӯшиши бештар талаб мекунанд ва
// ният равшантар аст. Дидан (impression) қариб сифр аст — он танҳо
// маънои «ба чашмаш афтод»-ро дорад, на «хуш омад».
//
// Аломати манфӣ = мӯҳтавои монандро камтар нишон деҳ.
var eventWeights = map[Event]float64{
	EventImpression:   0.002,
	EventOpen:         0.02,
	EventVideo25:      0.01,
	EventVideo50:      0.03,
	EventVideo75:      0.06,
	EventVideoDone:    0.10,
	EventLike:         0.08,
	EventComment:      0.12,
	EventShare:        0.15,
	EventSave:         0.15,
	EventFollow:       0.20,
	EventProfileView:  0.05,
	EventMoreLikeThis: 0.30,
	EventLessLikeThis: -0.30,
	EventHide:         -0.25,
	EventNotInterest:  -0.25,
	EventCreatorMute:  -0.50,
	EventSkip:         -0.02,
	EventUnfollow:     -0.20,
}

// Valid — оё чунин ҳодиса вуҷуд дорад?
//
// Client метавонад ҳар сатр фиристад; ҳодисаи номаълум рад мешавад,
// то ҷадвали ҳодисаҳо бо маълумоти бемаъно пур нашавад.
func (e Event) Valid() bool {
	_, ok := eventWeights[e]
	return ok
}

// Weight — вазни ҳодиса. Барои ҳодисаи номаълум сифр.
func (e Event) Weight() float64 { return eventWeights[e] }

// IsNegative — оё ҳодиса сигнали манфист?
func (e Event) IsNegative() bool { return eventWeights[e] < 0 }

// AllEvents рӯйхати ҳодисаҳои эътирофшударо бармегардонад.
func AllEvents() []Event {
	out := make([]Event, 0, len(eventWeights))
	for e := range eventWeights {
		out = append(out, e)
	}
	return out
}

// ── Ҷамъбасти афзалият ───────────────────────────────────────────

// maxTopicScore — ҳудуди афзалият. Холҳо ба [-1, 1] маҳдуд мешаванд,
// то як корбар бо садҳо лайк мавзӯъро то беохир боло набарад.
const maxTopicScore = 1.0

// ApplySignal холи навро баъди як ҳодиса ҳисоб мекунад.
//
// Афзоиш КОҲИШЁБАНДА аст: ҳар қадар хол ба ҳудуд наздик шавад, ҳамон
// қадар ҳодисаи нав камтар илова мекунад. Бе ин, даҳ лайк холро ба 1.0
// мебурд ва мавзӯъ дигар ҳеҷ гоҳ поён намеомад — лента дар як мавзӯъ
// мечаспид.
func ApplySignal(current, weight float64) float64 {
	if weight == 0 {
		return clamp(current, -maxTopicScore, maxTopicScore)
	}
	// Ҷои боқимонда то ҳудуди мувофиқ (боло барои мусбат, поён барои манфӣ).
	var room float64
	if weight > 0 {
		room = maxTopicScore - current
	} else {
		room = current + maxTopicScore
	}
	if room < 0 {
		room = 0
	}
	next := current + weight*room
	return clamp(next, -maxTopicScore, maxTopicScore)
}

// Decay афзалияти омӯхтаро бо гузашти вақт суст мекунад.
//
// Бе фаромӯшӣ, шавқи солипешина то абад дар лента мемонад. halfLifeDays
// — чанд рӯз лозим аст, то хол ду баробар кам шавад.
func Decay(score float64, days, halfLifeDays float64) float64 {
	if days <= 0 || halfLifeDays <= 0 {
		return score
	}
	return score * math.Pow(0.5, days/halfLifeDays)
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

// ── Муайян кардани мавзӯи мӯҳтаво ────────────────────────────────

// Topic — мавзӯъ бо калидвожаҳояш.
type Topic struct {
	Slug     string
	Keywords []string
}

// ClassifyText мавзӯъҳои матнро бо мувофиқати калидвожа муайян мекунад.
//
// Ин ҷо ҳеҷ LLM даъват НАМЕШАВАД: таснифи ҳар пост бо AI гарон ва суст
// мебуд. Мувофиқати калидвожа дар паснамо иҷро мешавад ва натиҷа дар
// content_topics захира мегардад.
//
// Вазн аз шумораи мувофиқат меояд, вале коҳишёбанда: як пост, ки
// калимаи «бозӣ»-ро даҳ бор такрор мекунад, аз пости муқаррарӣ
// даҳ баробар «бозӣ»-тар нест.
func ClassifyText(text string, topics []Topic) map[string]float64 {
	out := map[string]float64{}
	if strings.TrimSpace(text) == "" {
		return out
	}
	lower := strings.ToLower(text)
	// Марзҳо: то калимаи «игра» дар «играть» ва «gaming» дар
	// «engaging» мувофиқати бардурӯғ надиҳад, атрофи матн бо фосила
	// иҳота мешавад ва мувофиқат бо марзи калима санҷида мешавад.
	padded := " " + replaceSeparators(lower) + " "

	for _, t := range topics {
		hits := 0
		for _, kw := range t.Keywords {
			k := strings.ToLower(strings.TrimSpace(kw))
			if k == "" {
				continue
			}
			if strings.Contains(padded, " "+k+" ") ||
				strings.Contains(padded, " #"+k+" ") {
				hits++
			}
		}
		if hits == 0 {
			continue
		}
		// 1 мувофиқат → 0.6, 2 → 0.8, 3 → ~0.87 … ҳудуд 1.0
		w := 1 - 1/(float64(hits)+1.5)
		out[t.Slug] = round2(clamp(w, 0, 1))
	}
	return out
}

// replaceSeparators аломатҳои ҷудокунандаро ба фосила иваз мекунад,
// то калимаҳо марз дошта бошанд.
func replaceSeparators(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z',
			r >= '0' && r <= '9',
			r >= 'а' && r <= 'я',
			r == 'ё' || r == 'ӣ' || r == 'ӯ' || r == 'қ' || r == 'ғ' ||
				r == 'ҳ' || r == 'ҷ',
			r == '#':
			b.WriteRune(r)
		default:
			b.WriteRune(' ')
		}
	}
	return b.String()
}

func round2(v float64) float64 { return math.Round(v*100) / 100 }
