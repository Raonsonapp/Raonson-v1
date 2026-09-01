package store

import (
	"context"
	"errors"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/marketplace/domain"
	"raonson/marketplace/matching"
)

func validInput(title string, budget int64, creators int) CampaignInput {
	return CampaignInput{
		Title:         title,
		Description:   "тавсиф",
		Category:      "beauty",
		TargetCountry: "TJ",
		BudgetMinor:   budget,
		Currency:      "TJS",
		CampaignType:  "post",
		CreatorCount:  creators,
		TargetAgeMin:  18,
		TargetAgeMax:  45,
	}
}

// seedAdvertiser рекламадиҳандаи нав месозад (бе кампания).
func seedAdvertiser(t *testing.T, pool *pgxpool.Pool, userID string) string {
	t.Helper()
	var id string
	if err := pool.QueryRow(context.Background(), `
		INSERT INTO advertisers(user_id, company_name) VALUES ($1,$2)
		RETURNING id`, userID, "Co "+userID).Scan(&id); err != nil {
		t.Fatalf("advertiser: %v", err)
	}
	return id
}

// forceStatus кампанияро мустақиман ба ҳолати дилхоҳ мегузорад —
// то тестҳои offer маҷбур нашаванд тамоми роҳи пардохтро такрор кунанд.
func forceStatus(t *testing.T, pool *pgxpool.Pool, campaignID string, st domain.CampaignStatus) {
	t.Helper()
	if _, err := pool.Exec(context.Background(),
		`UPDATE campaigns SET status=$2 WHERE id=$1`, campaignID, string(st)); err != nil {
		t.Fatalf("тағйири ҳолат: %v", err)
	}
}

func campaignStatus(t *testing.T, pool *pgxpool.Pool, campaignID string) domain.CampaignStatus {
	t.Helper()
	var s string
	if err := pool.QueryRow(context.Background(),
		`SELECT status FROM campaigns WHERE id=$1`, campaignID).Scan(&s); err != nil {
		t.Fatalf("хондани ҳолат: %v", err)
	}
	return domain.CampaignStatus(s)
}

// Кампания дар DRAFT офарида мешавад ва commission ҚУФЛ мешавад:
// тағйири баъдии rate-и платформа ба кампанияи мавҷуда таъсир накунад.
func TestCreateCampaignLocksCommission(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv := seedAdvertiser(t, pool, "u_lock")

	var first Campaign
	runTx(t, pool, func(tx Tx) error {
		var err error
		first, err = CreateCampaign(ctx, tx, adv, validInput("Аввал", 100000, 3), 1000)
		return err
	})
	if first.Status != domain.CampaignDraft {
		t.Fatalf("кампанияи нав бояд DRAFT бошад, гирифтем %s", first.Status)
	}
	if first.CommissionBPS != 1000 {
		t.Fatalf("commission: интизор 1000, гирифтем %d", first.CommissionBPS)
	}

	// Rate-и платформа тағйир ёфт — кампанияи нав rate-и навро мегирад.
	var second Campaign
	runTx(t, pool, func(tx Tx) error {
		var err error
		second, err = CreateCampaign(ctx, tx, adv, validInput("Дуюм", 100000, 3), 2000)
		return err
	})
	if second.CommissionBPS != 2000 {
		t.Fatalf("кампанияи дуюм: интизор 2000, гирифтем %d", second.CommissionBPS)
	}

	// Кампанияи аввал бояд ҳамон 1000-ро нигоҳ дорад.
	runTx(t, pool, func(tx Tx) error {
		got, err := GetCampaign(ctx, tx, first.ID, adv)
		if err != nil {
			return err
		}
		if got.CommissionBPS != 1000 {
			t.Fatalf("commission-и қуфлшуда тағйир ёфт: %d", got.CommissionBPS)
		}
		if got.Budget.Minor != 100000 {
			t.Fatalf("буҷет: интизор 100000, гирифтем %d", got.Budget.Minor)
		}
		return nil
	})
}

func TestCreateCampaignRejectsInvalidCommission(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()
	adv := seedAdvertiser(t, pool, "u_bad_bps")

	for _, bps := range []int64{-1, 10001} {
		err := withTx(pool, func(tx Tx) error {
			_, e := CreateCampaign(ctx, tx, adv, validInput("Х", 10000, 1), bps)
			return e
		})
		if !errors.Is(err, ErrInvalidCampaign) {
			t.Fatalf("bps=%d: интизори ErrInvalidCampaign, гирифтем %v", bps, err)
		}
	}
}

