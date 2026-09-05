package push

// Идораи токенҳои дастгоҳ.
//
// Токен сир аст: он ҳеҷ гоҳ ба client ё ба log намеравад.

import (
	"context"
	"strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// DB — ҳадди ақали интерфейси лозим.
type DB interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Device — як дастгоҳи фаъол.
type Device struct {
	Token    string
	Platform string
}

// normalizePlatform платформаро ба қимати шинохта меорад.
//
// Client қаблӣ 'fcm' мефиристод — на android ва на ios. Бо ҷадвали
// кӯҳна ин маънои онро дошт, ки ҲАМА дастгоҳҳои корбар ба ЯК сатр
// меафтоданд ва ҳамдигарро мепӯшониданд.
func normalizePlatform(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "ios", "apns":
		return "ios"
	default:
		return "android"
	}
}

// SaveToken токени дастгоҳро сабт мекунад.
//
// Як дастгоҳ — як сатр. Агар ҳамон дастгоҳ токени нав гирад, сатри
// кӯҳнаи ҳамон дастгоҳ пок мешавад, вагарна огоҳинома ба токени
// мурда мерафт.
func SaveToken(ctx context.Context, db DB, userID, token, platform,
	deviceID string) error {
	token = strings.TrimSpace(token)
	if userID == "" || token == "" {
		return nil
	}
	p := normalizePlatform(platform)
	deviceID = strings.TrimSpace(deviceID)

	if deviceID != "" {
		// Ҳамон дастгоҳ, токени дигар — кӯҳнаро мебарем.
		db.Exec(ctx, `
			DELETE FROM device_tokens
			WHERE user_id=$1 AND device_id=$2 AND device_id <> '' AND token <> $3`,
			userID, deviceID, token)
	}

	// Токен метавонад ба корбари дигар гузарад (дастгоҳи муштарак):
	// он вақт соҳиби нав сабт мешавад.
	_, err := db.Exec(ctx, `
		INSERT INTO device_tokens(token, user_id, platform, device_id)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (token) DO UPDATE SET
		  user_id         = EXCLUDED.user_id,
		  platform        = EXCLUDED.platform,
		  device_id       = EXCLUDED.device_id,
		  enabled         = TRUE,
		  disabled_reason = '',
		  fail_count      = 0,
		  updated_at      = NOW(),
		  last_seen_at    = NOW()`,
		token, userID, p, deviceID)
	return err
}

// DeleteToken токенро мебарад (баромадан аз аккаунт).
func DeleteToken(ctx context.Context, db DB, userID, token string) error {
	if token == "" {
		return nil
	}
	_, err := db.Exec(ctx,
		`DELETE FROM device_tokens WHERE token=$1 AND user_id=$2`,
		token, userID)
	return err
}

// DevicesFor дастгоҳҳои фаъоли корбарро мегирад.
func DevicesFor(ctx context.Context, db DB, userID string) ([]Device, error) {
	rows, err := db.Query(ctx, `
		SELECT token, platform FROM device_tokens
		WHERE user_id=$1 AND enabled
		ORDER BY last_seen_at DESC
		LIMIT 20`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := []Device{}
	for rows.Next() {
		var d Device
		if err := rows.Scan(&d.Token, &d.Platform); err != nil {
			continue
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// DisableToken токени мурдаро хомӯш мекунад.
//
// Сатр НЕСТ карда намешавад: сабаб барои ташхис лозим аст — «чаро
// огоҳинома намеояд» бе ин ҷавоб надорад.
func DisableToken(ctx context.Context, db DB, token, reason string) error {
	if token == "" {
		return nil
	}
	_, err := db.Exec(ctx, `
		UPDATE device_tokens
		   SET enabled=FALSE, disabled_reason=$2, updated_at=NOW()
		 WHERE token=$1`, token, reason)
	return err
}

// NoteFailure хатои муваққатиро сабт мекунад.
//
// Токен фавран хомӯш НАМЕШАВАД: хатои шабака айби дастгоҳ нест.
func NoteFailure(ctx context.Context, db DB, token string) {
	if token == "" {
		return
	}
	db.Exec(ctx, `
		UPDATE device_tokens
		   SET fail_count = fail_count + 1, updated_at = NOW()
		 WHERE token=$1`, token)
}

// NoteSuccess ҳисоби хаторо аз нав сифр мекунад.
func NoteSuccess(ctx context.Context, db DB, token string) {
	if token == "" {
		return
	}
	db.Exec(ctx, `
		UPDATE device_tokens
		   SET fail_count = 0, last_seen_at = NOW(), updated_at = NOW()
		 WHERE token=$1`, token)
}
