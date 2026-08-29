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

// seedCompletedCampaign кампанияи COMPLETED бо як эҷодкори APPROVED месозад.
func seedCompletedCampaign(t *testing.T, pool *pgxpool.Pool,
	budgetMinor, agreedMinor int64, commissionBPS int) (campID, creatorID string) {
	t.Helper()
	ctx := context.Background()
	var advID string
	if err := pool.QueryRow(ctx, `
		INSERT INTO advertisers(user_id, company_name) VALUES ('u_adv','Co')
		RETURNING id`).Scan(&advID); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `
		INSERT INTO campaigns(advertiser_id,title,budget_minor,currency,status,commission_bps)
		VALUES ($1,'C',$2,'TJS','COMPLETED',$3) RETURNING id`,
		advID, budgetMinor, commissionBPS).Scan(&campID); err != nil {
		t.Fatal(err)
	}
	creatorID = "creator_1"
	if _, err := pool.Exec(ctx, `
		INSERT INTO campaign_creators(campaign_id,creator_id,status,agreed_minor,currency)
		VALUES ($1,$2,'APPROVED',$3,'TJS')`, campID, creatorID, agreedMinor); err != nil {
		t.Fatal(err)
	}
	// Escrow-ро бо буҷет пур мекунем (гӯё пардохт шудааст).
	runTx(t, pool, func(tx Tx) error {
		settlement, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerProvider, "mock",
			ledger.PurposeSettlement, money.TJS)
		if err != nil {
			return err
		}
		escrow, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, campID,
			ledger.PurposeEscrow, money.TJS)
		if err != nil {
			return err
		}
		_, err = ledger.Transfer(ctx, tx, "PAYMENT_CAPTURED", campID,
			"seed:"+campID, "seed", settlement, escrow,
			money.MustNew(money.Minor(budgetMinor), money.TJS))
		return err
	})
	return campID, creatorID
}

func TestCreatorCannotBePaidTwiceForOneCampaign(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	campID, creatorID := seedCompletedCampaign(t, pool, 50000, 50000, 1000)

	// Бори аввал — бояд сохта шавад.
	var first PayoutOrder
	runTx(t, pool, func(tx Tx) error {
		var err error
		first, err = CreatePayoutOrder(ctx, tx, campID, creatorID, "manual", "idem-1")
		return err
	})
	if first.ID == "" {
		t.Fatal("payout-и аввал бояд сохта шавад")
	}

	// Бори дуюм — бо калиди идемпотентии ДИГАР. Бояд рад шавад:
	// UNIQUE(campaign_id, creator_id) дар DB.
	err := withTx(pool, func(tx Tx) error {
		_, e := CreatePayoutOrder(ctx, tx, campID, creatorID, "manual", "idem-2")
		return e
	})
	if !errors.Is(err, ErrPayoutExists) {
		t.Fatalf("payout-и дуюм бояд рад шавад, гирифтем %v", err)
	}

	// Дар DB бояд ЯК payout бошад.
	var n int
	pool.QueryRow(ctx, `SELECT COUNT(*) FROM payout_orders WHERE campaign_id=$1`, campID).Scan(&n)
	if n != 1 {
		t.Errorf("шумораи payout: %d, интизор 1", n)
	}
}

