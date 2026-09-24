package sockets

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"
)

// ── Hub ──────────────────────────────────────────────────────────
var (
	mu      sync.RWMutex
	clients = map[string]*client{}
)

type client struct {
	userID string
	conn   *websocket.Conn
	send   chan []byte
}

func (cl *client) writePump() {
	ticker := time.NewTicker(25 * time.Second)
	defer func() {
		ticker.Stop()
		cl.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-cl.send:
			cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				cl.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			cl.conn.WriteMessage(websocket.TextMessage, msg)
		case <-ticker.C:
			cl.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := cl.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

// ── Message envelope ─────────────────────────────────────────────
type wsMsg struct {
	Event string          `json:"event"`
	Data  json.RawMessage `json:"data"`
}

func emit(userID, event string, data interface{}) {
	mu.RLock()
	cl, ok := clients[userID]
	mu.RUnlock()
	if !ok {
		return
	}
	b, _ := json.Marshal(wsMsg{Event: event, Data: toRaw(data)})
	select {
	case cl.send <- b:
	default:
	}
}

// emitToOnlineFollowers — рӯйдодро танҳо ба пайравоне мефиристад, ки
// ҳозир online ҳастанд. Барои миқёс (presence) ба ҷои broadcast ба ҳама.
func emitToOnlineFollowers(userID, event string, data interface{}) {
	// «Ҳолати фаъолият» хомӯш — ҳеҷ кас намебинад, ки ӯ онлайн аст.
	// Пеш ин танзим сабт мешуд, вале ҳеҷ ҷо хонда намешуд.
	if event == "presence:update" && !activityVisible(userID) {
		return
	}
	// Аввал рӯйхати userID-и пайравони онлайнро мегирем (бе блоки дароз).
	mu.RLock()
	online := make(map[string]bool, len(clients))
	for id := range clients {
		online[id] = true
	}
	mu.RUnlock()
	if len(online) == 0 {
		return
	}
	// Бастагон ва онҳое, ки худашон ҳолатро пинҳон кардаанд, намегиранд
	// (мисли Instagram: пинҳон кунӣ — худат ҳам намебинӣ).
	rows, err := db.Pool.Query(context.Background(),
		`SELECT f.follower_id FROM follows f JOIN users u ON u.id=f.follower_id
		 WHERE f.following_id=$1 AND COALESCE(u.activity_status,true)
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		     WHERE (b.blocker_id=$1 AND b.blocked_id=f.follower_id)
		        OR (b.blocker_id=f.follower_id AND b.blocked_id=$1))`, userID)
	if err != nil {
		return
	}
	targets := []string{}
	for rows.Next() {
		var fid string
		if rows.Scan(&fid) == nil && online[fid] {
			targets = append(targets, fid)
		}
	}
	rows.Close()
	for _, fid := range targets {
		emit(fid, event, data)
	}
}

func broadcast(event string, data interface{}) {
	b, _ := json.Marshal(wsMsg{Event: event, Data: toRaw(data)})
	mu.RLock()
	defer mu.RUnlock()
	for _, cl := range clients {
		select {
		case cl.send <- b:
		default:
		}
	}
}

func toRaw(v interface{}) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}

// ── GET /ws?token=... ─────────────────────────────────────────────
func Handler(c *gin.Context) {
	userID := parseToken(c.Query("token"))
	if userID == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
		return
	}

	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		log.Println("[WS] upgrade error:", err)
		return
	}

	cl := &client{userID: userID, conn: conn, send: make(chan []byte, 256)}
	mu.Lock()
	old := clients[userID]
	clients[userID] = cl
	mu.Unlock()
	// Пайвасти кӯҳнаро фавран мебандем: вагарна он то timeout зинда
	// мемонад ва ҳодисаҳоро ба сокети мурда мефиристад.
	if old != nil && old != cl {
		old.conn.Close()
	}

	// Online — танҳо ба пайравони ONLINE мефиристем (на ба ҳама).
	// Дар миқёси 20k+ корбар, broadcast ба ҳама O(N²) мешуд ва серверро
	// шах мекард. Ин роҳ корро бо шумораи пайравони онлайн маҳдуд мекунад.
	db.Pool.Exec(context.Background(),
		`UPDATE users SET last_seen=NULL WHERE id=$1`, userID)
	go emitToOnlineFollowers(userID, "presence:update", map[string]interface{}{
		"userId": userID, "status": "online", "lastSeen": nil})
	log.Printf("[WS] %s online", userID)

	go cl.writePump()

	// ⚠️ Сигнали «пайваст шуд» ба ХУДИ мизоҷ.
	//
	// Бе ин телефон намедонад, ки пайваст воқеан барқарор шуд.
	// `WebSocketChannel.connect` дар Dart КОСИЛ аст: он ҳатто
	// ҳангоми 401 хато намедиҳад ва фавран бармегардад. Барои ҳамин
	// мизоҷ пайвастро «муваффақ» мешумурд, ҳисоби такрорро сифр
	// мекард ва пас аз 401 боз як сония баъд кӯшиш мекард — абадан,
	// бе афзоиши фосила.
	//
	// Ин фрейм ягона нишонаи ҲАҚИҚИИ муваффақият аст.
	if b, err := json.Marshal(wsMsg{
		Event: "socket:ready",
		Data:  toRaw(map[string]interface{}{"userId": userID}),
	}); err == nil {
		select {
		case cl.send <- b:
		default:
			// Навбат пур — фрейм партофта мешавад; мизоҷ баъди
			// аввалин ҳодисаи дигар ҳам мефаҳмад.
		}
	}

	defer func() {
		// Танҳо пайвасти ХУДРО мебарорем.
		//
		// Ҳангоми аз нав пайвастшавӣ (шабакаи мобилӣ, бедор шудани
		// барнома) пайвасти нав аллакай дар харита сабт шудааст. Агар
		// поксозии пайвасти кӯҳна кӯр-кӯрона delete кунад, он сабти
		// НАВРО мебарорад: корбар пайваст аст, вале ҳеҷ ҳодиса
		// намегирад ва инро намефаҳмад.
		mu.Lock()
		removed := clients[userID] == cl
		if removed {
			delete(clients, userID)
		}
		mu.Unlock()
		if !removed {
			// Корбар аллакай бо пайвасти нав онлайн аст.
			log.Printf("[WS] %s пайвасти кӯҳна пӯшида шуд", userID)
			return
		}
		now := time.Now()
		db.Pool.Exec(context.Background(),
			`UPDATE users SET last_seen=$1 WHERE id=$2`, now, userID)
		go emitToOnlineFollowers(userID, "presence:update", map[string]interface{}{
			"userId": userID, "status": "offline",
			"lastSeen": now.Format(time.RFC3339)})
		log.Printf("[WS] %s offline", userID)
		conn.Close()
	}()

	conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	conn.SetPongHandler(func(string) error {
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		_, raw, err := conn.ReadMessage()
		if err != nil {
			break
		}
		conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		dispatch(cl, raw)
	}
}

