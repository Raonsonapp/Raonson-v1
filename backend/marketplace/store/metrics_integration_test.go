package store

import (
	"context"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/marketplace/domain"
)

// contentSchema — ҷадвалҳои Raonson, ки метрика аз онҳо ҷамъ мешавад.
//
// Танҳо сутунҳое, ки CollectCreatorMetrics мехонад. Ҳадаф ин аст,
// ки query-ҳо бо сохтори ВОҚЕӢ санҷида шаванд, на бо mock.
const contentSchema = `
CREATE TABLE IF NOT EXISTS follows (
    follower_id  TEXT NOT NULL,
    following_id TEXT NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (follower_id, following_id)
);
CREATE TABLE IF NOT EXISTS posts (
    id             TEXT PRIMARY KEY,
    user_id        TEXT NOT NULL,
    caption        TEXT DEFAULT '',
    likes_count    INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    archived       BOOLEAN DEFAULT FALSE,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS reels (
    id             TEXT PRIMARY KEY,
    user_id        TEXT NOT NULL,
    likes_count    INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    views_count    INTEGER DEFAULT 0,
    created_at     TIMESTAMPTZ DEFAULT NOW()
);
CREATE TABLE IF NOT EXISTS post_views (
    user_id   TEXT NOT NULL,
    post_id   TEXT NOT NULL,
    viewed_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);
CREATE TABLE IF NOT EXISTS post_saves (
    user_id TEXT NOT NULL,
    post_id TEXT NOT NULL,
    PRIMARY KEY (user_id, post_id)
);`

func applyContentSchema(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	if _, err := pool.Exec(context.Background(), contentSchema); err != nil {
		t.Fatalf("схемаи мӯҳтаво: %v", err)
	}
	if _, err := pool.Exec(context.Background(),
		`TRUNCATE follows, posts, reels, post_views, post_saves`); err != nil {
		t.Fatalf("тозакунӣ: %v", err)
	}
}

// Метрика аз ҷадвалҳои ВОҚЕӢ ҷамъ мешавад — на аз counter-и кэшшуда.
func TestCollectCreatorMetricsFromRealTables(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	applyContentSchema(t, pool)
	ctx := context.Background()

	// 3 пайрав.
	for _, f := range []string{"u1", "u2", "u3"} {
		if _, err := pool.Exec(ctx,
			`INSERT INTO follows(follower_id, following_id) VALUES ($1,'creator_1')`, f); err != nil {
			t.Fatal(err)
		}
	}
	// 2 пости фаъол + 1 бойгонишуда (набояд ҳисоб шавад).
	if _, err := pool.Exec(ctx, `
		INSERT INTO posts(id,user_id,likes_count,comments_count,archived) VALUES
		  ('p1','creator_1',10,2,FALSE),
		  ('p2','creator_1',20,3,FALSE),
		  ('p3','creator_1',99,99,TRUE)`); err != nil {
		t.Fatal(err)
	}
	// 1 рилс.
	if _, err := pool.Exec(ctx, `
		INSERT INTO reels(id,user_id,likes_count,comments_count,views_count)
		VALUES ('r1','creator_1',30,5,500)`); err != nil {
		t.Fatal(err)
	}
	// Бинишҳо ва захираҳо.
	if _, err := pool.Exec(ctx, `
		INSERT INTO post_views(user_id,post_id) VALUES ('u1','p1'),('u2','p1'),('u3','p2')`); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `
		INSERT INTO post_saves(user_id,post_id) VALUES ('u1','p1')`); err != nil {
		t.Fatal(err)
	}

	runTx(t, pool, func(tx Tx) error {
		m, err := CollectCreatorMetrics(ctx, tx, "creator_1")
		if err != nil {
			return err
		}
		if m.Followers != 3 {
			t.Errorf("пайравон: интизор 3, гирифтем %d", m.Followers)
		}
		// Пости бойгонишуда набояд ҳисоб шавад: 2 пост + 1 рилс.
		if m.ContentCount != 3 {
			t.Errorf("мӯҳтаво: интизор 3, гирифтем %d", m.ContentCount)
		}
		if m.Likes != 60 { // 10+20+30
			t.Errorf("лайкҳо: интизор 60, гирифтем %d", m.Likes)
		}
		if m.Comments != 10 { // 2+3+5
			t.Errorf("шарҳҳо: интизор 10, гирифтем %d", m.Comments)
		}
		if m.TotalViews != 503 { // 3 биниши пост + 500 рилс
			t.Errorf("бинишҳо: интизор 503, гирифтем %d", m.TotalViews)
		}
		if m.Saves != 1 {
			t.Errorf("захираҳо: интизор 1, гирифтем %d", m.Saves)
		}
		// Ҷадвали share нест — сохта намешавад.
		if m.Shares != 0 {
			t.Errorf("мубодила бояд 0 бошад, гирифтем %d", m.Shares)
		}
		return nil
	})

	// Эҷодкори бе ҳеҷ мӯҳтаво — ҳама сифр, бе хато.
	runTx(t, pool, func(tx Tx) error {
		m, err := CollectCreatorMetrics(ctx, tx, "creator_empty")
		if err != nil {
			return err
		}
		if m.Followers != 0 || m.ContentCount != 0 || m.AverageViews != 0 {
			t.Errorf("эҷодкори холӣ: %+v", m)
		}
		return nil
	})
}

