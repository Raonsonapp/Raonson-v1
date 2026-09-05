package creator

// Дастовардҳо ва зинаҳои эҷодкор.
//
// Ҳама аз маълумоти ВОҚЕИИ ҷадвалҳо ҳисоб мешавад. Client ҳеҷ гоҳ
// намегӯяд, ки кадом дастовардро гирифт — вагарна ҳар кас метавонист
// ҳар нишонро талаб кунад.
//
// Ҳадафи зинаҳо — оина, на бозӣ: онҳо танҳо кори анҷомшударо нишон
// медиҳанд. Ҳеҷ зина чизеро қулф намекунад ва ҳеҷ огоҳии «зинаатонро
// гум мекунед» вуҷуд надорад.

import (
	"context"
	"sort"
	"time"
)

// CreatorStats — рақамҳои умрӣ (на давравӣ), ки асоси дастоварданд.
type CreatorStats struct {
	Followers int `json:"followers"`
	Posts     int `json:"posts"`
	Reels     int `json:"reels"`
	Views     int `json:"views"`
	Likes     int `json:"likes"`
	// ActiveWeeks — шумораи ҳафтаҳои гуногун бо нашри мӯҳтаво.
	ActiveWeeks int `json:"activeWeeks"`
}

// GetCreatorStats рақамҳои умрии эҷодкорро ҷамъ мекунад.
func GetCreatorStats(ctx context.Context, db DB, userID string) (CreatorStats, error) {
	var s CreatorStats
	err := db.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT COUNT(*) FROM follows WHERE following_id=$1),0),
		  COALESCE((SELECT COUNT(*) FROM posts
		            WHERE user_id=$1 AND COALESCE(archived,false)=FALSE),0),
		  COALESCE((SELECT COUNT(*) FROM reels WHERE user_id=$1),0),
		  COALESCE((SELECT SUM(views_count) FROM reels WHERE user_id=$1),0)
		  + COALESCE((SELECT COUNT(*) FROM post_views pv
		              JOIN posts p ON p.id = pv.post_id
		              WHERE p.user_id=$1),0),
		  COALESCE((SELECT SUM(likes_count) FROM posts
		            WHERE user_id=$1 AND COALESCE(archived,false)=FALSE),0)
		  + COALESCE((SELECT SUM(likes_count) FROM reels WHERE user_id=$1),0),
		  COALESCE((SELECT COUNT(*) FROM (
		      SELECT DATE_TRUNC('week', created_at) AS w FROM posts
		      WHERE user_id=$1 AND COALESCE(archived,false)=FALSE
		      UNION
		      SELECT DATE_TRUNC('week', created_at) FROM reels WHERE user_id=$1
		  ) weeks),0)`,
		userID).Scan(&s.Followers, &s.Posts, &s.Reels, &s.Views,
		&s.Likes, &s.ActiveWeeks)
	if err != nil {
		return CreatorStats{}, err
	}
	return s, nil
}

// achievement — як нишон ва шарти он.
type achievement struct {
	Code string
	// value арзиши воқеиро мегирад; 0 маънои «ҳанӯз не».
	value func(CreatorStats) int
	// need — ҳадди зарурӣ.
	need int
}

// Рӯйхати нишонҳо.
//
// Ҳар нишон як кори АНҶОМШУДАро тасдиқ мекунад. Нишони «ҳар рӯз
// даромадед» вуҷуд надорад: он на кор, балки вобастагиро мукофот
// медиҳад.
var achievements = []achievement{
	{"firstPost", func(s CreatorStats) int { return s.Posts + s.Reels }, 1},
	{"tenPosts", func(s CreatorStats) int { return s.Posts + s.Reels }, 10},
	{"fiftyPosts", func(s CreatorStats) int { return s.Posts + s.Reels }, 50},
	{"tenFollowers", func(s CreatorStats) int { return s.Followers }, 10},
	{"hundredFollowers", func(s CreatorStats) int { return s.Followers }, 100},
	{"thousandFollowers", func(s CreatorStats) int { return s.Followers }, 1000},
	{"thousandViews", func(s CreatorStats) int { return s.Views }, 1000},
	{"tenThousandViews", func(s CreatorStats) int { return s.Views }, 10000},
	{"hundredLikes", func(s CreatorStats) int { return s.Likes }, 100},
	{"fourActiveWeeks", func(s CreatorStats) int { return s.ActiveWeeks }, 4},
}

// Achievement — нишони гирифташуда.
type Achievement struct {
	Code string `json:"code"`
	// Value — арзише, ки нишонро ба вуҷуд овард (масалан 1000 биниш).
	Value    int    `json:"value"`
	EarnedAt string `json:"earnedAt"`
}

// SyncAchievements нишонҳои навро сабт мекунад ва ҳамаро бармегардонад.
//
// Нишони як бор гирифташуда ҳеҷ гоҳ ГИРИФТА НАМЕШАВАД: агар обуначӣ
// кам шавад, кори анҷомшуда бекор намегардад.
func SyncAchievements(ctx context.Context, db DB, userID string) ([]Achievement, error) {
	stats, err := GetCreatorStats(ctx, db, userID)
	if err != nil {
		return nil, err
	}

	for _, a := range achievements {
		got := a.value(stats)
		if got < a.need {
			continue
		}
		// DO NOTHING: санаи аввалин гирифтан нигоҳ дошта мешавад.
		if _, err := db.Exec(ctx, `
			INSERT INTO creator_achievements(user_id, code, value)
			VALUES ($1,$2,$3)
			ON CONFLICT (user_id, code) DO NOTHING`,
			userID, a.Code, got); err != nil {
			return nil, err
		}
	}
	return GetAchievements(ctx, db, userID)
}

// GetAchievements нишонҳои гирифташударо мегирад.
func GetAchievements(ctx context.Context, db DB, userID string) ([]Achievement, error) {
	rows, err := db.Query(ctx, `
		SELECT code, value, earned_at FROM creator_achievements
		WHERE user_id=$1 ORDER BY earned_at DESC, code ASC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Achievement{}
	for rows.Next() {
		var a Achievement
		var at time.Time
		if err := rows.Scan(&a.Code, &a.Value, &at); err != nil {
			continue
		}
		a.EarnedAt = at.UTC().Format(time.RFC3339)
		out = append(out, a)
	}
	return out, rows.Err()
}

