package ads

// Сеанси тамошои реклама — роҳи Yandex.
//
// ⚠️ ИН ТАСДИҚИ КРИПТОГРАФӢ НЕСТ.
//
// Yandex Mobile Ads server-side verification (SSV/S2S) НАДОРАД ва
// онро ваъда ҳам намекунад. Пас баръакси verify.go — ки имзои
// шабакаро месанҷад ва барои шабакаҳои ОЯНДА нигоҳ дошта шудааст —
// ин ҷо ҳеҷ имзо нест. Ягона хабардиҳанда худи барнома аст.
//
// Барномаро бошад корбар дар дасти худ дорад: телефони root-шуда ё
// APK-и тағйирёфта метавонад бигӯяд «ман реклама дидам», бе он ки
// чизе бинад. Ин ҳақиқат бо ҳеҷ коди сервер бартараф намешавад.
//
// Пас вазифаи ин файл дигар аст: НАРХИ дурӯғро баланд кардан.
//
//   • Ҳар мукофот сеанси пешакӣ сохташударо талаб мекунад — «як
//     дархости curl» кифоя нест.
//   • Сеанс ба корбари воридшуда баста аст ва аз JWT гирифта
//     мешавад, на аз бадани дархост.
//   • Ҳар сеанс ФАҚАТ ЯК БОР ҳисоб мешавад (қулфи сатр дар база).
//   • Сеанс мӯҳлат дорад.
//   • Байни сохтан ва ҳисоб вақти ҳадди ақал лозим аст.
//   • Байни ду мукофот фосилаи ҳадди ақал лозим аст.
//   • Ҳадди рӯзона (DailyCap) боқӣ мемонад.
//
// Ҳамаи вақтҳо аз СЕРВЕР гирифта мешаванд. Вақти барнома ҳеҷ ҷо
// қабул намешавад.
//
// Дар дафтари `ad_rewards` чунин сатрҳо network='yandex-client'
// мегиранд — то баъдтар маълум бошад, ки кадом сатр бо имзо тасдиқ
// шудааст ва кадом танҳо ба сухани барнома такя мекунад.

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrRewardedNotConfigured — шиносаи Rewarded дар сервер нест.
//
// Дар ин ҳолат сеанс сохта НАМЕШАВАД. Ин қасдан аст: бе он сервер
// намедонад, ки барнома воқеан кадом рекламаро нишон дод, ва
// санҷиши ad_unit_id маъное намемонад.
var ErrRewardedNotConfigured = errors.New("ads: шиносаи Rewarded танзим нашудааст")

// RewardedUnitID — шиносаи ҷойгиршавии Rewarded аз муҳити сервер.
//
// Ҳамон арзише, ки барнома ҳангоми сохтан мегирад
// (dart_defines/ad_units.json → YANDEX_REWARDED_ID).
func RewardedUnitID() string { return os.Getenv("YANDEX_REWARDED_ID") }

// RewardedReady мегӯяд, ки оё роҳи мукофот кор карда метавонад.
func RewardedReady() bool { return RewardedUnitID() != "" }

// envSeconds арзиши сонияро мехонад ва СИФРро қабул мекунад.
//
// envInt-и умумӣ сифрро рад мекунад — барои зина ва ҳадди рӯзона
// ин дуруст аст (зинаи сифр маъно надорад). Вале ин ҷо сифр маънои
// возеҳ дорад: «ин санҷишро хомӯш кун». Агар онро рад кунем,
// оператор 0 мегузорад ва хомӯшакак 3 мегирад — танзими дурӯғ.
func envSeconds(key string, def int) time.Duration {
	n := def
	if v := os.Getenv(key); v != "" {
		if parsed, err := strconv.Atoi(v); err == nil && parsed >= 0 {
			n = parsed
		}
	}
	return time.Duration(n) * time.Second
}

