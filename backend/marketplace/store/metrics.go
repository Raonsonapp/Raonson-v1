package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/score"
)

// CollectCreatorMetrics метрикаро аз ҷадвалҳои ВОҚЕИИ Raonson ҷамъ мекунад.
//
// Ҳеҷ рақам ин ҷо тахмин ё сохта намешавад. Агар манбаи маълумот
// вуҷуд надошта бошад (масалан ҷадвали share), он сифр мемонад —
// сифри ростгӯ аз рақами сохта беҳтар аст, зеро score.Compute
// боварии холро аз ҳаҷми маълумот ҳисоб мекунад.
func CollectCreatorMetrics(ctx context.Context, tx Tx, creatorID string) (score.Metrics, error) {
	var m score.Metrics

	// Пайравон — аз ҷадвали follows, на аз counter-и кэшшуда.
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM follows WHERE following_id=$1`, creatorID).
		Scan(&m.Followers); err != nil {
		return m, fmt.Errorf("store: пайравон: %w", err)
	}

	// Мӯҳтаво: постҳо + рилсҳо.
	var postCount, reelCount int64
	var postLikes, postComments, reelLikes, reelComments, reelViews int64
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*), COALESCE(SUM(likes_count),0), COALESCE(SUM(comments_count),0)
		FROM posts WHERE user_id=$1 AND COALESCE(archived,FALSE)=FALSE`, creatorID).
		Scan(&postCount, &postLikes, &postComments); err != nil {
		return m, fmt.Errorf("store: постҳо: %w", err)
	}
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*), COALESCE(SUM(likes_count),0), COALESCE(SUM(comments_count),0),
		       COALESCE(SUM(views_count),0)
		FROM reels WHERE user_id=$1`, creatorID).
		Scan(&reelCount, &reelLikes, &reelComments, &reelViews); err != nil {
		return m, fmt.Errorf("store: рилсҳо: %w", err)
	}

	// Бинишҳои пост — аз ҷадвали воқеии post_views.
	var postViews int64
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM post_views v
		JOIN posts p ON p.id = v.post_id
		WHERE p.user_id=$1`, creatorID).Scan(&postViews); err != nil {
		return m, fmt.Errorf("store: бинишҳо: %w", err)
	}

	// Захираҳо — post_saves.
	var saves int64
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM post_saves s
		JOIN posts p ON p.id = s.post_id
		WHERE p.user_id=$1`, creatorID).Scan(&saves); err != nil {
		return m, fmt.Errorf("store: захираҳо: %w", err)
	}

	m.ContentCount = postCount + reelCount
	m.Likes = postLikes + reelLikes
	m.Comments = postComments + reelComments
	m.TotalViews = postViews + reelViews
	m.Saves = saves
	// Shares: Raonson ҳанӯз ҷадвали мубодилаи доимӣ надорад. Ба ҷои
	// рақами сохта сифр мемонад.
	m.Shares = 0
	if m.ContentCount > 0 {
		m.AverageViews = m.TotalViews / m.ContentCount
	}

	// Таърихи кампанияҳо — аз campaign_creators.
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*), COUNT(*) FILTER (WHERE status='APPROVED')
		FROM campaign_creators
		WHERE creator_id=$1 AND status NOT IN ('INVITED','REJECTED','EXPIRED')`,
		creatorID).Scan(&m.CampaignCount, &m.SuccessfulCampaigns); err != nil {
		return m, fmt.Errorf("store: кампанияҳо: %w", err)
	}
	if m.CampaignCount > 0 {
		m.AverageCampaignResult = float64(m.SuccessfulCampaigns) / float64(m.CampaignCount)
	}
	return m, nil
}

