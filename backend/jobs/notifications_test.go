package jobs

import (
	"context"
	"os"
	"testing"
	"time"

	"raonson/db"
)

// Ҷадвали кори ҳафтаина: агар он нодуруст бошад, хатогӣ як ҳафта
// ноаён мемонад.
func TestRecapScheduleFiresOnceAWeek(t *testing.T) {
	// Душанбе, соати дуруст.
	monday := time.Date(2026, 9, 7, recapNotifyHour, 0, 0, 0, time.UTC)
	if !shouldSendRecap(monday) {
		t.Error("душанбеи соати муқарраршуда рад шуд")
	}

	// Ҳамон рӯз, соати дигар.
	for h := 0; h < 24; h++ {
		if h == recapNotifyHour {
			continue
		}
		if shouldSendRecap(monday.Add(time.Duration(h-recapNotifyHour) * time.Hour)) {
			t.Errorf("соати %d низ оғоз шуд", h)
		}
	}

	// Рӯзҳои дигари ҳафта.
	for d := 1; d < 7; d++ {
		if shouldSendRecap(monday.AddDate(0, 0, d)) {
			t.Errorf("рӯзи +%d оғоз шуд", d)
		}
	}
}

// Минтақаи вақти сервер набояд ҷадвалро тағйир диҳад.
func TestRecapScheduleIsUTC(t *testing.T) {
	utc := time.Date(2026, 9, 7, recapNotifyHour, 30, 0, 0, time.UTC)
	east := utc.In(time.FixedZone("UTC+5", 5*3600))
	if shouldSendRecap(utc) != shouldSendRecap(east) {
		t.Error("натиҷа аз минтақаи вақт вобаста аст")
	}
}

// Ҳафтаи ҷамъбаст — ҳафтаи ГУЗАШТАи пурра, на ҳафтаи ҷорӣ.
func TestRecapWeekIsThePreviousOne(t *testing.T) {
	monday := time.Date(2026, 9, 7, recapNotifyHour, 0, 0, 0, time.UTC)
	week := recapWeekFor(monday)
	if got := week.Format("2006-01-02"); got != "2026-08-31" {
		t.Errorf("ҳафта: %s, интизори 2026-08-31", got)
	}
	if week.Weekday() != time.Monday {
		t.Errorf("оғози ҳафта рӯзи %v", week.Weekday())
	}
	// Ҳафта бояд ПУРРА гузашта бошад.
	if !week.AddDate(0, 0, 7).Before(monday.Add(time.Second)) {
		t.Error("ҳафтаи нопурра интихоб шуд")
	}
}

// Такрори кор дар ҳамон ҳафта огоҳиномаи дуюм намедиҳад.
func TestRecapIsSentOnlyOncePerWeek(t *testing.T) {
	if os.Getenv("RAONSON_TEST_DB") == "" {
		t.Skip("RAONSON_TEST_DB гузошта нашудааст")
	}
	db.Init()
	if db.Pool == nil {
		t.Fatal("ба база пайваст нашуд")
	}
	ctx := context.Background()

	var user string
	if err := db.Pool.QueryRow(ctx, `
		INSERT INTO users(username, email, password)
		VALUES ($1,$2,'x') RETURNING id`,
		"recap_"+itoaTest(int(time.Now().UnixNano()%1e9)),
		"r"+itoaTest(int(time.Now().UnixNano()%1e9))+"@t.tj").Scan(&user); err != nil {
		t.Fatal(err)
	}

	week := time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 6; i++ {
		if _, err := db.Pool.Exec(ctx, `
			INSERT INTO feed_events(user_id, event, created_at)
			VALUES ($1,'LIKE',$2)`, user, week.AddDate(0, 0, 1)); err != nil {
			t.Fatal(err)
		}
	}

	before := deliveryCount(t, user)
	sendWeeklyRecaps(ctx, week)
	after := deliveryCount(t, user)
	if after-before != 1 {
		t.Fatalf("аввалин иҷро %d сатр сохт, интизори 1", after-before)
	}

	// Такрор — ҳеҷ чиз.
	sendWeeklyRecaps(ctx, week)
	sendWeeklyRecaps(ctx, week)
	if deliveryCount(t, user) != after {
		t.Error("такрори кор огоҳиномаи дуюм дод")
	}
}

// Корбари ғайрифаъол ҷамъбасти холӣ намегирад.
func TestQuietUserGetsNoRecap(t *testing.T) {
	if os.Getenv("RAONSON_TEST_DB") == "" {
		t.Skip("RAONSON_TEST_DB гузошта нашудааст")
	}
	db.Init()
	ctx := context.Background()

	var user string
	n := itoaTest(int(time.Now().UnixNano() % 1e9))
	if err := db.Pool.QueryRow(ctx, `
		INSERT INTO users(username, email, password)
		VALUES ($1,$2,'x') RETURNING id`,
		"quiet_"+n, "q"+n+"@t.tj").Scan(&user); err != nil {
		t.Fatal(err)
	}
	// Як ҳодиса — аз ҳадди ақал камтар.
	week := time.Date(2026, 8, 31, 0, 0, 0, 0, time.UTC)
	db.Pool.Exec(ctx, `
		INSERT INTO feed_events(user_id, event, created_at)
		VALUES ($1,'LIKE',$2)`, user, week.AddDate(0, 0, 1))

	sendWeeklyRecaps(ctx, week)
	if deliveryCount(t, user) != 0 {
		t.Error("корбари ғайрифаъол ҷамъбаст гирифт")
	}
}

func deliveryCount(t *testing.T, user string) int {
	t.Helper()
	var n int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM notification_delivery WHERE user_id=$1`,
		user).Scan(&n)
	return n
}

func itoaTest(n int) string {
	if n == 0 {
		return "0"
	}
	var b [20]byte
	i := len(b)
	for n > 0 {
		i--
		b[i] = byte('0' + n%10)
		n /= 10
	}
	return string(b[i:])
}
