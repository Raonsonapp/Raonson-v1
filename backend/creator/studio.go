// Package creator маълумоти Creator Studio-ро ҷамъ мекунад.
//
// Ҳар рақам аз ҷадвалҳои ВОҚЕӢ меояд. Ҳеҷ рақам тахмин ё сохта
// намешавад: агар маълумот набошад, сифр бармегардад ва интерфейс
// инро возеҳ нишон медиҳад.
package creator

import (
	"context"
	"fmt"
	"sort"
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

// Window — давраи вақт.
type Window string

const (
	WindowToday Window = "today"
	Window7d    Window = "7d"
	Window30d   Window = "30d"
)

// bounds ҳудуди дақиқи давраро нисбат ба лаҳзаи додашуда медиҳад.
//
// Ҷамъбасти ҳафтагӣ ҳудуди ДАҚИҚ мехоҳад (душанбе то душанбе), на
// «7 рӯзи охир аз ҳозир». Бинобар ин ҳама ҳисоб дар як ҷо бо ду
// вақти возеҳ кор мекунад ва давраи номбаршуда танҳо онҳоро месозад.
func (w Window) bounds(now time.Time) (time.Time, time.Time) {
	switch w {
	case WindowToday:
		return now.AddDate(0, 0, -1), now
	case Window7d:
		return now.AddDate(0, 0, -7), now
	default:
		return now.AddDate(0, 0, -30), now
	}
}

// ParseWindow давраи дархостшударо тафтиш мекунад.
func ParseWindow(s string) Window {
	switch Window(s) {
	case WindowToday:
		return WindowToday
	case Window7d:
		return Window7d
	default:
		return Window30d
	}
}

// Overview — рақамҳои асосии эҷодкор.
type Overview struct {
	Window          string `json:"window"`
	Followers       int    `json:"followers"`
	FollowersGained int    `json:"followersGained"`
	Posts           int    `json:"posts"`
	Reels           int    `json:"reels"`
	Views           int    `json:"views"`
	Likes           int    `json:"likes"`
	Comments        int    `json:"comments"`
	Saves           int    `json:"saves"`
	Shares          int    `json:"shares"`
	ProfileVisits   int    `json:"profileVisits"`
	// EngagementRate 0..1 — (лайк+коммент+сейв)/биниш.
	EngagementRate float64 `json:"engagementRate"`
}

// GetOverview рақамҳои давраро ҷамъ мекунад.
//
// Ҳама дар ЯК дархост: ҳашт SELECT-и ҷудогона барои як экран
// исрофкорист ва бо афзоиши маълумот сустар мешавад.
func GetOverview(ctx context.Context, db DB, userID string, w Window) (Overview, error) {
	from, to := w.bounds(time.Now())
	return GetOverviewRange(ctx, db, userID, string(w), from, to)
}

// GetOverviewRange ҳамон ҳисоб, вале бо ҳудуди дақиқи вақт.
func GetOverviewRange(ctx context.Context, db DB, userID, label string,
	from, to time.Time) (Overview, error) {
	o := Overview{Window: label}

	err := db.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT COUNT(*) FROM follows WHERE following_id=$1),0),
		  COALESCE((SELECT COUNT(*) FROM follows
		            WHERE following_id=$1
		              AND created_at >= $2 AND created_at < $3),0),
		  COALESCE((SELECT COUNT(*) FROM posts
		            WHERE user_id=$1 AND COALESCE(archived,false)=FALSE
		              AND created_at >= $2 AND created_at < $3),0),
		  COALESCE((SELECT COUNT(*) FROM reels
		            WHERE user_id=$1
		              AND created_at >= $2 AND created_at < $3),0),
		  COALESCE((SELECT SUM(likes_count) FROM posts
		            WHERE user_id=$1 AND created_at >= $2 AND created_at < $3),0)
		  + COALESCE((SELECT SUM(likes_count) FROM reels
		            WHERE user_id=$1 AND created_at >= $2 AND created_at < $3),0),
		  COALESCE((SELECT SUM(comments_count) FROM posts
		            WHERE user_id=$1 AND created_at >= $2 AND created_at < $3),0)
		  + COALESCE((SELECT SUM(comments_count) FROM reels
		            WHERE user_id=$1 AND created_at >= $2 AND created_at < $3),0),
		  COALESCE((SELECT SUM(views_count) FROM reels
		            WHERE user_id=$1 AND created_at >= $2 AND created_at < $3),0)
		  + COALESCE((SELECT COUNT(*) FROM post_views pv
		            JOIN posts p ON p.id = pv.post_id
		            WHERE p.user_id=$1
		              AND pv.viewed_at >= $2 AND pv.viewed_at < $3),0),
		  COALESCE((SELECT COUNT(*) FROM post_saves ps
		            JOIN posts p ON p.id = ps.post_id
		            WHERE p.user_id=$1),0),
		  COALESCE((SELECT COUNT(*) FROM post_shares psh
		            JOIN posts p ON p.id = psh.post_id
		            WHERE p.user_id=$1),0)`,
		userID, from, to).Scan(&o.Followers, &o.FollowersGained, &o.Posts,
		&o.Reels, &o.Likes, &o.Comments, &o.Views, &o.Saves, &o.Shares)
	if err != nil {
		return Overview{}, fmt.Errorf("creator: overview: %w", err)
	}

	// Ташрифи профил — аз ҳодисаҳои лента, агар сабт шуда бошанд.
	db.QueryRow(ctx, `
		SELECT COUNT(*) FROM feed_events
		WHERE creator_id=$1 AND event='PROFILE_VIEW'
		  AND created_at >= $2 AND created_at < $3`,
		userID, from, to).Scan(&o.ProfileVisits)

	if o.Views > 0 {
		o.EngagementRate = round3(
			float64(o.Likes+o.Comments+o.Saves) / float64(o.Views))
	}
	return o, nil
}

// RecommendationStats — натиҷаи «Лентаи AI» барои эҷодкор.
//
// Ҳама аз feed_events меояд: ҳамон ҷадвале, ки лента менависад.
type RecommendationStats struct {
	Window      string `json:"window"`
	Impressions int    `json:"impressions"`
	Opens       int    `json:"opens"`
	Completions int    `json:"completions"`
	Likes       int    `json:"likes"`
	Saves       int    `json:"saves"`
	Shares      int    `json:"shares"`
	Follows     int    `json:"follows"`
	// CompletionRate 0..1 — аз оғози видео то анҷом.
	CompletionRate float64 `json:"completionRate"`
	// OpenRate 0..1 — аз намоиш то кушодан.
	OpenRate float64 `json:"openRate"`
}

// GetRecommendationStats натиҷаи тавсияро ҷамъ мекунад.
func GetRecommendationStats(ctx context.Context, db DB, userID string,
	w Window) (RecommendationStats, error) {
	from, to := w.bounds(time.Now())
	return GetRecommendationStatsRange(ctx, db, userID, string(w), from, to)
}

// GetRecommendationStatsRange ҳамон ҳисоб бо ҳудуди дақиқи вақт.
func GetRecommendationStatsRange(ctx context.Context, db DB, userID,
	label string, from, to time.Time) (RecommendationStats, error) {
	s := RecommendationStats{Window: label}

	var starts int
	err := db.QueryRow(ctx, `
		SELECT
		  COUNT(*) FILTER (WHERE event='FEED_IMPRESSION'),
		  COUNT(*) FILTER (WHERE event='POST_OPEN'),
		  COUNT(*) FILTER (WHERE event='VIDEO_25_PERCENT'),
		  COUNT(*) FILTER (WHERE event='VIDEO_COMPLETE'),
		  COUNT(*) FILTER (WHERE event='LIKE'),
		  COUNT(*) FILTER (WHERE event='SAVE'),
		  COUNT(*) FILTER (WHERE event='SHARE'),
		  COUNT(*) FILTER (WHERE event='FOLLOW')
		FROM feed_events
		WHERE creator_id=$1 AND created_at >= $2 AND created_at < $3`,
		userID, from, to).Scan(&s.Impressions, &s.Opens, &starts, &s.Completions,
		&s.Likes, &s.Saves, &s.Shares, &s.Follows)
	if err != nil {
		return RecommendationStats{}, fmt.Errorf("creator: rec stats: %w", err)
	}

	// Фоизи анҷом аз ОҒОЗи видео ҳисоб мешавад, на аз намоиш: касе
	// ки видеоро тамоман нақушод, дар ин ҳисоб ҷой надорад.
	if starts > 0 {
		s.CompletionRate = round3(float64(s.Completions) / float64(starts))
	}
	if s.Impressions > 0 {
		s.OpenRate = round3(float64(s.Opens) / float64(s.Impressions))
	}
	return s, nil
}

// TopContent — мӯҳтавои беҳтарин аз рӯи тавсия.
type TopContent struct {
	ContentType string `json:"contentType"`
	ContentID   string `json:"contentId"`
	Caption     string `json:"caption"`
	Thumbnail   string `json:"thumbnail"`
	Impressions int    `json:"impressions"`
	Completions int    `json:"completions"`
	Follows     int    `json:"follows"`
	Views       int    `json:"views"`
	Topic       string `json:"topic,omitempty"`
}

// GetTopRecommended мӯҳтавои беҳтарини тавсияшударо мегирад.
func GetTopRecommended(ctx context.Context, db DB, userID string,
	w Window, limit int) ([]TopContent, error) {
	from, to := w.bounds(time.Now())
	return GetTopRecommendedRange(ctx, db, userID, from, to, limit)
}

// GetTopRecommendedRange ҳамон интихоб бо ҳудуди дақиқи вақт.
func GetTopRecommendedRange(ctx context.Context, db DB, userID string,
	from, to time.Time, limit int) ([]TopContent, error) {
	if limit <= 0 || limit > 20 {
		limit = 5
	}
	rows, err := db.Query(ctx, `
		WITH ev AS (
		  SELECT content_type, content_id,
		         COUNT(*) FILTER (WHERE event='FEED_IMPRESSION') AS impressions,
		         COUNT(*) FILTER (WHERE event='VIDEO_COMPLETE')  AS completions,
		         COUNT(*) FILTER (WHERE event='FOLLOW')          AS follows
		  FROM feed_events
		  WHERE creator_id=$1 AND content_id <> ''
		    AND created_at >= $2 AND created_at < $3
		  GROUP BY content_type, content_id
		)
		SELECT ev.content_type, ev.content_id,
		       COALESCE(p.caption, r.caption, ''),
		       COALESCE(r.thumbnail_url, ''),
		       ev.impressions, ev.completions, ev.follows,
		       COALESCE(r.views_count, 0),
		       COALESCE((SELECT ct.topic_slug FROM content_topics ct
		                 WHERE ct.content_type = ev.content_type
		                   AND ct.content_id = ev.content_id
		                 ORDER BY ct.weight DESC LIMIT 1), '')
		FROM ev
		LEFT JOIN posts p ON p.id = ev.content_id AND ev.content_type='post'
		LEFT JOIN reels r ON r.id = ev.content_id AND ev.content_type='reel'
		-- Мӯҳтавои нестшуда набояд дар рӯйхат монад.
		WHERE p.id IS NOT NULL OR r.id IS NOT NULL
		ORDER BY ev.impressions DESC, ev.completions DESC
		LIMIT $4`, userID, from, to, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []TopContent{}
	for rows.Next() {
		var t TopContent
		if err := rows.Scan(&t.ContentType, &t.ContentID, &t.Caption,
			&t.Thumbnail, &t.Impressions, &t.Completions, &t.Follows,
			&t.Views, &t.Topic); err != nil {
			continue
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// TopicPerformance — натиҷаи як мавзӯи эҷодкор.
type TopicPerformance struct {
	Topic      string  `json:"topic"`
	Content    int     `json:"contentCount"`
	Views      int     `json:"views"`
	Engagement int     `json:"engagement"`
	PerContent float64 `json:"engagementPerContent"`
}

// GetTopicPerformance нишон медиҳад, кадом мавзӯъ беҳтар кор мекунад.
//
// Танҳо мавзӯъҳое, ки ҳадди ақал 2 мӯҳтаво доранд: як пости
// тасодуфан вирусӣ набояд «беҳтарин мавзӯи шумо» эълон шавад.
func GetTopicPerformance(ctx context.Context, db DB, userID string,
	w Window) ([]TopicPerformance, error) {
	from, to := w.bounds(time.Now())
	return GetTopicPerformanceRange(ctx, db, userID, from, to)
}

// GetTopicPerformanceRange ҳамон ҳисоб бо ҳудуди дақиқи вақт.
func GetTopicPerformanceRange(ctx context.Context, db DB, userID string,
	from, to time.Time) ([]TopicPerformance, error) {
	rows, err := db.Query(ctx, `
		WITH mine AS (
		  SELECT 'post' AS ct, p.id, p.likes_count, p.comments_count,
		         (SELECT COUNT(*) FROM post_views v WHERE v.post_id=p.id) AS views
		  FROM posts p
		  WHERE p.user_id=$1 AND COALESCE(p.archived,false)=FALSE
		    AND p.created_at >= $2 AND p.created_at < $3
		  UNION ALL
		  SELECT 'reel', r.id, r.likes_count, r.comments_count, r.views_count
		  FROM reels r
		  WHERE r.user_id=$1 AND r.created_at >= $2 AND r.created_at < $3
		)
		SELECT ct.topic_slug,
		       COUNT(*) AS content_count,
		       COALESCE(SUM(m.views),0) AS views,
		       COALESCE(SUM(m.likes_count + m.comments_count),0) AS engagement
		FROM mine m
		JOIN content_topics ct
		     ON ct.content_type = m.ct AND ct.content_id = m.id
		GROUP BY ct.topic_slug
		HAVING COUNT(*) >= 2
		ORDER BY engagement DESC`, userID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []TopicPerformance{}
	for rows.Next() {
		var t TopicPerformance
		if err := rows.Scan(&t.Topic, &t.Content, &t.Views, &t.Engagement); err != nil {
			continue
		}
		if t.Content > 0 {
			t.PerContent = round3(float64(t.Engagement) / float64(t.Content))
		}
		out = append(out, t)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	sort.SliceStable(out, func(i, j int) bool {
		if out[i].PerContent != out[j].PerContent {
			return out[i].PerContent > out[j].PerContent
		}
		return out[i].Topic < out[j].Topic
	})
	return out, nil
}

func round3(v float64) float64 {
	return float64(int(v*1000+0.5)) / 1000
}