// Аломати фиреб аз номувофиқатии ВОҚЕИИ рақамҳо меояд.
func TestDetectCreatorFraudUsesRealSignals(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	applyContentSchema(t, pool)
	ctx := context.Background()

	// Эҷодкори солим: лайкҳо аз бинишҳо камтар.
	if _, err := pool.Exec(ctx, `
		INSERT INTO reels(id,user_id,likes_count,views_count)
		VALUES ('r_ok','creator_ok',50,1000)`); err != nil {
		t.Fatal(err)
	}
	// Эҷодкори шубҳанок: лайк аз биниш зиёд.
	if _, err := pool.Exec(ctx, `
		INSERT INTO reels(id,user_id,likes_count,views_count)
		VALUES ('r_bad','creator_bad',5000,100)`); err != nil {
		t.Fatal(err)
	}

	runTx(t, pool, func(tx Tx) error {
		ok, err := DetectCreatorFraud(ctx, tx, "creator_ok")
		if err != nil {
			return err
		}
		if len(ok) != 0 {
			t.Errorf("эҷодкори солим парчам гирифт: %+v", ok)
		}

		bad, err := DetectCreatorFraud(ctx, tx, "creator_bad")
		if err != nil {
			return err
		}
		found := false
		for _, s := range bad {
			if s.Signal == "likes_exceed_views" {
				found = true
			}
		}
		if !found {
			t.Errorf("аломати likes_exceed_views ёфт нашуд: %+v", bad)
		}
		return SaveFraudSignals(ctx, tx, "creator_bad", bad)
	})

	// Такрори ҳамон аломат сатри дуюм намесозад.
	runTx(t, pool, func(tx Tx) error {
		again, err := DetectCreatorFraud(ctx, tx, "creator_bad")
		if err != nil {
			return err
		}
		return SaveFraudSignals(ctx, tx, "creator_bad", again)
	})
	var n int
	if err := pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM fraud_flags
		WHERE entity_id='creator_bad' AND signal='likes_exceed_views' AND status='OPEN'`).
		Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 1 {
		t.Fatalf("интизори 1 парчами кушода, гирифтем %d", n)
	}

	// Сабаб гузашт → парчам пӯшида мешавад.
	if _, err := pool.Exec(ctx,
		`UPDATE reels SET likes_count=10, views_count=1000 WHERE id='r_bad'`); err != nil {
		t.Fatal(err)
	}
	runTx(t, pool, func(tx Tx) error {
		cur, err := DetectCreatorFraud(ctx, tx, "creator_bad")
		if err != nil {
			return err
		}
		return ClearResolvedFraudSignals(ctx, tx, "creator_bad", cur)
	})
	if err := pool.QueryRow(ctx, `
		SELECT COUNT(*) FROM fraud_flags
		WHERE entity_id='creator_bad' AND status='OPEN'`).Scan(&n); err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Fatalf("парчами кӯҳна пӯшида нашуд: %d кушода монд", n)
	}
}

// Ҷамъбасти кампания танҳо мӯҳтавои воқеан пайвастшударо мешуморад.
func TestAggregateCampaignMetrics(t *testing.T) {
	pool := testPool(t)
	applySchema(t, pool)
	resetTables(t, pool)
	applyContentSchema(t, pool)
	ctx := context.Background()

	adv, camp := seedCampaign(t, pool, 100000, 1000)
	forceStatus(t, pool, camp, domain.CampaignPaid)

	if _, err := pool.Exec(ctx, `
		INSERT INTO posts(id,user_id,likes_count,comments_count) VALUES ('p1','creator_1',42,7)`); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `
		INSERT INTO post_views(user_id,post_id) VALUES ('a','p1'),('b','p1')`); err != nil {
		t.Fatal(err)
	}

	var o1, o2 Offer
	runTx(t, pool, func(tx Tx) error {
		var err error
		if o1, err = InviteCreator(ctx, tx, camp, "creator_1", adv, 40000, noMatch()); err != nil {
			return err
		}
		o2, err = InviteCreator(ctx, tx, camp, "creator_2", adv, 40000, noMatch())
		return err
	})
	runTx(t, pool, func(tx Tx) error {
		if _, err := RespondToOffer(ctx, tx, o1.ID, "creator_1", true); err != nil {
			return err
		}
		if _, err := RespondToOffer(ctx, tx, o2.ID, "creator_2", true); err != nil {
			return err
		}
		// Танҳо якум мӯҳтаво супорид.
		return SubmitContent(ctx, tx, o1.ID, "creator_1", "p1", "post")
	})

	runTx(t, pool, func(tx Tx) error {
		return AggregateCampaignMetrics(ctx, tx, camp)
	})

	runTx(t, pool, func(tx Tx) error {
		rows, err := GetCampaignMetrics(ctx, tx, camp)
		if err != nil {
			return err
		}
		// Эҷодкори бе мӯҳтаво сатр надорад — рақами сохта намешавад.
		if len(rows) != 1 {
			t.Fatalf("интизори 1 сатр, гирифтем %d", len(rows))
		}
		r := rows[0]
		if r.CreatorID != "creator_1" {
			t.Fatalf("эҷодкор: %s", r.CreatorID)
		}
		if r.Likes != 42 || r.Comments != 7 || r.Views != 2 {
			t.Fatalf("рақамҳо: %+v", r)
		}
		return nil
	})

	// Такрори ҷамъбаст рақамҳоро дучанд намекунад.
	runTx(t, pool, func(tx Tx) error {
		return AggregateCampaignMetrics(ctx, tx, camp)
	})
	runTx(t, pool, func(tx Tx) error {
		rows, err := GetCampaignMetrics(ctx, tx, camp)
		if err != nil {
			return err
		}
		if len(rows) != 1 || rows[0].Likes != 42 {
			t.Fatalf("такрори ҷамъбаст рақамҳоро тағйир дод: %+v", rows)
		}
		return nil
	})
}
