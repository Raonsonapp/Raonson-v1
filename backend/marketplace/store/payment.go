package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/domain"
	"raonson/marketplace/ledger"
	"raonson/marketplace/money"
)

// PaymentOrder — сатри payment_orders.
type PaymentOrder struct {
	ID                string
	CampaignID        string
	AdvertiserID      string
	Amount            money.Amount
	Status            domain.PaymentStatus
	Provider          string
	ProviderReference string
	IdempotencyKey    string
}

var ErrAmountMismatch = errors.New("store: маблағи webhook ба фармоиш мувофиқ нест")

// CreatePaymentOrder фармоиши пардохт месозад.
//
// Маблағ ҲАМЕША аз кампанияи дар DB буда гирифта мешавад — client
// онро таъин карда наметавонад. idempotency_key UNIQUE аст, бинобар
// ин такрори дархост фармоиши мавҷударо бармегардонад, на нав.
func CreatePaymentOrder(ctx context.Context, tx Tx, campaignID, advertiserID,
	provider, idempotencyKey string) (PaymentOrder, error) {

	// Маблағ ва ҳолатро аз кампания мегирем ва сатрро қуфл мекунем.
	var budget int64
	var cur, status string
	err := tx.QueryRow(ctx, `
		SELECT budget_minor, currency, status
		FROM campaigns WHERE id=$1 AND advertiser_id=$2
		FOR UPDATE`, campaignID, advertiserID).Scan(&budget, &cur, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		return PaymentOrder{}, domain.ErrNotFound
	}
	if err != nil {
		return PaymentOrder{}, fmt.Errorf("store: кампания: %w", err)
	}

	st := domain.CampaignStatus(status)
	// Пардохт танҳо аз DRAFT ё PENDING_PAYMENT маъно дорад.
	if st != domain.CampaignDraft && st != domain.CampaignPendingPayment {
		return PaymentOrder{}, fmt.Errorf("store: кампания дар ҳолати %s пардохт қабул намекунад", st)
	}
	currency, err := money.ParseCurrency(cur)
	if err != nil {
		return PaymentOrder{}, err
	}
	amt, err := money.New(money.Minor(budget), currency)
	if err != nil {
		return PaymentOrder{}, err
	}
	if amt.Minor <= 0 {
		return PaymentOrder{}, errors.New("store: буҷети кампания бояд мусбат бошад")
	}

	var o PaymentOrder
	var amountMinor int64
	var curOut, statusOut string
	err = tx.QueryRow(ctx, `
		INSERT INTO payment_orders
		  (campaign_id, advertiser_id, amount_minor, currency, status, provider, idempotency_key)
		VALUES ($1,$2,$3,$4,'CREATED',$5,$6)
		ON CONFLICT (idempotency_key) DO UPDATE
		  SET updated_at = NOW()
		RETURNING id, campaign_id, advertiser_id, amount_minor, currency, status,
		          provider, COALESCE(provider_reference,''), idempotency_key`,
		campaignID, advertiserID, int64(amt.Minor), string(currency), provider, idempotencyKey).
		Scan(&o.ID, &o.CampaignID, &o.AdvertiserID, &amountMinor, &curOut, &statusOut,
			&o.Provider, &o.ProviderReference, &o.IdempotencyKey)
	if err != nil {
		return PaymentOrder{}, fmt.Errorf("store: фармоиши пардохт: %w", err)
	}
	c2, _ := money.ParseCurrency(curOut)
	o.Amount = money.Amount{Minor: money.Minor(amountMinor), Currency: c2}
	o.Status = domain.PaymentStatus(statusOut)

	// Кампания ба PENDING_PAYMENT мегузарад (агар ҳанӯз набошад).
	if st == domain.CampaignDraft {
		if err := setCampaignStatus(ctx, tx, campaignID, st, domain.CampaignPendingPayment,
			advertiserID, "payment_order_created"); err != nil {
			return PaymentOrder{}, err
		}
	}
	return o, nil
}

// SetProviderReference reference-и provider-ро сабт мекунад.
func SetProviderReference(ctx context.Context, tx Tx, orderID, ref string, st domain.PaymentStatus) error {
	_, err := tx.Exec(ctx, `
		UPDATE payment_orders SET provider_reference=$2, status=$3, updated_at=NOW()
		WHERE id=$1`, orderID, ref, string(st))
	return err
}

