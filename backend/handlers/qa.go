package handlers

// «Савол ба ман» — қуттии саволҳо дар профил.
//
//   GET    /qa/settings                 — {mode: everyone|followers|off}
//   PUT    /qa/settings                 — {mode}
//   POST   /users/:id/questions         — {text, anonymous}
//   GET    /users/:id/questions         — ҷавобҳои оммавӣ (таби «Ҷавобҳо»)
//   GET    /qa/inbox                    — саволҳои ҷавобнадодаи ман
//   GET    /qa/sent                     — саволҳое, ки ман фиристодам
//   POST   /questions/:id/answer        — {text} (соҳиб)
//   DELETE /questions/:id               — соҳиб нест мекунад / савoлдиҳанда бозпас мегирад
//   POST   /questions/:id/block-asker   — «дигар савол нафиристад» (пинҳонӣ)
//   GET    /admin/questions/:id         — модератор савoлдиҳандаро ҳамеша мебинад
//
// Беном: номи савoлдиҳанда ба соҳиб ва тамошобинон нишон дода
// намешавад, вале asker_id ҳамеша сабт мешавад — модератсия, бастан ва
// ҳадди суръат бе он кор намекарданд.

import (
	"net/http"
	"strings"
	"time"

	"raonson/db"
	"raonson/features"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

func qaModeOf(c *gin.Context, uid string) string {
	mode := features.QAFollowers
	db.Pool.QueryRow(c.Request.Context(),
		`SELECT COALESCE(qa_mode,'followers') FROM users WHERE id=$1`, uid).Scan(&mode)
	m, _ := features.NormalizeQAMode(mode)
	return m
}

// GET /qa/settings
func GetQASettings(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"mode": qaModeOf(c, mw.UID(c))})
}

