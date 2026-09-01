package store

import (
	"context"
	"errors"
	"testing"

	"raonson/marketplace/money"
	"raonson/marketplace/score"
)

func TestCreatorProfileUpsertAndValidation(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	in := CreatorProfileInput{
		AudienceCountry:   "TJ",
		AudienceLanguage:  "tg",
		ContentCategories: []string{"beauty", "lifestyle"},
		PriceMinor:        25000,
		Currency:          "TJS",
		Available:         true,
	}

	var p CreatorProfile
	runTx(t, pool, func(tx Tx) error {
		var err error
		p, err = UpsertCreatorProfile(ctx, tx, "creator_1", in)
		return err
	})
	if p.Price.Minor != 25000 || p.Price.Currency != money.TJS {
		t.Fatalf("нарх: %v", p.Price)
	}
	// Эҷодкор худро тасдиқшуда эълон карда наметавонад.
	if p.VerificationStatus != "NONE" {
		t.Fatalf("ҳолати тасдиқ: интизори NONE, гирифтем %s", p.VerificationStatus)
	}

	// Такрори upsert — навсозӣ, на сатри дуюм.
	in.PriceMinor = 30000
	in.Available = false
	runTx(t, pool, func(tx Tx) error {
		var err error
		p, err = UpsertCreatorProfile(ctx, tx, "creator_1", in)
		return err
	})
	if p.Price.Minor != 30000 || p.Available {
		t.Fatalf("навсозӣ кор накард: %v available=%v", p.Price, p.Available)
	}
	var n int
	if err := pool.QueryRow(ctx, `SELECT COUNT(*) FROM creator_profiles`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("интизори 1 профил, гирифтем %d", n)
	}

	// Вуруди нодуруст.
	bad := []CreatorProfileInput{
		{Currency: "TJS", PriceMinor: -1},
		{Currency: "XYZ"},
		{Currency: "TJS", ContentCategories: []string{"", "x"}},
	}
	for i, b := range bad {
		err := withTx(pool, func(tx Tx) error {
			_, e := UpsertCreatorProfile(ctx, tx, "creator_bad", b)
			return e
		})
		if !errors.Is(err, ErrInvalidCreatorProfile) {
			t.Fatalf("вуруди %d: интизори ErrInvalidCreatorProfile, гирифтем %v", i, err)
		}
	}

	// Профили мавҷуднабуда.
	err := withTx(pool, func(tx Tx) error {
		_, e := GetCreatorProfile(ctx, tx, "creator_none")
		return e
	})
	if !errors.Is(err, ErrCreatorProfileMissing) {
		t.Fatalf("интизори ErrCreatorProfileMissing, гирифтем %v", err)
	}
}

// Хол ҳамеша аз score.Compute меояд — на аз вуруд, на тасодуфӣ.
func TestSaveCreatorMetricsComputesScore(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	m := score.Metrics{
		Followers:             10000,
		TotalViews:            200000,
		AverageViews:          4000,
		Likes:                 15000,
		Comments:              900,
		Shares:                300,
		Saves:                 400,
		ContentCount:          50,
		CampaignCount:         4,
		SuccessfulCampaigns:   4,
		AverageCampaignResult: 1,
	}
	want := score.Compute(m)

	var got CreatorMetrics
	runTx(t, pool, func(tx Tx) error {
		var err error
		got, err = SaveCreatorMetrics(ctx, tx, "creator_1", m)
		return err
	})
	if got.Score != want.Score || got.Confidence != want.Confidence {
		t.Fatalf("хол: интизор %v/%v, гирифтем %v/%v",
			want.Score, want.Confidence, got.Score, got.Confidence)
	}
	if got.Score <= 0 || got.Score > 100 {
		t.Fatalf("хол берун аз 0..100: %v", got.Score)
	}

	// Такрори ҳисоб бо ҳамон дохилшавӣ ҳамон холро медиҳад — детерминистӣ.
	runTx(t, pool, func(tx Tx) error {
		again, err := SaveCreatorMetrics(ctx, tx, "creator_1", m)
		if err != nil {
			return err
		}
		if again.Score != got.Score {
			t.Fatalf("ҳисоб детерминистӣ нест: %v ва %v", got.Score, again.Score)
		}
		return nil
	})

	// Хондан бармегардонад.
	runTx(t, pool, func(tx Tx) error {
		read, err := GetCreatorMetrics(ctx, tx, "creator_1")
		if err != nil {
			return err
		}
		if read.Score != got.Score || read.Followers != 10000 {
			t.Fatalf("хондашуда фарқ мекунад: %+v", read)
		}
		return nil
	})

	// Эҷодкори бе метрика — сифр, на хато.
	runTx(t, pool, func(tx Tx) error {
		empty, err := GetCreatorMetrics(ctx, tx, "creator_new")
		if err != nil {
			return err
		}
		if empty.Score != 0 || empty.SampleSize != 0 {
			t.Fatalf("эҷодкори нав бояд метрикаи холӣ дошта бошад: %+v", empty)
		}
		return nil
	})
}

