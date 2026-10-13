// Package featuredb — дархостҳои база, ки ҳам handler-ҳо ва ҳам корҳои
// вақтӣ (jobs) истифода мебаранд: ҷадвали чаленҷ, ёдрасии чорабинӣ,
// кушодани «Мактуб ба оянда» ва эълони ғолибони чаленҷ.
//
// `jobs` наметавонад `handlers`-ро import кунад, бинобар ин мантиқи
// умумӣ ин ҷост — як дархост, як қоида.
package featuredb

import (
	"context"
	"time"

	"raonson/features"
	"raonson/notify"
	"raonson/push"
)

// ChallengeEntries — ҳамаи иштирокҳои намоёни чаленҷ.
//
// Иштирок = пост ё Reel бо хештег, ки дар давраи чаленҷ нашр шуд.
// Хориҷ: ҳисоби пӯшида (чаленҷ оммавист), манъшуда, пинҳон/бойгонӣ,
// Reel-и интизори санҷиш ва бастан бо тамошобин (viewer="" — ҳеҷ).
// Хол танҳо аз лайк/шарҳи ДАВРАИ чаленҷ, бе худи муаллиф ва бе ҳисобҳои
// манъшуда; ҳар ҳисоб ба як иштирок ҳадди аксар як лайк ва як шарҳ
// (COUNT DISTINCT) медиҳад.
func ChallengeEntries(ctx context.Context, db push.DB, tag string, start, end time.Time, viewer string) ([]features.Entry, error) {
	rows, err := db.Query(ctx, `
	WITH e AS (
	  SELECT 'post'::text AS kind, p.id AS id, p.user_id AS user_id, p.created_at AS created_at
	    FROM content_hashtags ch
	    JOIN posts p ON p.id = ch.content_id
	    JOIN users u ON u.id = p.user_id
	   WHERE ch.content_kind = 'post' AND ch.tag = $1
	     AND p.created_at >= $2 AND p.created_at <= $3
	     AND COALESCE(p.hidden,false) = FALSE AND COALESCE(p.archived,false) = FALSE
	     AND (p.scheduled_at IS NULL OR p.scheduled_at <= NOW())
	     AND COALESCE(u.banned,false) = FALSE AND COALESCE(u.is_private,false) = FALSE
	     AND NOT EXISTS (SELECT 1 FROM blocks b
	          WHERE (b.blocker_id = $4 AND b.blocked_id = p.user_id)
	             OR (b.blocker_id = p.user_id AND b.blocked_id = $4))
	  UNION ALL
	  SELECT 'reel'::text, r.id, r.user_id, r.created_at
	    FROM content_hashtags ch
	    JOIN reels r ON r.id = ch.content_id
	    JOIN users u ON u.id = r.user_id
	   WHERE ch.content_kind = 'reel' AND ch.tag = $1
	     AND r.created_at >= $2 AND r.created_at <= $3
	     AND COALESCE(r.media_missing,false) = FALSE AND COALESCE(r.mod_hold,false) = FALSE
	     AND COALESCE(u.banned,false) = FALSE AND COALESCE(u.is_private,false) = FALSE
	     AND NOT EXISTS (SELECT 1 FROM blocks b
	          WHERE (b.blocker_id = $4 AND b.blocked_id = r.user_id)
	             OR (b.blocker_id = r.user_id AND b.blocked_id = $4))
	)
	SELECT e.kind, e.id, e.user_id, e.created_at,
	  CASE WHEN e.kind = 'post' THEN
	    (SELECT COUNT(DISTINCT l.user_id) FROM post_likes l JOIN users lu ON lu.id = l.user_id
	      WHERE l.post_id = e.id AND l.user_id <> e.user_id AND COALESCE(lu.banned,false) = FALSE
	        AND COALESCE(l.created_at, NOW()) BETWEEN $2 AND $3)
	  ELSE
	    (SELECT COUNT(DISTINCT l.user_id) FROM reel_likes l JOIN users lu ON lu.id = l.user_id
	      WHERE l.reel_id = e.id AND l.user_id <> e.user_id AND COALESCE(lu.banned,false) = FALSE
	        AND COALESCE(l.created_at, NOW()) BETWEEN $2 AND $3)
	  END,
	  CASE WHEN e.kind = 'post' THEN
	    (SELECT COUNT(DISTINCT cm.user_id) FROM comments cm JOIN users cu ON cu.id = cm.user_id
	      WHERE cm.post_id = e.id AND cm.user_id <> e.user_id AND COALESCE(cm.hidden,false) = FALSE
	        AND COALESCE(cu.banned,false) = FALSE AND cm.created_at BETWEEN $2 AND $3)
	  ELSE
	    (SELECT COUNT(DISTINCT cm.user_id) FROM reel_comments cm JOIN users cu ON cu.id = cm.user_id
	      WHERE cm.reel_id = e.id AND cm.user_id <> e.user_id AND COALESCE(cm.hidden,false) = FALSE
	        AND COALESCE(cu.banned,false) = FALSE AND cm.created_at BETWEEN $2 AND $3)
	  END
	FROM e
	LIMIT 5000`, tag, start, end, viewer)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []features.Entry
	for rows.Next() {
		var e features.Entry
		var likers, commenters int64
		if err := rows.Scan(&e.Kind, &e.ID, &e.UserID, &e.CreatedAt, &likers, &commenters); err != nil {
			return nil, err
		}
		e.Likers, e.Commenters = int(likers), int(commenters)
		out = append(out, e)
	}
	return out, rows.Err()
}

