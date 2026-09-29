package notify

// Занги воридотӣ ба телефон.
//
// Занг аз огоҳиномаи оддӣ фарқ дорад:
//   • дар Android паём DATA-ONLY аст — барнома худаш экрани пурраи
//     занг (қабул/рад + оҳанг) мекашад, ҳатто вақте пӯшида ё телефон
//     қулф аст. Бо блоки notification система танҳо banner-и хурд
//     нишон медод (маҳз шикояти соҳиб: «занг мисли паём дар боло»);
//   • TTL кӯтоҳ: занге, ки дер расид, дигар занг нест;
//   • ҳар занг шиносаи худро дорад — дедупликатсия ба ҳар ЗАНГ аст,
//     на ба ҷуфти одамон. Пештар TargetID холӣ буд ва занги ДУЮМИ
//     ҳамон шахс ҳеҷ гоҳ ба телефон намерасид.

import (
	"context"
	"log"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"

	"raonson/push"
)

// CallRingTTL — чӣ қадар FCM занги расониданашударо нигоҳ медорад.
//
// Зангзананда пас аз 60 сония худаш қатъ мекунад; 30 сония ҷой
// медиҳад, ки телефони оффлайн ҳанӯз «зинда» занг гирад.
const CallRingTTL = 30 * time.Second

// Call — як занги воридотӣ.
type Call struct {
	CalleeID string
	CallerID string
	// CallType — "voice" ё "video".
	CallType string
	// CallID — беназир барои ҳар занг (UUID). Холӣ бошад, сохта мешавад.
	CallID string
}

// NormalizeCallType ҳар қимати бегонаро ба "voice" меорад.
//
// Муштарӣ callType-ро худаш мефиристад; барнома танҳо ду қиматро
// мефаҳмад.
func NormalizeCallType(s string) string {
	if strings.EqualFold(strings.TrimSpace(s), "video") {
		return "video"
	}
	return "voice"
}

// CallData майдонҳои data-и push-и зангро месозад.
//
// Ҷудо аз фиристодан — то шакли он бе база санҷида шавад: барнома
// ҳар майдонро аз рӯи ҳамин номҳо мехонад (lib/calls/call_payload.dart).
func CallData(c Call, callerName, callerAvatar string, now time.Time) map[string]string {
	return map[string]string{
		"type":         string(IncomingCall),
		"callId":       c.CallID,
		"callerId":     c.CallerID,
		"callerName":   callerName,
		"callerAvatar": callerAvatar,
		"callType":     NormalizeCallType(c.CallType),
		// Вақти сервер — барнома занги кӯҳнаро (расидани дер) намезанад.
		"sentAt": strconv.FormatInt(now.UnixMilli(), 10),
		// Барои мутобиқат бо коди кӯҳнаи барнома (type + id).
		"id": c.CallerID,
	}
}

// CallMessage паёми push-и зангро барои як дастгоҳ месозад.
//
// Android — data-only (барнома экрани пурра мекашад). iOS бе PushKit
// паёми хомӯшро ҳангоми пӯшида будан нишон намедиҳад — барои ҳамин он
// огоҳиномаи оддии баланд мегирад, то занг ақаллан дида шавад.
func CallMessage(dev push.Device, data map[string]string, title, body string) push.Message {
	m := push.Message{
		Token:        dev.Token,
		Data:         data,
		HighPriority: true,
		TTL:          CallRingTTL,
		ChannelID:    string(ChannelCalls),
		CollapseKey:  "call:" + data["callerId"],
	}
	if dev.Platform == "ios" {
		m.Title, m.Body = title, body
		return m
	}
	m.DataOnly = true
	return m
}

// NotifyCall занги воридотиро ба ҳамаи дастгоҳҳои гиранда мефиристад.
//
// Ҳамеша фиристода мешавад (ҳатто агар сокет онлайн бошад): барномаи
// дар паснамо сокетро метавонад дошта бошад, вале экран кашида
// наметавонад. Агар сокет занги ҳамин шахсро аллакай нишон дода бошад,
// барнома push-ро худаш партояд (lib/calls/call_dedupe.dart).
func NotifyCall(ctx context.Context, d Deps, c Call) {
	if d.DB == nil || c.CalleeID == "" || c.CallerID == "" ||
		c.CalleeID == c.CallerID {
		return
	}
	if d.Now == nil {
		d.Now = time.Now
	}
	if c.CallID == "" {
		c.CallID = uuid.NewString()
	}
	if blocked(ctx, d.DB, c.CalleeID, c.CallerID) {
		return
	}

	e := Event{
		UserID: c.CalleeID, ActorID: c.CallerID, Kind: IncomingCall,
		TargetID: c.CallID,
	}
	key := dedupeKey(e)
	ct, err := d.DB.Exec(ctx, `
		INSERT INTO notification_delivery(dedupe_key, user_id, kind)
		VALUES ($1,$2,$3) ON CONFLICT (dedupe_key) DO NOTHING`,
		key, e.UserID, string(e.Kind))
	if err != nil || ct.RowsAffected() == 0 {
		return
	}
	// Танзимоти корбар (push/паёмҳо хомӯш) эҳтиром мешавад; соатҳои
	// ором ва маҳдудият ба аҳамияти High таъсир намерасонанд.
	if d.AllowPush != nil {
		if ok, reason := d.AllowPush(ctx, c.CalleeID, IncomingCall); !ok {
			mark(ctx, d.DB, key, "skipped", reason)
			return
		}
	}

	devices, err := push.DevicesFor(ctx, d.DB, c.CalleeID)
	if err != nil || len(devices) == 0 {
		mark(ctx, d.DB, key, "skipped", "no_device")
		return
	}

	lang, _ := recipientInfo(ctx, d.DB, c.CalleeID)
	name, avatar := callerInfo(ctx, d.DB, c.CallerID)
	title, body := Text(IncomingCall, lang, name, 0)
	data := CallData(c, name, avatar, d.Now())

	send := d.Send
	if send == nil {
		send = push.Send
	}
	sent := 0
	for _, dev := range devices {
		res, err := send(ctx, CallMessage(dev, data, title, body))
		switch res {
		case push.Sent:
			sent++
			push.NoteSuccess(ctx, d.DB, dev.Token)
		case push.TokenDead:
			push.DisableToken(ctx, d.DB, dev.Token, "provider_rejected")
		default:
			push.NoteFailure(ctx, d.DB, dev.Token)
			log.Printf("[push] %s user=%s result=%s err=%v",
				IncomingCall, c.CalleeID, res, err)
		}
	}
	if sent > 0 {
		mark(ctx, d.DB, key, "sent", "")
	} else {
		mark(ctx, d.DB, key, "failed", "no_device_accepted")
	}
}

// callerInfo ном ва аватари зангзанандаро аз база мегирад — на аз
// муштарӣ, то касе бо номи шахси дигар занг зада натавонад.
func callerInfo(ctx context.Context, db push.DB, id string) (string, string) {
	var name, avatar string
	db.QueryRow(ctx,
		`SELECT username, COALESCE(avatar,'') FROM users WHERE id=$1`,
		id).Scan(&name, &avatar)
	return name, avatar
}
