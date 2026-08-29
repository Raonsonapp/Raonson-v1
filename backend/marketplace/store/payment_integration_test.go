package store

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/marketplace/domain"
	"raonson/marketplace/ledger"
	"raonson/marketplace/money"
)

// seedCampaign рекламадиҳанда ва кампанияи омодаи пардохт месозад.
func seedCampaign(t *testing.T, pool *pgxpool.Pool, budgetMinor int64, commissionBPS int) (advID, campID string) {
	t.Helper()
	ctx := context.Background()
	if err := pool.QueryRow(ctx, `
		INSERT INTO advertisers(user_id, company_name) VALUES ('u_adv','Test Co')
		RETURNING id`).Scan(&advID); err != nil {
		t.Fatalf("advertiser: %v", err)
	}
	if err := pool.QueryRow(ctx, `
		INSERT INTO campaigns(advertiser_id,title,budget_minor,currency,status,commission_bps)
		VALUES ($1,'Test',$2,'TJS','DRAFT',$3) RETURNING id`,
		advID, budgetMinor, commissionBPS).Scan(&campID); err != nil {
		t.Fatalf("campaign: %v", err)
	}
	return advID, campID
}

func succeededWebhook(ref string, minor int64) PaymentWebhookInput {
	return PaymentWebhookInput{
		EventID:           "evt_1",
		EventType:         "payment.succeeded",
		ProviderReference: ref,
		Status:            domain.PaymentSucceeded,
		Amount:            money.MustNew(money.Minor(minor), money.TJS),
		RawJSON:           `{}`,
	}
}

func TestPaymentWebhookIsIdempotent(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	_, campID := seedCampaign(t, pool, 50000, 1000)

	// Фармоиши пардохт
	var order PaymentOrder
	runTx(t, pool, func(tx Tx) error {
		var err error
		order, err = CreatePaymentOrder(ctx, tx, campID, advOf(t, pool), "mock", "idem-1")
		if err != nil {
			return err
		}
		return SetProviderReference(ctx, tx, order.ID, "mock_ref_1", domain.PaymentPending)
	})

	ev := succeededWebhook("mock_ref_1", 50000)

	// Бори аввал — бояд татбиқ шавад.
	var applied bool
	runTx(t, pool, func(tx Tx) error {
		var err error
		applied, err = ApplyPaymentWebhook(ctx, tx, "mock", ev)
		return err
	})
	if !applied {
		t.Fatal("webhook-и аввал бояд татбиқ шавад")
	}

	// Бори дуюм — ҲАМОН event_id. Набояд дубора таъсир кунад.
	runTx(t, pool, func(tx Tx) error {
		var err error
		applied, err = ApplyPaymentWebhook(ctx, tx, "mock", ev)
		return err
	})
	if applied {
		t.Error("webhook-и такрорӣ набояд дубора татбиқ шавад")
	}

	// Ledger бояд ЯК транзаксия дошта бошад, на ду.
	var txCount int
	if err := pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM ledger_transactions WHERE campaign_id=$1`, campID).Scan(&txCount); err != nil {
		t.Fatal(err)
	}
	if txCount != 1 {
		t.Errorf("транзаксияи ledger: %d, интизор 1 — webhook дубора сабт кард", txCount)
	}

	// Кампания бояд PAID бошад.
	var status string
	pool.QueryRow(ctx, `SELECT status FROM campaigns WHERE id=$1`, campID).Scan(&status)
	if status != string(domain.CampaignPaid) {
		t.Errorf("ҳолати кампания: %s, интизор PAID", status)
	}
}

func TestPaymentWebhookRejectsWrongAmount(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()
	_, campID := seedCampaign(t, pool, 50000, 1000)

	runTx(t, pool, func(tx Tx) error {
		o, err := CreatePaymentOrder(ctx, tx, campID, advOf(t, pool), "mock", "idem-1")
		if err != nil {
			return err
		}
		return SetProviderReference(ctx, tx, o.ID, "mock_ref_1", domain.PaymentPending)
	})

	// Маблағи дигар — бояд рад шавад.
	bad := succeededWebhook("mock_ref_1", 999999)
	err := withTx(pool, func(tx Tx) error {
		_, e := ApplyPaymentWebhook(ctx, tx, "mock", bad)
		return e
	})
	if !errors.Is(err, ErrAmountMismatch) {
		t.Fatalf("интизор ErrAmountMismatch, гирифтем %v", err)
	}

	// Кампания набояд PAID шавад.
	var status string
	pool.QueryRow(ctx, `SELECT status FROM campaigns WHERE id=$1`, campID).Scan(&status)
	if status == string(domain.CampaignPaid) {
		t.Error("бо маблағи нодуруст кампания набояд PAID шавад")
	}
}

func TestLedgerBalancesAfterPayment(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()
	_, campID := seedCampaign(t, pool, 50000, 1000)

	runTx(t, pool, func(tx Tx) error {
		o, err := CreatePaymentOrder(ctx, tx, campID, advOf(t, pool), "mock", "idem-1")
		if err != nil {
			return err
		}
		if err := SetProviderReference(ctx, tx, o.ID, "ref1", domain.PaymentPending); err != nil {
			return err
		}
		_, err = ApplyPaymentWebhook(ctx, tx, "mock", succeededWebhook("ref1", 50000))
		return err
	})

	// Escrow бояд буҷетро дошта бошад.
	runTx(t, pool, func(tx Tx) error {
		escrow, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, campID,
			ledger.PurposeEscrow, money.TJS)
		if err != nil {
			return err
		}
		bal, err := ledger.Balance(ctx, tx, escrow)
		if err != nil {
			return err
		}
		if bal.Minor != 50000 {
			t.Errorf("тавозуни escrow: %d, интизор 50000", bal.Minor)
		}
		return nil
	})

	// Ҷамъи ҲАМАИ сатрҳо бояд сифр бошад — қоидаи дутарафа.
	var sum int64
	if err := pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount_minor),0) FROM ledger_entries`).Scan(&sum); err != nil {
		t.Fatal(err)
	}
	if sum != 0 {
		t.Errorf("ҷамъи ledger: %d, бояд 0 бошад", sum)
	}
}

// ── Ёрирасонҳо ───────────────────────────────────────────────────

func advOf(t *testing.T, pool *pgxpool.Pool) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(),
		`SELECT id FROM advertisers LIMIT 1`).Scan(&id); err != nil {
		t.Fatalf("advertiser: %v", err)
	}
	return id
}

func runTx(t *testing.T, pool *pgxpool.Pool, fn func(Tx) error) {
	t.Helper()
	if err := withTx(pool, fn); err != nil {
		t.Fatalf("транзаксия: %v", err)
	}
}

func withTx(pool *pgxpool.Pool, fn func(Tx) error) error {
	ctx := context.Background()
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	if err := fn(tx); err != nil {
		tx.Rollback(ctx)
		return err
	}
	return tx.Commit(ctx)
}