// Notifier — фиристодани огоҳинома (дар тест иваз мешавад).
type Notifier func(ctx context.Context, e notify.Event)

// SendEventReminders — ёдрасиҳои «1 рӯз» ва «2 соат» пеш аз оғоз.
//
// Ҳар марҳила як бор: байрақи база атомӣ «гирифта» мешавад (UPDATE ...
// WHERE reminded_x=FALSE), ва калиди дедупликатсия вақти оғозро дар бар
// мегирад — агар мизбон вақтро иваз кунад, ёдрасӣ аз нав меравад.
// Бармегардонад шумораи огоҳиномаҳо.
func SendEventReminders(ctx context.Context, db push.DB, now time.Time, send Notifier) int {
	rows, err := db.Query(ctx, `
		SELECT id, created_at, starts_at, reminded_day, reminded_2h FROM invite_events
		 WHERE cancelled = FALSE AND hidden = FALSE
		   AND starts_at > $1 AND starts_at <= $1 + INTERVAL '24 hours'
		   AND (reminded_day = FALSE OR reminded_2h = FALSE)
		 ORDER BY starts_at LIMIT 500`, now)
	if err != nil {
		return 0
	}
	type due struct {
		id    string
		start time.Time
		stage string
	}
	var list []due
	for rows.Next() {
		var id string
		var created, start time.Time
		var day, two bool
		if rows.Scan(&id, &created, &start, &day, &two) != nil {
			continue
		}
		if st := features.DueReminder(now, created, start, day, two); st != "" {
			list = append(list, due{id, start, st})
		}
	}
	rows.Close()

	sent := 0
	for _, d := range list {
		q := `UPDATE invite_events SET reminded_day = TRUE WHERE id = $1 AND reminded_day = FALSE`
		if d.stage == features.Reminder2h {
			q = `UPDATE invite_events SET reminded_2h = TRUE, reminded_day = TRUE
			      WHERE id = $1 AND reminded_2h = FALSE`
		}
		tag, err := db.Exec(ctx, q, d.id)
		if err != nil || tag.RowsAffected() == 0 {
			continue
		}
		for _, uid := range eventAudience(ctx, db, d.id) {
			send(ctx, notify.Event{
				UserID: uid, Kind: notify.EventReminder, TargetID: d.id,
				DedupeSuffix: d.stage + ":" + d.start.UTC().Format(time.RFC3339),
			})
			sent++
		}
	}
	return sent
}

// eventAudience — мизбонон ва меҳмонони «Меоям/Шояд».
func eventAudience(ctx context.Context, db push.DB, id string) []string {
	rows, err := db.Query(ctx, `
		SELECT host_id FROM invite_events WHERE id = $1
		UNION SELECT user_id FROM event_cohosts WHERE event_id = $1
		UNION SELECT user_id FROM event_guests WHERE event_id = $1 AND rsvp IN ('going','maybe')
		LIMIT 2000`, id)
	if err != nil {
		return nil
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var u string
		if rows.Scan(&u) == nil && u != "" {
			out = append(out, u)
		}
	}
	return out
}

