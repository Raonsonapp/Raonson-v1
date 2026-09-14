// Package ads реклама ва галочкаи аз он ҳосилшударо ҳисоб мекунад.
//
// ⚠️ Қоидаи асосӣ: BALANCE-и реклама ПУЛ АСТ.
//
// Галочка 20 сомонӣ меарзад. Агар барнома ба сухани client бовар
// кунад («ман реклама дидам»), ҳар кас метавонад бо 1200 дархости
// оддии HTTP галочкаро ройгон гирад — бе он ки ягон реклама бинад.
// Он вақт ҳам даромад нест, ҳам галочка маъно надорад.
//
// Аз ин рӯ ҳисоб ТАНҲО аз callback-и имзошудаи шабакаи реклама қабул
// мешавад (server-side verification). Агар он танзим нашуда бошад,
// реклама ҳисоб НАМЕШАВАД — на «ба эҳтимоли хуб» ҳисоб мешавад.
package ads

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

// DB — ҳадди ақали интерфейси лозим.
type DB interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Tier — як зинаи галочка: чанд реклама ва чанд рӯз.
type Tier struct {
	Code string `json:"code"`
	Ads  int    `json:"ads"`
	Days int    `json:"days"`
}

// tiers — зинаҳои пешфарз.
//
// Рақамҳо аз env танзим мешаванд, то бе ҷойгиркунии нав тағйир ёбанд:
// шабакаҳои реклама ҳаҷми зиёдро ҳамчун «трафики бардурӯғ» мешуморанд
// ва аккаунтро маҳдуд карда метавонанд.
func Tiers() []Tier {
	return []Tier{
		{"3d", envInt("ADS_TIER_3D", 300), 3},
		{"7d", envInt("ADS_TIER_7D", 600), 7},
		{"30d", envInt("ADS_TIER_30D", 1200), 30},
	}
}

// TierByCode зинаро аз рамз меёбад.
func TierByCode(code string) (Tier, bool) {
	for _, t := range Tiers() {
		if t.Code == code {
			return t, true
		}
	}
	return Tier{}, false
}

// DefaultGoal — ҳадафи пешфарзи корбари нав.
const DefaultGoal = "3d"

// DailyCap — ҳадди рекламаи ҳисобшаванда дар як рӯз.
//
// Ду сабаб: ҳимоя аз сӯиистифода ва талаби худи шабакаҳои реклама.
// Аз ин зиёд ҳисоб намешавад, вале реклама боз ҳам нишон дода
// мешавад — танҳо ба ҳисоб намеравад.
func DailyCap() int { return envInt("ADS_DAILY_CAP", 200) }

func envInt(key string, def int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			return n
		}
	}
	return def
}

// ── Ҳисоби реклама ───────────────────────────────────────────────

// Record як нишондиҳии ТАСДИҚШУДАи рекламаро сабт мекунад.
//
// impressionID аз худи шабакаи реклама меояд ва беназир аст —
// такрори ҳамон callback ҳисобро дучанд намекунад.
//
// Бармегардонад: оё сабт НАВ буд.
func Record(ctx context.Context, db DB, userID, impressionID,
	network string) (bool, error) {
	if userID == "" || impressionID == "" {
		return false, fmt.Errorf("ads: маълумоти нопурра")
	}

	// Ҳадди рӯзона: аз он зиёд ба ҳисоб намеравад.
	var today int
	if err := db.QueryRow(ctx, `
		SELECT COUNT(*) FROM ad_rewards
		WHERE user_id=$1 AND created_at >= date_trunc('day', NOW())`,
		userID).Scan(&today); err != nil {
		return false, err
	}
	if today >= DailyCap() {
		return false, nil
	}

	ct, err := db.Exec(ctx, `
		INSERT INTO ad_rewards(impression_id, user_id, network)
		VALUES ($1,$2,$3) ON CONFLICT (impression_id) DO NOTHING`,
		impressionID, userID, network)
	if err != nil {
		return false, err
	}
	return ct.RowsAffected() > 0, nil
}

// Progress — вазъи корбар.
type Progress struct {
	// Watched — ҳамаи рекламаҳои тасдиқшуда.
	Watched int `json:"watched"`
	// Spent — рекламаҳои аллакай ба галочка табдилшуда.
	Spent int `json:"spent"`
	// Balance — боқимонда.
	Balance int `json:"balance"`
	// Today — имрӯз чанд то ҳисоб шуд (барои нишон додани ҳад).
	Today    int  `json:"today"`
	DailyCap int  `json:"dailyCap"`
	Goal     Tier `json:"goal"`
	// Remaining — то ҳадаф чанд то мондааст.
	Remaining int `json:"remaining"`
	// VerifiedUntil — то кай галочка фаъол аст (холӣ = нест).
	VerifiedUntil string `json:"verifiedUntil,omitempty"`
	Verified      bool   `json:"verified"`
	// Tiers — ҳамаи зинаҳо, то экран онҳоро нишон диҳад.
	Tiers []Tier `json:"tiers"`
	// Enabled — оё ҳисоби реклама умуман кор мекунад.
	//
	// false вақте callback-и шабакаи реклама танзим нашудааст. Он
	// вақт экран бояд рост бигӯяд, на пешрафти бардурӯғ нишон диҳад.
	Enabled bool `json:"enabled"`
}

