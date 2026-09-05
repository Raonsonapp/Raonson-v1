package notify

// Роҳи огоҳинома аз ҳодиса то дастгоҳ.
//
// Тартиб:
//   1. худро огоҳ намекунем
//   2. блок / хомӯшкардашуда
//   3. дедупликатсия (як ҳодиса — як огоҳинома)
//   4. сатри огоҳинома дар маркази огоҳиномаҳо
//   5. танзимоти корбар
//   6. соатҳои ором
//   7. маҳдудияти шумора
//   8. гурӯҳбандӣ
//   9. фиристодан ба ҳар дастгоҳ
//
// Қадами 4 ҲАМЕША иҷро мешавад: агар push рад шавад ҳам, одам
// огоҳиномаро дар барнома мебинад. Чизе гум намешавад — танҳо
// ларзиши телефон бас мешавад.

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"log"
	"time"

	"raonson/push"
)

// Event — як ҳодисаи огоҳинома.
type Event struct {
	// UserID — гиранда.
	UserID string
	// ActorID — касе, ки амал кард. Холӣ барои огоҳиномаи барнома.
	ActorID string
	Kind    Kind
	// TargetID — объект (пост, рилс, кампания...).
	TargetID string
	// DedupeSuffix — вақте як ҳодиса метавонад такрор шавад ва
	// такрор ҚОНУНӢ бошад (масалан ҳафтаи дигар).
	DedupeSuffix string
}

// dedupeKey калиди идемпотентиро месозад.
//
// Ҳамон амал (ҳамон одам, ҳамон объект, ҳамон намуд) ду огоҳинома
// намедиҳад — ҳатто агар handler ду бор даъват шавад.
func dedupeKey(e Event) string {
	h := sha256.Sum256([]byte(string(e.Kind) + "\x00" + e.UserID + "\x00" +
		e.ActorID + "\x00" + e.TargetID + "\x00" + e.DedupeSuffix))
	return hex.EncodeToString(h[:16])
}

// Deps — вобастагиҳо. Барои тест иваз карда мешаванд.
type Deps struct {
	DB push.DB
	// Now — вақти ҷорӣ.
	Now func() time.Time
	// AllowPush — санҷиши танзимот, соатҳои ором ва маҳдудият.
	// Ҷавоб: иҷозат ва сабаби рад.
	AllowPush func(ctx context.Context, userID string, k Kind) (bool, string)
	// Send — фиристодан. Барои тест иваз мешавад.
	Send func(ctx context.Context, m push.Message) (push.Result, error)
}

// Notify ҳодисаро пурра коркард мекунад: сатри огоҳинома + push.
//
// Ҳеҷ гоҳ хато бармегардонад: огоҳинома набояд амали асосиро
// (лайк, шарҳ, обуна) вайрон кунад.
func Notify(ctx context.Context, d Deps, e Event) {
	run(ctx, d, e, true)
}

// PushOnly танҳо push мефиристад, бе навиштани сатри нав.
//
// Барои ҷойҳое, ки сатри огоҳинома аллакай ҷудогона навишта мешавад
// — вагарна корбар як ҳодисаро ду бор дар рӯйхат медид.
func PushOnly(ctx context.Context, d Deps, e Event) {
	run(ctx, d, e, false)
}

func run(ctx context.Context, d Deps, e Event, writeNotification bool) {
	if d.DB == nil || e.UserID == "" || e.UserID == e.ActorID {
		return
	}
	if d.Now == nil {
		d.Now = time.Now
	}

	// Блок — пеш аз ҳама чиз. Касе, ки блок шудааст, набояд
	// огоҳинома тавлид кунад.
	if e.ActorID != "" && blocked(ctx, d.DB, e.UserID, e.ActorID) {
		return
	}

	key := dedupeKey(e)
	// Танҳо аввалин сабт идома медиҳад: ҳамон ҳодиса ду бор
	// огоҳинома намедиҳад, ҳатто агар handler ду бор даъват шавад.
	ct, err := d.DB.Exec(ctx, `
		INSERT INTO notification_delivery(dedupe_key, user_id, kind)
		VALUES ($1,$2,$3) ON CONFLICT (dedupe_key) DO NOTHING`,
		key, e.UserID, string(e.Kind))
	if err != nil || ct.RowsAffected() == 0 {
		return
	}

	// Сатри маркази огоҳиномаҳо — новобаста аз push.
	if writeNotification {
		writeRow(ctx, d.DB, e)
	}

	if d.AllowPush != nil {
		if ok, reason := d.AllowPush(ctx, e.UserID, e.Kind); !ok {
			mark(ctx, d.DB, key, "skipped", reason)
			return
		}
	}
	deliver(ctx, d, e, key)
}

// blocked мегӯяд, ки оё гиранда амалкунандаро блок ё хомӯш кардааст.
//
// Блоккардашуда набояд огоҳинома тавлид кунад — вагарна блок кардан
// маънои худро гум мекунад.
func blocked(ctx context.Context, db push.DB, userID, actorID string) bool {
	var yes bool
	err := db.QueryRow(ctx, `
		SELECT EXISTS(
		  SELECT 1 FROM blocks
		  WHERE (blocker_id=$1 AND blocked_id=$2)
		     OR (blocker_id=$2 AND blocked_id=$1))`,
		userID, actorID).Scan(&yes)
	if err != nil {
		// Ҷадвал нест ё хато — огоҳиномаро бас намекунем.
		return false
	}
	return yes
}

