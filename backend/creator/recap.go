package creator

import (
	"context"
	"encoding/json"
	"time"
)

// MinRecapActivity — ҳадди ақали фаъолият барои ҷамъбаст.
//
// Бе ин, корбари ғайрифаъол ҷамъбасти пур аз сифр мегирифт — ин ҳам
// бефоида аст ва ҳам ба сарзаниш монанд аст. Дар ин ҳолат ҷамъбаст
// «маълумот кофӣ нест» мегӯяд.
const MinRecapActivity = 5

// ViewerRecap — «Ҳафтаи шумо дар Raonson».
//
// Ҳама рақам аз feed_events ва ҷадвалҳои воқеӣ меояд.
type ViewerRecap struct {
	WeekStart          string `json:"weekStart"`
	HasEnoughData      bool   `json:"hasEnoughData"`
	ReelsWatched       int    `json:"reelsWatched"`
	PostsViewed        int    `json:"postsViewed"`
	CreatorsDiscovered int    `json:"creatorsDiscovered"`
	Followed           int    `json:"followed"`
	Liked              int    `json:"liked"`
	Saved              int    `json:"saved"`
	Shared             int    `json:"shared"`
	// TopTopic — мавзӯе, ки корбар бо он бештар ҳамкорӣ кард. Холӣ
	// вақте маълум нест — тахмин намезанем.
	TopTopic string `json:"topTopic,omitempty"`
	// Номи мавзӯъ бо се забон: client slug-и техникиро нишон надиҳад.
	TopTopicName *TopicName `json:"topTopicName,omitempty"`
}

// TopicName — номи мавзӯъ бо забонҳои барнома.
type TopicName struct {
	TJ string `json:"tj"`
	RU string `json:"ru"`
	EN string `json:"en"`
}

// topicName номи мавзӯъро аз ҷадвал мегирад.
//
// Агар мавзӯъ ёфт нашуд, номҳо холӣ мемонанд ва client slug-ро
// истифода мебарад — беҳтар аз ном ихтироъ кардан.
func topicName(ctx context.Context, db DB, slug string) *TopicName {
	if slug == "" {
		return nil
	}
	var n TopicName
	db.QueryRow(ctx, `
		SELECT name_tj, name_ru, name_en FROM feed_topics WHERE slug=$1`,
		slug).Scan(&n.TJ, &n.RU, &n.EN)
	if n.TJ == "" && n.RU == "" && n.EN == "" {
		return nil
	}
	return &n
}

// BuildViewerRecap ҷамъбасти ҳафтаи корбарро месозад.
func BuildViewerRecap(ctx context.Context, db DB, userID string,
	weekStart time.Time) (ViewerRecap, error) {
	r := ViewerRecap{WeekStart: weekStart.Format("2006-01-02")}
	weekEnd := weekStart.AddDate(0, 0, 7)

	err := db.QueryRow(ctx, `
		SELECT
		  COUNT(*) FILTER (WHERE event='VIDEO_COMPLETE'),
		  COUNT(*) FILTER (WHERE event='POST_OPEN'),
		  COUNT(DISTINCT creator_id) FILTER (
		    WHERE creator_id <> '' AND event IN ('POST_OPEN','VIDEO_COMPLETE')),
		  COUNT(*) FILTER (WHERE event='FOLLOW'),
		  COUNT(*) FILTER (WHERE event='LIKE'),
		  COUNT(*) FILTER (WHERE event='SAVE'),
		  COUNT(*) FILTER (WHERE event='SHARE')
		FROM feed_events
		WHERE user_id=$1 AND created_at >= $2 AND created_at < $3`,
		userID, weekStart, weekEnd).
		Scan(&r.ReelsWatched, &r.PostsViewed, &r.CreatorsDiscovered,
			&r.Followed, &r.Liked, &r.Saved, &r.Shared)
	if err != nil {
		return ViewerRecap{}, err
	}

	total := r.ReelsWatched + r.PostsViewed + r.Liked + r.Saved + r.Shared
	r.HasEnoughData = total >= MinRecapActivity
	if !r.HasEnoughData {
		return r, nil
	}

	// Мавзӯи маҳбуб — аз мӯҳтавое, ки корбар бо он ҳамкорӣ кард.
	var topic string
	err = db.QueryRow(ctx, `
		SELECT ct.topic_slug
		FROM feed_events e
		JOIN content_topics ct
		     ON ct.content_type = e.content_type AND ct.content_id = e.content_id
		WHERE e.user_id=$1 AND e.created_at >= $2 AND e.created_at < $3
		  AND e.event IN ('VIDEO_COMPLETE','LIKE','SAVE','SHARE')
		GROUP BY ct.topic_slug
		ORDER BY COUNT(*) DESC, ct.topic_slug ASC
		LIMIT 1`, userID, weekStart, weekEnd).Scan(&topic)
	if err == nil {
		r.TopTopic = topic
		r.TopTopicName = topicName(ctx, db, topic)
	}
	return r, nil
}

