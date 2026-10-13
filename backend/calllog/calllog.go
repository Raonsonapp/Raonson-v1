// Package calllog — таърихи зангҳо: сабт аз ҳодисаҳои сокет ва хондан.
//
// Сабт аз `sockets` (call:offer/answer/decline/end/switch) ва хондан аз
// `handlers` (GET /calls/history). Мантиқи тоза (Classify, курсор) бе
// база санҷида мешавад.
package calllog

import (
	"context"
	"encoding/base64"
	"errors"
	"strings"
	"time"

	"raonson/db"
)

// Сабабҳои қатъ, ки дар end_reason нигоҳ дошта мешаванд.
const (
	ReasonCompleted = "completed" // гуфтугӯ шуд ва касе қатъ кард
	ReasonCancelled = "cancelled" // зангзананда пеш аз ҷавоб қатъ кард
	ReasonDeclined  = "declined"  // гиранда рад кард
	ReasonNoAnswer  = "no_answer" // касе ҷавоб надод (вақт гузашт)
	ReasonReplaced  = "replaced"  // занги нав сатри кушодаро баст
)

// RingTimeout — пас аз ин вақт сатри бе ҷавоб «ҷавоб надод» ҳисоб
// мешавад (барнома пас аз 60с худаш қатъ мекунад; каме захира).
const RingTimeout = 90 * time.Second

// MaxOpenCall — гуфтугӯи қабулшуда, ки ин қадар вақт қатъ нашуд, кушода
// ҳисоб намешавад (телефон хомӯш шуд ва call:end нафиристод).
const MaxOpenCall = 6 * time.Hour

// dedupeWindow — call:offer-и такрорӣ (масалан аз нав фиристодан) дар
// ин муддат сатри навро намесозад.
const dedupeWindow = 10 * time.Second

// ── Сабт ──────────────────────────────────────────────────────────

