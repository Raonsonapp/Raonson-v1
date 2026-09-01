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

// inviteCreator як даъват месозад ва id-и онро бармегардонад.
//
// Ҳама даъватҳо бояд ПЕШ аз ҷараёни мӯҳтаво сохта шаванд: баъди он ки
// ҳамаи эҷодкорони фаъол тасдиқ шуданд, кампания ба REVIEW мегузарад ва
// даъвати нав дигар қабул намешавад.
func inviteCreator(t *testing.T, pool *pgxpool.Pool, camp, adv, creatorID string,
	agreed int64) string {
	t.Helper()
	ctx := context.Background()
	var offer Offer
	runTx(t, pool, func(tx Tx) error {
		var err error
		offer, err = InviteCreator(ctx, tx, camp, creatorID, adv, agreed, noMatch())
		return err
	})
	return offer.ID
}

// deliverAndApprove як offer-ро аз қабул то тасдиқ мебарад.
func deliverAndApprove(t *testing.T, pool *pgxpool.Pool, offerID, adv, creatorID string) {
	t.Helper()
	ctx := context.Background()
	runTx(t, pool, func(tx Tx) error {
		if _, err := RespondToOffer(ctx, tx, offerID, creatorID, true); err != nil {
			return err
		}
		if err := SubmitContent(ctx, tx, offerID, creatorID, "post_"+creatorID, "post"); err != nil {
			return err
		}
		return ApproveContent(ctx, tx, offerID, adv)
	})
}