// GetProgress вазъи ҷории корбарро мегирад.
func GetProgress(ctx context.Context, db DB, userID string) (Progress, error) {
	p := Progress{Tiers: Tiers(), DailyCap: DailyCap(), Enabled: Configured()}

	goal := DefaultGoal
	if err := db.QueryRow(ctx, `
		SELECT goal, ads_spent FROM verification_state WHERE user_id=$1`,
		userID).Scan(&goal, &p.Spent); err != nil {
		goal = DefaultGoal
	}
	t, ok := TierByCode(goal)
	if !ok {
		t, _ = TierByCode(DefaultGoal)
	}
	p.Goal = t

	db.QueryRow(ctx, `SELECT COUNT(*) FROM ad_rewards WHERE user_id=$1`,
		userID).Scan(&p.Watched)
	db.QueryRow(ctx, `
		SELECT COUNT(*) FROM ad_rewards
		WHERE user_id=$1 AND created_at >= date_trunc('day', NOW())`,
		userID).Scan(&p.Today)

	p.Balance = p.Watched - p.Spent
	if p.Balance < 0 {
		p.Balance = 0
	}
	p.Remaining = t.Ads - p.Balance
	if p.Remaining < 0 {
		p.Remaining = 0
	}

	var until *time.Time
	db.QueryRow(ctx, `
		SELECT verified, verified_until FROM users WHERE id=$1`,
		userID).Scan(&p.Verified, &until)
	if until != nil {
		p.VerifiedUntil = until.UTC().Format(time.RFC3339)
	}
	return p, nil
}

// SetGoal ҳадафи корбарро иваз мекунад.
//
// Бе ҳадаф барнома намедонад, ки дар кадом зина галочка диҳад: касе
// ки моҳро мехоҳад, набояд дар 300 реклама се рӯз гирад ва ҳисобаш
// сифр шавад.
func SetGoal(ctx context.Context, db DB, userID, goal string) error {
	if _, ok := TierByCode(goal); !ok {
		return fmt.Errorf("ads: зинаи номаълум")
	}
	_, err := db.Exec(ctx, `
		INSERT INTO verification_state(user_id, goal)
		VALUES ($1,$2)
		ON CONFLICT (user_id) DO UPDATE SET
		  goal = EXCLUDED.goal, updated_at = NOW()`, userID, goal)
	return err
}

// GrantIfEarned галочкаро медиҳад, агар реклама кофӣ бошад.
//
// Ин ҷо ҳама чиз дар ЯК транзаксия: вагарна ду дархости ҳамзамон
// метавонистанд як balance-ро ду бор харҷ кунанд ва ду мӯҳлат
// диҳанд.
//
// Бармегардонад: оё галочка дода шуд ва то кай.
func GrantIfEarned(ctx context.Context, pool *pgxpool.Pool,
	userID string) (bool, time.Time, error) {

	tx, err := pool.Begin(ctx)
	if err != nil {
		return false, time.Time{}, err
	}
	defer tx.Rollback(ctx)

	// Сатрро қулф мекунем — ҳисоб бояд танҳо як бор харҷ шавад.
	var goal string
	var spent int
	err = tx.QueryRow(ctx, `
		INSERT INTO verification_state(user_id, goal) VALUES ($1,$2)
		ON CONFLICT (user_id) DO UPDATE SET user_id = EXCLUDED.user_id
		RETURNING goal, ads_spent`, userID, DefaultGoal).Scan(&goal, &spent)
	if err != nil {
		return false, time.Time{}, err
	}

	t, ok := TierByCode(goal)
	if !ok {
		t, _ = TierByCode(DefaultGoal)
	}

	var watched int
	if err := tx.QueryRow(ctx,
		`SELECT COUNT(*) FROM ad_rewards WHERE user_id=$1`,
		userID).Scan(&watched); err != nil {
		return false, time.Time{}, err
	}
	if watched-spent < t.Ads {
		return false, time.Time{}, nil
	}

	// Мӯҳлат аз вақти ҷорӣ ё аз охири мӯҳлати мавҷуда дароз мешавад,
	// то корбар рӯзҳои пардохтаашро гум накунад.
	var until time.Time
	if err := tx.QueryRow(ctx, `
		UPDATE users
		   SET verified = TRUE,
		       verified_until = GREATEST(COALESCE(verified_until, NOW()), NOW())
		                        + ($2 || ' days')::interval
		 WHERE id=$1
		 RETURNING verified_until`,
		userID, strconv.Itoa(t.Days)).Scan(&until); err != nil {
		return false, time.Time{}, err
	}

	if _, err := tx.Exec(ctx, `
		UPDATE verification_state
		   SET ads_spent = ads_spent + $2, updated_at = NOW()
		 WHERE user_id=$1`, userID, t.Ads); err != nil {
		return false, time.Time{}, err
	}

	if err := tx.Commit(ctx); err != nil {
		return false, time.Time{}, err
	}
	return true, until, nil
}
