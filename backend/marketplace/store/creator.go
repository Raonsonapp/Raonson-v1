package store

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/ledger"
	"raonson/marketplace/matching"
	"raonson/marketplace/money"
	"raonson/marketplace/score"
)

var ErrInvalidCreatorProfile = errors.New("store: профили эҷодкор нодуруст")

// CreatorProfile — он чи худи эҷодкор дар бораи худ мегӯяд.
//
// Метрикаҳо ин ҷо НЕСТАНД: онҳо аз маълумоти воқеӣ ҳисоб мешаванд
// (CreatorMetrics) ва эҷодкор онҳоро таҳрир карда наметавонад.
type CreatorProfile struct {
	CreatorID          string       `json:"creatorId"`
	AudienceCountry    string       `json:"audienceCountry"`
	AudienceLanguage   string       `json:"audienceLanguage"`
	ContentCategories  []string     `json:"contentCategories"`
	Price              money.Amount `json:"price"`
	Available          bool         `json:"available"`
	VerificationStatus string       `json:"verificationStatus"`
}

// CreatorProfileInput — вуруди таҳрир аз ҷониби эҷодкор.
type CreatorProfileInput struct {
	AudienceCountry   string   `json:"audienceCountry"`
	AudienceLanguage  string   `json:"audienceLanguage"`
	ContentCategories []string `json:"contentCategories"`
	PriceMinor        int64    `json:"priceMinor"`
	Currency          string   `json:"currency"`
	Available         bool     `json:"available"`
}

// Validate — ҳадди чизҳое, ки эҷодкор таъин мекунад.
//
// verification_status дар вуруд нест: эҷодкор худро тасдиқшуда
// эълон карда наметавонад.
func (in CreatorProfileInput) Validate() error {
	if in.PriceMinor < 0 {
		return fmt.Errorf("%w: нарх манфӣ буда наметавонад", ErrInvalidCreatorProfile)
	}
	if _, err := money.ParseCurrency(in.Currency); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCreatorProfile, err)
	}
	if len(in.ContentCategories) > 10 {
		return fmt.Errorf("%w: аз 10 категория зиёд намешавад", ErrInvalidCreatorProfile)
	}
	for _, cat := range in.ContentCategories {
		if strings.TrimSpace(cat) == "" || len([]rune(cat)) > 40 {
			return fmt.Errorf("%w: категорияи нодуруст", ErrInvalidCreatorProfile)
		}
	}
	if len([]rune(in.AudienceCountry)) > 60 || len([]rune(in.AudienceLanguage)) > 20 {
		return fmt.Errorf("%w: маълумоти аудитория хеле дароз", ErrInvalidCreatorProfile)
	}
	return nil
}

// UpsertCreatorProfile профили эҷодкорро месозад ё нав мекунад.
func UpsertCreatorProfile(ctx context.Context, tx Tx, creatorID string,
	in CreatorProfileInput) (CreatorProfile, error) {
	if creatorID == "" {
		return CreatorProfile{}, ErrInvalidCreatorProfile
	}
	if err := in.Validate(); err != nil {
		return CreatorProfile{}, err
	}
	cur, _ := money.ParseCurrency(in.Currency)
	cats := in.ContentCategories
	if cats == nil {
		cats = []string{}
	}

	var p CreatorProfile
	var price int64
	var curOut string
	err := tx.QueryRow(ctx, `
		INSERT INTO creator_profiles
		  (creator_id, audience_country, audience_language, content_categories,
		   price_minor, currency, available)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		ON CONFLICT (creator_id) DO UPDATE SET
		  audience_country   = EXCLUDED.audience_country,
		  audience_language  = EXCLUDED.audience_language,
		  content_categories = EXCLUDED.content_categories,
		  price_minor        = EXCLUDED.price_minor,
		  currency           = EXCLUDED.currency,
		  available          = EXCLUDED.available,
		  updated_at         = NOW()
		RETURNING creator_id, audience_country, audience_language,
		          content_categories, price_minor, currency, available,
		          verification_status`,
		creatorID, in.AudienceCountry, in.AudienceLanguage, cats,
		in.PriceMinor, string(cur), in.Available).
		Scan(&p.CreatorID, &p.AudienceCountry, &p.AudienceLanguage,
			&p.ContentCategories, &price, &curOut, &p.Available,
			&p.VerificationStatus)
	if err != nil {
		return CreatorProfile{}, fmt.Errorf("store: сабти профили эҷодкор: %w", err)
	}
	c, _ := money.ParseCurrency(curOut)
	p.Price = money.Amount{Minor: money.Minor(price), Currency: c}
	return p, nil
}

