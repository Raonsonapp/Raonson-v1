package store

import (
	"context"
	"testing"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
	"raonson/marketplace/score"
)

// Даромад аз ҷадвалҳо ҳисоб мешавад ва танҳо аз они худи эҷодкор аст.
func TestCreatorEarningsAreScopedAndDerived(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	camp, creatorID := seedCompletedCampaign(t, pool, 100000, 100000, 1000)
	runTx(t, pool, func(tx Tx) error {
		_, e := CreatePayoutOrder(ctx, tx, camp, creatorID, "manual", "earn-1")
		return e
	})

	runTx(t, pool, func(tx Tx) error {
		e, err := GetCreatorEarnings(ctx, tx, creatorID, money.TJS)
		if err != nil {
			return err
		}
		// Комиссияи 10%: 100000 → 90000 ба ҳамён.
		if e.Wallet.Available.Minor != 90000 {
			t.Errorf("тавозун: интизор 90000, гирифтем %d", e.Wallet.Available.Minor)
		}
		// Ҳанӯз интиқол тасдиқ нашуда — PaidOut бояд сифр бошад.
		if e.PaidOut.Minor != 0 {
			t.Errorf("пардохтшуда: интизор 0, гирифтем %d", e.PaidOut.Minor)
		}
		if e.Campaigns != 1 {
			t.Errorf("кампанияҳо: интизор 1, гирифтем %d", e.Campaigns)
		}
		return nil
	})

	// Эҷодкори бегона ҳеҷ чиз намебинад.
	runTx(t, pool, func(tx Tx) error {
		e, err := GetCreatorEarnings(ctx, tx, "creator_stranger", money.TJS)
		if err != nil {
			return err
		}
		if e.Wallet.Available.Minor != 0 || e.PaidOut.Minor != 0 || e.Campaigns != 0 {
			t.Fatalf("эҷодкори бегона маълумот дид: %+v", e)
		}
		return nil
	})

	// Баъди тасдиқи интиқол PaidOut пур мешавад.
	if _, err := pool.Exec(ctx,
		`UPDATE payout_orders SET status='SUCCEEDED' WHERE campaign_id=$1`, camp); err != nil {
		t.Fatal(err)
	}
	runTx(t, pool, func(tx Tx) error {
		e, err := GetCreatorEarnings(ctx, tx, creatorID, money.TJS)
		if err != nil {
			return err
		}
		if e.PaidOut.Minor != 90000 {
			t.Fatalf("пардохтшуда: интизор 90000, гирифтем %d", e.PaidOut.Minor)
		}
		return nil
	})
}

// Маблағи интизорӣ комиссияро тарҳ мекунад — ваъдаи аз ҳад дода намешавад.
func TestUpcomingEarningsSubtractCommission(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 2000) // комиссияи 20%
	forceStatus(t, pool, camp, domain.CampaignPaid)

	o := inviteCreator(t, pool, camp, adv, "creator_1", 50000)
	deliverAndApprove(t, pool, o, adv, "creator_1")

	runTx(t, pool, func(tx Tx) error {
		e, err := GetCreatorEarnings(ctx, tx, "creator_1", money.TJS)
		if err != nil {
			return err
		}
		// 50000 - 20% = 40000.
		if e.Upcoming.Minor != 40000 {
			t.Fatalf("интизорӣ: интизор 40000, гирифтем %d", e.Upcoming.Minor)
		}
		return nil
	})
}

// Пардохтҳо ва кампанияҳои эҷодкор ба ӯ маҳдуданд.
func TestCreatorListsAreScoped(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	camp, creatorID := seedCompletedCampaign(t, pool, 100000, 100000, 1000)
	runTx(t, pool, func(tx Tx) error {
		_, e := CreatePayoutOrder(ctx, tx, camp, creatorID, "manual", "scope-1")
		return e
	})

	runTx(t, pool, func(tx Tx) error {
		mine, err := ListPayoutsForCreator(ctx, tx, creatorID, 50, 0)
		if err != nil {
			return err
		}
		if len(mine) != 1 || mine[0].Amount.Minor != 90000 {
			t.Fatalf("пардохтҳои худам: %+v", mine)
		}
		// Ном аз кампания меояд, на аз client.
		if mine[0].Title == "" {
			t.Error("сарлавҳаи кампания холӣ")
		}

		other, err := ListPayoutsForCreator(ctx, tx, "creator_stranger", 50, 0)
		if err != nil {
			return err
		}
		if len(other) != 0 {
			t.Fatalf("бегона %d пардохт дид", len(other))
		}

		camps, err := ListCampaignsForCreator(ctx, tx, creatorID, 50, 0)
		if err != nil {
			return err
		}
		if len(camps) != 1 || camps[0].CampaignID != camp {
			t.Fatalf("кампанияҳо: %+v", camps)
		}
		return nil
	})
}

// Нусхаи алгоритм ва параметрҳо бо хол захира мешаванд.
func TestScoreVersionIsPersisted(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	m := score.Metrics{
		Followers: 10000, TotalViews: 200000, AverageViews: 4000,
		Likes: 15000, Comments: 900, ContentCount: 50,
		CampaignCount: 4, SuccessfulCampaigns: 4, AverageCampaignResult: 1,
	}
	runTx(t, pool, func(tx Tx) error {
		saved, err := SaveCreatorMetrics(ctx, tx, "creator_1", m)
		if err != nil {
			return err
		}
		if saved.ScoreVersion != score.Version {
			t.Fatalf("нусха: интизор %d, гирифтем %d", score.Version, saved.ScoreVersion)
		}
		if saved.ScoreParams["weightEngagement"] != 40 {
			t.Fatalf("параметрҳо нигоҳ дошта нашуданд: %+v", saved.ScoreParams)
		}
		return nil
	})

	// Ҳангоми хондан ҳам бармегардад — то маълум бошад, ки холи
	// захирашуда бо кадом алгоритм ҳисоб шудааст.
	runTx(t, pool, func(tx Tx) error {
		read, err := GetCreatorMetrics(ctx, tx, "creator_1")
		if err != nil {
			return err
		}
		if read.ScoreVersion != score.Version {
			t.Fatalf("нусхаи хондашуда: %d", read.ScoreVersion)
		}
		if len(read.ScoreBreakdown) == 0 {
			t.Fatal("тақсимоти хол нигоҳ дошта нашуд")
		}
		if read.ScoreBreakdown["engagement"] <= 0 {
			t.Fatalf("тақсимот: %+v", read.ScoreBreakdown)
		}
		return nil
	})
}