func writeRow(ctx context.Context, db push.DB, e Event) {
	var actor any
	if e.ActorID != "" {
		actor = e.ActorID
	}
	db.Exec(ctx, `
		INSERT INTO notifications(user_id, from_user_id, type, target_id)
		VALUES ($1,$2,$3,$4)`,
		e.UserID, actor, string(e.Kind), e.TargetID)
}

func mark(ctx context.Context, db push.DB, key, status, reason string) {
	db.Exec(ctx, `
		UPDATE notification_delivery
		   SET status=$2, reason=$3, updated_at=NOW()
		 WHERE dedupe_key=$1`, key, status, reason)
}

// deliver огоҳиномаро ба ҳамаи дастгоҳҳои корбар мефиристад.
func deliver(ctx context.Context, d Deps, e Event, key string) {
	devices, err := push.DevicesFor(ctx, d.DB, e.UserID)
	if err != nil || len(devices) == 0 {
		mark(ctx, d.DB, key, "skipped", "no_device")
		return
	}

	lang, badge := recipientInfo(ctx, d.DB, e.UserID)
	actor := actorName(ctx, d.DB, e.ActorID)
	others := groupCount(ctx, d.DB, e, d.Now())

	title, body := Text(e.Kind, lang, actor, others)
	if title == "" && body == "" {
		// Матн нест — рамзи техникӣ ба корбар фиристода намешавад.
		mark(ctx, d.DB, key, "skipped", "no_text")
		return
	}

	rule := RuleFor(e.Kind)
	data := map[string]string{
		"type": string(e.Kind),
		"id":   e.TargetID,
	}
	if l := Link(e.Kind, e.TargetID, actor); l != "" {
		data["link"] = l
	}

	send := d.Send
	if send == nil {
		send = push.Send
	}

	sent := 0
	for _, dev := range devices {
		res, err := send(ctx, push.Message{
			Token:        dev.Token,
			Title:        title,
			Body:         body,
			Data:         data,
			ChannelID:    string(rule.Channel),
			HighPriority: rule.Priority == High,
			Badge:        badge,
			// Огоҳиномаи гурӯҳӣ кӯҳнаро иваз мекунад, на илова.
			CollapseKey: string(e.Kind) + ":" + e.TargetID,
		})
		switch res {
		case push.Sent:
			sent++
			push.NoteSuccess(ctx, d.DB, dev.Token)
		case push.TokenDead:
			push.DisableToken(ctx, d.DB, dev.Token, "provider_rejected")
		default:
			push.NoteFailure(ctx, d.DB, dev.Token)
			// Хато НАБОЯД хомӯш бимонад: бе ин «чаро огоҳинома
			// намеояд» ҷавоб надорад. Токен ба log намеравад.
			log.Printf("[push] %s user=%s result=%s err=%v",
				e.Kind, e.UserID, res, err)
		}
	}

	if sent > 0 {
		mark(ctx, d.DB, key, "sent", "")
	} else {
		mark(ctx, d.DB, key, "failed", "no_device_accepted")
	}
}

// recipientInfo забон ва шумораи нахондашударо мегирад.
func recipientInfo(ctx context.Context, db push.DB, userID string) (Lang, int) {
	var lang string
	var unread int
	db.QueryRow(ctx,
		`SELECT COALESCE(language,'tj') FROM users WHERE id=$1`,
		userID).Scan(&lang)
	db.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND read=FALSE`,
		userID).Scan(&unread)
	return NormalizeLang(lang), unread
}

func actorName(ctx context.Context, db push.DB, actorID string) string {
	if actorID == "" {
		return ""
	}
	var name string
	db.QueryRow(ctx, `SELECT username FROM users WHERE id=$1`,
		actorID).Scan(&name)
	return name
}

// groupWindow — давраи ҷамъбандӣ.
//
// Панҷоҳ лайк дар як соат набояд панҷоҳ бор телефонро ларзонад.
const groupWindow = time.Hour

// groupCount шумораи одамони ИЛОВАГӢ дар ҳамин давраро мешуморад.
//
// 0 маънои «танҳо як нафар» дорад.
func groupCount(ctx context.Context, db push.DB, e Event, now time.Time) int {
	if !RuleFor(e.Kind).Groupable || e.TargetID == "" {
		return 0
	}
	var n int
	err := db.QueryRow(ctx, `
		SELECT COUNT(DISTINCT from_user_id)
		FROM notifications
		WHERE user_id=$1 AND type=$2 AND COALESCE(target_id,'')=$3
		  AND from_user_id IS NOT NULL
		  AND created_at >= $4`,
		e.UserID, string(e.Kind), e.TargetID,
		now.Add(-groupWindow)).Scan(&n)
	if err != nil || n <= 1 {
		return 0
	}
	return n - 1
}