// Кампания аз ҳодисаҳои ВОҚЕӢ пеш меравад, на аз таймер.
func TestCampaignAdvancesOnRealEvents(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var offer Offer
	runTx(t, pool, func(tx Tx) error {
		var err error
		offer, err = InviteCreator(ctx, tx, camp, "creator_1", adv, 50000, noMatch())
		return err
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignCreatorInvited {
		t.Fatalf("баъди даъват: %s", got)
	}

	runTx(t, pool, func(tx Tx) error {
		_, err := RespondToOffer(ctx, tx, offer.ID, "creator_1", true)
		return err
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignCreatorAccepted {
		t.Fatalf("баъди қабул: %s", got)
	}

	// Таҳвили мӯҳтаво → кампания ФАЪОЛ (мӯҳтаво зинда аст).
	runTx(t, pool, func(tx Tx) error {
		return SubmitContent(ctx, tx, offer.ID, "creator_1", "post_1", "post")
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignActive {
		t.Fatalf("баъди таҳвил: интизори ACTIVE, гирифтем %s", got)
	}

	// Тасдиқи ҳамаи эҷодкорон → REVIEW.
	runTx(t, pool, func(tx Tx) error {
		return ApproveContent(ctx, tx, offer.ID, adv)
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignReview {
		t.Fatalf("баъди тасдиқ: интизори REVIEW, гирифтем %s", got)
	}
}

// То даме ки як эҷодкор боқӣ бошад, кампания ба REVIEW намеравад.
func TestCampaignStaysActiveUntilAllApproved(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var a, b Offer
	runTx(t, pool, func(tx Tx) error {
		var err error
		if a, err = InviteCreator(ctx, tx, camp, "creator_1", adv, 40000, noMatch()); err != nil {
			return err
		}
		b, err = InviteCreator(ctx, tx, camp, "creator_2", adv, 40000, noMatch())
		return err
	})
	runTx(t, pool, func(tx Tx) error {
		if _, err := RespondToOffer(ctx, tx, a.ID, "creator_1", true); err != nil {
			return err
		}
		if _, err := RespondToOffer(ctx, tx, b.ID, "creator_2", true); err != nil {
			return err
		}
		if err := SubmitContent(ctx, tx, a.ID, "creator_1", "p1", "post"); err != nil {
			return err
		}
		return SubmitContent(ctx, tx, b.ID, "creator_2", "p2", "post")
	})

	// Танҳо якеро тасдиқ мекунем.
	runTx(t, pool, func(tx Tx) error {
		return ApproveContent(ctx, tx, a.ID, adv)
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignActive {
		t.Fatalf("бо як эҷодкори боқимонда: интизори ACTIVE, гирифтем %s", got)
	}

	// Анҷом ҳанӯз мумкин нест.
	err := withTx(pool, func(tx Tx) error {
		_, e := CompleteCampaign(ctx, tx, camp, "manual", adv)
		return e
	})
	if !errors.Is(err, ErrCampaignNotReady) {
		t.Fatalf("интизори ErrCampaignNotReady, гирифтем %v", err)
	}

	// Дуюмро ҳам тасдиқ мекунем → REVIEW.
	runTx(t, pool, func(tx Tx) error {
		return ApproveContent(ctx, tx, b.ID, adv)
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignReview {
		t.Fatalf("баъди тасдиқи ҳама: интизори REVIEW, гирифтем %s", got)
	}
}

// Анҷоми кампания барои ҳар эҷодкори тасдиқшуда ЯК фармоиши пардохт
// месозад — ва такрори даъват фармоиши дуюм намесозад.
func TestCompleteCampaignCreatesOnePayoutPerCreator(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)
	// Escrow-ро пур мекунем, гӯё рекламадиҳанда пардохт кардааст.
	fundEscrow(t, pool, camp, 100000)

	// Ҳар ду даъват пеш аз ҷараёни мӯҳтаво.
	o1 := inviteCreator(t, pool, camp, adv, "creator_1", 40000)
	o2 := inviteCreator(t, pool, camp, adv, "creator_2", 40000)
	deliverAndApprove(t, pool, o1, adv, "creator_1")
	deliverAndApprove(t, pool, o2, adv, "creator_2")

	var payouts []PayoutOrder
	runTx(t, pool, func(tx Tx) error {
		var err error
		payouts, err = CompleteCampaign(ctx, tx, camp, "manual", adv)
		return err
	})
	if len(payouts) != 2 {
		t.Fatalf("интизори 2 пардохт, гирифтем %d", len(payouts))
	}
	if got := campaignStatus(t, pool, camp); got != domain.CampaignCompleted {
		t.Fatalf("интизори COMPLETED, гирифтем %s", got)
	}

	// Комиссияи 10%: 40000 → 36000 ба эҷодкор.
	for _, p := range payouts {
		if p.Amount.Minor != 36000 {
			t.Fatalf("маблағи пардохт: интизор 36000, гирифтем %d", p.Amount.Minor)
		}
	}

	// Такрори анҷом — кампания аллакай COMPLETED, пардохти дуюм нест.
	err := withTx(pool, func(tx Tx) error {
		_, e := CompleteCampaign(ctx, tx, camp, "manual", adv)
		return e
	})
	if !errors.Is(err, ErrCampaignNotReady) {
		t.Fatalf("такрори анҷом: интизори ErrCampaignNotReady, гирифтем %v", err)
	}
	var n int
	if err := pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM payout_orders WHERE campaign_id=$1`, camp).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 2 {
		t.Fatalf("интизори 2 фармоиши пардохт, гирифтем %d", n)
	}

	// Дафтар бояд ҳамвор бошад: ҷамъи ҳама сатрҳо сифр.
	var sum int64
	if err := pool.QueryRow(ctx, `SELECT COALESCE(SUM(amount_minor),0) FROM ledger_entries`).
		Scan(&sum); err != nil {
		t.Fatal(err)
	}
	if sum != 0 {
		t.Fatalf("дафтар ҳамвор нест: ҷамъ %d", sum)
	}
}

// Кампания бе эҷодкори тасдиқшуда баста намешавад.
func TestCompleteCampaignRequiresApprovedCreator(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignReview)

	err := withTx(pool, func(tx Tx) error {
		_, e := CompleteCampaign(ctx, tx, camp, "manual", adv)
		return e
	})
	if !errors.Is(err, ErrNoApprovedCreators) {
		t.Fatalf("интизори ErrNoApprovedCreators, гирифтем %v", err)
	}
	if got := campaignStatus(t, pool, camp); got != domain.CampaignReview {
		t.Fatalf("ҳолат баъди анҷоми номуваффақ тағйир ёфт: %s", got)
	}
}

// fundEscrow escrow-и кампанияро пур мекунад, гӯё пардохт шудааст.
func fundEscrow(t *testing.T, pool *pgxpool.Pool, campID string, minor int64) {
	t.Helper()
	ctx := context.Background()
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
			"fund:"+campID, "test", settlement, escrow,
			money.MustNew(money.Minor(minor), money.TJS))
		return err
	})
}