func dispatch(cl *client, raw []byte) {
	var msg wsMsg
	if err := json.Unmarshal(raw, &msg); err != nil {
		return
	}

	switch msg.Event {

	// ── Presence ──────────────────────────────────────────────
	case "presence:online":
		// ⚠️ Ҳамеша худи соҳиби сокет. Пеш `userId` аз муштарӣ гирифта
		// мешуд — ҳар кас ҳар корбарро «онлайн» эълон карда метавонист.
		uid := cl.userID
		db.Pool.Exec(context.Background(), `UPDATE users SET last_seen=NULL WHERE id=$1`, uid)
		go emitToOnlineFollowers(uid, "presence:update", map[string]interface{}{
			"userId": uid, "status": "online", "lastSeen": nil})

	case "presence:check":
		var p struct{ UserID string `json:"userId"` }
		json.Unmarshal(msg.Data, &p)
		mu.RLock()
		_, online := clients[p.UserID]
		mu.RUnlock()
		var lastSeen interface{}
		if !activityVisible(p.UserID) || !activityVisible(cl.userID) ||
			!callAllowed(cl.userID, p.UserID) {
			online = false // ҳолат пинҳон аст — на онлайн, на «охирин бор»
		} else if !online {
			db.Pool.QueryRow(context.Background(),
				`SELECT last_seen FROM users WHERE id=$1`, p.UserID).Scan(&lastSeen)
		}
		emit(cl.userID, "presence:checked", map[string]interface{}{
			"userId": p.UserID, "isOnline": online, "lastSeen": lastSeen})

	// ── Chat ──────────────────────────────────────────────────
	case "chat:send":
		var p struct {
			ChatID   string `json:"chatId"`
			Text     string `json:"text"`
			Receiver string `json:"receiver"`
		}
		json.Unmarshal(msg.Data, &p)
		if p.ChatID == "" || p.Text == "" {
			return
		}
		// Гирандаро аз chatID мегирем (он "idA_idB"-и мураттабшуда аст),
		// то client натавонад паёмро ба каси дигар нависад.
		// Фиристанда бояд аъзои ҳамин чат бошад. Пеш, агар ӯ аъзо
		// набуд, гиранда аз муштарӣ гирифта мешуд ва паём ба чати
		// бегона навишта мешуд.
		a, b, ok := strings.Cut(p.ChatID, "_")
		switch {
		case ok && cl.userID == a:
			p.Receiver = b
		case ok && cl.userID == b:
			p.Receiver = a
		default:
			return
		}
		if p.Receiver == "" || p.Receiver == cl.userID || !callAllowed(cl.userID, p.Receiver) {
			return
		}
		if len([]rune(p.Text)) > 1000 {
			r := []rune(p.Text)
			p.Text = string(r[:1000])
		}
		var msgID string
		var createdAt interface{}
		db.Pool.QueryRow(context.Background(),
			`INSERT INTO messages(chat_id,sender_id,receiver_id,text) VALUES($1,$2,$3,$4) RETURNING id,created_at`,
			p.ChatID, cl.userID, p.Receiver, p.Text,
		).Scan(&msgID, &createdAt)

		var uname, uavatar string
		var verified bool
		db.Pool.QueryRow(context.Background(),
			`SELECT username,avatar,verified FROM users WHERE id=$1`, cl.userID,
		).Scan(&uname, &uavatar, &verified)

		payload := map[string]interface{}{
			"_id": msgID, "chatId": p.ChatID, "text": p.Text,
			"read": false, "createdAt": createdAt,
			"sender": map[string]interface{}{
				"_id": cl.userID, "username": uname,
				"avatar": uavatar, "verified": verified,
			},
		}
		emit(cl.userID, "chat:new", payload)
		emit(p.Receiver, "chat:new", payload)

	case "chat:typing":
		var p struct {
			ChatID   string `json:"chatId"`
			Receiver string `json:"receiver"`
			IsTyping *bool  `json:"isTyping"`
		}
		json.Unmarshal(msg.Data, &p)
		isTyping := true
		if p.IsTyping != nil {
			isTyping = *p.IsTyping
		}
		// Танҳо ба ҳамсӯҳбати ҳамин чат ва на ба касе, ки блок кардааст.
		if a, b, ok := strings.Cut(p.ChatID, "_"); !ok ||
			!((a == cl.userID && b == p.Receiver) || (b == cl.userID && a == p.Receiver)) ||
			!callAllowed(cl.userID, p.Receiver) {
			break
		}
		emit(p.Receiver, "chat:typing", map[string]interface{}{
			"userId": cl.userID, "chatId": p.ChatID, "isTyping": isTyping})

	case "chat:read":
		var p struct{ MessageID string `json:"messageId"` }
		json.Unmarshal(msg.Data, &p)
		// Танҳо паёмҳое, ки ба худи ҳамин корбар фиристода шудаанд, хонда
		// эълон карда мешаванд — то касе паёми каси дигарро "read" накунад.
		// RETURNING — то фиристандаро донем ва ба ӯ хабар диҳем, вагарна
		// ду тик танҳо баъд аз refresh пайдо мешуд.
		var senderID, chatID string
		if db.Pool.QueryRow(context.Background(),
			`UPDATE messages SET read=TRUE WHERE id=$1 AND receiver_id=$2
			 RETURNING sender_id, chat_id`,
			p.MessageID, cl.userID).Scan(&senderID, &chatID) == nil && senderID != "" {
			emit(senderID, "chat:read", map[string]interface{}{
				"chatId": chatID, "messageId": p.MessageID, "readBy": cl.userID})
		}

	// ── WebRTC / Calls ────────────────────────────────────────
	case "user:register":
		// Already registered by token auth — no-op
	case "call:offer":
		var p struct {
			To           string      `json:"to"`
			Offer        interface{} `json:"offer"`
			CallType     string      `json:"callType"`
			From         string      `json:"from"`
			FromUsername string      `json:"fromUsername"`
			FromAvatar   string      `json:"fromAvatar"`
		}
		json.Unmarshal(msg.Data, &p)
		// Зангзананда ҲАМЕША худи соҳиби сокет аст — номаш аз базаи
		// маълумот, на аз муштарӣ (вагарна касе метавонист бо номи
		// шахси дигар занг занад). Бастагон занг зада наметавонанд.
		p.From = cl.userID
		if p.To == "" || p.To == p.From || !callAllowed(p.From, p.To) {
			break
		}
		db.Pool.QueryRow(context.Background(),
			`SELECT username, COALESCE(avatar,'') FROM users WHERE id=$1`,
			p.From).Scan(&p.FromUsername, &p.FromAvatar)
		emit(p.To, "call:incoming", map[string]interface{}{
			"from": p.From, "fromUsername": p.FromUsername,
			"fromAvatar": p.FromAvatar, "offer": p.Offer, "callType": p.CallType,
		})
		// Гиранда офлайн — сокет ҳеҷ ҷо намебарад. Огоҳиномаи
		// телефон ягона роҳи расидан аст.
		if p.To != "" && !isOnline(p.To) && OnMissedCall != nil {
			go OnMissedCall(p.To, p.From)
		}
	case "call:answer":
		var p struct {
			To     string      `json:"to"`
			Answer interface{} `json:"answer"`
		}
		json.Unmarshal(msg.Data, &p)
		if p.To == "" || p.To == cl.userID || !callAllowed(cl.userID, p.To) {
			break
		}
		emit(p.To, "call:answered", map[string]interface{}{"answer": p.Answer})

	case "call:ice-candidate":
		var p struct {
			To        string      `json:"to"`
			Candidate interface{} `json:"candidate"`
		}
		json.Unmarshal(msg.Data, &p)
		if p.To == "" || p.To == cl.userID || !callAllowed(cl.userID, p.To) {
			break
		}
		emit(p.To, "call:ice-candidate", map[string]interface{}{"candidate": p.Candidate})

	case "call:end":
		var p struct{ To string `json:"to"` }
		json.Unmarshal(msg.Data, &p)
		if p.To == "" || p.To == cl.userID || !callAllowed(cl.userID, p.To) {
			break
		}
		emit(p.To, "call:ended", map[string]interface{}{})

	// ── Notifications ──────────────────────────────────────
	case "notification:subscribe":
		var p struct{ UserID string `json:"userId"` }
		json.Unmarshal(msg.Data, &p)
		if p.UserID == "" { p.UserID = cl.userID }
		// Already handled by userID-based emit — no-op needed

	case "notification:push":
		// ⚠️ Хомӯш карда шуд. Ҳар корбари пайваст метавонист ба ҳар кас
		// огоҳиномаи дилхоҳ (ҳар навъ, ҳар ҳадаф) нависад — бе санҷиши
		// блок. Огоҳиномаҳо танҳо аз сервер (notify) сохта мешаванд.

	case "notification:read":
		var p struct{ NotificationID string `json:"notificationId"` }
		json.Unmarshal(msg.Data, &p)
		// Танҳо хабарномаҳои худи корбар хонда эълон карда мешаванд.
		db.Pool.Exec(context.Background(),
			`UPDATE notifications SET read=TRUE WHERE id=$1 AND user_id=$2`,
			p.NotificationID, cl.userID)

	case "call:decline":
		var p struct{ To string `json:"to"` }
		json.Unmarshal(msg.Data, &p)
		if p.To == "" || p.To == cl.userID || !callAllowed(cl.userID, p.To) {
			break
		}
		emit(p.To, "call:declined", map[string]interface{}{})
	}
}

