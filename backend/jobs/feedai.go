package jobs

// Кори паснамои «Лентаи AI».
//
// Ду вазифа:
//   1. Мӯҳтавои нав ба мавзӯъҳо тақсим мешавад (аз матн, бе LLM).
//   2. Ҳодисаҳои ҷамъшуда ба профили корбар гузаронда мешаванд.
//
// Ҳарду дар паснамо иҷро мешаванд, то дархости лента ҳеҷ гоҳ интизори
// таснифот нашавад.

import (
	"context"
	"log"
	"time"

	"raonson/db"
	"raonson/feedai"
)

const (
	// Дар як давр чанд мӯҳтаво тасниф мешавад. Маҳдудият лозим аст:
	// дар оғоз ҷадвал метавонад ҳазорҳо пости таснифнашуда дошта
	// бошад ва як давр набояд DB-ро банд кунад.
	classifyBatch = 200
	// Чанд ҳодиса дар як давр коркард мешавад.
	eventBatch = 500
)

// StartFeedAIJobs корҳои лентаи AI-ро оғоз мекунад.
func StartFeedAIJobs() {
	go func() {
		time.Sleep(60 * time.Second) // сервер аввал боло ояд
		runFeedAICycle()
		ticker := time.NewTicker(5 * time.Minute)
		for range ticker.C {
			runFeedAICycle()
		}
	}()
}

func runFeedAICycle() {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("feedai jobs: panic: %v", r)
		}
	}()
	classifyNewContent()
	aggregateEvents()
}

// classifyNewContent мӯҳтавои ҳанӯз таснифнашударо ба мавзӯъҳо тақсим
// мекунад.
//
// Таснифот бо мувофиқати калидвожа аст, на бо LLM: даъвати AI барои
// ҳар пост гарон мебуд ва натиҷа ба ҳар ҳол дар ҷадвал кэш мешуд.
func classifyNewContent() {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	topics, err := feedai.LoadTopics(ctx, db.Pool)
	if err != nil || len(topics) == 0 {
		if err != nil {
			log.Printf("feedai jobs: мавзӯъҳо: %v", err)
		}
		return
	}

	total := 0
	for _, kind := range []struct{ typ, table string }{
		{"post", "posts"}, {"reel", "reels"},
	} {
		// Танҳо мӯҳтавое, ки ҳанӯз ягон сатри мавзӯъ надорад.
		// NOT EXISTS аз индекси PK-и content_topics истифода мебарад.
		rows, err := db.Pool.Query(ctx, `
			SELECT c.id, COALESCE(c.caption,'')
			FROM `+kind.table+` c
			WHERE NOT EXISTS (
			  SELECT 1 FROM content_topics ct
			  WHERE ct.content_type=$1 AND ct.content_id=c.id)
			ORDER BY c.created_at DESC
			LIMIT $2`, kind.typ, classifyBatch)
		if err != nil {
			log.Printf("feedai jobs: интихоби %s: %v", kind.typ, err)
			continue
		}
		type item struct{ id, caption string }
		items := []item{}
		for rows.Next() {
			var it item
			if err := rows.Scan(&it.id, &it.caption); err == nil {
				items = append(items, it)
			}
		}
		rows.Close()

		for _, it := range items {
			found := feedai.ClassifyText(it.caption, topics)
			if len(found) == 0 {
				// Мавзӯъ ёфт нашуд. Сатри «холӣ» бо мавзӯи хизматӣ
				// сабт НАМЕШАВАД — вагарна мо мавзӯи бардурӯғ месохтем.
				// Ба ҷои он пост дар давраи оянда дубора кӯшиш мешавад,
				// вақте калидвожаҳо васеътар шаванд.
				continue
			}
			for slug, w := range found {
				if _, err := db.Pool.Exec(ctx, `
					INSERT INTO content_topics(content_type, content_id, topic_slug, weight)
					VALUES ($1,$2,$3,$4)
					ON CONFLICT (content_type, content_id, topic_slug) DO NOTHING`,
					kind.typ, it.id, slug, w); err != nil {
					log.Printf("feedai jobs: сабти мавзӯъ: %v", err)
					break
				}
			}
			total++
		}
	}
	if total > 0 {
		log.Printf("feedai jobs: %d мӯҳтаво тасниф шуд", total)
	}
}

// aggregateEvents ҳодисаҳои сабтшударо ба профили корбар мегузаронад.
//
// Сигналҳои қавӣ (монанди ин бештар/камтар) аллакай ҳангоми сабт
// татбиқ шудаанд ва processed=TRUE доранд; ин ҷо танҳо сигналҳои
// заиф ҷамъ мешаванд.
func aggregateEvents() {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	rows, err := db.Pool.Query(ctx, `
		SELECT id, user_id, content_type, content_id, creator_id, weight
		FROM feed_events
		WHERE processed = FALSE
		ORDER BY created_at ASC
		LIMIT $1`, eventBatch)
	if err != nil {
		log.Printf("feedai jobs: ҳодисаҳо: %v", err)
		return
	}
	type ev struct {
		id                            int64
		userID, cType, cID, creatorID string
		weight                        float64
	}
	list := []ev{}
	for rows.Next() {
		var e ev
		if err := rows.Scan(&e.id, &e.userID, &e.cType, &e.cID,
			&e.creatorID, &e.weight); err == nil {
			list = append(list, e)
		}
	}
	rows.Close()
	if len(list) == 0 {
		return
	}

	ids := make([]int64, 0, len(list))
	for _, e := range list {
		if err := feedai.ApplyEvent(ctx, db.Pool, e.userID, e.cType,
			e.cID, e.creatorID, e.weight); err != nil {
			log.Printf("feedai jobs: татбиқи ҳодиса %d: %v", e.id, err)
			continue
		}
		ids = append(ids, e.id)
	}
	if len(ids) == 0 {
		return
	}
	// Танҳо онҳое, ки воқеан татбиқ шуданд, ҳамчун коркардшуда сабт
	// мешаванд — вагарна сигнали ноком хомӯшона гум мешуд.
	if _, err := db.Pool.Exec(ctx,
		`UPDATE feed_events SET processed = TRUE WHERE id = ANY($1)`,
		ids); err != nil {
		log.Printf("feedai jobs: сабти коркард: %v", err)
		return
	}
	log.Printf("feedai jobs: %d ҳодиса коркард шуд", len(ids))
}
