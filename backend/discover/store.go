package discover

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// DB — ҳадди ақали интерфейси лозим.
type DB interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// ── Ҳисоб ва сабти тренд ─────────────────────────────────────────

// RecomputeTopicTrends трендҳои мавзӯъро аз нав ҳисоб мекунад.
//
// Ду давраи ҲАМВАЗН муқоиса мешаванд: 7 рӯзи охир бар зидди 7 рӯзи
// пеш аз он. Муқоисаи давраҳои нобаробар фоизи бемаъно медиҳад.
func RecomputeTopicTrends(ctx context.Context, db DB) (int, error) {
	rows, err := db.Query(ctx, `
		SELECT t.slug,
		       COUNT(*) FILTER (
		         WHERE c.created_at > NOW() - INTERVAL '7 days') AS cur,
		       COUNT(*) FILTER (
		         WHERE c.created_at > NOW() - INTERVAL '14 days'
		           AND c.created_at <= NOW() - INTERVAL '7 days') AS prev
		FROM feed_topics t
		LEFT JOIN content_topics ct ON ct.topic_slug = t.slug
		LEFT JOIN LATERAL (
		  SELECT created_at, user_id FROM posts WHERE id = ct.content_id
		                                          AND ct.content_type='post'
		  UNION ALL
		  SELECT created_at, user_id FROM reels WHERE id = ct.content_id
		                                          AND ct.content_type='reel'
		) c ON TRUE
		LEFT JOIN users u ON u.id = c.user_id
		WHERE t.active = TRUE AND (u.id IS NULL OR u.banned = FALSE)
		GROUP BY t.slug`)
	if err != nil {
		return 0, err
	}
	type row struct {
		slug      string
		cur, prev int
	}
	list := []row{}
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.slug, &r.cur, &r.prev); err == nil {
			list = append(list, r)
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}

	// Ҳама сатрҳо ҲАМОН лаҳзаи ҳисобро мегиранд, то як «акс» созанд.
	now := time.Now().UTC().Truncate(time.Minute)
	saved := 0
	for _, r := range list {
		tr := ComputeTrend("topic", r.slug, r.cur, r.prev)
		if _, err := db.Exec(ctx, `
			INSERT INTO trend_snapshots(kind, slug, current_count, previous_count,
			                            change_pct, significant, computed_at)
			VALUES ('topic',$1,$2,$3,$4,$5,$6)
			ON CONFLICT (kind, slug, computed_at) DO UPDATE SET
			  current_count = EXCLUDED.current_count,
			  previous_count = EXCLUDED.previous_count,
			  change_pct = EXCLUDED.change_pct,
			  significant = EXCLUDED.significant`,
			r.slug, r.cur, r.prev, tr.ChangePct, tr.Significant, now); err != nil {
			return saved, err
		}
		saved++
	}
	return saved, nil
}