// sessionTTL — то кай сеанс зинда аст.
//
// Дароз аст қасдан: реклама метавонад дер бор шавад, интернет суст
// шавад, ё корбар барномаро дар мобайн пинҳон кунад. Мӯҳлати кӯтоҳ
// корбари ҳалолро ҷарима мекард.
func sessionTTL() time.Duration {
	return time.Duration(envInt("ADS_SESSION_TTL_MIN", 30)) * time.Minute
}

// minWatch — вақти ҳадди ақал аз сохтани сеанс то ҳисоб.
//
// Суст будани дастгоҳ инро ВАЙРОН НАМЕКУНАД: сустӣ фосиларо дароз
// мекунад, на кӯтоҳ. Танҳо «сохтан ва дарҳол гирифтан» бозмедорад.
func minWatch() time.Duration { return envSeconds("ADS_MIN_WATCH_SEC", 3) }

// minInterval — фосилаи ҳадди ақал байни ду мукофот.
//
// Рекламаи воқеӣ 15–30 сония давом мекунад, пас 5 сония ба корбари
// ҳалол халал намерасонад, вале дархостҳои пай дар пайро мебандад.
func minInterval() time.Duration {
	return envSeconds("ADS_MIN_CLAIM_INTERVAL_SEC", 5)
}

// Session — он чи ба барнома бармегардад.
type Session struct {
	ID        string    `json:"sessionId"`
	ExpiresAt time.Time `json:"expiresAt"`
}

// CreateSession сеанси навро мекушояд.
//
// userID аз JWT меояд, на аз бадани дархост.
func CreateSession(ctx context.Context, db DB, userID, adUnitID string) (Session, error) {
	want := RewardedUnitID()
	if want == "" {
		return Session{}, ErrRewardedNotConfigured
	}
	if adUnitID != want {
		return Session{}, fmt.Errorf("ads: ҷойгиршавии нодуруст")
	}
	if userID == "" {
		return Session{}, fmt.Errorf("ads: корбар нест")
	}

	// Шиносаи тасодуфии криптографӣ: онро пешакӣ ҳисоб кардан
	// мумкин нест.
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return Session{}, err
	}
	id := hex.EncodeToString(raw)

	var expires time.Time
	// Мӯҳлат аз соати СЕРВЕР ҳисоб мешавад.
	if err := db.QueryRow(ctx, `
		INSERT INTO ad_watch_sessions(id, user_id, ad_unit_id, expires_at)
		VALUES ($1, $2, $3, NOW() + ($4 || ' seconds')::interval)
		RETURNING expires_at`,
		id, userID, adUnitID,
		fmt.Sprint(int(sessionTTL().Seconds()))).Scan(&expires); err != nil {
		return Session{}, err
	}
	return Session{ID: id, ExpiresAt: expires.UTC()}, nil
}

// ClaimResult — натиҷаи кӯшиши гирифтани мукофот.
type ClaimResult string

const (
	// ClaimCounted — реклама ҳисоб шуд.
	ClaimCounted ClaimResult = "counted"
	// ClaimDuplicate — ҳамин сеанс аллакай истифода шудааст.
	ClaimDuplicate ClaimResult = "duplicate"
	// ClaimInvalid — сеанс нест, бегона, кӯҳна, ё ҷойгиршавӣ дигар.
	//
	// Ҳамаи ин сабабҳо ЯК ҷавоб мегиранд: фарқи онҳо ба
	// ҳамлакунанда мегӯяд, ки кадом тахминаш наздик буд.
	ClaimInvalid ClaimResult = "invalid"
	// ClaimTooFast — зуд аз ҳад.
	ClaimTooFast ClaimResult = "too_fast"
	// ClaimDailyCap — ҳадди рӯзона. Ин хато НЕСТ.
	ClaimDailyCap ClaimResult = "daily_cap"
)