// ReleaseCapsules — мактубҳое, ки вақташон расид: «кушода» ва огоҳинома.
//
// Матн аллакай аз рӯи вақт кушода мешавад (handler вақтро месанҷад);
// ин кор танҳо хабар медиҳад. Як мактуб — як бор (released атомӣ).
func ReleaseCapsules(ctx context.Context, db push.DB, now time.Time, send Notifier) int {
	rows, err := db.Query(ctx, `
		UPDATE time_capsules SET released = TRUE
		 WHERE id IN (SELECT id FROM time_capsules
		               WHERE released = FALSE AND hidden = FALSE AND unlock_at <= $1
		               ORDER BY unlock_at LIMIT 200 FOR UPDATE SKIP LOCKED)
		RETURNING id, author_id, audience, recipient_id`, now)
	if err != nil {
		return 0
	}
	type capsule struct{ id, author, audience, recipient string }
	var list []capsule
	for rows.Next() {
		var c capsule
		if rows.Scan(&c.id, &c.author, &c.audience, &c.recipient) == nil {
			list = append(list, c)
		}
	}
	rows.Close()

	sent := 0
	for _, c := range list {
		// Муаллиф ҳамеша (актёр нест — огоҳинома аз худи барнома).
		send(ctx, notify.Event{UserID: c.author, Kind: notify.CapsuleUnlocked,
			TargetID: c.id, DedupeSuffix: c.id})
		sent++
		var to []string
		switch c.audience {
		case features.CapsuleFriend:
			if c.recipient != "" {
				to = []string{c.recipient}
			}
		case features.CapsuleFollowers:
			fr, err := db.Query(ctx, `SELECT follower_id FROM follows
				WHERE following_id = $1 LIMIT 2000`, c.author)
			if err == nil {
				for fr.Next() {
					var u string
					if fr.Scan(&u) == nil {
						to = append(to, u)
					}
				}
				fr.Close()
			}
		}
		for _, u := range to {
			if u == c.author {
				continue
			}
			// ActorID = муаллиф: бастан огоҳиномаро бозмедорад.
			send(ctx, notify.Event{UserID: u, ActorID: c.author,
				Kind: notify.CapsuleUnlocked, TargetID: c.id, DedupeSuffix: c.id})
			sent++
		}
	}
	return sent
}

// FinalizeChallenges — чаленҷҳои тамомшуда: 3 ғолиб (хол > 0), нишон
// дар профил ва огоҳинома. Як чаленҷ — як бор (finalized атомӣ).
func FinalizeChallenges(ctx context.Context, db push.DB, now time.Time, send Notifier) int {
	rows, err := db.Query(ctx, `
		SELECT id, tag, starts_at, ends_at FROM challenges
		 WHERE finalized = FALSE AND hidden = FALSE AND ends_at <= $1
		 ORDER BY ends_at LIMIT 50`, now)
	if err != nil {
		return 0
	}
	type ch struct {
		id, tag    string
		start, end time.Time
	}
	var list []ch
	for rows.Next() {
		var c ch
		if rows.Scan(&c.id, &c.tag, &c.start, &c.end) == nil {
			list = append(list, c)
		}
	}
	rows.Close()

	winners := 0
	for _, c := range list {
		entries, err := ChallengeEntries(ctx, db, c.tag, c.start, c.end, "")
		if err != nil {
			continue
		}
		tag, err := db.Exec(ctx, `UPDATE challenges SET finalized = TRUE
			WHERE id = $1 AND finalized = FALSE`, c.id)
		if err != nil || tag.RowsAffected() == 0 {
			continue
		}
		for _, r := range features.Leaderboard(entries, features.ChallengeWinners) {
			if r.Score <= 0 {
				break
			}
			if _, err := db.Exec(ctx, `
				INSERT INTO challenge_winners(challenge_id, user_id, rank, score, content_kind, content_id)
				VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT DO NOTHING`,
				c.id, r.UserID, r.Rank, r.Score, r.Kind, r.ID); err != nil {
				continue
			}
			winners++
			send(ctx, notify.Event{UserID: r.UserID, Kind: notify.ChallengeWin,
				TargetID: c.id, DedupeSuffix: c.id})
		}
	}
	return winners
}