// GetTrends трендҳои ОХИРИНи маънодорро мегирад.
func GetTrends(ctx context.Context, db DB, limit int) ([]Trend, error) {
	if limit <= 0 || limit > 50 {
		limit = 12
	}
	rows, err := db.Query(ctx, `
		SELECT slug, kind, current_count, previous_count, change_pct
		FROM trend_snapshots
		WHERE kind='topic' AND significant = TRUE
		  AND computed_at = (SELECT MAX(computed_at) FROM trend_snapshots
		                     WHERE kind='topic')
		ORDER BY COALESCE(change_pct, 0) DESC, current_count DESC
		LIMIT $1`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Trend{}
	for rows.Next() {
		var t Trend
		if err := rows.Scan(&t.Slug, &t.Kind, &t.Current, &t.Previous,
			&t.ChangePct); err != nil {
			continue
		}
		t.Significant = true
		out = append(out, t)
	}
	return out, rows.Err()
}

// ── Эҷодкорони боло раванда ──────────────────────────────────────

// RecomputeRisingCreators холи эҷодкоронро аз нав ҳисоб мекунад.
func RecomputeRisingCreators(ctx context.Context, db DB) (int, error) {
	rows, err := db.Query(ctx, `
		WITH ev AS (
		  SELECT creator_id,
		         COUNT(*) FILTER (WHERE event='FOLLOW')           AS follows,
		         COUNT(*) FILTER (WHERE event='FEED_IMPRESSION')  AS impressions,
		         COUNT(*) FILTER (WHERE event='VIDEO_COMPLETE')   AS completions,
		         COUNT(*) FILTER (WHERE event='SAVE')             AS saves,
		         COUNT(*) FILTER (WHERE event='SHARE')            AS shares
		  FROM feed_events
		  WHERE creator_id <> '' AND created_at > NOW() - INTERVAL '14 days'
		  GROUP BY creator_id
		),
		content AS (
		  SELECT user_id, COUNT(*) AS n FROM (
		    SELECT user_id FROM posts
		    WHERE created_at > NOW() - INTERVAL '14 days'
		      AND COALESCE(archived,false)=FALSE
		    UNION ALL
		    SELECT user_id FROM reels
		    WHERE created_at > NOW() - INTERVAL '14 days'
		  ) t GROUP BY user_id
		)
		SELECT u.id, COALESCE(ev.follows,0), COALESCE(ev.impressions,0),
		       COALESCE(ev.completions,0), COALESCE(ev.saves,0),
		       COALESCE(ev.shares,0), COALESCE(content.n,0)
		FROM users u
		LEFT JOIN ev ON ev.creator_id = u.id
		JOIN content ON content.user_id = u.id
		WHERE u.banned = FALSE AND COALESCE(u.is_private,false) = FALSE`)
	if err != nil {
		return 0, err
	}
	type row struct {
		id string
		s  RisingSignals
	}
	list := []row{}
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.id, &r.s.FollowersGained, &r.s.Impressions,
			&r.s.Completions, &r.s.Saves, &r.s.Shares,
			&r.s.ContentCount); err == nil {
			list = append(list, r)
		}
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return 0, err
	}

	saved := 0
	for _, r := range list {
		score := ComputeRisingScore(r.s)
		if score <= 0 {
			// Холи сифр сабт намешавад — рӯйхат бо сатрҳои бемаъно
			// пур намешавад.
			db.Exec(ctx, `DELETE FROM creator_rising WHERE creator_id=$1`, r.id)
			continue
		}
		if _, err := db.Exec(ctx, `
			INSERT INTO creator_rising(creator_id, followers_gained, impressions,
			                           completions, saves, shares, content_count,
			                           score, computed_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
			ON CONFLICT (creator_id) DO UPDATE SET
			  followers_gained = EXCLUDED.followers_gained,
			  impressions = EXCLUDED.impressions,
			  completions = EXCLUDED.completions,
			  saves = EXCLUDED.saves,
			  shares = EXCLUDED.shares,
			  content_count = EXCLUDED.content_count,
			  score = EXCLUDED.score,
			  computed_at = NOW()`,
			r.id, r.s.FollowersGained, r.s.Impressions, r.s.Completions,
			r.s.Saves, r.s.Shares, r.s.ContentCount, score); err != nil {
			return saved, err
		}
		saved++
	}
	return saved, nil
}

// RisingCreator — эҷодкор дар рӯйхати «боло раванда».
type RisingCreator struct {
	UserID    string  `json:"userId"`
	Username  string  `json:"username"`
	Avatar    string  `json:"avatar"`
	Bio       string  `json:"bio"`
	Verified  bool    `json:"verified"`
	Followers int     `json:"followersCount"`
	Score     float64 `json:"risingScore"`
	// Reason — рамзи сабаб; матн дар client тарҷума мешавад.
	Reason string `json:"reason"`
}

// GetRisingCreators эҷодкорони боло равандаро мегирад.
//
// Корбарони блокшуда, хомӯшшуда ва аллакай обунашуда берун мемонанд.
func GetRisingCreators(ctx context.Context, db DB, viewerID string,
	limit int) ([]RisingCreator, error) {
	if limit <= 0 || limit > 30 {
		limit = 10
	}
	rows, err := db.Query(ctx, `
		SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.bio,''),
		       COALESCE(u.verified,false), COALESCE(u.followers_count,0),
		       cr.score, cr.followers_gained, cr.saves, cr.shares
		FROM creator_rising cr
		JOIN users u ON u.id = cr.creator_id
		WHERE u.banned = FALSE
		  AND COALESCE(u.is_private,false) = FALSE
		  AND u.id <> $1
		  AND NOT EXISTS (SELECT 1 FROM follows f
		        WHERE f.follower_id=$1 AND f.following_id=u.id)
		  AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		           OR (b.blocker_id=u.id AND b.blocked_id=$1))
		  AND NOT EXISTS (SELECT 1 FROM muted_users mu
		        WHERE mu.user_id=$1 AND mu.muted_id=u.id)
		  -- Холи кӯҳна ҷои худро медиҳад.
		  AND cr.computed_at > NOW() - INTERVAL '7 days'
		ORDER BY cr.score DESC, u.id ASC
		LIMIT $2`, viewerID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []RisingCreator{}
	for rows.Next() {
		var c RisingCreator
		var gained, saves, shares int
		if err := rows.Scan(&c.UserID, &c.Username, &c.Avatar, &c.Bio,
			&c.Verified, &c.Followers, &c.Score, &gained, &saves,
			&shares); err != nil {
			continue
		}
		// Сабаб аз сигнали ВОҚЕАН қавитарин меояд.
		switch {
		case gained > 0:
			c.Reason = "newFollowers"
		case saves > 0:
			c.Reason = "saved"
		case shares > 0:
			c.Reason = "shared"
		default:
			c.Reason = "growing"
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
