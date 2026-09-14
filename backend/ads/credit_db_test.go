package ads

// Роҳи пурра бо базаи ВОҚЕӢ.
//
// Хосияти асосӣ: галочка ТАНҲО бо рекламаи тасдиқшуда меояд ва
// ҳисоб ҳеҷ гоҳ ду бор харҷ намешавад.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"context"
	"fmt"
	"os"
	"sync"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	if os.Getenv("RAONSON_TEST_DB") == "" {
		t.Skip("RAONSON_TEST_DB гузошта нашудааст")
	}
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL нест")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	return pool
}

func newUser(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	n := fmt.Sprintf("ads_%d", time.Now().UnixNano())
	var id string
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO users(username, email, password)
		VALUES ($1,$2,'x') RETURNING id`,
		n, n+"@test.invalid").Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

// watch n рекламаи тасдиқшударо сабт мекунад.
//
// Ҳадди рӯзона баланд бардошта мешавад: ин ҷо мантиқи ДОДАНИ
// галочка санҷида мешавад, на худи ҳад (барои он тести ҷудогона
// ҳаст). Бо ҳадди пешфарз 300 реклама дар як рӯз ҷамъ намешавад —
// ва ин қасдан аст.
func watch(t *testing.T, pool *pgxpool.Pool, user string, n int) {
	t.Helper()
	t.Setenv("ADS_DAILY_CAP", "100000")
	ctx := context.Background()
	for i := 0; i < n; i++ {
		imp := fmt.Sprintf("%s-%d-%d", user, time.Now().UnixNano(), i)
		if _, err := Record(ctx, pool, user, imp, "test"); err != nil {
			t.Fatal(err)
		}
	}
}

func verifiedUntil(t *testing.T, pool *pgxpool.Pool, user string) *time.Time {
	t.Helper()
	var until *time.Time
	pool.QueryRow(context.Background(),
		`SELECT verified_until FROM users WHERE id=$1`, user).Scan(&until)
	return until
}

// Камтар аз зина — галочка нест.
func TestNotEnoughAdsNoBadge(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	tier, _ := TierByCode(DefaultGoal)

	watch(t, pool, user, tier.Ads-1)
	granted, _, err := GrantIfEarned(context.Background(), pool, user)
	if err != nil {
		t.Fatal(err)
	}
	if granted {
		t.Error("бо рекламаи нокифоя галочка дода шуд")
	}
	if verifiedUntil(t, pool, user) != nil {
		t.Error("мӯҳлат гузошта шуд")
	}
}

// Расидан ба зина — галочка ХУДКОР.
func TestReachingTierGrantsBadge(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	tier, _ := TierByCode(DefaultGoal)

	watch(t, pool, user, tier.Ads)
	granted, until, err := GrantIfEarned(context.Background(), pool, user)
	if err != nil {
		t.Fatal(err)
	}
	if !granted {
		t.Fatal("галочка дода нашуд")
	}
	// Мӯҳлат бояд тақрибан ба зина мувофиқ бошад.
	want := time.Now().AddDate(0, 0, tier.Days)
	if until.Sub(want) > time.Hour || want.Sub(until) > time.Hour {
		t.Errorf("мӯҳлат %v, интизори тақрибан %v", until, want)
	}

	var isVerified bool
	pool.QueryRow(context.Background(),
		`SELECT verified FROM users WHERE id=$1`, user).Scan(&isVerified)
	if !isVerified {
		t.Error("майдони verified гузошта нашуд")
	}
}

// Ҳисоб ЯК БОР харҷ мешавад.
//
// Бе ин, як маротиба 300 реклама дида, корбар метавонист бо
// даъватҳои такрорӣ мӯҳлатро беохир дароз кунад.
func TestBalanceIsSpentOnce(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	tier, _ := TierByCode(DefaultGoal)
	ctx := context.Background()

	watch(t, pool, user, tier.Ads)
	if ok, _, _ := GrantIfEarned(ctx, pool, user); !ok {
		t.Fatal("аввалин додан нашуд")
	}
	first := verifiedUntil(t, pool, user)

	for i := 0; i < 5; i++ {
		if ok, _, _ := GrantIfEarned(ctx, pool, user); ok {
			t.Fatal("ҳисоб ду бор харҷ шуд")
		}
	}
	second := verifiedUntil(t, pool, user)
	if !first.Equal(*second) {
		t.Errorf("мӯҳлат бе реклама дароз шуд: %v → %v", first, second)
	}
}

// Дархостҳои ҲАМЗАМОН набояд ду мӯҳлат диҳанд.
func TestConcurrentGrantsAreSafe(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	tier, _ := TierByCode(DefaultGoal)
	ctx := context.Background()

	watch(t, pool, user, tier.Ads)

	var wg sync.WaitGroup
	var mu sync.Mutex
	grants := 0
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if ok, _, _ := GrantIfEarned(ctx, pool, user); ok {
				mu.Lock()
				grants++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if grants != 1 {
		t.Errorf("%d маротиба дода шуд, интизори 1", grants)
	}
}

// Ҳамон нишондиҳӣ ду бор ҳисоб намешавад.
func TestDuplicateImpressionCountsOnce(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	ctx := context.Background()

	imp := fmt.Sprintf("dup-%d", time.Now().UnixNano())
	first, err := Record(ctx, pool, user, imp, "test")
	if err != nil || !first {
		t.Fatalf("аввалин сабт: %v %v", first, err)
	}
	for i := 0; i < 5; i++ {
		again, _ := Record(ctx, pool, user, imp, "test")
		if again {
			t.Fatal("нишондиҳии такрорӣ ҳисоб шуд")
		}
	}
	p, _ := GetProgress(ctx, pool, user)
	if p.Watched != 1 {
		t.Errorf("%d ҳисоб шуд, интизори 1", p.Watched)
	}
}

// Ҳадди рӯзона: аз он зиёд ҳисоб намешавад.
func TestDailyCapStopsCounting(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	t.Setenv("ADS_DAILY_CAP", "5")
	ctx := context.Background()

	for i := 0; i < 20; i++ {
		imp := fmt.Sprintf("cap-%d-%d", time.Now().UnixNano(), i)
		Record(ctx, pool, user, imp, "test")
	}
	p, _ := GetProgress(ctx, pool, user)
	if p.Watched > 5 {
		t.Errorf("%d ҳисоб шуд, ҳад 5", p.Watched)
	}
}

// Ҳадафи корбар зинаро муайян мекунад.
func TestGoalSelectsTier(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	ctx := context.Background()

	if err := SetGoal(ctx, pool, user, "30d"); err != nil {
		t.Fatal(err)
	}
	month, _ := TierByCode("30d")
	three, _ := TierByCode("3d")

	// Реклама барои се рӯз кофист, вале ҳадаф як моҳ аст.
	watch(t, pool, user, three.Ads)
	if ok, _, _ := GrantIfEarned(ctx, pool, user); ok {
		t.Error("дар ҳадафи моҳона зинаи хурд дода шуд")
	}

	watch(t, pool, user, month.Ads-three.Ads)
	ok, until, err := GrantIfEarned(ctx, pool, user)
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("ҳадафи моҳона дода нашуд")
	}
	want := time.Now().AddDate(0, 0, month.Days)
	if until.Sub(want) > time.Hour || want.Sub(until) > time.Hour {
		t.Errorf("мӯҳлат %v, интизори %v", until, want)
	}
}

// Ҳадафи бегона қабул намешавад.
func TestBadGoalRejected(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	for _, bad := range []string{"", "1d", "999d", "free"} {
		if err := SetGoal(context.Background(), pool, user, bad); err == nil {
			t.Errorf("ҳадафи %q қабул шуд", bad)
		}
	}
}

// Мӯҳлати мавҷуда ДАРОЗ мешавад, на иваз.
func TestExistingTimeIsExtended(t *testing.T) {
	pool := testPool(t)
	user := newUser(t, pool)
	ctx := context.Background()
	tier, _ := TierByCode(DefaultGoal)

	// Мӯҳлати аллакай мавҷуда.
	future := time.Now().AddDate(0, 0, 10)
	pool.Exec(ctx, `UPDATE users SET verified=TRUE, verified_until=$2
		WHERE id=$1`, user, future)

	watch(t, pool, user, tier.Ads)
	if ok, _, _ := GrantIfEarned(ctx, pool, user); !ok {
		t.Fatal("дода нашуд")
	}
	got := verifiedUntil(t, pool, user)
	want := future.AddDate(0, 0, tier.Days)
	if got.Sub(want) > time.Hour || want.Sub(*got) > time.Hour {
		t.Errorf("мӯҳлат %v, интизори %v — рӯзҳои мавҷуда гум шуданд",
			got, want)
	}
}