// ── Зинаҳо ───────────────────────────────────────────────────────

// levelStep — як зина ва шарти он.
type levelStep struct {
	Level     int
	Followers int
	Views     int
	Content   int
}

// Зинаҳо. Ҳар се шарт бояд иҷро шавад: як рақами тасодуфан калон
// эҷодкорро ба зинаи болотар намебарад.
var levelSteps = []levelStep{
	{1, 0, 0, 0},
	{2, 10, 100, 3},
	{3, 100, 1000, 10},
	{4, 1000, 10000, 30},
	{5, 10000, 100000, 100},
}

// CreatorLevel — зинаи ҷорӣ ва роҳи то зинаи оянда.
type CreatorLevel struct {
	Level int          `json:"level"`
	Stats CreatorStats `json:"stats"`
	// Next — шартҳои зинаи оянда; nil дар зинаи охирин.
	Next *LevelTarget `json:"next,omitempty"`
}

// LevelTarget — чӣ лозим аст барои зинаи оянда.
//
// Ҳар се рақам возеҳ нишон дода мешавад: эҷодкор бояд бидонад, ки
// чаро зинааш нашуд, на ин ки тахмин занад.
type LevelTarget struct {
	Level     int `json:"level"`
	Followers int `json:"followers"`
	Views     int `json:"views"`
	Content   int `json:"content"`
}

// GetCreatorLevel зинаро аз рақамҳои воқеӣ ҳисоб мекунад.
func GetCreatorLevel(ctx context.Context, db DB, userID string) (CreatorLevel, error) {
	stats, err := GetCreatorStats(ctx, db, userID)
	if err != nil {
		return CreatorLevel{}, err
	}
	return LevelFor(stats), nil
}

// LevelFor зинаро аз рақамҳои додашуда ҳисоб мекунад.
func LevelFor(s CreatorStats) CreatorLevel {
	steps := make([]levelStep, len(levelSteps))
	copy(steps, levelSteps)
	sort.Slice(steps, func(i, j int) bool { return steps[i].Level < steps[j].Level })

	content := s.Posts + s.Reels
	out := CreatorLevel{Level: steps[0].Level, Stats: s}
	for _, st := range steps {
		if s.Followers >= st.Followers && s.Views >= st.Views &&
			content >= st.Content {
			out.Level = st.Level
			continue
		}
		// Аввалин зинае, ки нарасид — ҳамон ҳадаф.
		out.Next = &LevelTarget{
			Level:     st.Level,
			Followers: st.Followers,
			Views:     st.Views,
			Content:   st.Content,
		}
		break
	}
	return out
}
