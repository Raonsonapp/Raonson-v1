package ads

// Сеанси тамошо бо базаи ВОҚЕӢ.
//
// Ин тестҳо мегӯянд, ки хабари бебовари барнома то куҷо маҳдуд
// шудааст. Онҳо НАМЕГӮЯНД, ки хабар рост аст — инро санҷидан
// ғайриимкон аст, чунки Yandex SSV надорад.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

const testUnit = "R-M-19230220-2"

// setupRewarded муҳити кориро тайёр мекунад.
//
// minWatch ба сифр бароварда мешавад: тест наметавонад се сония
// интизор шавад. Худи он ҳимоя тести ҷудогона дорад.
func setupRewarded(t *testing.T) {
	t.Helper()
	t.Setenv("YANDEX_REWARDED_ID", testUnit)
	t.Setenv("ADS_MIN_WATCH_SEC", "0")
	t.Setenv("ADS_MIN_CLAIM_INTERVAL_SEC", "0")
	t.Setenv("ADS_DAILY_CAP", "100000")
}

func newSession(t *testing.T, pool *pgxpool.Pool, user string) string {
	t.Helper()
	s, err := CreateSession(context.Background(), pool, user, testUnit)
	if err != nil {
		t.Fatal(err)
	}
	if s.ID == "" {
		t.Fatal("шиносаи сеанс холӣ")
	}
	return s.ID
}

// claim — роҳи пурра: сеанс сохтан ва фавран ҳисоб кардан.
func claim(t *testing.T, pool *pgxpool.Pool, user string) ClaimResult {
	t.Helper()
	id := newSession(t, pool, user)
	res, err := ConsumeAndCredit(context.Background(), pool, user, id, testUnit)
	if err != nil {
		t.Fatal(err)
	}
	return res
}

func rewardCount(t *testing.T, pool *pgxpool.Pool, user string) int {
	t.Helper()
	var n int
	pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM ad_rewards WHERE user_id=$1`, user).Scan(&n)
	return n
}

// ── Роҳи дуруст ──────────────────────────────────────────────────

func TestValidClaimCounts(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)

	if res := claim(t, pool, u); res != ClaimCounted {
		t.Fatalf("интизор counted, гирифта шуд %s", res)
	}
	if n := rewardCount(t, pool, u); n != 1 {
		t.Fatalf("интизор 1 реклама, гирифта шуд %d", n)
	}
}

// Сатр бояд нишон диҳад, ки ба ин ҳисоб имзо НЕСТ.
func TestClientClaimIsMarkedUntrusted(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)
	claim(t, pool, u)

	var network string
	pool.QueryRow(context.Background(),
		`SELECT network FROM ad_rewards WHERE user_id=$1`, u).Scan(&network)
	if network != "yandex-client" {
		t.Fatalf("дараҷаи бовар нигоҳ дошта нашуд: %q", network)
	}
}

// ── Сеанси нодуруст ──────────────────────────────────────────────

func TestUnknownSessionRejected(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)

	res, err := ConsumeAndCredit(context.Background(), pool, u,
		"00000000000000000000000000000000", testUnit)
	if err != nil {
		t.Fatal(err)
	}
	if res != ClaimInvalid {
		t.Fatalf("сеанси номаълум қабул шуд: %s", res)
	}
	if n := rewardCount(t, pool, u); n != 0 {
		t.Fatalf("реклама ҳисоб шуд: %d", n)
	}
}

// Сеанси каси дигарро дуздидан мумкин нест.
func TestOtherUsersSessionRejected(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	victim := newUser(t, pool)
	attacker := newUser(t, pool)

	id := newSession(t, pool, victim)

	res, err := ConsumeAndCredit(context.Background(), pool, attacker,
		id, testUnit)
	if err != nil {
		t.Fatal(err)
	}
	if res != ClaimInvalid {
		t.Fatalf("сеанси бегона қабул шуд: %s", res)
	}
	if n := rewardCount(t, pool, attacker); n != 0 {
		t.Fatalf("ҳамлакунанда ҳисоб гирифт: %d", n)
	}
	// Сеанс бояд ҳанӯз кушода бошад — соҳибаш онро истифода барад.
	var status string
	pool.QueryRow(context.Background(),
		`SELECT status FROM ad_watch_sessions WHERE id=$1`, id).Scan(&status)
	if status != "pending" {
		t.Fatalf("сеанси қурбонӣ вайрон шуд: %s", status)
	}
}

func TestExpiredSessionRejected(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)
	id := newSession(t, pool, u)

	// Мӯҳлат ба гузашта бурда мешавад — вақти СЕРВЕР.
	if _, err := pool.Exec(context.Background(),
		`UPDATE ad_watch_sessions SET expires_at = NOW() - INTERVAL '1 minute'
		  WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}

	res, _ := ConsumeAndCredit(context.Background(), pool, u, id, testUnit)
	if res != ClaimInvalid {
		t.Fatalf("сеанси кӯҳна қабул шуд: %s", res)
	}
	if n := rewardCount(t, pool, u); n != 0 {
		t.Fatalf("реклама ҳисоб шуд: %d", n)
	}
}