// FindCandidates танҳо эҷодкорони дастрасро бо холи фиреби воқеӣ медиҳад.
func TestFindCandidatesFiltersAndScoresFraud(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	mk := func(id string, price int64, available bool, followers int64) {
		runTx(t, pool, func(tx Tx) error {
			if _, err := UpsertCreatorProfile(ctx, tx, id, CreatorProfileInput{
				AudienceCountry:   "TJ",
				AudienceLanguage:  "tg",
				ContentCategories: []string{"beauty"},
				PriceMinor:        price,
				Currency:          "TJS",
				Available:         available,
			}); err != nil {
				return err
			}
			_, err := SaveCreatorMetrics(ctx, tx, id, score.Metrics{
				Followers: followers, AverageViews: followers / 2,
				Likes: followers / 10, ContentCount: 20, TotalViews: followers * 5,
			})
			return err
		})
	}
	mk("creator_ok", 20000, true, 10000)
	mk("creator_busy", 20000, false, 50000) // дастрас нест
	mk("creator_expensive", 900000, true, 90000)
	mk("creator_flagged", 20000, true, 12000)

	// Парчами кушодаи фиреб.
	if _, err := pool.Exec(ctx, `
		INSERT INTO fraud_flags(entity_type, entity_id, signal, score, status)
		VALUES ('creator','creator_flagged','follower_spike',0.8,'OPEN')`); err != nil {
		t.Fatal(err)
	}
	// Парчами пӯшида набояд ҳисоб шавад.
	if _, err := pool.Exec(ctx, `
		INSERT INTO fraud_flags(entity_type, entity_id, signal, score, status)
		VALUES ('creator','creator_ok','old_signal',0.9,'RESOLVED')`); err != nil {
		t.Fatal(err)
	}

	runTx(t, pool, func(tx Tx) error {
		cands, err := FindCandidates(ctx, tx, money.TJS, 50000, 100)
		if err != nil {
			return err
		}
		byID := map[string]float64{}
		for _, c := range cands {
			byID[c.CreatorID] = c.FraudScore
		}
		if _, ok := byID["creator_busy"]; ok {
			t.Error("эҷодкори дастраснабуда дар номзадҳо")
		}
		if _, ok := byID["creator_expensive"]; ok {
			t.Error("эҷодкори аз буҷет гарон дар номзадҳо")
		}
		if f, ok := byID["creator_flagged"]; !ok || f != 0.8 {
			t.Errorf("холи фиреб: интизор 0.8, гирифтем %v (ҳаст=%v)", f, ok)
		}
		if f := byID["creator_ok"]; f != 0 {
			t.Errorf("парчами пӯшида ҳисоб шуд: %v", f)
		}
		return nil
	})
}

// Тавозун аз дафтар ҳисоб мешавад, на аз сутуни нигоҳдошташуда.
func TestCreatorWalletDerivesFromLedger(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	ctx := context.Background()

	// Ҳамёни холӣ — сифр, на хато.
	runTx(t, pool, func(tx Tx) error {
		w, err := GetCreatorWallet(ctx, tx, "creator_1", money.TJS)
		if err != nil {
			return err
		}
		if w.Available.Minor != 0 || w.Pending.Minor != 0 {
			t.Fatalf("ҳамёни нав бояд сифр бошад: %+v", w)
		}
		return nil
	})

	// Кампанияи анҷомёфта бо як эҷодкори тасдиқшуда, escrow пур.
	camp, creatorID := seedCompletedCampaign(t, pool, 100000, 100000, 1000)

	runTx(t, pool, func(tx Tx) error {
		_, e := CreatePayoutOrder(ctx, tx, camp, creatorID, "manual", "payout-wallet-1")
		return e
	})

	// 10% комиссия → 90000 ба эҷодкор, ки ҳанӯз дар payout-и PENDING аст.
	runTx(t, pool, func(tx Tx) error {
		w, err := GetCreatorWallet(ctx, tx, creatorID, money.TJS)
		if err != nil {
			return err
		}
		if w.Available.Minor != 90000 {
			t.Fatalf("тавозун: интизор 90000, гирифтем %d", w.Available.Minor)
		}
		if w.Pending.Minor != 90000 {
			t.Fatalf("дар роҳ: интизор 90000, гирифтем %d", w.Pending.Minor)
		}
		return nil
	})
}