// Рекламадиҳанда кампанияи каси дигарро дида наметавонад.
func TestGetCampaignForbidsForeignAdvertiser(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	owner := seedAdvertiser(t, pool, "u_owner")
	other := seedAdvertiser(t, pool, "u_other")

	var c Campaign
	runTx(t, pool, func(tx Tx) error {
		var err error
		c, err = CreateCampaign(ctx, tx, owner, validInput("Аз они ман", 50000, 2), 1000)
		return err
	})

	err := withTx(pool, func(tx Tx) error {
		_, e := GetCampaign(ctx, tx, c.ID, other)
		return e
	})
	if !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("интизори ErrForbidden, гирифтем %v", err)
	}

	// Кампанияи мавҷуднабуда — ErrNotFound, на panic.
	err = withTx(pool, func(tx Tx) error {
		_, e := GetCampaign(ctx, tx, "00000000-0000-0000-0000-000000000000", owner)
		return e
	})
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("интизори ErrNotFound, гирифтем %v", err)
	}
}

// ListCampaigns танҳо кампанияҳои худи рекламадиҳандаро бармегардонад.
func TestListCampaignsIsScopedToAdvertiser(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	a := seedAdvertiser(t, pool, "u_a")
	b := seedAdvertiser(t, pool, "u_b")

	runTx(t, pool, func(tx Tx) error {
		if _, err := CreateCampaign(ctx, tx, a, validInput("A1", 10000, 1), 1000); err != nil {
			return err
		}
		if _, err := CreateCampaign(ctx, tx, a, validInput("A2", 10000, 1), 1000); err != nil {
			return err
		}
		_, err := CreateCampaign(ctx, tx, b, validInput("B1", 10000, 1), 1000)
		return err
	})

	runTx(t, pool, func(tx Tx) error {
		list, err := ListCampaigns(ctx, tx, a, 50, 0)
		if err != nil {
			return err
		}
		if len(list) != 2 {
			t.Fatalf("интизори 2 кампания, гирифтем %d", len(list))
		}
		for _, c := range list {
			if c.AdvertiserID != a {
				t.Fatalf("кампанияи каси дигар дар рӯйхат: %s", c.ID)
			}
		}
		return nil
	})
}

// Гузаришҳои ғайриқонунӣ рад мешаванд, такрори ҳамон ҳолат no-op аст.
func TestTransitionCampaignEnforcesStateMachine(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv := seedAdvertiser(t, pool, "u_fsm")
	var c Campaign
	runTx(t, pool, func(tx Tx) error {
		var err error
		c, err = CreateCampaign(ctx, tx, adv, validInput("FSM", 50000, 1), 1000)
		return err
	})

	// DRAFT → COMPLETED иҷозат нест: пардохт гузаронда намешавад.
	err := withTx(pool, func(tx Tx) error {
		return TransitionCampaign(ctx, tx, c.ID, domain.CampaignCompleted, adv, "test")
	})
	if err == nil {
		t.Fatal("гузариши DRAFT→COMPLETED бояд рад шавад")
	}
	if got := campaignStatus(t, pool, c.ID); got != domain.CampaignDraft {
		t.Fatalf("ҳолат баъди гузариши радшуда тағйир ёфт: %s", got)
	}

	// DRAFT → PENDING_PAYMENT иҷозат аст.
	runTx(t, pool, func(tx Tx) error {
		return TransitionCampaign(ctx, tx, c.ID, domain.CampaignPendingPayment, adv, "checkout")
	})
	if got := campaignStatus(t, pool, c.ID); got != domain.CampaignPendingPayment {
		t.Fatalf("интизори PENDING_PAYMENT, гирифтем %s", got)
	}

	// Такрори ҳамон гузариш — no-op, на хато (retry-и webhook).
	runTx(t, pool, func(tx Tx) error {
		return TransitionCampaign(ctx, tx, c.ID, domain.CampaignPendingPayment, adv, "retry")
	})
	if got := campaignStatus(t, pool, c.ID); got != domain.CampaignPendingPayment {
		t.Fatalf("баъди такрор: %s", got)
	}

	// Кампанияи мавҷуднабуда.
	err = withTx(pool, func(tx Tx) error {
		return TransitionCampaign(ctx, tx, "00000000-0000-0000-0000-000000000000",
			domain.CampaignCancelled, adv, "x")
	})
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("интизори ErrNotFound, гирифтем %v", err)
	}
}

