package feedai

import (
	"context"
	"sort"
)

// Reason — як сабаби воқеӣ, ки чаро мӯҳтаво нишон дода шуд.
//
// Code барои тарҷума дар client аст, Params рақамҳои воқеӣ. Матн дар
// server сохта НАМЕШАВАД: вагарна се забон дар ду ҷо нигоҳ дошта
// мешуд ва аз ҳам дур мерафт.
type Reason struct {
	Code   string         `json:"code"`
	Params map[string]any `json:"params,omitempty"`
	// Strength — саҳми ин сабаб; барои тартиб.
	Strength float64 `json:"strength"`
}

// Explanation — ҷавоби «Чаро инро мебинам?».
type Explanation struct {
	Reasons []Reason `json:"reasons"`
	// Personalized — оё ин мӯҳтаво воқеан аз рӯи профили корбар боло
	// рафт? Агар не, ба корбар рост гуфта мешавад.
	Personalized bool `json:"personalized"`
}

// Explain сабабҳоро АЗ МАЪЛУМОТИ ВОҚЕАН ЗАХИРАШУДА месозад.
//
// Ҳеҷ сабаб ихтироъ намешавад. Агар система чизе надонад, ҷавоб холӣ
// мемонад ва client «мӯҳтавои маъмул» мегӯяд — ин ростӣ аст, на
// «AI фикр мекунад ба шумо маъқул мешавад».
func Explain(ctx context.Context, db DB, userID, contentType,
	contentID, creatorID string) (Explanation, error) {

	out := Explanation{Reasons: []Reason{}}

	// 1. Обуна — сабаби қавитарин ва оддитарин.
	if creatorID != "" {
		var following bool
		if err := db.QueryRow(ctx, `
			SELECT EXISTS(SELECT 1 FROM follows
			WHERE follower_id=$1 AND following_id=$2)`,
			userID, creatorID).Scan(&following); err == nil && following {
			out.Reasons = append(out.Reasons, Reason{
				Code: "following", Strength: 100,
			})
		}
	}

	// 2. Афзалияти эҷодкор — танҳо агар воқеан сабт шуда бошад.
	if creatorID != "" {
		var score float64
		var source string
		if err := db.QueryRow(ctx, `
			SELECT score, source FROM feed_creator_prefs
			WHERE user_id=$1 AND creator_id=$2`, userID, creatorID).
			Scan(&score, &source); err == nil && score > 0.05 {
			code := "creatorLearned"
			if source == "explicit" {
				code = "creatorExplicit"
			}
			out.Reasons = append(out.Reasons, Reason{
				Code: code, Strength: 60 * score,
			})
			out.Personalized = true
		}
	}

	// 3. Мавзӯъҳо: танҳо онҳое, ки ҳам дар мӯҳтаво ҳастанд ва ҳам
	//    корбар ба онҳо таваҷҷӯҳ нишон додааст.
	if contentID != "" && contentType != "" {
		rows, err := db.Query(ctx, `
			SELECT ct.topic_slug, t.name_tj, p.score, p.source
			FROM content_topics ct
			JOIN feed_topics t ON t.slug = ct.topic_slug
			JOIN feed_topic_prefs p
			     ON p.topic_slug = ct.topic_slug AND p.user_id = $1
			WHERE ct.content_type=$2 AND ct.content_id=$3 AND p.score > 0.05
			ORDER BY p.score DESC LIMIT 3`, userID, contentType, contentID)
		if err == nil {
			for rows.Next() {
				var slug, name, source string
				var score float64
				if err := rows.Scan(&slug, &name, &score, &source); err != nil {
					continue
				}
				code := "topicLearned"
				if source == "explicit" {
					code = "topicExplicit"
				}
				out.Reasons = append(out.Reasons, Reason{
					Code:     code,
					Params:   map[string]any{"topic": slug},
					Strength: 50 * score,
				})
				out.Personalized = true
			}
			rows.Close()
		}
	}

	// 4. Рафтори воқеӣ: чанд бор корбар бо ҳамин мавзӯъ амал кард.
	//    Ин рақам аз feed_events меояд — на аз тахмин.
	if contentID != "" && contentType != "" {
		var doneCount int
		err := db.QueryRow(ctx, `
			SELECT COUNT(DISTINCT e.content_id)
			FROM feed_events e
			JOIN content_topics ect
			     ON ect.content_type = e.content_type
			    AND ect.content_id  = e.content_id
			WHERE e.user_id = $1
			  AND e.event IN ('VIDEO_COMPLETE','LIKE','SAVE','MORE_LIKE_THIS')
			  AND e.content_id <> $3
			  AND ect.topic_slug IN (
			      SELECT topic_slug FROM content_topics
			      WHERE content_type=$2 AND content_id=$3)`,
			userID, contentType, contentID).Scan(&doneCount)
		if err == nil && doneCount >= 2 {
			out.Reasons = append(out.Reasons, Reason{
				Code:     "similarEngagement",
				Params:   map[string]any{"count": doneCount},
				Strength: 40,
			})
			out.Personalized = true
		}
	}

	// Сабаби қавитарин аввал.
	sort.SliceStable(out.Reasons, func(i, j int) bool {
		return out.Reasons[i].Strength > out.Reasons[j].Strength
	})
	if len(out.Reasons) > 4 {
		out.Reasons = out.Reasons[:4]
	}
	return out, nil
}
