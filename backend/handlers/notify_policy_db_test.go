package handlers

// Санҷиши хониши танзимот аз ҷадвали ВОҚЕӢ.
//
// Мантиқи соатҳои ором дар notify_policy_test.go бе базаи маълумот
// санҷида мешавад. Ин ҷо танҳо як чиз санҷида мешавад: оё JSON-и
// нигоҳдошта дуруст хонда мешавад — маҳз ҳамин ҷо шакли калидҳо
// метавонад бо client фарқ кунад ва хатогӣ хомӯш бимонад.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"context"
	"os"
	"testing"
	"time"

	"raonson/db"
)

func TestLoadNotifPrefsReadsStoredJSON(t *testing.T) {
	if os.Getenv("RAONSON_TEST_DB") == "" {
		t.Skip("RAONSON_TEST_DB гузошта нашудааст")
	}
	db.Init()
	if db.Pool == nil {
		t.Fatal("ба база пайваст нашуд")
	}
	ctx := context.Background()

	var userID string
	if err := db.Pool.QueryRow(ctx,
		`SELECT id FROM users LIMIT 1`).Scan(&userID); err != nil {
		t.Skipf("корбари санҷишӣ нест: %v", err)
	}

	// Ҳамон шакле, ки барнома мефиристад.
	if _, err := db.Pool.Exec(ctx, `
		UPDATE users SET notif_prefs = $1::jsonb WHERE id=$2`,
		`{"push":true,"quietHours":{"enabled":true,"startHour":23,`+
			`"endHour":8,"tzOffsetMinutes":300}}`, userID); err != nil {
		t.Fatal(err)
	}

	p := loadNotifPrefs(userID)
	if !p.QuietHours.Enabled {
		t.Fatal("enabled хонда нашуд")
	}
	if p.QuietHours.StartHour == nil || *p.QuietHours.StartHour != 23 {
		t.Errorf("startHour: %v", p.QuietHours.StartHour)
	}
	if p.QuietHours.TZOffsetMinutes == nil ||
		*p.QuietHours.TZOffsetMinutes != 300 {
		t.Errorf("tzOffsetMinutes: %v", p.QuietHours.TZOffsetMinutes)
	}

	// UTC+5: 19:30 UTC = 00:30 маҳаллӣ.
	if !inQuietHours(p, time.Date(2026, 9, 5, 19, 30, 0, 0, time.UTC)) {
		t.Error("нимишаби маҳаллӣ ором ҳисоб нашуд")
	}

	// Корбари бе танзимот набояд хомӯш шавад.
	if _, err := db.Pool.Exec(ctx,
		`UPDATE users SET notif_prefs = '{}'::jsonb WHERE id=$1`,
		userID); err != nil {
		t.Fatal(err)
	}
	if inQuietHours(loadNotifPrefs(userID), time.Now()) {
		t.Error("бе танзимот набояд ором бошад")
	}
}