// GetCreatorProfile профилро мегирад. Агар набошад — ErrNotFound.
func GetCreatorProfile(ctx context.Context, tx Tx, creatorID string) (CreatorProfile, error) {
	var p CreatorProfile
	var price int64
	var curOut string
	err := tx.QueryRow(ctx, `
		SELECT creator_id, audience_country, audience_language, content_categories,
		       price_minor, currency, available, verification_status
		FROM creator_profiles WHERE creator_id=$1`, creatorID).
		Scan(&p.CreatorID, &p.AudienceCountry, &p.AudienceLanguage,
			&p.ContentCategories, &price, &curOut, &p.Available,
			&p.VerificationStatus)
	if errors.Is(err, pgx.ErrNoRows) {
		return CreatorProfile{}, ErrCreatorProfileMissing
	}
	if err != nil {
		return CreatorProfile{}, err
	}
	c, _ := money.ParseCurrency(curOut)
	p.Price = money.Amount{Minor: money.Minor(price), Currency: c}
	return p, nil
}

// ErrCreatorProfileMissing — эҷодкор ҳанӯз ба marketplace ворид нашудааст.
var ErrCreatorProfileMissing = errors.New("store: профили эҷодкор вуҷуд надорад")

// CreatorMetrics — метрикаи ҳисобшуда. Танҳо job онро менависад.
type CreatorMetrics struct {
	CreatorID       string  `json:"creatorId"`
	Followers       int64   `json:"followers"`
	TotalViews      int64   `json:"totalViews"`
	AverageViews    int64   `json:"averageViews"`
	Likes           int64   `json:"likes"`
	Comments        int64   `json:"comments"`
	Shares          int64   `json:"shares"`
	Saves           int64   `json:"saves"`
	EngagementRate  float64 `json:"engagementRate"`
	ContentCount    int64   `json:"contentCount"`
	CampaignCount   int64   `json:"campaignCount"`
	SuccessfulCount int64   `json:"successfulCampaignCount"`
	AverageResult   float64 `json:"averageCampaignResult"`
	Score           float64 `json:"creatorScore"`
	Confidence      float64 `json:"scoreConfidence"`
	SampleSize      int64   `json:"sampleSize"`

	// Метаи ҳисоб — то холи кӯҳна бо алгоритми нав омехта нашавад.
	ScoreVersion   int                `json:"scoreVersion"`
	ScoreParams    map[string]float64 `json:"scoreParams,omitempty"`
	ScoreBreakdown map[string]float64 `json:"scoreBreakdown,omitempty"`
}