// ApplyPaymentWebhook ҳодисаи webhook-ро дар як транзаксия татбиқ мекунад.
//
// Идемпотентӣ дар се сатҳ:
//  1. webhook_events UNIQUE(provider,event_id) — ҳамон ҳодиса ду бор коркард намешавад
//  2. state machine — гузариши такрорӣ ErrAlreadyInState медиҳад
//  3. ledger reference UNIQUE — сатрҳои дукарата навишта намешаванд
//
// Маблағи webhook бо маблағи фармоиш муқоиса мешавад: агар фарқ кунад,
// коркард рад мешавад — client ё provider маблағро тағйир дода наметавонад.
func ApplyPaymentWebhook(ctx context.Context, tx Tx, provider string,
	ev PaymentWebhookInput) (applied bool, err error) {

	// 1) Ҳодисаро сабт мекунем. Агар аллакай бошад — коркард намекунем.
	var eventRow int64
	err = tx.QueryRow(ctx, `
		INSERT INTO webhook_events(provider, event_id, event_type, payload, status)
		VALUES ($1,$2,$3,$4,'RECEIVED')
		ON CONFLICT (provider, event_id) DO NOTHING
		RETURNING id`, provider, ev.EventID, ev.EventType, ev.RawJSON).Scan(&eventRow)
	if errors.Is(err, pgx.ErrNoRows) {
		// Такрори webhook — ҷавоб бехатар, ҳеҷ таъсир.
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("store: сабти webhook: %w", err)
	}

	// 2) Фармоишро меёбем ва қуфл мекунем.
	var o PaymentOrder
	var amountMinor int64
	var cur, status string
	err = tx.QueryRow(ctx, `
		SELECT id, campaign_id, advertiser_id, amount_minor, currency, status
		FROM payment_orders
		WHERE provider=$1 AND provider_reference=$2
		FOR UPDATE`, provider, ev.ProviderReference).
		Scan(&o.ID, &o.CampaignID, &o.AdvertiserID, &amountMinor, &cur, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		_ = markWebhook(ctx, tx, eventRow, "IGNORED", "фармоиш ёфт нашуд")
		return false, domain.ErrNotFound
	}
	if err != nil {
		return false, fmt.Errorf("store: фармоиш: %w", err)
	}
	c, err := money.ParseCurrency(cur)
	if err != nil {
		return false, err
	}
	o.Amount = money.Amount{Minor: money.Minor(amountMinor), Currency: c}
	o.Status = domain.PaymentStatus(status)

	// 3) Маблағ бояд мувофиқ бошад — вагарна ин пардохти мо нест.
	if ev.Amount.Minor != o.Amount.Minor || ev.Amount.Currency != o.Amount.Currency {
		_ = markWebhook(ctx, tx, eventRow, "REJECTED", "маблағ мувофиқ нест")
		return false, ErrAmountMismatch
	}

	// 4) Гузариши ҳолат.
	if err := o.Status.Transition(ev.Status); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			_ = markWebhook(ctx, tx, eventRow, "DUPLICATE", "")
			return false, nil
		}
		_ = markWebhook(ctx, tx, eventRow, "REJECTED", err.Error())
		return false, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE payment_orders SET status=$2, failure_reason=$3, updated_at=NOW()
		WHERE id=$1`, o.ID, string(ev.Status), ev.FailureReason); err != nil {
		return false, err
	}

	// 5) Танҳо ҳангоми муваффақият: пул ба escrow ва кампания ба PAID.
	if ev.Status == domain.PaymentSucceeded {
		if err := creditEscrow(ctx, tx, o); err != nil {
			return false, err
		}
		if err := advanceCampaignToPaid(ctx, tx, o); err != nil {
			return false, err
		}
	}

	_ = markWebhook(ctx, tx, eventRow, "PROCESSED", "")
	_ = Audit(ctx, tx, "", "provider", "payment.webhook", "payment_order", o.ID,
		map[string]any{"status": ev.Status, "eventId": ev.EventID})
	return true, nil
}

// PaymentWebhookInput — ҳодисаи нормализашуда аз provider adapter.
type PaymentWebhookInput struct {
	EventID           string
	EventType         string
	ProviderReference string
	Status            domain.PaymentStatus
	Amount            money.Amount
	FailureReason     string
	RawJSON           string
}

// creditEscrow пулро аз ҳисоби provider ба escrow-и кампания мегузаронад.
func creditEscrow(ctx context.Context, tx Tx, o PaymentOrder) error {
	settlement, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerProvider, o.Provider,
		ledger.PurposeSettlement, o.Amount.Currency)
	if err != nil {
		return err
	}
	escrow, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, o.CampaignID,
		ledger.PurposeEscrow, o.Amount.Currency)
	if err != nil {
		return err
	}
	// reference = id-и фармоиш → ledger ҳеҷ гоҳ ду бор навишта намешавад.
	_, err = ledger.Transfer(ctx, tx, "PAYMENT_CAPTURED", o.CampaignID,
		"payment:"+o.ID, "буҷети кампания", settlement, escrow, o.Amount)
	if errors.Is(err, ledger.ErrDuplicateRef) {
		return nil // аллакай сабт шудааст
	}
	return err
}

func advanceCampaignToPaid(ctx context.Context, tx Tx, o PaymentOrder) error {
	var status string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM campaigns WHERE id=$1 FOR UPDATE`, o.CampaignID).Scan(&status); err != nil {
		return err
	}
	from := domain.CampaignStatus(status)
	if from == domain.CampaignPaid {
		return nil // аллакай
	}
	if err := from.Transition(domain.CampaignPaid); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			return nil
		}
		return err
	}
	return setCampaignStatus(ctx, tx, o.CampaignID, from, domain.CampaignPaid, "", "payment_succeeded")
}

func setCampaignStatus(ctx context.Context, tx Tx, campaignID string,
	from, to domain.CampaignStatus, actorID, reason string) error {
	if _, err := tx.Exec(ctx, `
		UPDATE campaigns SET status=$2, updated_at=NOW() WHERE id=$1`,
		campaignID, string(to)); err != nil {
		return err
	}
	return CampaignEvent(ctx, tx, campaignID, "", reason, string(from), string(to), actorID, nil)
}

func markWebhook(ctx context.Context, tx Tx, id int64, status, errMsg string) error {
	_, err := tx.Exec(ctx, `
		UPDATE webhook_events SET status=$2, error=$3, processed_at=NOW()
		WHERE id=$1`, id, status, errMsg)
	return err
}
