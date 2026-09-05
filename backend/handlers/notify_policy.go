package handlers

// Пайванди огоҳиномаҳо ба қабати нави фиристодан.
//
// pushNotify имзои худро нигоҳ медорад, то ҳама ҷои даъват бе тағйир
// монад; вале дохили он акнун:
//   • FCM HTTP v1 (қаблӣ Legacy API буд, ки Google хомӯш кард)
//   • ҳамаи дастгоҳҳои корбар, на танҳо охирин
//   • танзимот, соатҳои ором, маҳдудияти шумора
//   • дедупликатсия ва гурӯҳбандӣ
//   • матни тарҷумашуда ва линки чуқур
//   • пок кардани токени мурда

import (
	"context"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	ntf "raonson/notify"
)

// cacheCounter кэши мавҷудро ба интерфейси notify мепайвандад.
//
// Кэши дуюм сохта намешавад.
type cacheCounter struct{}

func (cacheCounter) Get(key string) ([]byte, bool) { return mw.CacheGet(key) }
func (cacheCounter) Set(key string, v []byte, ttl time.Duration) {
	mw.CacheSet(key, v, ttl)
}

// notifyDeps вобастагиҳои қабати огоҳиномаро месозад.
func notifyDeps() ntf.Deps {
	return ntf.Deps{
		DB:        db.Pool,
		Now:       time.Now,
		AllowPush: ntf.Gate(db.Pool, cacheCounter{}, time.Now),
	}
}

// pushNotify огоҳиномаро ба дастгоҳҳои корбар мефиристад.
//
// Сатри огоҳинома дар notify() навишта мешавад, бинобар ин ин ҷо
// PushOnly истифода мешавад — вагарна корбар як ҳодисаро ду бор дар
// рӯйхат медид.
//
// Параметри body акнун истифода намешавад: матн дар сервер аз рӯи
// забони ГИРАНДА сохта мешавад (ниг. notify/text.go). Пештар он
// ҳамеша тоҷикӣ буд, ҳатто барои корбари русзабон.
func pushNotify(userID, fromID, ntype, targetID, body string) {
	_ = body
	if userID == "" || userID == fromID {
		return
	}
	go ntf.PushOnly(context.Background(), notifyDeps(), ntf.Event{
		UserID:   userID,
		ActorID:  fromID,
		Kind:     ntf.Kind(ntype),
		TargetID: targetID,
	})
}

// NotifyEvent огоҳиномаи пурраро месозад: ҳам сатр, ҳам push.
//
// Барои ҳодисаҳое, ки notify() ҷудогона даъват намешавад — масалан
// ҷамъбасти ҳафта ё нишони нав.
func NotifyEvent(e ntf.Event) {
	go ntf.Notify(context.Background(), notifyDeps(), e)
}