// PUT /qa/settings {mode}
func UpdateQASettings(c *gin.Context) {
	var b struct {
		Mode string `json:"mode"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "mode лозим аст")
		return
	}
	mode, ok := features.NormalizeQAMode(b.Mode)
	if !ok || strings.TrimSpace(b.Mode) == "" {
		badRequest(c, "mode: everyone, followers ё off")
		return
	}
	db.Pool.Exec(c.Request.Context(), `UPDATE users SET qa_mode=$2 WHERE id=$1`, mw.UID(c), mode)
	mw.InvalidateUserCache(mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"mode": mode})
}

// canAskOwner — (иҷозат, сабаб). Ҳамон 404 барои баста ва пӯшида.
func canAskOwner(c *gin.Context, me, owner string) (bool, int, string) {
	ctx := c.Request.Context()
	if owner == me {
		return false, http.StatusBadRequest, "Ба худ савол дода намешавад"
	}
	if !activeUserExists(ctx, owner) {
		return false, http.StatusNotFound, "Ёфт нашуд"
	}
	if ok, _ := CanSeeProfileContent(me, owner); !ok {
		return false, http.StatusNotFound, "Ёфт нашуд"
	}
	if !features.CanAsk(qaModeOf(c, owner), followsUser(ctx, me, owner)) {
		return false, http.StatusForbidden, "Ин корбар ҳоло савол қабул намекунад"
	}
	return true, 0, ""
}

// POST /users/:id/questions {text, anonymous}
func AskQuestion(c *gin.Context) {
	me := mw.UID(c)
	owner := c.Param("id")
	ctx := c.Request.Context()
	var b struct {
		Text      string `json:"text"`
		Anonymous bool   `json:"anonymous"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "text лозим аст")
		return
	}
	text, err := features.ValidateQuestion(b.Text)
	if err != nil {
		badRequest(c, err.Error())
		return
	}
	if ok, code, msg := canAskOwner(c, me, owner); !ok {
		c.JSON(code, gin.H{"message": msg})
		return
	}
	if !otpSendAllowed("qa_owner:"+me+":"+owner, features.QuestionsPerOwnerHour, time.Hour) ||
		!otpSendAllowed("qa_day:"+me, features.QuestionsPerDay, 24*time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{"message": "Саволҳо бисёр шуданд — каме интизор шавед"})
		return
	}
	modReq, mod, okMod := captionAllowed(c, "question", text)
	if !okMod {
		return
	}
	if mod.Hold {
		heldText(c)
		return
	}
	// Соҳиб ин савoлдиҳандаро пинҳонӣ бастааст: савол «қабул» мешавад
	// (савoлдиҳанда намефаҳмад), вале ба қуттӣ намерасад.
	var muted bool
	db.Pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM qa_blocks WHERE owner_id=$1 AND asker_id=$2)`,
		owner, me).Scan(&muted)
	if muted {
		c.JSON(http.StatusCreated, gin.H{"_id": "", "text": text, "anonymous": b.Anonymous})
		return
	}
	var id string
	if err := db.Pool.QueryRow(ctx, `
		INSERT INTO profile_questions(owner_id, asker_id, text, anonymous)
		VALUES ($1,$2,$3,$4) RETURNING id`, owner, me, text, b.Anonymous).Scan(&id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	queueReview(me, modReq, id, mod, false)
	// Огоҳинома БЕ муаллиф: номи савoлдиҳанда танҳо дар қутти
	// (ва танҳо агар беном набошад).
	NotifyQuestion(owner, id)
	c.JSON(http.StatusCreated, gin.H{"_id": id, "text": text, "anonymous": b.Anonymous})
}

// questionJSON — як савол. showAsker — номи савoлдиҳанда нишон дода шавад.
func questionJSON(id, text, answer, status string, anonymous bool, created time.Time,
	answered *time.Time, asker gin.H, showAsker bool) gin.H {
	out := gin.H{"_id": id, "text": text, "answer": answer, "status": status,
		"anonymous": anonymous, "createdAt": created, "answeredAt": answered}
	if showAsker && asker != nil {
		out["asker"] = asker
	}
	return out
}

// GET /users/:id/questions — ҷавобҳои оммавӣ.
func GetAnsweredQuestions(c *gin.Context) {
	me := mw.UID(c)
	owner := c.Param("id")
	ctx := c.Request.Context()
	meta := gin.H{"mode": qaModeOf(c, owner)}
	can, _, _ := canAskOwner(c, me, owner)
	meta["canAsk"] = can
	if ok, _ := CanSeeProfileContent(me, owner); !ok {
		c.JSON(http.StatusOK, gin.H{"questions": []gin.H{}, "meta": meta})
		return
	}
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 20))
	rows, err := db.Pool.Query(ctx, `
		SELECT q.id, q.text, q.answer, q.anonymous, q.created_at, q.answered_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		  FROM profile_questions q JOIN users u ON u.id=q.asker_id
		 WHERE q.owner_id=$1 AND q.status='answered' AND q.hidden=FALSE
		   AND (q.anonymous OR NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$2 AND b.blocked_id=q.asker_id)
		           OR (b.blocker_id=q.asker_id AND b.blocked_id=$2)))
		 ORDER BY q.answered_at DESC LIMIT $3 OFFSET $4`, owner, me, limit, (page-1)*limit)
	list := []gin.H{}
	if err == nil {
		for rows.Next() {
			var id, text, answer, uid, uname, avatar string
			var anon, verified bool
			var created time.Time
			var answered *time.Time
			if rows.Scan(&id, &text, &answer, &anon, &created, &answered,
				&uid, &uname, &avatar, &verified) != nil {
				continue
			}
			asker := gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": verified}
			q := questionJSON(id, text, answer, "answered", anon, created, answered, asker,
				features.AskerVisible(anon, uid == me, false))
			q["canDelete"] = me == owner
			list = append(list, q)
		}
		rows.Close()
	}
	if me == owner {
		var pending int
		db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM profile_questions
			WHERE owner_id=$1 AND status='pending'`, me).Scan(&pending)
		meta["pendingCount"] = pending
	}
	c.JSON(http.StatusOK, gin.H{"questions": list, "meta": meta, "page": page})
}

// GET /qa/inbox — саволҳои ҷавобнадода барои соҳиб.
func GetQAInbox(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	rows, err := db.Pool.Query(ctx, `
		SELECT q.id, q.text, q.anonymous, q.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		  FROM profile_questions q JOIN users u ON u.id=q.asker_id
		 WHERE q.owner_id=$1 AND q.status='pending' AND q.hidden=FALSE
		   AND COALESCE(u.banned,false)=FALSE
		   AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$1 AND b.blocked_id=q.asker_id)
		           OR (b.blocker_id=q.asker_id AND b.blocked_id=$1))
		 ORDER BY q.created_at DESC LIMIT 200`, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var id, text, uid, uname, avatar string
		var anon, verified bool
		var created time.Time
		if rows.Scan(&id, &text, &anon, &created, &uid, &uname, &avatar, &verified) != nil {
			continue
		}
		asker := gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": verified}
		list = append(list, questionJSON(id, text, "", "pending", anon, created, nil, asker,
			features.AskerVisible(anon, false, false)))
	}
	c.JSON(http.StatusOK, gin.H{"questions": list})
}

