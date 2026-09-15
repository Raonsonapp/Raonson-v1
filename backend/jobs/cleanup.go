package jobs

import (
	"context"
	"log"
	"time"

	"raonson/db"
)

func StartJobs() {
	// Start queue workers
	processFeedQueue()
	processNotifQueue()
	processEmailQueue()
	processMediaQueue()

	// Background scheduled jobs
	go func() {
		runAll()
		ticker := time.NewTicker(1 * time.Hour)
		for range ticker.C {
			runAll()
		}
	}()

	// Stats every 10 minutes
	go func() {
		time.Sleep(30 * time.Second) // wait for DB ready
		runStatsJob()
		ticker := time.NewTicker(10 * time.Minute)
		for range ticker.C {
			runStatsJob()
		}
	}()

	// Creator Marketplace — метрика, ҷамъбаст ва такрори payout.
	StartMarketplaceJobs()

	// Лентаи AI — таснифи мӯҳтаво ва ҷамъбасти ҳодисаҳо.
	StartFeedAIJobs()

	// Огоҳиномаҳои вақтӣ: ҷамъбаст, нишон, поксозии токен.
	StartNotificationJobs()

	log.Println("✅ All background jobs + queues started")
}

func runAll() {
	cleanExpiredStories()
	cleanOldNotifications()
	cleanOldPostViews()
	cleanOldAdSessions()
}

// cleanOldAdSessions сеансҳои кӯҳнаи рекламаро мебарорад.
//
// Сеанси кушода, ки реклама дар он бор нашуд, то абад мемонад.
// Онҳо зиёданд: ҳар кӯшиши тамошо як сатр.
//
// Мӯҳлат + 1 рӯз интизор мешавем, то сатри навакак мӯҳлаташ
// расида барои ташхис дастрас бошад.
func cleanOldAdSessions() {
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM ad_watch_sessions WHERE expires_at < NOW() - INTERVAL '1 day'`)
	if res.RowsAffected() > 0 {
		log.Printf("[Job] deleted %d old ad watch sessions", res.RowsAffected())
	}
}

func cleanExpiredStories() {
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM stories WHERE expires_at < NOW() - INTERVAL '1 hour'`)
	if res.RowsAffected() > 0 {
		log.Printf("[Job] deleted %d expired stories", res.RowsAffected())
	}
}

func cleanOldNotifications() {
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM notifications WHERE read=TRUE AND created_at < NOW() - INTERVAL '30 days'`)
	if res.RowsAffected() > 0 {
		log.Printf("[Job] deleted %d old notifications", res.RowsAffected())
	}
}

func cleanOldPostViews() {
	// Keep only last 500 views per user
	res, _ := db.Pool.Exec(context.Background(), `
		DELETE FROM post_views WHERE (user_id, post_id) IN (
		  SELECT user_id, post_id FROM (
		    SELECT user_id, post_id,
		           ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY viewed_at DESC) rn
		    FROM post_views
		  ) t WHERE rn > 500
		)`)
	if res.RowsAffected() > 0 {
		log.Printf("[Job] cleaned %d old post views", res.RowsAffected())
	}
}
