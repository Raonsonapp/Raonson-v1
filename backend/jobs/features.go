package jobs

// Корҳои вақтии имкониятҳои нав — ҳар дақиқа:
//   - ёдрасии чорабинӣ (1 рӯз ва 2 соат пеш);
//   - кушодани «Мактуб ба оянда» ва огоҳинома;
//   - эълони ғолибони чаленҷҳои тамомшуда (нишон дар профил).
//
// Ҳар се идемпотентанд (байрақи атомӣ + калиди дедупликатсия): агар
// кор ду бор ё дар ду нусхаи сервер иҷро шавад, огоҳинома дубора
// намеравад.

import (
	"context"
	"log"
	"time"

	"raonson/db"
	"raonson/featuredb"
	"raonson/notify"
)

// StartFeatureJobs корҳоро оғоз мекунад.
func StartFeatureJobs() {
	go func() {
		// Каме интизор, то база ва миграцияҳо тайёр шаванд.
		time.Sleep(20 * time.Second)
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for {
			runFeatureJobs(time.Now().UTC())
			<-t.C
		}
	}()
}

func runFeatureJobs(now time.Time) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("[Job] features: %v", r)
		}
	}()
	ctx := context.Background()
	d := notifyDeps()
	send := func(ctx context.Context, e notify.Event) { notify.Notify(ctx, d, e) }
	if n := featuredb.SendEventReminders(ctx, db.Pool, now, send); n > 0 {
		log.Printf("[Job] ёдрасии чорабинӣ: %d", n)
	}
	if n := featuredb.ReleaseCapsules(ctx, db.Pool, now, send); n > 0 {
		log.Printf("[Job] мактуб ба оянда кушода шуд: %d огоҳинома", n)
	}
	if n := featuredb.FinalizeChallenges(ctx, db.Pool, now, send); n > 0 {
		log.Printf("[Job] ғолибони чаленҷ: %d", n)
	}
}
