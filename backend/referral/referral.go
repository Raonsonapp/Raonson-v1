// Package referral даъвати органикӣ ва ҳисоби он.
//
// Ҳеҷ мукофот ва ҳеҷ ваъда: ин ҷо танҳо сабт мешавад, ки кӣ киро
// овард. Мукофоти пулӣ қарори тиҷоратӣ аст ва бе он ихтироъ намешавад.
//
// Ҳама ҳисоб дар СЕРВЕР: client наметавонад бигӯяд «ман 50 кас
// овардам». Мансубият танҳо ҳангоми БАҚАЙДГИРӢ як бор сабт мешавад ва
// баъдан тағйир дода намешавад.
package referral

import (
	"context"
	"crypto/rand"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// DB — ҳадди ақали интерфейси лозим.
type DB interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// codeAlphabet — бе аломатҳои ба ҳам монанд (0/O, 1/I/L).
//
// Код бо забон гуфта ва бо даст навишта мешавад; хатои як ҳарф
// корбарро ба даъвати каси дигар мебарад.
const codeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"

// codeLength — 8 аломат аз 31 ⇒ тахминан 8·10¹¹ вариант.
const codeLength = 8

// NewCode коди тасодуфиро месозад.
func NewCode() (string, error) {
	b := make([]byte, codeLength)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	out := make([]byte, codeLength)
	for i, v := range b {
		out[i] = codeAlphabet[int(v)%len(codeAlphabet)]
	}
	return string(out), nil
}

// NormalizeCode кодро барои муқоиса тайёр мекунад.
//
// Корбар кодро бо ҳарфи хурд ё бо фосила ворид карда метавонад.
func NormalizeCode(s string) string {
	return strings.ToUpper(strings.TrimSpace(s))
}

// GetOrCreateCode коди даъвати корбарро мегирад.
//
// Код доимист: линке, ки корбар паҳн кард, набояд рӯзи дигар бекор
// шавад.
func GetOrCreateCode(ctx context.Context, db DB, userID string) (string, error) {
	var code string
	err := db.QueryRow(ctx,
		`SELECT code FROM referral_codes WHERE user_id=$1`, userID).Scan(&code)
	if err == nil && code != "" {
		return code, nil
	}

	// Бархӯрди код камэҳтимол аст, вале имконнопазир не.
	for attempt := 0; attempt < 5; attempt++ {
		c, err := NewCode()
		if err != nil {
			return "", err
		}
		var stored string
		err = db.QueryRow(ctx, `
			INSERT INTO referral_codes(user_id, code) VALUES ($1,$2)
			ON CONFLICT (user_id) DO UPDATE SET code = referral_codes.code
			RETURNING code`, userID, c).Scan(&stored)
		if err == nil {
			return stored, nil
		}
	}
	return "", fmt.Errorf("referral: код сохта нашуд")
}

// Attribute даъватро сабт мекунад.
//
// Қоидаҳо:
//   - танҳо як бор барои ҳар корбари нав (PRIMARY KEY);
//   - худдаъваткунӣ рад мешавад;
//   - коди номаълум хато НЕСТ — бақайдгирӣ бояд идома ёбад.
//
// Хато танҳо ҳангоми мушкили база бармегардад; «код ёфт нашуд»
// ҳамчун false бармегардад.
func Attribute(ctx context.Context, db DB, inviteeID, rawCode string) (bool, error) {
	code := NormalizeCode(rawCode)
	if code == "" || inviteeID == "" {
		return false, nil
	}

	var inviterID string
	err := db.QueryRow(ctx,
		`SELECT user_id FROM referral_codes WHERE code=$1`, code).Scan(&inviterID)
	if err != nil || inviterID == "" {
		return false, nil
	}
	if inviterID == inviteeID {
		return false, nil
	}

	ct, err := db.Exec(ctx, `
		INSERT INTO referrals(invitee_id, inviter_id, code)
		VALUES ($1,$2,$3)
		ON CONFLICT (invitee_id) DO NOTHING`, inviteeID, inviterID, code)
	if err != nil {
		return false, err
	}
	return ct.RowsAffected() > 0, nil
}

// Invitee — касе, ки бо даъват омад.
type Invitee struct {
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
	JoinedAt string `json:"joinedAt"`
}

// Summary — ҳисоби даъватҳои корбар.
type Summary struct {
	Code string `json:"code"`
	// Joined — шумораи ҳамаи касоне, ки бо коди ин корбар омаданд.
	Joined int       `json:"joined"`
	Recent []Invitee `json:"recent"`
	// InvitedBy — коди касе, ки худи ин корбарро овард (агар бошад).
	InvitedBy string `json:"invitedBy,omitempty"`
}

// GetSummary ҳисоби воқеиро мегирад.
func GetSummary(ctx context.Context, db DB, userID string, limit int) (Summary, error) {
	if limit <= 0 || limit > 50 {
		limit = 20
	}
	code, err := GetOrCreateCode(ctx, db, userID)
	if err != nil {
		return Summary{}, err
	}
	s := Summary{Code: code, Recent: []Invitee{}}

	if err := db.QueryRow(ctx,
		`SELECT COUNT(*) FROM referrals WHERE inviter_id=$1`,
		userID).Scan(&s.Joined); err != nil {
		return Summary{}, err
	}

	// Корбари нестшуда дар рӯйхат намемонад.
	rows, err := db.Query(ctx, `
		SELECT u.id, u.username, COALESCE(u.avatar,''), r.created_at
		FROM referrals r
		JOIN users u ON u.id = r.invitee_id
		WHERE r.inviter_id=$1
		ORDER BY r.created_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return s, nil
	}
	defer rows.Close()
	for rows.Next() {
		var in Invitee
		var at time.Time
		if err := rows.Scan(&in.UserID, &in.Username, &in.Avatar, &at); err != nil {
			continue
		}
		in.JoinedAt = at.UTC().Format(time.RFC3339)
		s.Recent = append(s.Recent, in)
	}

	db.QueryRow(ctx, `SELECT code FROM referrals WHERE invitee_id=$1`,
		userID).Scan(&s.InvitedBy)
	return s, nil
}
