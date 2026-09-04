package creator

import (
	"context"
	"sort"
)

// Insight — як мушоҳидаи аз маълумоти ВОҚЕӢ бармеомада.
//
// Матн ин ҷо сохта НАМЕШАВАД: танҳо рамз ва рақамҳо мераванд, ва
// тарҷума дар client аст. Ин ду фоида дорад — се забон дар як ҷо
// мемонад, ва хулосаи бе рақам сохта шуда наметавонад.
type Insight struct {
	Code   string         `json:"code"`
	Params map[string]any `json:"params,omitempty"`
	// Priority — кадомаш аввал нишон дода шавад.
	Priority int `json:"priority"`
}

// Ҳадди ақали маълумот барои хулоса.
//
// Бе ин, «мавзӯи беҳтарини шумо» аз як пост бо ду лайк ҳисоб мешуд ва
// эҷодкорро ба хулосаи бардурӯғ мебурд.
const (
	minContentForTopicClaim = 2
	minImpressionsForClaim  = 50
	minFollowsForClaim      = 3
)

// BuildInsights мушоҳидаҳоро аз рақамҳои воқеӣ месозад.
//
// Ҳар хулоса шарти ҳадди ақали маълумот дорад. Агар маълумот кам
// бошад, хулоса СОХТА НАМЕШАВАД — рӯйхати холӣ ростӣ аст.
func BuildInsights(ctx context.Context, db DB, userID string,
	w Window) ([]Insight, error) {

	out := []Insight{}

	ov, err := GetOverview(ctx, db, userID, w)
	if err != nil {
		return nil, err
	}
	rec, err := GetRecommendationStats(ctx, db, userID, w)
	if err != nil {
		return nil, err
	}
	topics, err := GetTopicPerformance(ctx, db, userID, w)
	if err != nil {
		return nil, err
	}

	// 1. Мавзӯи беҳтарин — танҳо вақте ду мавзӯъ барои МУҚОИСА ҳаст.
	//    Бе муқоиса «беҳтарин» маъно надорад.
	if len(topics) >= 2 &&
		topics[0].Content >= minContentForTopicClaim &&
		topics[0].PerContent > topics[1].PerContent {
		out = append(out, Insight{
			Code:     "topTopic",
			Priority: 100,
			Params: map[string]any{
				"topic":   topics[0].Topic,
				"perPost": topics[0].PerContent,
				"second":  topics[1].Topic,
			},
		})
	}

	// 2. Тавсия обуначӣ овард.
	if rec.Follows >= minFollowsForClaim {
		out = append(out, Insight{
			Code:     "followsFromRecommendations",
			Priority: 95,
			Params:   map[string]any{"count": rec.Follows},
		})
	}

	// 3. Фоизи анҷом — танҳо бо намоиши кофӣ.
	if rec.Impressions >= minImpressionsForClaim && rec.CompletionRate > 0 {
		code := "completionLow"
		priority := 70
		if rec.CompletionRate >= 0.5 {
			code = "completionHigh"
			priority = 85
		}
		out = append(out, Insight{
			Code:     code,
			Priority: priority,
			Params: map[string]any{
				"percent": int(rec.CompletionRate*100 + 0.5),
			},
		})
	}

	// 4. Тавсия чӣ қадар мерасонад.
	if rec.Impressions >= minImpressionsForClaim {
		out = append(out, Insight{
			Code:     "recommendationReach",
			Priority: 80,
			Params:   map[string]any{"impressions": rec.Impressions},
		})
	}

	// 5. Афзоиши обуначиён.
	if ov.FollowersGained > 0 {
		out = append(out, Insight{
			Code:     "followerGrowth",
			Priority: 75,
			Params: map[string]any{
				"count":  ov.FollowersGained,
				"window": string(w),
			},
		})
	}

	// 6. Ҳанӯз мӯҳтаво нест — ин ягона «маслиҳат»-и бе маълумот аст
	//    ва он вазъи воқеиро мегӯяд, на тахминро.
	if ov.Posts == 0 && ov.Reels == 0 {
		out = append(out, Insight{Code: "noContentYet", Priority: 60})
	}

	sort.SliceStable(out, func(i, j int) bool {
		return out[i].Priority > out[j].Priority
	})
	if len(out) > 5 {
		out = out[:5]
	}
	return out, nil
}

// ContentIdea — як пешниҳоди мӯҳтаво.
type ContentIdea struct {
	Title    string   `json:"title"`
	Hook     string   `json:"hook"`
	Idea     string   `json:"idea"`
	Format   string   `json:"format"`
	Duration string   `json:"duration"`
	Hashtags []string `json:"hashtags"`
	CTA      string   `json:"cta"`
}

// IdeaContext — заминаи воқеии эҷодкор барои пешниҳоди мӯҳтаво.
//
// Ин аз маълумоти ВОҚЕӢ пур мешавад ва ба модел дода мешавад, то
// пешниҳод ба ин эҷодкор мансуб бошад, на умумӣ.
type IdeaContext struct {
	TopTopics    []string
	Language     string
	RecentTitles []string
}

// BuildIdeaContext заминаро аз маълумоти эҷодкор ҷамъ мекунад.
func BuildIdeaContext(ctx context.Context, db DB, userID string) (IdeaContext, error) {
	var out IdeaContext

	topics, err := GetTopicPerformance(ctx, db, userID, Window30d)
	if err != nil {
		return out, err
	}
	for i, t := range topics {
		if i >= 3 {
			break
		}
		out.TopTopics = append(out.TopTopics, t.Topic)
	}

	// Сарлавҳаҳои охирин — то модел ҳамонро такрор напешниҳод кунад.
	rows, err := db.Query(ctx, `
		SELECT caption FROM (
		  SELECT caption, created_at FROM posts
		  WHERE user_id=$1 AND COALESCE(caption,'') <> ''
		  UNION ALL
		  SELECT caption, created_at FROM reels
		  WHERE user_id=$1 AND COALESCE(caption,'') <> ''
		) t ORDER BY created_at DESC LIMIT 10`, userID)
	if err == nil {
		for rows.Next() {
			var s string
			if rows.Scan(&s) == nil && s != "" {
				out.RecentTitles = append(out.RecentTitles, s)
			}
		}
		rows.Close()
	}

	db.QueryRow(ctx, `SELECT COALESCE(language,'tj') FROM users WHERE id=$1`,
		userID).Scan(&out.Language)
	if out.Language == "" {
		out.Language = "tj"
	}
	return out, nil
}