// Ҳар гузариши муваффақ дар campaign_events сабт мешавад — audit trail.
func TestCampaignEventsAreRecorded(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv := seedAdvertiser(t, pool, "u_events")
	var c Campaign
	runTx(t, pool, func(tx Tx) error {
		var err error
		c, err = CreateCampaign(ctx, tx, adv, validInput("Events", 50000, 1), 1000)
		return err
	})
	runTx(t, pool, func(tx Tx) error {
		return TransitionCampaign(ctx, tx, c.ID, domain.CampaignPendingPayment, adv, "checkout")
	})

	var n int
	if err := pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM campaign_events WHERE campaign_id=$1`, c.ID).Scan(&n); err != nil {
		t.Fatalf("шумориши ҳодисаҳо: %v", err)
	}
	if n < 2 {
		t.Fatalf("интизори ҳадди ақал 2 ҳодиса (created + checkout), гирифтем %d", n)
	}
}

// Rollback-и транзаксия бояд audit-ро ҳам баргардонад: log ҳеҷ гоҳ
// амалеро нишон надиҳад, ки воқеан рух надод.
func TestFailedTransactionLeavesNoTrace(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv := seedAdvertiser(t, pool, "u_rollback")

	sentinel := errors.New("шикасти сунъӣ")
	err := withTx(pool, func(tx Tx) error {
		if _, e := CreateCampaign(ctx, tx, adv, validInput("Rollback", 50000, 1), 1000); e != nil {
			return e
		}
		return sentinel // транзаксия бекор мешавад
	})
	if !errors.Is(err, sentinel) {
		t.Fatalf("интизори хатои сунъӣ, гирифтем %v", err)
	}

	var campaigns, events, audits int
	if err := pool.QueryRow(ctx, `SELECT
		(SELECT COUNT(*) FROM campaigns),
		(SELECT COUNT(*) FROM campaign_events),
		(SELECT COUNT(*) FROM marketplace_audit_logs)`).
		Scan(&campaigns, &events, &audits); err != nil {
		t.Fatalf("шуморидан: %v", err)
	}
	if campaigns != 0 || events != 0 || audits != 0 {
		t.Fatalf("баъди rollback осор монд: campaigns=%d events=%d audits=%d",
			campaigns, events, audits)
	}
}

// ── Offer lifecycle ──────────────────────────────────────────────

func noMatch() matching.Match { return matching.Match{MatchScore: 0, Reasons: []string{}} }

// Даъват бе пардохт маъно надорад — DRAFT бояд рад шавад.
func TestInviteRequiresPaidCampaign(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000) // DRAFT

	err := withTx(pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_1", adv, 10000, noMatch())
		return e
	})
	if !errors.Is(err, ErrCampaignNotPaid) {
		t.Fatalf("интизори ErrCampaignNotPaid, гирифтем %v", err)
	}

	var n int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM campaign_creators`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatalf("даъвати радшуда сабт шуд: %d", n)
	}
}

// Ҷамъи маблағи даъватҳо аз буҷет гузашта наметавонад — сервер ҳисоб мекунад.
func TestInviteEnforcesBudget(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	// 60000 — мемонад.
	runTx(t, pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_1", adv, 60000, noMatch())
		return e
	})
	// Боз 60000 — ҷамъ 120000 > 100000, бояд рад шавад.
	err := withTx(pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_2", adv, 60000, noMatch())
		return e
	})
	if !errors.Is(err, ErrBudgetExceeded) {
		t.Fatalf("интизори ErrBudgetExceeded, гирифтем %v", err)
	}

	// Расо то буҷет — иҷозат.
	runTx(t, pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_3", adv, 40000, noMatch())
		return e
	})

	var sum int64
	if err := pool.QueryRow(ctx,
		`SELECT COALESCE(SUM(agreed_minor),0) FROM campaign_creators WHERE campaign_id=$1`,
		camp).Scan(&sum); err != nil {
		t.Fatal(err)
	}
	if sum != 100000 {
		t.Fatalf("ҷамъи даъватҳо: интизор 100000, гирифтем %d", sum)
	}

	// Маблағи ғайримусбат.
	err = withTx(pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_4", adv, 0, noMatch())
		return e
	})
	if err == nil {
		t.Fatal("маблағи сифр бояд рад шавад")
	}
}