// GET /qa/sent — саволҳои ман (ҳолат ва ҷавоб).
func GetQASent(c *gin.Context) {
	me := mw.UID(c)
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT q.id, q.text, q.answer, q.status, q.anonymous, q.created_at, q.answered_at,
		       u.id, u.username, COALESCE(u.avatar,'')
		  FROM profile_questions q JOIN users u ON u.id=q.owner_id
		 WHERE q.asker_id=$1 ORDER BY q.created_at DESC LIMIT 100`, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var id, text, answer, status, uid, uname, avatar string
		var anon bool
		var created time.Time
		var answered *time.Time
		if rows.Scan(&id, &text, &answer, &status, &anon, &created, &answered,
			&uid, &uname, &avatar) != nil {
			continue
		}
		q := questionJSON(id, text, answer, status, anon, created, answered, nil, false)
		q["owner"] = gin.H{"_id": uid, "username": uname, "avatar": avatar}
		list = append(list, q)
	}
	c.JSON(http.StatusOK, gin.H{"questions": list})
}

// POST /questions/:id/answer {text}
func AnswerQuestion(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	id := c.Param("id")
	var asker, owner, status string
	if err := db.Pool.QueryRow(ctx, `SELECT asker_id, owner_id, status FROM profile_questions WHERE id=$1`,
		id).Scan(&asker, &owner, &status); err != nil || owner != me {
		notFound(c)
		return
	}
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "text лозим аст")
		return
	}
	text, err := features.ValidateAnswer(b.Text)
	if err != nil {
		badRequest(c, err.Error())
		return
	}
	modReq := modRequest{Surface: "qa_answer", AI: true, Texts: []string{text}}
	mod, okMod := screenContent(c, me, modReq)
	if !okMod {
		return
	}
	db.Pool.Exec(ctx, `UPDATE profile_questions SET answer=$2, status='answered',
		answered_at=COALESCE(answered_at, NOW()) WHERE id=$1`, id, text)
	held := holdIfNeeded(me, modReq, id, mod)
	if status != "answered" && !held {
		notify(asker, me, "qa_answer", id)
		pushNotify(asker, me, "qa_answer", id, "")
	}
	mw.InvalidateUserCache(me)
	c.JSON(http.StatusOK, gin.H{"_id": id, "answer": text, "status": "answered", "pendingReview": held})
}

// DELETE /questions/:id
func DeleteQuestion(c *gin.Context) {
	me := mw.UID(c)
	tag, err := db.Pool.Exec(c.Request.Context(), `
		DELETE FROM profile_questions
		 WHERE id=$1 AND (owner_id=$2 OR (asker_id=$2 AND status='pending'))`, c.Param("id"), me)
	if err != nil || tag.RowsAffected() == 0 {
		notFound(c)
		return
	}
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

// POST /questions/:id/block-asker — савoлдиҳанда дигар савол фиристода
// наметавонад. Номи ӯ ба соҳиб фош намешавад.
func BlockQuestionAsker(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var asker string
	if err := db.Pool.QueryRow(ctx, `SELECT asker_id FROM profile_questions WHERE id=$1 AND owner_id=$2`,
		c.Param("id"), me).Scan(&asker); err != nil {
		notFound(c)
		return
	}
	db.Pool.Exec(ctx, `INSERT INTO qa_blocks(owner_id, asker_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, me, asker)
	db.Pool.Exec(ctx, `DELETE FROM profile_questions WHERE owner_id=$1 AND asker_id=$2 AND status='pending'`, me, asker)
	c.JSON(http.StatusOK, gin.H{"blocked": true})
}

// GET /admin/questions/:id — модератор ҳамеша савoлдиҳандаро мебинад.
func AdminGetQuestion(c *gin.Context) {
	ctx := c.Request.Context()
	var id, owner, asker, text, answer, status string
	var anon, hidden bool
	var created time.Time
	if err := db.Pool.QueryRow(ctx, `SELECT id, owner_id, asker_id, text, answer, status, anonymous,
		hidden, created_at FROM profile_questions WHERE id=$1`, c.Param("id")).
		Scan(&id, &owner, &asker, &text, &answer, &status, &anon, &hidden, &created); err != nil {
		notFound(c)
		return
	}
	users := miniUsers(ctx, []string{owner, asker})
	q := questionJSON(id, text, answer, status, anon, created, nil, users[asker],
		features.AskerVisible(anon, false, true))
	q["owner"] = users[owner]
	q["hidden"] = hidden
	c.JSON(http.StatusOK, q)
}
