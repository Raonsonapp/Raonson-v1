package notify

// Санҷиши роҳи пурра бо базаи ВОҚЕӢ.
//
// Танҳо худи фиристодан иваз мешавад (FCM дар муҳити санҷиш нест) —
// ҳама чизи дигар воқеист: дедупликатсия, гурӯҳбандӣ, забон,
// линки чуқур ва хомӯш кардани токени мурда.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/push"
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

// capture ҳамаи паёмҳоро ҷамъ мекунад ва натиҷаи додашударо
// бармегардонад.
func capture(res push.Result) (func(context.Context, push.Message) (push.Result, error), *[]push.Message) {
	var got []push.Message
	return func(_ context.Context, m push.Message) (push.Result, error) {
		got = append(got, m)
		return res, nil
	}, &got
}

// seed ду корбар ва як постро месозад.
func seed(t *testing.T, pool *pgxpool.Pool, suffix string) (owner, actor, post string) {
	t.Helper()
	ctx := context.Background()
	err := pool.QueryRow(ctx, `
		INSERT INTO users(username, email, password, language)
		VALUES ('owner_`+suffix+`','o_`+suffix+`@t.tj','x','ru')
		RETURNING id`).Scan(&owner)
	if err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `
		INSERT INTO users(username, email, password)
		VALUES ('actor_`+suffix+`','a_`+suffix+`@t.tj','x')
		RETURNING id`).Scan(&actor); err != nil {
		t.Fatal(err)
	}
	if err := pool.QueryRow(ctx, `
		INSERT INTO posts(user_id, caption) VALUES ($1,'x') RETURNING id`,
		owner).Scan(&post); err != nil {
		t.Fatal(err)
	}
	return owner, actor, post
}

// Роҳи пурра: сатр навишта мешавад, push ба ҲАМАИ дастгоҳҳо меравад,
// матн бо забони ГИРАНДА месозад ва линки чуқур дорад.
func TestFullDeliveryPath(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, actor, post := seed(t, pool, "full")

	// Ду дастгоҳи гиранда.
	for _, tok := range []string{"d1-full", "d2-full"} {
		if err := push.SaveToken(ctx, pool, owner, tok, "android", tok); err != nil {
			t.Fatal(err)
		}
	}

	send, got := capture(push.Sent)
	Notify(ctx, Deps{DB: pool, Send: send}, Event{
		UserID: owner, ActorID: actor, Kind: Like, TargetID: post,
	})

	if len(*got) != 2 {
		t.Fatalf("ба %d дастгоҳ фиристода шуд, интизори 2", len(*got))
	}
	m := (*got)[0]
	// Забони гиранда русӣ аст (дар seed гузошта шуд).
	if !strings.Contains(m.Body, "пост") {
		t.Errorf("матн бо забони гиранда нест: %q", m.Body)
	}
	if m.Data["link"] != "/post/"+post {
		t.Errorf("линки чуқур: %q", m.Data["link"])
	}
	if m.ChannelID != string(ChannelSocial) {
		t.Errorf("канал: %q", m.ChannelID)
	}
	if m.HighPriority {
		t.Error("лайк набояд аҳамияти баланд дошта бошад")
	}

	// Сатри маркази огоҳиномаҳо навишта шуд.
	var rows int
	pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND type='like'`,
		owner).Scan(&rows)
	if rows != 1 {
		t.Errorf("сатрҳои огоҳинома: %d, интизори 1", rows)
	}

	var status string
	pool.QueryRow(ctx,
		`SELECT status FROM notification_delivery WHERE user_id=$1`,
		owner).Scan(&status)
	if status != "sent" {
		t.Errorf("ҳолати фиристодан: %q", status)
	}
}

// Ҳамон ҳодиса ду бор — як огоҳинома.
func TestDedupe(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, actor, post := seed(t, pool, "dedupe")
	push.SaveToken(ctx, pool, owner, "d-dedupe", "android", "d")

	send, got := capture(push.Sent)
	d := Deps{DB: pool, Send: send}
	e := Event{UserID: owner, ActorID: actor, Kind: Like, TargetID: post}
	Notify(ctx, d, e)
	Notify(ctx, d, e)
	Notify(ctx, d, e)

	if len(*got) != 1 {
		t.Errorf("%d push фиристода шуд, интизори 1", len(*got))
	}
	var rows int
	pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1`, owner).Scan(&rows)
	if rows != 1 {
		t.Errorf("%d сатр, интизори 1", rows)
	}
}

