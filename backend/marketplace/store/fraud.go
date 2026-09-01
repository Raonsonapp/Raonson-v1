package store

import (
	"context"
	"encoding/json"
	"fmt"

	"raonson/marketplace/score"
)

// FraudSignal — як аломати шубҳанок.
type FraudSignal struct {
	Signal  string         `json:"signal"`
	Score   float64        `json:"score"` // 0..1, саҳм дар холи умумӣ
	Details map[string]any `json:"details"`
}

// DetectCreatorFraud аломатҳои шубҳанокро аз маълумоти ВОҚЕӢ меёбад.
//
// Ин ҷо ҳеҷ «модели зеҳни сунъӣ» ва ҳеҷ рақами тасодуфӣ нест. Ҳар
// аломат як номувофиқатии ченшавандаи маълумот аст, ки шарҳ дода
// мешавад — то эҷодкор бидонад, ки чаро парчам гузошта шуд.
//
// Аломат ҳукм НЕСТ: он холи мувофиқатро паст мекунад ва барои
// баррасии дастӣ сабт мешавад.
func DetectCreatorFraud(ctx context.Context, tx Tx, creatorID string) ([]FraudSignal, error) {
	m, err := CollectCreatorMetrics(ctx, tx, creatorID)
	if err != nil {
		return nil, err
	}
	out := []FraudSignal{}

	// 1) Лайк аз биниш зиёд. Одам чизеро, ки надидааст, лайк карда
	//    наметавонад — ин аломати лайкҳои харидашуда аст.
	if m.TotalViews > 0 && m.Likes > m.TotalViews {
		out = append(out, FraudSignal{
			Signal: "likes_exceed_views",
			Score:  0.6,
			Details: map[string]any{
				"likes": m.Likes,
				"views": m.TotalViews,
			},
		})
	}

	// 2) Ҳамкорӣ аз аудитория хеле зиёд. Дар амал engagement аз 40%
	//    боло дар аудиторияи калон қариб рух намедиҳад.
	if m.Followers >= 1000 {
		er := score.EngagementRate(m)
		if er > 0.4 {
			out = append(out, FraudSignal{
				Signal: "engagement_implausible",
				Score:  0.5,
				Details: map[string]any{
					"engagementRate": er,
					"followers":      m.Followers,
				},
			})
		}
	}

	// 3) Аудиторияи калон бе мӯҳтаво. Аккаунти бе пост, вале бо даҳҳо
	//    ҳазор пайрав, аудиторияи харидашударо нишон медиҳад.
	if m.Followers >= 5000 && m.ContentCount == 0 {
		out = append(out, FraudSignal{
			Signal: "audience_without_content",
			Score:  0.5,
			Details: map[string]any{
				"followers":    m.Followers,
				"contentCount": m.ContentCount,
			},
		})
	}

	// 4) Кампанияҳои қаблӣ иҷро нашудаанд.
	if m.CampaignCount >= 3 && m.AverageCampaignResult < 0.34 {
		out = append(out, FraudSignal{
			Signal: "poor_campaign_delivery",
			Score:  0.4,
			Details: map[string]any{
				"campaigns": m.CampaignCount,
				"delivered": m.SuccessfulCampaigns,
			},
		})
	}
	return out, nil
}

// SaveFraudSignals аломатҳоро сабт мекунад.
//
// Аломати ТАКРОРӢ сабти нав намесозад: ҳар аломат барои як эҷодкор
// як сатри КУШОДА дорад, вагарна як мушкили доимӣ холи фиребро
// бо ҳар давр боло мебарад.
func SaveFraudSignals(ctx context.Context, tx Tx, creatorID string, signals []FraudSignal) error {
	for _, s := range signals {
		var exists bool
		if err := tx.QueryRow(ctx, `
			SELECT EXISTS(
			  SELECT 1 FROM fraud_flags
			  WHERE entity_type='creator' AND entity_id=$1
			    AND signal=$2 AND status='OPEN')`, creatorID, s.Signal).Scan(&exists); err != nil {
			return err
		}
		if exists {
			continue
		}
		details := s.Details
		if details == nil {
			details = map[string]any{}
		}
		if _, err := tx.Exec(ctx, `
			INSERT INTO fraud_flags(entity_type, entity_id, signal, score, details, status)
			VALUES ('creator',$1,$2,$3,$4,'OPEN')`,
			creatorID, s.Signal, s.Score, mustJSON(details)); err != nil {
			return fmt.Errorf("store: сабти аломати фиреб: %w", err)
		}
	}
	return nil
}

// ClearResolvedFraudSignals парчамҳоеро мебандад, ки сабабашон гузаштааст.
//
// Бе ин, як хатогии кӯҳна эҷодкорро то абад ҷазо медиҳад.
func ClearResolvedFraudSignals(ctx context.Context, tx Tx, creatorID string,
	current []FraudSignal) error {
	active := make([]string, 0, len(current))
	for _, s := range current {
		active = append(active, s.Signal)
	}
	_, err := tx.Exec(ctx, `
		UPDATE fraud_flags SET status='RESOLVED'
		WHERE entity_type='creator' AND entity_id=$1 AND status='OPEN'
		  AND NOT (signal = ANY($2))`, creatorID, active)
	return err
}

// mustJSON ҷузъиётро ба JSON табдил медиҳад; ҳангоми хато объекти холӣ.
func mustJSON(v any) string {
	b, err := json.Marshal(v)
	if err != nil {
		return "{}"
	}
	return string(b)
}