func TestCommissionSplitIsExactAndUsesLockedRate(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	// Комиссияи кампания 10% ҚУФЛ шудааст.
	campID, creatorID := seedCompletedCampaign(t, pool, 50000, 50000, 1000)

	var o PayoutOrder
	runTx(t, pool, func(tx Tx) error {
		var err error
		o, err = CreatePayoutOrder(ctx, tx, campID, creatorID, "manual", "idem-1")
		return err
	})

	// 500.00 TJS − 10% = 450.00 ба эҷодкор, 50.00 ба платформа.
	if o.Amount.Minor != 45000 {
		t.Errorf("маблағи эҷодкор: %d, интизор 45000", o.Amount.Minor)
	}
	var feeMinor, bps int64
	pool.QueryRow(ctx, `SELECT fee_minor, commission_bps FROM platform_fees WHERE campaign_id=$1`,
		campID).Scan(&feeMinor, &bps)
	if feeMinor != 5000 {
		t.Errorf("комиссия: %d, интизор 5000", feeMinor)
	}
	if bps != 1000 {
		t.Errorf("bps-и қуфлшуда: %d, интизор 1000", bps)
	}

	// Ledger: ҳамёни эҷодкор 450.00, даромади платформа 50.00, escrow сифр.
	runTx(t, pool, func(tx Tx) error {
		wallet, _ := ledger.EnsureAccount(ctx, tx, ledger.OwnerUser, creatorID, ledger.PurposeWallet, money.TJS)
		revenue, _ := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, "", ledger.PurposeRevenue, money.TJS)
		escrow, _ := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, campID, ledger.PurposeEscrow, money.TJS)

		w, _ := ledger.Balance(ctx, tx, wallet)
		r, _ := ledger.Balance(ctx, tx, revenue)
		e, _ := ledger.Balance(ctx, tx, escrow)

		if w.Minor != 45000 {
			t.Errorf("ҳамёни эҷодкор: %d, интизор 45000", w.Minor)
		}
		if r.Minor != 5000 {
			t.Errorf("даромади платформа: %d, интизор 5000", r.Minor)
		}
		if e.Minor != 0 {
			t.Errorf("escrow баъди пардохт: %d, интизор 0", e.Minor)
		}
		return nil
	})

	// Ҷамъи умумии ledger бояд сифр монад.
	var sum int64
	pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount_minor),0) FROM ledger_entries`).Scan(&sum)
	if sum != 0 {
		t.Errorf("ҷамъи ledger: %d, бояд 0 бошад", sum)
	}
}

func TestPayoutRefusedWhenCampaignNotCompleted(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	campID, creatorID := seedCompletedCampaign(t, pool, 50000, 50000, 1000)
	// Кампанияро ба ACTIVE бармегардонем.
	pool.Exec(ctx, `UPDATE campaigns SET status='ACTIVE' WHERE id=$1`, campID)

	err := withTx(pool, func(tx Tx) error {
		_, e := CreatePayoutOrder(ctx, tx, campID, creatorID, "manual", "idem-1")
		return e
	})
	if !errors.Is(err, ErrCampaignNotComplete) {
		t.Fatalf("интизор ErrCampaignNotComplete, гирифтем %v", err)
	}
}

func TestPayoutRefusedWhenOfferNotApproved(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	campID, creatorID := seedCompletedCampaign(t, pool, 50000, 50000, 1000)
	pool.Exec(ctx, `UPDATE campaign_creators SET status='ACCEPTED' WHERE campaign_id=$1`, campID)

	err := withTx(pool, func(tx Tx) error {
		_, e := CreatePayoutOrder(ctx, tx, campID, creatorID, "manual", "idem-1")
		return e
	})
	if !errors.Is(err, ErrOfferNotApproved) {
		t.Fatalf("интизор ErrOfferNotApproved, гирифтем %v", err)
	}
}

func TestPayoutStatusTransitionGuarded(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	campID, creatorID := seedCompletedCampaign(t, pool, 50000, 50000, 1000)
	var o PayoutOrder
	runTx(t, pool, func(tx Tx) error {
		var err error
		o, err = CreatePayoutOrder(ctx, tx, campID, creatorID, "manual", "idem-1")
		return err
	})

	// PENDING → SUCCEEDED мустақим бояд рад шавад.
	err := withTx(pool, func(tx Tx) error {
		return MarkPayoutStatus(ctx, tx, o.ID, domain.PayoutSucceeded, "")
	})
	if err == nil {
		t.Error("PENDING → SUCCEEDED бояд рад шавад")
	}

	// PENDING → PROCESSING → SUCCEEDED бояд кор кунад.
	runTx(t, pool, func(tx Tx) error {
		return MarkPayoutStatus(ctx, tx, o.ID, domain.PayoutProcessing, "")
	})
	runTx(t, pool, func(tx Tx) error {
		return MarkPayoutStatus(ctx, tx, o.ID, domain.PayoutSucceeded, "")
	})
	var st string
	pool.QueryRow(ctx, `SELECT status FROM payout_orders WHERE id=$1`, o.ID).Scan(&st)
	if st != string(domain.PayoutSucceeded) {
		t.Errorf("ҳолати ниҳоӣ: %s, интизор SUCCEEDED", st)
	}
}