func TestSessionCannotBeReused(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)
	id := newSession(t, pool, u)
	ctx := context.Background()

	if res, _ := ConsumeAndCredit(ctx, pool, u, id, testUnit); res != ClaimCounted {
		t.Fatalf("бори якум: %s", res)
	}
	for i := 0; i < 5; i++ {
		res, _ := ConsumeAndCredit(ctx, pool, u, id, testUnit)
		if res != ClaimDuplicate {
			t.Fatalf("такрори %d қабул шуд: %s", i+2, res)
		}
	}
	if n := rewardCount(t, pool, u); n != 1 {
		t.Fatalf("интизор 1, гирифта шуд %d", n)
	}
}

// Даҳ дархости ҲАМЗАМОН бо як сеанс — танҳо яке ҳисоб шавад.
func TestConcurrentClaimsCountOnce(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)
	id := newSession(t, pool, u)

	var wg sync.WaitGroup
	var mu sync.Mutex
	counted := 0

	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			res, err := ConsumeAndCredit(context.Background(), pool, u,
				id, testUnit)
			if err != nil {
				return
			}
			if res == ClaimCounted {
				mu.Lock()
				counted++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()

	if counted != 1 {
		t.Fatalf("%d дархост ҳисоб шуд, бояд 1", counted)
	}
	if n := rewardCount(t, pool, u); n != 1 {
		t.Fatalf("дар база %d сатр, бояд 1", n)
	}
}

// ── Ҷойгиршавӣ ───────────────────────────────────────────────────

func TestWrongAdUnitRejected(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)
	id := newSession(t, pool, u)

	// Banner ба ҷои Rewarded.
	res, _ := ConsumeAndCredit(context.Background(), pool, u, id,
		"R-M-19230220-3")
	if res != ClaimInvalid {
		t.Fatalf("ҷойгиршавии нодуруст қабул шуд: %s", res)
	}
	if n := rewardCount(t, pool, u); n != 0 {
		t.Fatalf("реклама ҳисоб шуд: %d", n)
	}
}

func TestSessionForWrongUnitNotCreated(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)

	if _, err := CreateSession(context.Background(), pool, u,
		"R-M-19230220-3"); err == nil {
		t.Fatal("сеанс барои ҷойгиршавии дигар сохта шуд")
	}
}

// Бе YANDEX_REWARDED_ID хусусият хомӯш аст — на «ба эҳтимоли хуб».
func TestNoRewardedIdMeansNoSessions(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("YANDEX_REWARDED_ID", "")
	u := newUser(t, pool)

	_, err := CreateSession(context.Background(), pool, u, testUnit)
	if err != ErrRewardedNotConfigured {
		t.Fatalf("интизор ErrRewardedNotConfigured, гирифта шуд %v", err)
	}
	if RewardedReady() {
		t.Fatal("RewardedReady бе шиноса true гуфт")
	}
}

// ── Вақт ─────────────────────────────────────────────────────────

func TestTooFastAfterSessionCreated(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_MIN_WATCH_SEC", "30")
	u := newUser(t, pool)
	id := newSession(t, pool, u)

	res, _ := ConsumeAndCredit(context.Background(), pool, u, id, testUnit)
	if res != ClaimTooFast {
		t.Fatalf("дархости фаврӣ қабул шуд: %s", res)
	}
	if n := rewardCount(t, pool, u); n != 0 {
		t.Fatalf("реклама ҳисоб шуд: %d", n)
	}
}