// CreatorsNeedingMetrics эҷодкороне, ки метрикаашон кӯҳна шудааст.
//
// Танҳо онҳое, ки ба marketplace ворид шудаанд: ҳисоби метрика барои
// ҳар корбари Raonson бефоида ва гарон аст.
func CreatorsNeedingMetrics(ctx context.Context, tx Tx, staleMinutes, limit int) ([]string, error) {
	rows, err := tx.Query(ctx, `
		SELECT p.creator_id
		FROM creator_profiles p
		LEFT JOIN creator_metrics m ON m.creator_id = p.creator_id
		WHERE m.computed_at IS NULL
		   OR m.computed_at < NOW() - ($1 || ' minutes')::interval
		ORDER BY COALESCE(m.computed_at, TIMESTAMPTZ '-infinity') ASC
		LIMIT $2`, staleMinutes, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			continue
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// RefreshCreatorMetrics метрикаро ҷамъ мекунад ва хол месозад.
func RefreshCreatorMetrics(ctx context.Context, tx Tx, creatorID string) (CreatorMetrics, error) {
	m, err := CollectCreatorMetrics(ctx, tx, creatorID)
	if err != nil {
		return CreatorMetrics{}, err
	}
	return SaveCreatorMetrics(ctx, tx, creatorID, m)
}

// AggregateCampaignMetrics натиҷаи ВОҚЕИИ мӯҳтавои кампанияро ҷамъ мекунад.
//
// Танҳо мӯҳтавои воқеан пайвастшуда (content_id) ҳисоб мешавад. Агар
// эҷодкор ҳанӯз чизе насупорида бошад, сатри ӯ сифр мемонад — на тахмин.
func AggregateCampaignMetrics(ctx context.Context, tx Tx, campaignID string) error {
	rows, err := tx.Query(ctx, `
		SELECT creator_id, content_id, content_type
		FROM campaign_creators
		WHERE campaign_id=$1 AND content_id <> ''`, campaignID)
	if err != nil {
		return err
	}
	type item struct{ creator, content, ctype string }
	items := []item{}
	for rows.Next() {
		var it item
		if err := rows.Scan(&it.creator, &it.content, &it.ctype); err != nil {
			continue
		}
		items = append(items, it)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return err
	}

	for _, it := range items {
		var views, likes, comments, saves int64
		switch it.ctype {
		case "post":
			err = tx.QueryRow(ctx, `
				SELECT COALESCE(p.likes_count,0), COALESCE(p.comments_count,0),
				       (SELECT COUNT(*) FROM post_views v WHERE v.post_id=p.id),
				       (SELECT COUNT(*) FROM post_saves s WHERE s.post_id=p.id)
				FROM posts p WHERE p.id=$1`, it.content).
				Scan(&likes, &comments, &views, &saves)
		case "reel":
			err = tx.QueryRow(ctx, `
				SELECT COALESCE(likes_count,0), COALESCE(comments_count,0),
				       COALESCE(views_count,0), 0
				FROM reels WHERE id=$1`, it.content).
				Scan(&likes, &comments, &views, &saves)
		default:
			// Стори ва навъҳои дигар ҳанӯз метрикаи доимӣ надоранд.
			continue
		}
		if errors.Is(err, pgx.ErrNoRows) {
			// Мӯҳтаво нест шуд — сатр даст нахӯрда мемонад, то
			// рақамҳои қаблӣ гум нашаванд.
			continue
		}
		if err != nil {
			return err
		}

		if _, err := tx.Exec(ctx, `
			INSERT INTO campaign_metrics
			  (campaign_id, creator_id, impressions, views, likes, comments, saves, updated_at)
			VALUES ($1,$2,$3,$3,$4,$5,$6,NOW())
			ON CONFLICT (campaign_id, creator_id) DO UPDATE SET
			  impressions = EXCLUDED.impressions,
			  views       = EXCLUDED.views,
			  likes       = EXCLUDED.likes,
			  comments    = EXCLUDED.comments,
			  saves       = EXCLUDED.saves,
			  updated_at  = NOW()`,
			campaignID, it.creator, views, likes, comments, saves); err != nil {
			return err
		}
	}
	return nil
}

// CampaignMetricsRow — сатри ҷамъбасти кампания.
type CampaignMetricsRow struct {
	CreatorID   string `json:"creatorId"`
	Impressions int64  `json:"impressions"`
	Views       int64  `json:"views"`
	Likes       int64  `json:"likes"`
	Comments    int64  `json:"comments"`
	Saves       int64  `json:"saves"`
}

// GetCampaignMetrics натиҷаи кампанияро бармегардонад.
func GetCampaignMetrics(ctx context.Context, tx Tx, campaignID string) ([]CampaignMetricsRow, error) {
	rows, err := tx.Query(ctx, `
		SELECT creator_id, impressions, views, likes, comments, saves
		FROM campaign_metrics WHERE campaign_id=$1
		ORDER BY creator_id`, campaignID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CampaignMetricsRow{}
	for rows.Next() {
		var r CampaignMetricsRow
		if err := rows.Scan(&r.CreatorID, &r.Impressions, &r.Views,
			&r.Likes, &r.Comments, &r.Saves); err != nil {
			continue
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