// CreatorRecap — «Ҳафтаи эҷодкории шумо».
type CreatorRecap struct {
	WeekStart      string              `json:"weekStart"`
	HasEnoughData  bool                `json:"hasEnoughData"`
	Overview       Overview            `json:"overview"`
	Recommendation RecommendationStats `json:"recommendation"`
	TopContent     []TopContent        `json:"topContent"`
	TopTopic       string              `json:"topTopic,omitempty"`
	TopTopicName   *TopicName          `json:"topTopicName,omitempty"`
	Insights       []Insight           `json:"insights"`
}

// BuildCreatorRecap ҷамъбасти ҳафтаи эҷодкорро месозад.
//
// Мантиқи таҳлил такрор НАМЕШАВАД: ҳамон функсияҳои Creator Studio
// истифода мешаванд, танҳо бо давраи ҳафта.
func BuildCreatorRecap(ctx context.Context, db DB, userID string,
	weekStart time.Time) (CreatorRecap, error) {
	r := CreatorRecap{
		WeekStart:  weekStart.Format("2006-01-02"),
		TopContent: []TopContent{},
		Insights:   []Insight{},
	}
	weekEnd := weekStart.AddDate(0, 0, 7)

	ov, err := GetOverviewRange(ctx, db, userID, "week", weekStart, weekEnd)
	if err != nil {
		return CreatorRecap{}, err
	}
	r.Overview = ov

	rec, err := GetRecommendationStatsRange(ctx, db, userID, "week",
		weekStart, weekEnd)
	if err != nil {
		return CreatorRecap{}, err
	}
	r.Recommendation = rec

	// Эҷодкоре, ки чизе нашр накард ва ҳеҷ намоиш нагирифт, ҷамъбасти
	// холӣ намегирад.
	r.HasEnoughData = ov.Posts+ov.Reels > 0 || rec.Impressions > 0
	if !r.HasEnoughData {
		return r, nil
	}

	if top, err := GetTopRecommendedRange(ctx, db, userID,
		weekStart, weekEnd, 3); err == nil {
		r.TopContent = top
	}

	topics, err := GetTopicPerformanceRange(ctx, db, userID, weekStart, weekEnd)
	if err != nil {
		topics = []TopicPerformance{}
	}
	if len(topics) > 0 {
		r.TopTopic = topics[0].Topic
		r.TopTopicName = topicName(ctx, db, r.TopTopic)
	}

	// Мушоҳидаҳо аз рақамҳои ҲАМИН ҳафта — ҳамон қоидаҳои Creator
	// Studio, бе дархости иловагӣ.
	r.Insights = insightsFrom(ov, rec, topics, "week")
	return r, nil
}

// ── Кэши ҷамъбаст ────────────────────────────────────────────────

// WeekStart оғози ҳафтаи (душанбе) додашударо бармегардонад.
//
// Ҳамеша UTC: вагарна корбарони минтақаҳои гуногун ҷамъбасти
// «ҳафтаи гуногун» мегирифтанд ва кэш номувофиқ мешуд.
func WeekStart(t time.Time) time.Time {
	t = t.UTC()
	// Дар Go якшанбе 0 аст; мо душанберо оғоз мешуморем.
	offset := (int(t.Weekday()) + 6) % 7
	d := t.AddDate(0, 0, -offset)
	return time.Date(d.Year(), d.Month(), d.Day(), 0, 0, 0, 0, time.UTC)
}

// SaveRecap ҷамъбастро дар ҷадвал нигоҳ медорад.
//
// Ҳисоби ҳафта гарон аст ва набояд дар ҳар кушодани экран такрор
// шавад; ҷамъбасти ҳафтаи гузашта дигар тағйир намеёбад.
func SaveRecap(ctx context.Context, db DB, userID, kind string,
	weekStart time.Time, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	_, err = db.Exec(ctx, `
		INSERT INTO weekly_recaps(user_id, week_start, kind, payload)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (user_id, week_start, kind) DO UPDATE SET
		  payload = EXCLUDED.payload`,
		userID, weekStart, kind, string(b))
	return err
}

// LoadRecap ҷамъбасти захирашударо мегирад.
//
// found=false маънои «ҳанӯз ҳисоб нашудааст»-ро дорад, на хато.
func LoadRecap(ctx context.Context, db DB, userID, kind string,
	weekStart time.Time, out any) (bool, error) {
	var raw []byte
	err := db.QueryRow(ctx, `
		SELECT payload FROM weekly_recaps
		WHERE user_id=$1 AND week_start=$2 AND kind=$3`,
		userID, weekStart, kind).Scan(&raw)
	if err != nil {
		return false, nil
	}
	if err := json.Unmarshal(raw, out); err != nil {
		return false, err
	}
	return true, nil
}