// Offer — зангзананда занг зад.
func Offer(caller, callee, callType string) {
	if db.Pool == nil || caller == "" || callee == "" || caller == callee {
		return
	}
	if callType != "video" {
		callType = "voice"
	}
	ctx := context.Background()
	// Такрор: ҳамон ҷуфт, ҳанӯз бе ҷавоб, хеле нав — нав намесозем.
	var exists bool
	_ = db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM call_logs
		  WHERE caller_id=$1 AND callee_id=$2 AND ended_at IS NULL
		    AND answered_at IS NULL AND started_at > NOW() - ($3 * INTERVAL '1 second'))`,
		caller, callee, int(dedupeWindow.Seconds())).Scan(&exists)
	if exists {
		return
	}
	// Ҳар занги кушодаи пешинаи зангзананда (бо ҳар кас) баста мешавад:
	// як нафар дар як вақт танҳо як занг дорад.
	_, _ = db.Pool.Exec(ctx,
		`UPDATE call_logs SET ended_at=NOW(),
		   end_reason=CASE WHEN answered_at IS NULL THEN $2 ELSE $3 END
		 WHERE ended_at IS NULL AND (caller_id=$1 OR callee_id=$1)`,
		caller, ReasonReplaced, ReasonCompleted)
	_, _ = db.Pool.Exec(ctx,
		`INSERT INTO call_logs (caller_id, callee_id, call_type, video_used)
		 VALUES ($1, $2, $3, $4)`,
		caller, callee, callType, callType == "video")
}

// Answer — гиранда (callee) қабул кард.
func Answer(callee, caller string) {
	if db.Pool == nil || callee == "" || caller == "" {
		return
	}
	_, _ = db.Pool.Exec(context.Background(),
		`UPDATE call_logs SET answered_at=NOW()
		 WHERE id = (SELECT id FROM call_logs
		   WHERE caller_id=$1 AND callee_id=$2 AND ended_at IS NULL
		     AND answered_at IS NULL
		   ORDER BY started_at DESC LIMIT 1)`, caller, callee)
}

// Decline — гиранда рад кард.
func Decline(callee, caller string) {
	if db.Pool == nil || callee == "" || caller == "" {
		return
	}
	_, _ = db.Pool.Exec(context.Background(),
		`UPDATE call_logs SET ended_at=NOW(), end_reason=$3
		 WHERE id = (SELECT id FROM call_logs
		   WHERE caller_id=$1 AND callee_id=$2 AND ended_at IS NULL
		     AND answered_at IS NULL
		   ORDER BY started_at DESC LIMIT 1)`, caller, callee, ReasonDeclined)
}

// End — яке аз ду тараф қатъ кард (call:end аз [from] ба [to]).
func End(from, to string) {
	if db.Pool == nil || from == "" || to == "" {
		return
	}
	_, _ = db.Pool.Exec(context.Background(),
		`UPDATE call_logs SET ended_at=NOW(),
		   end_reason=CASE
		     WHEN answered_at IS NOT NULL THEN $3
		     WHEN caller_id=$1 THEN $4
		     ELSE $5 END
		 WHERE id = (SELECT id FROM call_logs
		   WHERE ended_at IS NULL
		     AND ((caller_id=$1 AND callee_id=$2) OR (caller_id=$2 AND callee_id=$1))
		   ORDER BY started_at DESC LIMIT 1)`,
		from, to, ReasonCompleted, ReasonCancelled, ReasonDeclined)
}

// VideoUsed — гуфтугӯи аудио ба видео гузашт (бо розигии ҳарду).
func VideoUsed(a, b string) {
	if db.Pool == nil || a == "" || b == "" {
		return
	}
	_, _ = db.Pool.Exec(context.Background(),
		`UPDATE call_logs SET video_used=TRUE
		 WHERE ended_at IS NULL
		   AND ((caller_id=$1 AND callee_id=$2) OR (caller_id=$2 AND callee_id=$1))`,
		a, b)
}

// ── Тасниф ────────────────────────────────────────────────────────

// Row — як сатри call_logs.
type Row struct {
	ID         string
	CallerID   string
	CalleeID   string
	CallType   string
	VideoUsed  bool
	StartedAt  time.Time
	AnsweredAt *time.Time
	EndedAt    *time.Time
	EndReason  string
}

// View — сатр аз нигоҳи корбари [me].
type View struct {
	Direction string // "outgoing" | "incoming"
	// Status: "completed" | "missed" (ба ман занг заданд, ҷавоб надодам) |
	// "declined" | "cancelled" | "no_answer" | "ringing" | "ongoing".
	Status      string
	DurationSec int
	EndedAt     *time.Time
}

// Classify — ҳолати сатр барои [me] дар лаҳзаи [now].
//
// Сатри кушода, ки вақташ гузаштааст, ҳамчун тамомшуда нишон дода
// мешавад: бе ҷавоб → «ҷавоб надод»/«аздастрафта»; қабулшуда → бо
// давомнокии номаълум (0).
func Classify(r Row, me string, now time.Time) View {
	v := View{Direction: "incoming"}
	if r.CallerID == me {
		v.Direction = "outgoing"
	}
	reason := r.EndReason
	ended := r.EndedAt
	if ended == nil {
		switch {
		case r.AnsweredAt == nil && now.Sub(r.StartedAt) > RingTimeout:
			reason = ReasonNoAnswer
		case r.AnsweredAt != nil && now.Sub(*r.AnsweredAt) > MaxOpenCall:
			reason = ReasonCompleted
		case r.AnsweredAt == nil:
			v.Status = "ringing"
			return v
		default:
			v.Status = "ongoing"
			v.DurationSec = int(now.Sub(*r.AnsweredAt).Seconds())
			return v
		}
	}
	v.EndedAt = ended
	if r.AnsweredAt != nil {
		v.Status = "completed"
		if ended != nil && ended.After(*r.AnsweredAt) {
			v.DurationSec = int(ended.Sub(*r.AnsweredAt).Seconds())
		}
		return v
	}
	if v.Direction == "incoming" {
		if reason == ReasonDeclined {
			v.Status = "declined"
		} else {
			v.Status = "missed"
		}
		return v
	}
	switch reason {
	case ReasonDeclined:
		v.Status = "declined"
	case ReasonNoAnswer:
		v.Status = "no_answer"
	default:
		v.Status = "cancelled"
	}
	return v
}

// ── Курсор ────────────────────────────────────────────────────────

// Cursor — мавқеи саҳифа: (started_at, id) — тартиби камшаванда.
type Cursor struct {
	At time.Time
	ID string
}

// Encode — сатри шаффоф барои муштарӣ.
func (c Cursor) Encode() string {
	raw := c.At.UTC().Format(time.RFC3339Nano) + "|" + c.ID
	return base64.RawURLEncoding.EncodeToString([]byte(raw))
}

// ErrBadCursor — курсори вайрон.
var ErrBadCursor = errors.New("bad cursor")

// DecodeCursor — баръакси Encode. Сатри холӣ → (nil, nil).
func DecodeCursor(s string) (*Cursor, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return nil, nil
	}
	b, err := base64.RawURLEncoding.DecodeString(s)
	if err != nil {
		return nil, ErrBadCursor
	}
	at, id, ok := strings.Cut(string(b), "|")
	if !ok || id == "" {
		return nil, ErrBadCursor
	}
	t, err := time.Parse(time.RFC3339Nano, at)
	if err != nil {
		return nil, ErrBadCursor
	}
	return &Cursor{At: t, ID: id}, nil
}

// ClampLimit — андозаи саҳифа: пешфарз 30, ҳадди аксар 50.
func ClampLimit(n int) int {
	switch {
	case n <= 0:
		return 30
	case n > 50:
		return 50
	}
	return n
}

// ── Хондан ────────────────────────────────────────────────────────

// Peer — ҳамсӯҳбат дар сатри таърих.
type Peer struct {
	ID       string
	Username string
	Avatar   string
	Verified bool
}

// Entry — сатри таърих бо ҳамсӯҳбат.
type Entry struct {
	Row
	Peer Peer
}

// History — таърихи [me], навтарин аввал.
//
// Сатрҳо бо корбари басташуда (ҳар ду самт), ҳисобҳои несткардашуда ва
// сатрҳои «аз таърих несткарда» нишон дода намешаванд. [limit]+1 сатр
// хонда мешавад, то маълум шавад саҳифаи дигар ҳаст ё не.
func History(ctx context.Context, me string, cur *Cursor, limit int) ([]Entry, *Cursor, error) {
	limit = ClampLimit(limit)
	args := []interface{}{me, limit + 1}
	where := ""
	if cur != nil {
		args = append(args, cur.At, cur.ID)
		where = ` AND (l.started_at, l.id) < ($3, $4)`
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT l.id, l.caller_id, l.callee_id, l.call_type, l.video_used,
		       l.started_at, l.answered_at, l.ended_at, COALESCE(l.end_reason,''),
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		FROM call_logs l
		JOIN users u ON u.id = CASE WHEN l.caller_id=$1 THEN l.callee_id ELSE l.caller_id END
		WHERE ((l.caller_id=$1 AND NOT l.hidden_for_caller)
		    OR (l.callee_id=$1 AND NOT l.hidden_for_callee))
		  AND NOT EXISTS (SELECT 1 FROM blocks b
		      WHERE (b.blocker_id=$1 AND b.blocked_id=u.id)
		         OR (b.blocker_id=u.id AND b.blocked_id=$1))`+where+`
		ORDER BY l.started_at DESC, l.id DESC
		LIMIT $2`, args...)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()
	out := make([]Entry, 0, limit)
	for rows.Next() {
		var e Entry
		if err := rows.Scan(&e.ID, &e.CallerID, &e.CalleeID, &e.CallType, &e.VideoUsed,
			&e.StartedAt, &e.AnsweredAt, &e.EndedAt, &e.EndReason,
			&e.Peer.ID, &e.Peer.Username, &e.Peer.Avatar, &e.Peer.Verified); err != nil {
			return nil, nil, err
		}
		out = append(out, e)
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}
	var next *Cursor
	if len(out) > limit {
		out = out[:limit]
		last := out[len(out)-1]
		next = &Cursor{At: last.StartedAt, ID: last.ID}
	}
	return out, next, nil
}

// Hide — сатрро аз таърихи [me] нест мекунад (ҳамсӯҳбат онро нигоҳ
// медорад). [id] == "" — ҳамаи таърих. Шумораи сатрҳоро бармегардонад.
func Hide(ctx context.Context, me, id string) (int64, error) {
	q := `UPDATE call_logs SET
	        hidden_for_caller = hidden_for_caller OR caller_id=$1,
	        hidden_for_callee = hidden_for_callee OR callee_id=$1
	      WHERE (caller_id=$1 OR callee_id=$1)`
	args := []interface{}{me}
	if id != "" {
		q += ` AND id=$2`
		args = append(args, id)
	}
	tag, err := db.Pool.Exec(ctx, q, args...)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}