// Дастгоҳи суст ҷарима намегирад: сустӣ фосиларо ДАРОЗ мекунад.
func TestSlowDeviceStillCounts(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_MIN_WATCH_SEC", "3")
	u := newUser(t, pool)
	id := newSession(t, pool, u)

	// Реклама 40 сония давом кард — дастгоҳ суст буд.
	if _, err := pool.Exec(context.Background(),
		`UPDATE ad_watch_sessions SET created_at = NOW() - INTERVAL '40 seconds'
		  WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}

	res, _ := ConsumeAndCredit(context.Background(), pool, u, id, testUnit)
	if res != ClaimCounted {
		t.Fatalf("дастгоҳи суст рад шуд: %s", res)
	}
}

func TestMinIntervalBetweenClaims(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_MIN_CLAIM_INTERVAL_SEC", "60")
	u := newUser(t, pool)

	if res := claim(t, pool, u); res != ClaimCounted {
		t.Fatalf("якум: %s", res)
	}
	if res := claim(t, pool, u); res != ClaimTooFast {
		t.Fatalf("дуюм фавран қабул шуд: %s", res)
	}
	if n := rewardCount(t, pool, u); n != 1 {
		t.Fatalf("интизор 1, гирифта шуд %d", n)
	}
}

// ── Ҳадди рӯзона ─────────────────────────────────────────────────

func TestDailyCapStopsSessionClaims(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_DAILY_CAP", "3")
	u := newUser(t, pool)

	for i := 0; i < 3; i++ {
		if res := claim(t, pool, u); res != ClaimCounted {
			t.Fatalf("реклама %d: %s", i+1, res)
		}
	}
	if res := claim(t, pool, u); res != ClaimDailyCap {
		t.Fatalf("аз ҳад гузашт: %s", res)
	}
	if n := rewardCount(t, pool, u); n != 3 {
		t.Fatalf("интизор 3, гирифта шуд %d", n)
	}
}

// Сеанси аз ҳад гузашта бояд БАСТА шавад — вагарна онро нигоҳ
// дошта, фардо истифода кардан мумкин мешуд.
func TestCappedSessionIsStillConsumed(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_DAILY_CAP", "1")
	u := newUser(t, pool)

	claim(t, pool, u)
	id := newSession(t, pool, u)
	if res, _ := ConsumeAndCredit(context.Background(), pool, u, id,
		testUnit); res != ClaimDailyCap {
		t.Fatalf("интизор daily_cap, гирифта шуд %s", res)
	}

	var status string
	pool.QueryRow(context.Background(),
		`SELECT status FROM ad_watch_sessions WHERE id=$1`, id).Scan(&status)
	if status != "consumed" {
		t.Fatalf("сеанс кушода монд: %s", status)
	}
}

// ── Транзаксия ───────────────────────────────────────────────────

// Бастани сеанс ва ҳисоби реклама якҷоя мераванд: набояд ҳолате
// бошад, ки сеанс баста шуд, вале реклама ҳисоб нашуд.
func TestConsumeAndCreditAreAtomic(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	u := newUser(t, pool)
	id := newSession(t, pool, u)

	if res, _ := ConsumeAndCredit(context.Background(), pool, u, id,
		testUnit); res != ClaimCounted {
		t.Fatal(res)
	}

	var status string
	var consumed *time.Time
	pool.QueryRow(context.Background(),
		`SELECT status, consumed_at FROM ad_watch_sessions WHERE id=$1`,
		id).Scan(&status, &consumed)

	var n int
	pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM ad_rewards WHERE impression_id=$1`,
		"ws:"+id).Scan(&n)

	if status != "consumed" || consumed == nil || n != 1 {
		t.Fatalf("ҳолати нимкора: status=%s consumed=%v rewards=%d",
			status, consumed, n)
	}
}

// ── Галочка ──────────────────────────────────────────────────────

// Роҳи пурра: реклама → галочка. Системаи мукофот ЯК аст —
// ҳамон GrantIfEarned, ки callback-и имзошуда истифода мебарад.
func TestClaimsLeadToBadge(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_TIER_3D", "4")
	u := newUser(t, pool)
	ctx := context.Background()

	for i := 0; i < 4; i++ {
		if res := claim(t, pool, u); res != ClaimCounted {
			t.Fatalf("реклама %d: %s", i+1, res)
		}
	}

	granted, until, err := GrantIfEarned(ctx, pool, u)
	if err != nil {
		t.Fatal(err)
	}
	if !granted {
		t.Fatal("галочка дода нашуд")
	}
	if until.Before(time.Now()) {
		t.Fatalf("мӯҳлат дар гузашта: %v", until)
	}
	if v := verifiedUntil(t, pool, u); v == nil {
		t.Fatal("дар ҷадвали users мӯҳлат нест")
	}
}

// Пешрафт аз шиносаи Rewarded вобаста аст, на аз сирри HMAC:
// Yandex ба callback занг намезанад, пас он сир ба ин роҳ дахл
// надорад.
func TestProgressEnabledFollowsRewardedId(t *testing.T) {
	pool := testPool(t)
	setupRewarded(t)
	t.Setenv("ADS_CALLBACK_SECRET", "")
	u := newUser(t, pool)

	p, err := GetProgress(context.Background(), pool, u)
	if err != nil {
		t.Fatal(err)
	}
	if !p.Enabled {
		t.Fatal("бе сирри HMAC хусусият хомӯш эълон шуд")
	}

	t.Setenv("YANDEX_REWARDED_ID", "")
	p, _ = GetProgress(context.Background(), pool, u)
	if p.Enabled {
		t.Fatal("бе шиносаи Rewarded хусусият фаъол эълон шуд")
	}
}
