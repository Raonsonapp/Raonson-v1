package jobs

// Огоҳиномаҳое, ки аз ҳодисаи корбар не, балки аз ВАҚТ меоянд.
//
// Ҳамаи онҳо аз ҳамон дарвозаи ягона мегузаранд (танзимот, соатҳои
// ором, маҳдудият) ва идемпотентанд: такрори кор огоҳиномаи дуюм
// намедиҳад.
//
// Ҳисоби гарон дар ин ҷо иҷро мешавад, на дар handler-и HTTP.

import (
	"context"
	"log"
	"time"

	"raonson/creator"
	"raonson/db"
	mw "raonson/middleware"
	"raonson/notify"
)

// jobCounter кэши мавҷудро ба дарвоза мепайвандад.
type jobCounter struct{}

func (jobCounter) Get(key string) ([]byte, bool) { return mw.CacheGet(key) }
func (jobCounter) Set(key string, v []byte, ttl time.Duration) {
	mw.CacheSet(key, v, ttl)
}

func notifyDeps() notify.Deps {
	return notify.Deps{
		DB:        db.Pool,
		Now:       time.Now,
		AllowPush: notify.Gate(db.Pool, jobCounter{}, time.Now),
	}
}

// StartNotificationJobs корҳои огоҳиномаро оғоз мекунад.
func StartNotificationJobs() {
	go func() {
		// Каме интизор, то база тайёр шавад.
		time.Sleep(45 * time.Second)
		runNotificationJobs()
		t := time.NewTicker(time.Hour)
		defer t.Stop()
		for range t.C {
			runNotificationJobs()
		}
	}()
}

func runNotificationJobs() {
	notifyWeeklyRecaps()
	notifyNewAchievements()
	cleanDeadTokens()
}

// recapNotifyHour — соати фиристодани ҷамъбаст (UTC).
//
// Минтақаи вақти аксари корбарон маълум нест, бинобар ин соати собит
// интихоб мешавад — на нимишаб. Барои Тоҷикистон (UTC+5) ин тақрибан
// соати 14 аст.
const recapNotifyHour = 9

// notifyWeeklyRecaps ҷамъбасти ҳафтаро эълон мекунад.
//
// Танҳо як бор дар як ҳафта барои ҳар корбар: калиди дедупликатсия
// оғози ҳафтаро дар бар мегирад, бинобар ин такрори кор дар ҳамон
// ҳафта чизе намефиристад.
//
// Танҳо ба онҳое, ки ҳафтаи гузашта ФАЪОЛ буданд: «ҳафтаи шумо тайёр
// аст» ба одами ғайрифаъол ҷамъбасти холӣ мекушояд.
func notifyWeeklyRecaps() {
	now := time.Now().UTC()
	if !shouldSendRecap(now) {
		return
	}
	sendWeeklyRecaps(context.Background(), recapWeekFor(now))
}

// shouldSendRecap мегӯяд, ки оё ҳозир вақти фиристодан аст.
//
// Ҷудо нигоҳ дошта мешавад, то ҷадвал санҷида шавад: кори ҳафтаина,
// ки нодуруст оғоз мешавад, як ҳафта ноаён мемонад.
func shouldSendRecap(now time.Time) bool {
	n := now.UTC()
	return n.Weekday() == time.Monday && n.Hour() == recapNotifyHour
}

// recapWeekFor ҳафтаи ГУЗАШТАи пурраро бармегардонад.
func recapWeekFor(now time.Time) time.Time {
	return creator.WeekStart(now).AddDate(0, 0, -7)
}

func sendWeeklyRecaps(ctx context.Context, week time.Time) int {
	rows, err := db.Pool.Query(ctx, `
		SELECT user_id, COUNT(*) AS events
		FROM feed_events
		WHERE created_at >= $1 AND created_at < $2
		GROUP BY user_id
		HAVING COUNT(*) >= $3
		LIMIT 5000`,
		week, week.AddDate(0, 0, 7), creator.MinRecapActivity)
	if err != nil {
		log.Printf("[Job] recap notify: %v", err)
		return 0
	}
	defer rows.Close()

	var users []string
	for rows.Next() {
		var id string
		var n int
		if err := rows.Scan(&id, &n); err == nil && id != "" {
			users = append(users, id)
		}
	}

	d := notifyDeps()
	suffix := week.Format("2006-01-02")
	for _, id := range users {
		notify.Notify(ctx, d, notify.Event{
			UserID:       id,
			Kind:         notify.WeeklyRecap,
			DedupeSuffix: suffix,
		})
	}
	if len(users) > 0 {
		log.Printf("[Job] weekly recap: %d корбар", len(users))
	}
	return len(users)
}

// notifyNewAchievements нишонҳои навро эълон мекунад.
//
// Рамзи нишон дар калиди дедупликатсия аст, бинобар ин як нишон
// ҳамеша як огоҳинома медиҳад — ҳатто агар кор садҳо бор иҷро шавад.
func notifyNewAchievements() {
	ctx := context.Background()
	rows, err := db.Pool.Query(ctx, `
		SELECT user_id, code FROM creator_achievements
		WHERE earned_at > NOW() - INTERVAL '2 days'
		LIMIT 2000`)
	if err != nil {
		return
	}
	defer rows.Close()

	type badge struct{ user, code string }
	var list []badge
	for rows.Next() {
		var b badge
		if err := rows.Scan(&b.user, &b.code); err == nil {
			list = append(list, b)
		}
	}

	d := notifyDeps()
	for _, b := range list {
		notify.Notify(ctx, d, notify.Event{
			UserID:       b.user,
			Kind:         notify.Achievement,
			TargetID:     b.code,
			DedupeSuffix: b.code,
		})
	}
}

// cleanDeadTokens токенҳои кайҳо хомӯшшударо мебарад.
//
// Онҳо як муддат нигоҳ дошта мешаванд, то саволи «чаро огоҳинома
// намеояд» ҷавоб дошта бошад; баъд ҷои беҳуда мегиранд.
func cleanDeadTokens() {
	res, err := db.Pool.Exec(context.Background(), `
		DELETE FROM device_tokens
		WHERE NOT enabled AND updated_at < NOW() - INTERVAL '30 days'`)
	if err == nil && res.RowsAffected() > 0 {
		log.Printf("[Job] %d токени мурда пок шуд", res.RowsAffected())
	}
}
