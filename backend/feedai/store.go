package feedai

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// DB — ҳадди ақали интерфейси лозим. Ҳам *pgxpool.Pool ва ҳам pgx.Tx
// онро қонеъ мекунанд, бинобар ин функсияҳо дар транзаксия низ кор
// мекунанд.
type DB interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

var ErrUnknownTopic = errors.New("feedai: мавзӯи номаълум")

// supportedLanguages — забонҳое, ки барнома дастгирӣ мекунад.
//
// Забони дилхоҳ қабул намешавад: вагарна корбар метавонад ҳар сатрро
// ҳамчун «забон» нависад ва ҷадвал бо маълумоти бемаъно пур шавад.
var supportedLanguages = map[string]bool{"tj": true, "ru": true, "en": true}

// LoadTopics мавзӯъҳои фаъолро мехонад.
func LoadTopics(ctx context.Context, db DB) ([]Topic, error) {
	rows, err := db.Query(ctx, `
		SELECT slug, COALESCE(keywords,'{}')
		FROM feed_topics WHERE active = TRUE ORDER BY slug`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Topic{}
	for rows.Next() {
		var t Topic
		if err := rows.Scan(&t.Slug, &t.Keywords); err != nil {
			continue
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// TopicView — мавзӯъ бо номҳо ва афзалияти корбар.
type TopicView struct {
	Slug   string  `json:"slug"`
	NameTJ string  `json:"nameTj"`
	NameRU string  `json:"nameRu"`
	NameEN string  `json:"nameEn"`
	Score  float64 `json:"score"`
	Source string  `json:"source"`
}

// Prefs — профили пурраи тавсияи корбар.
type Prefs struct {
	Languages       []string    `json:"languages"`
	PreferLocal     bool        `json:"preferLocal"`
	PreferOriginal  bool        `json:"preferOriginal"`
	PreferFollowing bool        `json:"preferFollowing"`
	FewerRecs       bool        `json:"fewerRecommendations"`
	Topics          []TopicView `json:"topics"`
	MutedCreators   int         `json:"mutedCreators"`
	BoostedCreators int         `json:"boostedCreators"`
	UpdatedAt       *time.Time  `json:"updatedAt,omitempty"`
}

// GetPrefs профили корбарро мехонад.
//
// Корбари нав профил надорад — ин хато НЕСТ: холии профил маънои
// «ҳанӯз чизе нагуфтааст»-ро дорад ва лента бо рейтинги мавҷуда кор
// мекунад.
func GetPrefs(ctx context.Context, db DB, userID string) (Prefs, error) {
	p := Prefs{Languages: []string{}, Topics: []TopicView{}}

	var updated *time.Time
	err := db.QueryRow(ctx, `
		SELECT COALESCE(languages,'{}'), prefer_local, prefer_original,
		       prefer_following, fewer_recommendations, updated_at
		FROM feed_prefs WHERE user_id=$1`, userID).
		Scan(&p.Languages, &p.PreferLocal, &p.PreferOriginal,
			&p.PreferFollowing, &p.FewerRecs, &updated)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return Prefs{}, err
	}
	p.UpdatedAt = updated

	// Ҳамаи мавзӯъҳо бо холи корбар (агар бошад) — то экран пурра
	// нишон дода шавад, на танҳо онҳое ки корбар даст расонд.
	rows, err := db.Query(ctx, `
		SELECT t.slug, t.name_tj, t.name_ru, t.name_en,
		       COALESCE(p.score,0), COALESCE(p.source,'')
		FROM feed_topics t
		LEFT JOIN feed_topic_prefs p
		       ON p.topic_slug = t.slug AND p.user_id = $1
		WHERE t.active = TRUE
		ORDER BY COALESCE(p.score,0) DESC, t.slug`, userID)
	if err != nil {
		return Prefs{}, err
	}
	defer rows.Close()
	for rows.Next() {
		var v TopicView
		if err := rows.Scan(&v.Slug, &v.NameTJ, &v.NameRU, &v.NameEN,
			&v.Score, &v.Source); err != nil {
			continue
		}
		p.Topics = append(p.Topics, v)
	}
	if err := rows.Err(); err != nil {
		return Prefs{}, err
	}

	db.QueryRow(ctx, `
		SELECT COUNT(*) FILTER (WHERE score < 0),
		       COUNT(*) FILTER (WHERE score > 0)
		FROM feed_creator_prefs WHERE user_id=$1`, userID).
		Scan(&p.MutedCreators, &p.BoostedCreators)

	return p, nil
}

// PrefsInput — он чи корбар танзим карда метавонад.
type PrefsInput struct {
	Languages       []string `json:"languages"`
	PreferLocal     bool     `json:"preferLocal"`
	PreferOriginal  bool     `json:"preferOriginal"`
	PreferFollowing bool     `json:"preferFollowing"`
	FewerRecs       bool     `json:"fewerRecommendations"`
}

// SavePrefs танзимоти умумиро сабт мекунад.
//
// Забонҳои номаълум хомӯшона партофта мешаванд — вуруди client
// эътимоднок нест.
func SavePrefs(ctx context.Context, db DB, userID string, in PrefsInput) error {
	langs := make([]string, 0, len(in.Languages))
	seen := map[string]bool{}
	for _, l := range in.Languages {
		code := strings.ToLower(strings.TrimSpace(l))
		if supportedLanguages[code] && !seen[code] {
			seen[code] = true
			langs = append(langs, code)
		}
	}
	_, err := db.Exec(ctx, `
		INSERT INTO feed_prefs(user_id, languages, prefer_local, prefer_original,
		                       prefer_following, fewer_recommendations, updated_at)
		VALUES ($1,$2,$3,$4,$5,$6,NOW())
		ON CONFLICT (user_id) DO UPDATE SET
		  languages             = EXCLUDED.languages,
		  prefer_local          = EXCLUDED.prefer_local,
		  prefer_original       = EXCLUDED.prefer_original,
		  prefer_following      = EXCLUDED.prefer_following,
		  fewer_recommendations = EXCLUDED.fewer_recommendations,
		  updated_at            = NOW()`,
		userID, langs, in.PreferLocal, in.PreferOriginal,
		in.PreferFollowing, in.FewerRecs)
	return err
}

// SetTopicScore афзалияти мавзӯъро возеҳан таъин мекунад.
//
// Танҳо мавзӯи ВОҚЕАН мавҷуд қабул мешавад — slug-и ихтироъшуда рад
// мешавад, то ҷадвал бо мавзӯъҳои нестбуда пур нашавад.
func SetTopicScore(ctx context.Context, db DB, userID, slug string,
	score float64) error {
	if score < -1 || score > 1 {
		return fmt.Errorf("feedai: хол бояд дар байни -1 ва 1 бошад")
	}
	var exists bool
	if err := db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM feed_topics WHERE slug=$1 AND active)`,
		slug).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		return ErrUnknownTopic
	}
	_, err := db.Exec(ctx, `
		INSERT INTO feed_topic_prefs(user_id, topic_slug, score, source, updated_at)
		VALUES ($1,$2,$3,'explicit',NOW())
		ON CONFLICT (user_id, topic_slug) DO UPDATE SET
		  score = EXCLUDED.score, source = 'explicit', updated_at = NOW()`,
		userID, slug, score)
	return err
}

// nudgeTopic холи мавзӯъро аз рӯи сигнал ҳаракат медиҳад.
//
// Интихоби возеҳи корбар ('explicit') аз сигнали омӯхта БОЛОТАР аст:
// агар касе гуфта бошад «news намехоҳам», як тасодуфан то охир
// тамошокардаи видеои ахбор набояд онро бекор кунад.
func nudgeTopic(ctx context.Context, db DB, userID, slug string,
	weight float64) error {
	var current float64
	var source string
	err := db.QueryRow(ctx, `
		SELECT score, source FROM feed_topic_prefs
		WHERE user_id=$1 AND topic_slug=$2`, userID, slug).Scan(&current, &source)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	if source == "explicit" {
		// Сигнали омӯхта таъсир мекунад, вале хеле сустар.
		weight *= 0.25
	}
	next := ApplySignal(current, weight)
	_, err = db.Exec(ctx, `
		INSERT INTO feed_topic_prefs(user_id, topic_slug, score, source, updated_at)
		VALUES ($1,$2,$3,$4,NOW())
		ON CONFLICT (user_id, topic_slug) DO UPDATE SET
		  score = EXCLUDED.score, updated_at = NOW()`,
		userID, slug, next, sourceOr(source, "learned"))
	return err
}

func sourceOr(current, def string) string {
	if current == "" {
		return def
	}
	return current
}

// nudgeCreator афзалияти эҷодкорро ҳаракат медиҳад.
func nudgeCreator(ctx context.Context, db DB, userID, creatorID string,
	weight float64) error {
	if creatorID == "" || creatorID == userID {
		return nil
	}
	var current float64
	var source string
	err := db.QueryRow(ctx, `
		SELECT score, source FROM feed_creator_prefs
		WHERE user_id=$1 AND creator_id=$2`, userID, creatorID).
		Scan(&current, &source)
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	if source == "explicit" {
		weight *= 0.25
	}
	next := ApplySignal(current, weight)
	_, err = db.Exec(ctx, `
		INSERT INTO feed_creator_prefs(user_id, creator_id, score, source, updated_at)
		VALUES ($1,$2,$3,$4,NOW())
		ON CONFLICT (user_id, creator_id) DO UPDATE SET
		  score = EXCLUDED.score, updated_at = NOW()`,
		userID, creatorID, next, sourceOr(source, "learned"))
	return err
}

// SetCreatorScore афзалияти эҷодкорро возеҳан таъин мекунад.
func SetCreatorScore(ctx context.Context, db DB, userID, creatorID string,
	score float64) error {
	if score < -1 || score > 1 {
		return fmt.Errorf("feedai: хол бояд дар байни -1 ва 1 бошад")
	}
	if creatorID == "" || creatorID == userID {
		return fmt.Errorf("feedai: эҷодкор нодуруст")
	}
	_, err := db.Exec(ctx, `
		INSERT INTO feed_creator_prefs(user_id, creator_id, score, source, updated_at)
		VALUES ($1,$2,$3,'explicit',NOW())
		ON CONFLICT (user_id, creator_id) DO UPDATE SET
		  score = EXCLUDED.score, source = 'explicit', updated_at = NOW()`,
		userID, creatorID, score)
	return err
}

// ── Ҳодисаҳо ─────────────────────────────────────────────────────

// FeedbackInput — як ҳодисаи тавсия.
type FeedbackInput struct {
	Event       Event  `json:"event"`
	ContentType string `json:"contentType"`
	ContentID   string `json:"contentId"`
	CreatorID   string `json:"creatorId"`
}

// RecordFeedback ҳодисаро сабт ва профилро нав мекунад.
//
// Сигналҳои ЗАИФ (дидан, скролл) танҳо сабт мешаванд ва job онҳоро
// ҷамъбаст мекунад. Сигналҳои ҚАВӢ (монанди ин бештар/камтар) фавран
// татбиқ мешаванд, зеро корбар натиҷаро дарҳол интизор аст.
func RecordFeedback(ctx context.Context, db DB, userID string,
	in FeedbackInput) error {
	if !in.Event.Valid() {
		return fmt.Errorf("feedai: ҳодисаи номаълум %q", in.Event)
	}
	if in.ContentType != "" && in.ContentType != "post" && in.ContentType != "reel" {
		return fmt.Errorf("feedai: навъи мӯҳтаво нодуруст")
	}
	w := in.Event.Weight()

	immediate := w >= 0.20 || w <= -0.20
	if _, err := db.Exec(ctx, `
		INSERT INTO feed_events(user_id, content_type, content_id, creator_id,
		                        event, weight, processed)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		userID, in.ContentType, in.ContentID, in.CreatorID,
		string(in.Event), w, immediate); err != nil {
		return err
	}
	if !immediate {
		return nil
	}
	return applyFeedbackNow(ctx, db, userID, in, w)
}

// applyFeedbackNow сигнали қавиро фавран ба профил мегузаронад.
func applyFeedbackNow(ctx context.Context, db DB, userID string,
	in FeedbackInput, w float64) error {
	// Мавзӯъҳои ин мӯҳтаво.
	if in.ContentID != "" && in.ContentType != "" {
		rows, err := db.Query(ctx, `
			SELECT topic_slug, weight FROM content_topics
			WHERE content_type=$1 AND content_id=$2`,
			in.ContentType, in.ContentID)
		if err != nil {
			return err
		}
		type tw struct {
			slug string
			w    float64
		}
		list := []tw{}
		for rows.Next() {
			var t tw
			if err := rows.Scan(&t.slug, &t.w); err == nil {
				list = append(list, t)
			}
		}
		rows.Close()
		for _, t := range list {
			// Вазни мансубият сигналро миқёс мекунад: мавзӯи асосии
			// пост аз мавзӯи канорӣ бештар таъсир мебинад.
			if err := nudgeTopic(ctx, db, userID, t.slug, w*t.w); err != nil {
				return err
			}
		}
	}
	// Эҷодкор: «монанди ин камтар» набояд эҷодкорро ҳамон қадар ҷазо
	// диҳад, ки мавзӯъро — шояд корбар маҳз ин мавзӯъро нахоҳад.
	if in.CreatorID != "" {
		return nudgeCreator(ctx, db, userID, in.CreatorID, w*0.5)
	}
	return nil
}

// ResetPrefs афзалиятҳои тавсияро тоза мекунад.
//
// Танҳо маълумоти ТАВСИЯ нест мешавад: аккаунт, обунаҳо, лайкҳо,
// шарҳҳо ва мӯҳтавои корбар даст нахӯрда мемонанд.
//
// keepExplicit — интихоби худи корбарро нигоҳ медорад ва танҳо он чи
// система «омӯхтааст» тоза мекунад.
func ResetPrefs(ctx context.Context, db DB, userID string, keepExplicit bool) error {
	if keepExplicit {
		if _, err := db.Exec(ctx,
			`DELETE FROM feed_topic_prefs WHERE user_id=$1 AND source='learned'`,
			userID); err != nil {
			return err
		}
		if _, err := db.Exec(ctx,
			`DELETE FROM feed_creator_prefs WHERE user_id=$1 AND source='learned'`,
			userID); err != nil {
			return err
		}
	} else {
		if _, err := db.Exec(ctx,
			`DELETE FROM feed_topic_prefs WHERE user_id=$1`, userID); err != nil {
			return err
		}
		if _, err := db.Exec(ctx,
			`DELETE FROM feed_creator_prefs WHERE user_id=$1`, userID); err != nil {
			return err
		}
		if _, err := db.Exec(ctx,
			`DELETE FROM feed_prefs WHERE user_id=$1`, userID); err != nil {
			return err
		}
	}
	// Ҳодисаҳои хом низ тоза мешаванд — вагарна job онҳоро дубора
	// ҷамъ мекунад ва профили «тозашуда» худ ба худ барқарор мешавад.
	_, err := db.Exec(ctx, `DELETE FROM feed_events WHERE user_id=$1`, userID)
	return err
}

// ApplyIntent натиҷаи таҷзияи забони табииро татбиқ мекунад.
//
// Ҳар мавзӯъ пеш аз навиштан тафтиш мешавад — ҷавоби таҷзия ҳеҷ гоҳ
// мустақиман ба ҷадвал намеравад.
func ApplyIntent(ctx context.Context, db DB, userID string, in Intent) error {
	for _, slug := range in.PositiveTopics {
		if err := SetTopicScore(ctx, db, userID, slug, 0.8); err != nil &&
			!errors.Is(err, ErrUnknownTopic) {
			return err
		}
	}
	for _, slug := range in.NegativeTopics {
		if err := SetTopicScore(ctx, db, userID, slug, -0.8); err != nil &&
			!errors.Is(err, ErrUnknownTopic) {
			return err
		}
	}
	if len(in.Languages) > 0 || in.PreferLocal || in.PreferOriginal {
		cur, err := GetPrefs(ctx, db, userID)
		if err != nil {
			return err
		}
		next := PrefsInput{
			Languages:       cur.Languages,
			PreferLocal:     cur.PreferLocal || in.PreferLocal,
			PreferOriginal:  cur.PreferOriginal || in.PreferOriginal,
			PreferFollowing: cur.PreferFollowing,
			FewerRecs:       cur.FewerRecs,
		}
		if len(in.Languages) > 0 {
			next.Languages = in.Languages
		}
		return SavePrefs(ctx, db, userID, next)
	}
	return nil
}