// Даъвати такрории ҳамон эҷодкор — UNIQUE-и DB онро мебандад.
func TestDuplicateInviteRejected(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	runTx(t, pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_1", adv, 10000, noMatch())
		return e
	})
	err := withTx(pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_1", adv, 10000, noMatch())
		return e
	})
	if !errors.Is(err, ErrOfferExists) {
		t.Fatalf("интизори ErrOfferExists, гирифтем %v", err)
	}

	var n int
	if err := pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM campaign_creators WHERE campaign_id=$1`, camp).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("интизори 1 даъват, гирифтем %d", n)
	}
}

// Роҳи пурраи offer: даъват → қабул → таҳвил → тасдиқ.
func TestOfferFullLifecycle(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var offer Offer
	runTx(t, pool, func(tx Tx) error {
		var e error
		offer, e = InviteCreator(ctx, tx, camp, "creator_1", adv, 50000,
			matching.Match{MatchScore: 82.5, Reasons: []string{"audience_match"}})
		return e
	})
	if offer.Status != domain.OfferInvited {
		t.Fatalf("интизори INVITED, гирифтем %s", offer.Status)
	}
	if offer.Agreed.Minor != 50000 {
		t.Fatalf("маблағ: интизор 50000, гирифтем %d", offer.Agreed.Minor)
	}
	// Кампания бояд ба CREATOR_INVITED гузарад.
	if got := campaignStatus(t, pool, camp); got != domain.CampaignCreatorInvited {
		t.Fatalf("баъди даъват: интизори CREATOR_INVITED, гирифтем %s", got)
	}

	// Қабул.
	runTx(t, pool, func(tx Tx) error {
		o, e := RespondToOffer(ctx, tx, offer.ID, "creator_1", true)
		if e != nil {
			return e
		}
		if o.Status != domain.OfferAccepted {
			t.Fatalf("интизори ACCEPTED, гирифтем %s", o.Status)
		}
		return nil
	})
	if got := campaignStatus(t, pool, camp); got != domain.CampaignCreatorAccepted {
		t.Fatalf("баъди қабул: интизори CREATOR_ACCEPTED, гирифтем %s", got)
	}

	// Такрори қабул — no-op, на хато.
	runTx(t, pool, func(tx Tx) error {
		o, e := RespondToOffer(ctx, tx, offer.ID, "creator_1", true)
		if e != nil {
			return e
		}
		if o.Status != domain.OfferAccepted {
			t.Fatalf("такрори қабул ҳолатро вайрон кард: %s", o.Status)
		}
		return nil
	})

	// Таҳвили мӯҳтаво.
	runTx(t, pool, func(tx Tx) error {
		return SubmitContent(ctx, tx, offer.ID, "creator_1", "post_42", "post")
	})

	// Тасдиқ аз ҷониби рекламадиҳанда.
	runTx(t, pool, func(tx Tx) error {
		return ApproveContent(ctx, tx, offer.ID, adv)
	})

	var st, contentID, contentType string
	if err := pool.QueryRow(ctx, `
		SELECT status, content_id, content_type FROM campaign_creators WHERE id=$1`,
		offer.ID).Scan(&st, &contentID, &contentType); err != nil {
		t.Fatal(err)
	}
	if st != string(domain.OfferApproved) {
		t.Fatalf("ҳолати ниҳоӣ: интизори APPROVED, гирифтем %s", st)
	}
	if contentID != "post_42" || contentType != "post" {
		t.Fatalf("мӯҳтаво сабт нашуд: %s/%s", contentID, contentType)
	}
}

// Эҷодкор ба offer-и каси дигар даст расонда наметавонад.
func TestOfferActionsAreScopedToOwner(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var offer Offer
	runTx(t, pool, func(tx Tx) error {
		var e error
		offer, e = InviteCreator(ctx, tx, camp, "creator_1", adv, 10000, noMatch())
		return e
	})

	// Эҷодкори бегона ҷавоб дода наметавонад.
	err := withTx(pool, func(tx Tx) error {
		_, e := RespondToOffer(ctx, tx, offer.ID, "creator_hacker", true)
		return e
	})
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("ҷавоби бегона: интизори ErrNotFound, гирифтем %v", err)
	}

	// Ва мӯҳтаво ҳам фиристода наметавонад.
	err = withTx(pool, func(tx Tx) error {
		return SubmitContent(ctx, tx, offer.ID, "creator_hacker", "post_x", "post")
	})
	if !errors.Is(err, domain.ErrNotFound) {
		t.Fatalf("таҳвили бегона: интизори ErrNotFound, гирифтем %v", err)
	}

	// Рекламадиҳандаи бегона тасдиқ карда наметавонад.
	other := seedAdvertiser(t, pool, "u_stranger")
	err = withTx(pool, func(tx Tx) error {
		return ApproveContent(ctx, tx, offer.ID, other)
	})
	if !errors.Is(err, domain.ErrForbidden) {
		t.Fatalf("тасдиқи бегона: интизори ErrForbidden, гирифтем %v", err)
	}

	if got := offerStatus(t, pool, offer.ID); got != string(domain.OfferInvited) {
		t.Fatalf("ҳолат баъди кӯшишҳои бегона тағйир ёфт: %s", got)
	}
}

// Тартиби қадамҳо маҷбурист: мӯҳтаво пеш аз қабул фиристода намешавад.
func TestSubmitBeforeAcceptIsRejected(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var offer Offer
	runTx(t, pool, func(tx Tx) error {
		var e error
		offer, e = InviteCreator(ctx, tx, camp, "creator_1", adv, 10000, noMatch())
		return e
	})

	// INVITED → DELIVERED иҷозат нест.
	if err := withTx(pool, func(tx Tx) error {
		return SubmitContent(ctx, tx, offer.ID, "creator_1", "post_1", "post")
	}); err == nil {
		t.Fatal("таҳвил пеш аз қабул бояд рад шавад")
	}

	// Ва тасдиқ пеш аз таҳвил ҳам.
	if err := withTx(pool, func(tx Tx) error {
		return ApproveContent(ctx, tx, offer.ID, adv)
	}); err == nil {
		t.Fatal("тасдиқ пеш аз таҳвил бояд рад шавад")
	}

	if got := offerStatus(t, pool, offer.ID); got != string(domain.OfferInvited) {
		t.Fatalf("ҳолат тағйир ёфт: %s", got)
	}
}

// Радкардаи эҷодкор буҷетро озод мекунад — ҷои холӣ дубора истифода мешавад.
func TestRejectedOfferReleasesBudget(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var first Offer
	runTx(t, pool, func(tx Tx) error {
		var e error
		first, e = InviteCreator(ctx, tx, camp, "creator_1", adv, 100000, noMatch())
		return e
	})

	// Тамоми буҷет банд аст.
	if err := withTx(pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_2", adv, 1, noMatch())
		return e
	}); !errors.Is(err, ErrBudgetExceeded) {
		t.Fatalf("интизори ErrBudgetExceeded, гирифтем %v", err)
	}

	// Эҷодкор рад мекунад.
	runTx(t, pool, func(tx Tx) error {
		o, e := RespondToOffer(ctx, tx, first.ID, "creator_1", false)
		if e != nil {
			return e
		}
		if o.Status != domain.OfferRejected {
			t.Fatalf("интизори REJECTED, гирифтем %s", o.Status)
		}
		return nil
	})

	// Акнун ҷой ҳаст.
	runTx(t, pool, func(tx Tx) error {
		_, e := InviteCreator(ctx, tx, camp, "creator_2", adv, 100000, noMatch())
		return e
	})
}

// ListOffersForCreator танҳо offer-ҳои худи эҷодкорро бо филтри ҳолат медиҳад.
func TestListOffersForCreator(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	var mine Offer
	runTx(t, pool, func(tx Tx) error {
		var e error
		if mine, e = InviteCreator(ctx, tx, camp, "creator_1", adv, 30000, noMatch()); e != nil {
			return e
		}
		_, e = InviteCreator(ctx, tx, camp, "creator_2", adv, 30000, noMatch())
		return e
	})

	runTx(t, pool, func(tx Tx) error {
		list, err := ListOffersForCreator(ctx, tx, "creator_1", "", 50, 0)
		if err != nil {
			return err
		}
		if len(list) != 1 || list[0].ID != mine.ID {
			t.Fatalf("интизори танҳо offer-и худаш, гирифтем %d", len(list))
		}
		if list[0].Agreed.Minor != 30000 {
			t.Fatalf("маблағ: %d", list[0].Agreed.Minor)
		}
		return nil
	})

	// Филтри ҳолат.
	runTx(t, pool, func(tx Tx) error {
		list, err := ListOffersForCreator(ctx, tx, "creator_1", "ACCEPTED", 50, 0)
		if err != nil {
			return err
		}
		if len(list) != 0 {
			t.Fatalf("филтри ACCEPTED бояд холӣ бошад, гирифтем %d", len(list))
		}
		return nil
	})
}

func offerStatus(t *testing.T, pool *pgxpool.Pool, offerID string) string {
	t.Helper()
	var s string
	if err := pool.QueryRow(context.Background(),
		`SELECT status FROM campaign_creators WHERE id=$1`, offerID).Scan(&s); err != nil {
		t.Fatalf("хондани ҳолати offer: %v", err)
	}
	return s
}
