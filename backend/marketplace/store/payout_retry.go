package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

// maxPayoutAttempts — баъди ин шумора кӯшиш худкор қатъ мешавад ва
// payout интизори баррасии дастӣ мемонад.
//
// Такрори беохир хатарнок аст: агар хато доимӣ бошад (масалан
// реквизити нодуруст), ҳазор кӯшиш онро дуруст намекунад ва танҳо
// provider-ро бор мекунад.
const maxPayoutAttempts = 6

// PayoutBackoff таъхири кӯшиши навбатиро ҳисоб мекунад.
//
// Афзоиши экспоненсиалӣ: 1, 2, 4, 8, 16, 32 дақиқа. Ҳадди боло
// мемонад, то интизорӣ беохир дароз нашавад.
func PayoutBackoff(attempts int) time.Duration {
	if attempts < 0 {
		attempts = 0
	}
	if attempts > 5 {
		attempts = 5
	}
	return time.Duration(1<<uint(attempts)) * time.Minute
}

// DuePayout — фармоише, ки омодаи кӯшиш аст.
type DuePayout struct {
	ID         string
	CampaignID string
	CreatorID  string
	Amount     money.Amount
	Provider   string
	Status     domain.PayoutStatus
	Attempts   int
}

// DuePayouts фармоишҳоро мегирад, ки вақти кӯшишашон расидааст.
//
// FOR UPDATE SKIP LOCKED — агар ду нусхаи сервер кор кунанд, ҳар
// фармоишро танҳо яке мегирад ва пардохти дукарата рух намедиҳад.
func DuePayouts(ctx context.Context, tx Tx, limit int) ([]DuePayout, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	rows, err := tx.Query(ctx, `
		SELECT id, campaign_id, creator_id, amount_minor, currency,
		       provider, status, COALESCE(attempts,0)
		FROM payout_orders
		WHERE status IN ('PENDING','FAILED')
		  AND COALESCE(attempts,0) < $1
		  AND (next_attempt_at IS NULL OR next_attempt_at <= NOW())
		ORDER BY created_at ASC
		LIMIT $2
		FOR UPDATE SKIP LOCKED`, maxPayoutAttempts, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []DuePayout{}
	for rows.Next() {
		var p DuePayout
		var amt int64
		var cur, st string
		if err := rows.Scan(&p.ID, &p.CampaignID, &p.CreatorID, &amt, &cur,
			&p.Provider, &st, &p.Attempts); err != nil {
			continue
		}
		c, _ := money.ParseCurrency(cur)
		p.Amount = money.Amount{Minor: money.Minor(amt), Currency: c}
		p.Status = domain.PayoutStatus(st)
		out = append(out, p)
	}
	return out, rows.Err()
}

// MarkPayoutAttempt натиҷаи як кӯшишро сабт мекунад.
//
// Ҳангоми нокомӣ вақти кӯшиши навбатӣ бо афзоиши экспоненсиалӣ
// гузошта мешавад. Баъди maxPayoutAttempts payout дигар худкор
// такрор намешавад — он ба REQUIRES_ACTION мегузарад, то оператор
// бинад, на ин ки хомӯш нест шавад.
func MarkPayoutAttempt(ctx context.Context, tx Tx, payoutID string,
	to domain.PayoutStatus, reason string) error {
	var cur string
	var attempts int
	if err := tx.QueryRow(ctx, `
		SELECT status, COALESCE(attempts,0) FROM payout_orders
		WHERE id=$1 FOR UPDATE`, payoutID).Scan(&cur, &attempts); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return err
	}
	attempts++

	from := domain.PayoutStatus(cur)
	target := to
	if to == domain.PayoutFailed && attempts >= maxPayoutAttempts {
		// Кӯшишҳо тамом шуданд — дасти одам лозим аст.
		target = domain.PayoutRequiresAction
	}
	if err := from.Transition(target); err != nil {
		if !errors.Is(err, domain.ErrAlreadyInState) {
			return fmt.Errorf("store: кӯшиши payout: %w", err)
		}
	}

	next := time.Now().Add(PayoutBackoff(attempts))
	if _, err := tx.Exec(ctx, `
		UPDATE payout_orders
		SET status=$2, failure_reason=$3, attempts=$4, next_attempt_at=$5, updated_at=NOW()
		WHERE id=$1`, payoutID, string(target), reason, attempts, next); err != nil {
		return err
	}
	_ = Audit(ctx, tx, "", "system", "payout.attempt", "payout_order", payoutID,
		map[string]any{"status": target, "attempts": attempts, "reason": reason})
	return nil
}

// SetPayoutReference reference-и provider-ро сабт мекунад.
func SetPayoutReference(ctx context.Context, tx Tx, payoutID, ref string,
	st domain.PayoutStatus) error {
	_, err := tx.Exec(ctx, `
		UPDATE payout_orders
		SET provider_reference=$2, status=$3, updated_at=NOW()
		WHERE id=$1`, payoutID, ref, string(st))
	return err
}