// Панҷ нафар як постро писандиданд → матни гурӯҳӣ.
func TestGroupingCountsOtherPeople(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, _, post := seed(t, pool, "group")
	push.SaveToken(ctx, pool, owner, "d-group", "android", "d")

	send, got := capture(push.Sent)
	d := Deps{DB: pool, Send: send}

	for i := 0; i < 5; i++ {
		var actor string
		pool.QueryRow(ctx, `
			INSERT INTO users(username, email, password)
			VALUES ($1,$2,'x') RETURNING id`,
			"liker_group_"+itoa(i), "lg"+itoa(i)+"@t.tj").Scan(&actor)
		Notify(ctx, d, Event{UserID: owner, ActorID: actor,
			Kind: Like, TargetID: post})
	}

	if len(*got) != 5 {
		t.Fatalf("%d push, интизори 5", len(*got))
	}
	// Аввалин — як нафар, бе рақам.
	if strings.Contains((*got)[0].Body, "4") {
		t.Errorf("аввалин push матни гурӯҳӣ гирифт: %q", (*got)[0].Body)
	}
	// Охирин — «ва 4 нафари дигар».
	last := (*got)[4].Body
	if !strings.Contains(last, "4") {
		t.Errorf("охирин push гурӯҳбандӣ нашуд: %q", last)
	}
}

// Токене, ки провайдер рад кард, хомӯш мешавад — вагарна абадӣ
// кӯшиш мекардем.
func TestDeadTokenIsDisabled(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, actor, post := seed(t, pool, "dead")
	push.SaveToken(ctx, pool, owner, "d-dead", "android", "d")

	send, _ := capture(push.TokenDead)
	Notify(ctx, Deps{DB: pool, Send: send}, Event{
		UserID: owner, ActorID: actor, Kind: Like, TargetID: post,
	})

	var enabled bool
	var reason string
	pool.QueryRow(ctx,
		`SELECT enabled, disabled_reason FROM device_tokens WHERE token='d-dead'`).
		Scan(&enabled, &reason)
	if enabled {
		t.Error("токени мурда хомӯш нашуд")
	}
	if reason == "" {
		t.Error("сабаби хомӯшӣ сабт нашуд")
	}
}

// Хатои муваққатӣ НАБОЯД токенро нобуд кунад.
func TestTemporaryFailureKeepsToken(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, actor, post := seed(t, pool, "temp")
	push.SaveToken(ctx, pool, owner, "d-temp", "android", "d")

	send, _ := capture(push.Retry)
	Notify(ctx, Deps{DB: pool, Send: send}, Event{
		UserID: owner, ActorID: actor, Kind: Like, TargetID: post,
	})

	var enabled bool
	pool.QueryRow(ctx,
		`SELECT enabled FROM device_tokens WHERE token='d-temp'`).Scan(&enabled)
	if !enabled {
		t.Error("хатои муваққатӣ токени солимро нобуд кард")
	}
}

// Корбари блоккарда огоҳинома тавлид намекунад.
func TestBlockedActorProducesNothing(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, actor, post := seed(t, pool, "block")
	push.SaveToken(ctx, pool, owner, "d-block", "android", "d")
	if _, err := pool.Exec(ctx,
		`INSERT INTO blocks(blocker_id, blocked_id) VALUES ($1,$2)`,
		owner, actor); err != nil {
		t.Fatal(err)
	}

	send, got := capture(push.Sent)
	Notify(ctx, Deps{DB: pool, Send: send}, Event{
		UserID: owner, ActorID: actor, Kind: Like, TargetID: post,
	})

	if len(*got) != 0 {
		t.Error("блоккардашуда push фиристод")
	}
	var rows int
	pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1`, owner).Scan(&rows)
	if rows != 0 {
		t.Errorf("блоккардашуда %d сатр сохт", rows)
	}
}

// Танзимот push-ро бас мекунад, ВАЛЕ сатри огоҳинома мемонад:
// корбар онро дар барнома мебинад.
func TestPreferenceStopsPushButKeepsRow(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, actor, post := seed(t, pool, "pref")
	push.SaveToken(ctx, pool, owner, "d-pref", "android", "d")
	if _, err := pool.Exec(ctx,
		`UPDATE users SET notif_prefs='{"likes":false}'::jsonb WHERE id=$1`,
		owner); err != nil {
		t.Fatal(err)
	}

	send, got := capture(push.Sent)
	Notify(ctx, Deps{
		DB:        pool,
		Send:      send,
		AllowPush: Gate(pool, nil, time.Now),
	}, Event{UserID: owner, ActorID: actor, Kind: Like, TargetID: post})

	if len(*got) != 0 {
		t.Error("танзимот push-ро бас накард")
	}
	var rows int
	pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1`, owner).Scan(&rows)
	if rows != 1 {
		t.Errorf("сатр гум шуд: %d", rows)
	}
	var reason string
	pool.QueryRow(ctx,
		`SELECT reason FROM notification_delivery WHERE user_id=$1`,
		owner).Scan(&reason)
	if reason != "preference" {
		t.Errorf("сабаб: %q, интизори preference", reason)
	}
}

// Худро огоҳ намекунем.
func TestNoSelfNotification(t *testing.T) {
	pool := testDB(t)
	ctx := context.Background()
	owner, _, post := seed(t, pool, "self")
	push.SaveToken(ctx, pool, owner, "d-self", "android", "d")

	send, got := capture(push.Sent)
	Notify(ctx, Deps{DB: pool, Send: send}, Event{
		UserID: owner, ActorID: owner, Kind: Like, TargetID: post,
	})
	if len(*got) != 0 {
		t.Error("корбар ба худаш огоҳинома фиристод")
	}
}
