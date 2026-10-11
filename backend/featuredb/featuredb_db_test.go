package featuredb

// Санҷиш бо базаи ВОҚЕӢ (бе RAONSON_TEST_DB гузаронда мешавад):
// ёдрасии чорабинӣ, кушодани мактуб ва ғолибони чаленҷ — ҳар кадом як
// бор, ҳатто агар кор ду бор иҷро шавад.

import (
	"context"
	"os"
	"strconv"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/notify"
)

func testDB(t *testing.T) *pgxpool.Pool {
	t.Helper()
	if os.Getenv("RAONSON_TEST_DB") == "" {
		t.Skip("RAONSON_TEST_DB гузошта нашудааст")
	}
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL нест")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(pool.Close)
	return pool
}

func mkUser(t *testing.T, pool *pgxpool.Pool, name string) string {
	t.Helper()
	n := name + strconv.FormatInt(time.Now().UnixNano()%1e10, 36)
	var id string
	if err := pool.QueryRow(context.Background(), `INSERT INTO users(username, email, password)
		VALUES ($1::text, $1::text || '@t.tj', 'x') RETURNING id`, n).Scan(&id); err != nil {
		t.Fatal(err)
	}
	return id
}

type sink struct{ got []notify.Event }

func (s *sink) send(_ context.Context, e notify.Event) { s.got = append(s.got, e) }

func TestEventRemindersOncePerStage(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	host, guest, no := mkUser(t, pool, "evh"), mkUser(t, pool, "evg"), mkUser(t, pool, "evn")
	now := time.Now().UTC()
	start := now.Add(23 * time.Hour)
	var id string
	if err := pool.QueryRow(ctx, `INSERT INTO invite_events(host_id, title, starts_at, created_at)
		VALUES ($1,'Тӯй',$2,$3) RETURNING id`, host, start, now.Add(-72*time.Hour)).Scan(&id); err != nil {
		t.Fatal(err)
	}
	pool.Exec(ctx, `INSERT INTO event_guests(event_id,user_id,rsvp) VALUES ($1,$2,'going'),($1,$3,'declined')`, id, guest, no)

	s := &sink{}
	SendEventReminders(ctx, pool, now, s.send)
	mine := func() []notify.Event {
		var out []notify.Event
		for _, e := range s.got {
			if e.TargetID == id {
				out = append(out, e)
			}
		}
		return out
	}
	got := mine()
	if len(got) != 2 {
		t.Fatalf("«1 рӯз»: мизбон + меҳмони «Меоям», на «Намеоям»: %+v", got)
	}
	for _, e := range got {
		if e.UserID == no || e.Kind != notify.EventReminder {
			t.Errorf("гирандаи нодуруст: %+v", e)
		}
	}
	SendEventReminders(ctx, pool, now.Add(time.Minute), s.send)
	if len(mine()) != 2 {
		t.Error("ёдрасии «1 рӯз» такрор шуд")
	}
	SendEventReminders(ctx, pool, start.Add(-90*time.Minute), s.send)
	if len(mine()) != 4 {
		t.Errorf("«2 соат» нарафт: %d", len(mine()))
	}
	SendEventReminders(ctx, pool, start.Add(-80*time.Minute), s.send)
	if len(mine()) != 4 {
		t.Error("ёдрасии «2 соат» такрор шуд")
	}
}

func TestCapsuleReleaseOnce(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	a, b := mkUser(t, pool, "cpa"), mkUser(t, pool, "cpb")
	now := time.Now().UTC()
	var id, later string
	pool.QueryRow(ctx, `INSERT INTO time_capsules(author_id, audience, recipient_id, text, unlock_at)
		VALUES ($1,'friend',$2,'салом',$3) RETURNING id`, a, b, now.Add(-time.Second)).Scan(&id)
	pool.QueryRow(ctx, `INSERT INTO time_capsules(author_id, audience, text, unlock_at)
		VALUES ($1,'self','баъдтар',$2) RETURNING id`, a, now.Add(time.Hour)).Scan(&later)
	s := &sink{}
	ReleaseCapsules(ctx, pool, now, s.send)
	ReleaseCapsules(ctx, pool, now, s.send)
	to := map[string]int{}
	for _, e := range s.got {
		if e.TargetID == later {
			t.Error("мактуби оянда пеш аз вақт кушода шуд")
		}
		if e.TargetID == id {
			to[e.UserID]++
		}
	}
	if to[a] != 1 || to[b] != 1 {
		t.Errorf("муаллиф ва гиранда як бор: %v", to)
	}
}

func TestFinalizeChallengeWinners(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	p1, p2, fan := mkUser(t, pool, "chp"), mkUser(t, pool, "chq"), mkUser(t, pool, "chf")
	now := time.Now().UTC()
	tag := "тест" + strconv.FormatInt(now.UnixNano()%1e9, 36)
	var cid string
	pool.QueryRow(ctx, `INSERT INTO challenges(creator_id, tag, title, starts_at, ends_at)
		VALUES ($1,$2,'Тест',$3,$4) RETURNING id`, fan, tag, now.Add(-2*time.Hour), now.Add(-time.Minute)).Scan(&cid)
	post := func(uid string) string {
		var id string
		pool.QueryRow(ctx, `INSERT INTO posts(user_id, caption, created_at) VALUES ($1,$2,$3) RETURNING id`,
			uid, "#"+tag, now.Add(-time.Hour)).Scan(&id)
		pool.Exec(ctx, `INSERT INTO content_hashtags(content_kind, content_id, tag, created_at)
			VALUES ('post',$1,$2,$3)`, id, tag, now.Add(-time.Hour))
		return id
	}
	w, l := post(p1), post(p2)
	pool.Exec(ctx, `INSERT INTO post_likes(user_id, post_id, created_at) VALUES ($1,$2,$3)`, fan, w, now.Add(-30*time.Minute))
	// Лайк баъди анҷом ҳисоб намешавад.
	pool.Exec(ctx, `INSERT INTO post_likes(user_id, post_id, created_at) VALUES ($1,$2,$3)`, fan, l, now.Add(time.Hour))
	s := &sink{}
	FinalizeChallenges(ctx, pool, now, s.send)
	FinalizeChallenges(ctx, pool, now, s.send)
	var rows []string
	r, _ := pool.Query(ctx, `SELECT user_id FROM challenge_winners WHERE challenge_id=$1 ORDER BY rank`, cid)
	for r.Next() {
		var u string
		r.Scan(&u)
		rows = append(rows, u)
	}
	r.Close()
	if len(rows) != 1 || rows[0] != p1 {
		t.Errorf("ғолиб танҳо p1 (p2 хол надорад): %v", rows)
	}
	n := 0
	for _, e := range s.got {
		if e.TargetID == cid {
			n++
		}
	}
	if n != 1 {
		t.Errorf("огоҳиномаи ғолиб як бор: %d", n)
	}
}