func nullIfEmpty(s string) interface{} {
	if s == "" { return nil }
	return s
}

func parseToken(s string) string {
	if s == "" { return "" }
	secret := mw.JWTSecret()
	tok, err := jwt.Parse(s, func(t *jwt.Token) (interface{}, error) {
		return []byte(secret), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !tok.Valid { return "" }
	claims, ok := tok.Claims.(jwt.MapClaims)
	if !ok { return "" }
	id, _ := claims["id"].(string)
	// Token-и бекоршуда (ивази рамз, «Ҳамаро бандед», ban) — сокет не.
	if id == "" || !mw.TokenAllowed(id, claims["tv"]) {
		return ""
	}
	return id
}

// EmitToUser - for use from handlers
func EmitToUser(userID, event string, data interface{}) { emit(userID, event, data) }

// OnMissedCall ҳангоми занг ба корбари ОФЛАЙН ҷеғ зада мешавад.
//
// ⚠️ Занг танҳо тавассути сокет мерафт. Агар гиранда барномаро
// баста бошад — маҳз он вақте ки занг муҳим аст — ҳеҷ чиз намеомад.
//
// Ин ҷо callback аст, на даъвати мустақим: `handlers` аллакай
// `sockets`-ро import мекунад, пас баръакс ҳалқаи вобастагӣ мешуд.
// `main` онро васл мекунад.
var OnMissedCall func(toUserID, fromUserID string)

// isOnline мегӯяд, ки оё корбар пайвасти зинда дорад.
func isOnline(userID string) bool {
	mu.RLock()
	_, ok := clients[userID]
	mu.RUnlock()
	return ok
}
// ── PATCH: backend/sockets/ws.go ─────────────────────────────────
// Ин функсияҳоро ба охири ws.go илова кун (пеш аз охири файл)

// BroadcastNewPost — вақте пост сохта мешавад, ба ҳама followers мефиристад
// Дар handlers/post.go, баъди tx.Commit() чунин зоваш кун:
//   go sockets.BroadcastNewPost(myID, postPayload)
func BroadcastNewPost(authorID string, post interface{}) {
	// 1. Пайдо кун ҳама followers-и ин автор
	rows, err := db.Pool.Query(context.Background(),
		`SELECT follower_id FROM follows WHERE following_id=$1`, authorID)
	if err != nil {
		return
	}
	defer rows.Close()

	// 2. Ба ҳар follower event мефиристад
	for rows.Next() {
		var followerID string
		if rows.Scan(&followerID) == nil {
			emit(followerID, "feed:new_post", post)
		}
	}

	// 3. Ба худи автор ҳам (барои дидани посташ дар feed)
	emit(authorID, "feed:new_post", post)
}

// BroadcastNewStory — вақте story сохта мешавад, ба followers мефиристад
// Дар handlers/story_chat_notif_admin.go, баъди INSERT чунин:
//   go sockets.BroadcastNewStory(myID, storyPayload)
//
// ⚠️ Сторияи «Дӯстони наздик» пеш ба ҲАМАИ обунаҳо мерафт — дар экран
// то навсозӣ пайдо мешуд. Акнун танҳо ба дӯстони наздик; бастагон
// намегиранд.
func BroadcastNewStory(authorID string, story interface{}) {
	closeOnly := false
	if m, ok := story.(map[string]interface{}); ok {
		closeOnly = m["audience"] == "close"
	}
	rows, err := db.Pool.Query(context.Background(),
		`SELECT f.follower_id FROM follows f
		 WHERE f.following_id=$1
		   AND ($2 = FALSE OR EXISTS (SELECT 1 FROM close_friends cf
		        WHERE cf.user_id=$1 AND cf.friend_id=f.follower_id))
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$1 AND b.blocked_id=f.follower_id)
		           OR (b.blocker_id=f.follower_id AND b.blocked_id=$1))`,
		authorID, closeOnly)
	if err != nil {
		return
	}
	defer rows.Close()

	for rows.Next() {
		var followerID string
		if rows.Scan(&followerID) == nil {
			emit(followerID, "story:new", story)
		}
	}
	// Худ ҳам мебинад
	emit(authorID, "story:new", story)
}

// callAllowed — занг байни ду нафар, агар ҳеҷ кадом дигареро набаста бошад.
func callAllowed(a, b string) bool {
	var blocked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM blocks
		  WHERE (blocker_id=$1 AND blocked_id=$2)
		     OR (blocker_id=$2 AND blocked_id=$1))`, a, b).Scan(&blocked)
	return !blocked
}

// activityVisible — оё корбар «Ҳолати фаъолият»-ро фаъол нигоҳ доштааст.
func activityVisible(uid string) bool {
	vis := true
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(activity_status,true) FROM users WHERE id=$1`, uid).Scan(&vis)
	return vis
}