// SaveCreatorMetrics метрикаро бо холи ҳисобшуда сабт мекунад.
//
// Хол ин ҷо аз score.Compute меояд — ҳеҷ гоҳ аз вуруди корбар ва
// ҳеҷ гоҳ тасодуфӣ.
func SaveCreatorMetrics(ctx context.Context, tx Tx, creatorID string,
	m score.Metrics) (CreatorMetrics, error) {
	if creatorID == "" {
		return CreatorMetrics{}, ErrInvalidCreatorProfile
	}
	res := score.Compute(m)
	out := CreatorMetrics{
		CreatorID:       creatorID,
		Followers:       m.Followers,
		TotalViews:      m.TotalViews,
		AverageViews:    m.AverageViews,
		Likes:           m.Likes,
		Comments:        m.Comments,
		Shares:          m.Shares,
		Saves:           m.Saves,
		EngagementRate:  res.EngagementRate,
		ContentCount:    m.ContentCount,
		CampaignCount:   m.CampaignCount,
		SuccessfulCount: m.SuccessfulCampaigns,
		AverageResult:   m.AverageCampaignResult,
		Score:           res.Score,
		Confidence:      res.Confidence,
		SampleSize:      res.SampleSize,
		ScoreVersion:    res.Version,
		ScoreParams:     res.Params,
		ScoreBreakdown:  res.Breakdown,
	}
	_, err := tx.Exec(ctx, `
		INSERT INTO creator_metrics
		  (creator_id, followers_count, total_views, average_views, likes,
		   comments, shares, saves, engagement_rate, content_count,
		   campaign_count, successful_campaign_count, average_campaign_result,
		   creator_score, score_confidence, sample_size, computed_at,
		   score_version, score_params, score_breakdown)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,NOW(),$17,$18,$19)
		ON CONFLICT (creator_id) DO UPDATE SET
		  followers_count           = EXCLUDED.followers_count,
		  total_views               = EXCLUDED.total_views,
		  average_views             = EXCLUDED.average_views,
		  likes                     = EXCLUDED.likes,
		  comments                  = EXCLUDED.comments,
		  shares                    = EXCLUDED.shares,
		  saves                     = EXCLUDED.saves,
		  engagement_rate           = EXCLUDED.engagement_rate,
		  content_count             = EXCLUDED.content_count,
		  campaign_count            = EXCLUDED.campaign_count,
		  successful_campaign_count = EXCLUDED.successful_campaign_count,
		  average_campaign_result   = EXCLUDED.average_campaign_result,
		  creator_score             = EXCLUDED.creator_score,
		  score_confidence          = EXCLUDED.score_confidence,
		  sample_size               = EXCLUDED.sample_size,
		  score_version             = EXCLUDED.score_version,
		  score_params              = EXCLUDED.score_params,
		  score_breakdown           = EXCLUDED.score_breakdown,
		  computed_at               = NOW(),
		  updated_at                = NOW()`,
		creatorID, out.Followers, out.TotalViews, out.AverageViews, out.Likes,
		out.Comments, out.Shares, out.Saves, out.EngagementRate, out.ContentCount,
		out.CampaignCount, out.SuccessfulCount, out.AverageResult,
		out.Score, out.Confidence, out.SampleSize,
		out.ScoreVersion, mustJSON(out.ScoreParams), mustJSON(out.ScoreBreakdown))
	if err != nil {
		return CreatorMetrics{}, fmt.Errorf("store: сабти метрика: %w", err)
	}
	return out, nil
}

// GetCreatorMetrics метрикаи эҷодкорро мегирад.
//
// Агар ҳанӯз ҳисоб нашуда бошад, метрикаи холӣ бармегардад — на хато:
// эҷодкори нав метрика надорад ва ин ҳолати муқаррарист.
func GetCreatorMetrics(ctx context.Context, tx Tx, creatorID string) (CreatorMetrics, error) {
	m := CreatorMetrics{CreatorID: creatorID}
	var params, breakdown []byte
	err := tx.QueryRow(ctx, `
		SELECT followers_count, total_views, average_views, likes, comments,
		       shares, saves, engagement_rate, content_count, campaign_count,
		       successful_campaign_count, average_campaign_result,
		       creator_score, score_confidence, sample_size,
		       COALESCE(score_version,0),
		       COALESCE(score_params,'{}'::jsonb),
		       COALESCE(score_breakdown,'{}'::jsonb)
		FROM creator_metrics WHERE creator_id=$1`, creatorID).
		Scan(&m.Followers, &m.TotalViews, &m.AverageViews, &m.Likes, &m.Comments,
			&m.Shares, &m.Saves, &m.EngagementRate, &m.ContentCount,
			&m.CampaignCount, &m.SuccessfulCount, &m.AverageResult,
			&m.Score, &m.Confidence, &m.SampleSize,
			&m.ScoreVersion, &params, &breakdown)
	if errors.Is(err, pgx.ErrNoRows) {
		return m, nil
	}
	if err != nil {
		return CreatorMetrics{}, err
	}
	_ = json.Unmarshal(params, &m.ScoreParams)
	_ = json.Unmarshal(breakdown, &m.ScoreBreakdown)
	return m, nil
}