// ConsumeAndCredit сеансро мебандад ва рекламаро ҳисоб мекунад.
//
// Бастан ва ҳисоб дар ЯК транзаксия мераванд: вагарна ду дархости
// ҳамзамон метавонистанд як сеансро ду бор ҳисоб кунанд.
//
// Бармегардонад: натиҷа ва оё галочка дар ҳамин дархост дода шуд.
func ConsumeAndCredit(ctx context.Context, pool *pgxpool.Pool,
	userID, sessionID, adUnitID string) (ClaimResult, error) {

	if userID == "" || sessionID == "" {
		return ClaimInvalid, nil
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		return ClaimInvalid, err
	}
	defer tx.Rollback(ctx)

	// FOR UPDATE сатрро қулф мекунад. Дархости дуюми ҳамзамон ин
	// ҷо интизор мешавад ва баъд status='consumed'-ро мебинад.
	var owner, unit, status string
	var createdAt, expiresAt, now time.Time
	err = tx.QueryRow(ctx, `
		SELECT user_id, ad_unit_id, status, created_at, expires_at, NOW()
		  FROM ad_watch_sessions WHERE id=$1 FOR UPDATE`,
		sessionID).Scan(&owner, &unit, &status, &createdAt, &expiresAt, &now)
	if errors.Is(err, pgx.ErrNoRows) {
		return ClaimInvalid, nil
	}
	if err != nil {
		return ClaimInvalid, err
	}

	// Сеанси каси дигар — ҳеҷ гоҳ.
	if owner != userID {
		return ClaimInvalid, nil
	}
	if status != "pending" {
		return ClaimDuplicate, nil
	}
	if now.After(expiresAt) {
		return ClaimInvalid, nil
	}
	// Ҷойгиршавӣ бояд ҳам бо сеанс ва ҳам бо танзими сервер мувофиқ
	// бошад — вагарна мукофоти Rewarded-ро барои banner гирифтан
	// мумкин мешуд.
	if unit != adUnitID || unit != RewardedUnitID() {
		return ClaimInvalid, nil
	}
	if now.Sub(createdAt) < minWatch() {
		return ClaimTooFast, nil
	}

	// Фосила аз мукофоти охирин — вақти СЕРВЕР.
	var last *time.Time
	if err := tx.QueryRow(ctx,
		`SELECT MAX(created_at) FROM ad_rewards WHERE user_id=$1`,
		userID).Scan(&last); err != nil {
		return ClaimInvalid, err
	}
	if last != nil && now.Sub(*last) < minInterval() {
		return ClaimTooFast, nil
	}

	// Ҳадди рӯзона.
	var today int
	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM ad_rewards
		 WHERE user_id=$1 AND created_at >= date_trunc('day', NOW())`,
		userID).Scan(&today); err != nil {
		return ClaimInvalid, err
	}

	// Сеанс дар ҳар ду ҳолат баста мешавад — ҳатто агар ҳад расида
	// бошад. Вагарна онро нигоҳ дошта, фардо истифода кардан мумкин
	// мешуд.
	if _, err := tx.Exec(ctx, `
		UPDATE ad_watch_sessions
		   SET status='consumed', consumed_at=NOW()
		 WHERE id=$1 AND status='pending'`, sessionID); err != nil {
		return ClaimInvalid, err
	}

	if today >= DailyCap() {
		if err := tx.Commit(ctx); err != nil {
			return ClaimInvalid, err
		}
		return ClaimDailyCap, nil
	}

	// Шиносаи сеанс ҳамчун impression_id: ҷадвали `ad_rewards`
	// аллакай онро беназир мекунад, пас дафтари дуюм лозим нест.
	if _, err := tx.Exec(ctx, `
		INSERT INTO ad_rewards(impression_id, user_id, network)
		VALUES ($1, $2, 'yandex-client')
		ON CONFLICT (impression_id) DO NOTHING`,
		"ws:"+sessionID, userID); err != nil {
		return ClaimInvalid, err
	}

	if err := tx.Commit(ctx); err != nil {
		return ClaimInvalid, err
	}
	return ClaimCounted, nil
}