// FindCandidates номзадҳоро барои матчинг мегирад.
//
// Танҳо эҷодкороне, ки ба marketplace ВОРИД шудаанд (профил доранд) ва
// дастрасанд. Фильтри ниҳоӣ ва тартиб дар matching.Engine аст — ин ҷо
// танҳо маълумот ҷамъ карда мешавад.
//
// FraudScore аз fraud_flags-и КУШОДА меояд: ҳар парчами кушода вазн
// дорад ва холи фиребро баланд мекунад.
func FindCandidates(ctx context.Context, tx Tx, cur money.Currency,
	maxPriceMinor int64, limit int) ([]matching.Candidate, error) {
	if limit <= 0 || limit > 500 {
		limit = 200
	}
	rows, err := tx.Query(ctx, `
		SELECT p.creator_id,
		       COALESCE(p.content_categories,'{}'),
		       COALESCE(p.audience_country,''),
		       COALESCE(p.audience_language,''),
		       COALESCE(p.price_minor,0),
		       COALESCE(p.currency,$1),
		       COALESCE(m.average_views,0),
		       COALESCE(m.engagement_rate,0),
		       COALESCE(m.creator_score,0),
		       COALESCE(m.score_confidence,0),
		       COALESCE(m.campaign_count,0),
		       COALESCE(m.successful_campaign_count,0),
		       COALESCE(m.average_campaign_result,0),
		       COALESCE(f.fraud_score,0)
		FROM creator_profiles p
		LEFT JOIN creator_metrics m ON m.creator_id = p.creator_id
		LEFT JOIN (
		    SELECT entity_id, LEAST(1.0, SUM(score)::float8) AS fraud_score
		    FROM fraud_flags
		    WHERE entity_type='creator' AND status='OPEN'
		    GROUP BY entity_id
		) f ON f.entity_id = p.creator_id
		WHERE p.available = TRUE
		  AND p.currency = $1
		  AND ($2 <= 0 OR p.price_minor <= $2)
		ORDER BY COALESCE(m.creator_score,0) DESC, p.creator_id ASC
		LIMIT $3`, string(cur), maxPriceMinor, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []matching.Candidate{}
	for rows.Next() {
		var cand matching.Candidate
		var price int64
		var curOut string
		if err := rows.Scan(&cand.CreatorID, &cand.Categories,
			&cand.AudienceCountry, &cand.AudienceLanguage, &price, &curOut,
			&cand.AverageViews, &cand.EngagementRate, &cand.CreatorScore,
			&cand.ScoreConfidence, &cand.CampaignCount,
			&cand.SuccessfulCampaigns, &cand.AverageCampaignResult,
			&cand.FraudScore); err != nil {
			continue
		}
		c, _ := money.ParseCurrency(curOut)
		cand.Price = money.Amount{Minor: money.Minor(price), Currency: c}
		cand.Available = true
		out = append(out, cand)
	}
	return out, rows.Err()
}

// CreatorWallet — тавозуни ҳамёни эҷодкор аз дафтари дукарата.
//
// Тавозун ҲЕҶ ГОҲ ҳамчун сутуни алоҳида нигоҳ дошта намешавад: он
// ҳамеша аз сабтҳо ҳисоб мешавад, то ҳеҷ гоҳ бо дафтар фарқ накунад.
type CreatorWallet struct {
	CreatorID string       `json:"creatorId"`
	Available money.Amount `json:"available"`
	Pending   money.Amount `json:"pending"`
}

// GetCreatorWallet тавозун ва маблағи дар роҳбударо бармегардонад.
func GetCreatorWallet(ctx context.Context, tx Tx, creatorID string,
	cur money.Currency) (CreatorWallet, error) {
	w := CreatorWallet{
		CreatorID: creatorID,
		Available: money.Amount{Currency: cur},
		Pending:   money.Amount{Currency: cur},
	}
	// ҲАМОН ҳисобе, ки payout ба он менависад — вагарна тавозун
	// ҳамеша сифр менамояд, ҳол он ки пул воқеан ҳаст.
	accID, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerUser, creatorID,
		ledger.PurposeWallet, cur)
	if err != nil {
		return CreatorWallet{}, err
	}
	bal, err := ledger.Balance(ctx, tx, accID)
	if err != nil {
		return CreatorWallet{}, err
	}
	// Ҳисоби бе ҳаракат асъор надорад — дар ин ҳолат асъори дархостшуда
	// нигоҳ дошта мешавад, вагарна ҳамён бо асъори холӣ бармегардад ва
	// client «0 » бе асъор нишон медиҳад.
	if bal.Currency != "" {
		w.Available = bal
	}

	// Дар роҳ: payout-ҳое, ки ҳанӯз ба ҳолати ниҳоӣ нарасидаанд.
	var pending int64
	if err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount_minor),0) FROM payout_orders
		WHERE creator_id=$1 AND currency=$2
		  AND status IN ('PENDING','PROCESSING','REQUIRES_ACTION')`,
		creatorID, string(cur)).Scan(&pending); err != nil {
		return CreatorWallet{}, err
	}
	w.Pending = money.Amount{Minor: money.Minor(pending), Currency: cur}
	return w, nil
}
