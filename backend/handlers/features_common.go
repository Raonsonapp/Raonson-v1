package handlers

// Ёрдамчиҳои умумии панҷ имконияти нав: «Даъватнома», пурсиш дар пост,
// «Савол ба ман», «Мактуб ба оянда» ва «Чаленҷ».
//
// Қоидаҳои тоза дар backend/features; инҷо танҳо база ва HTTP.

import (
	"context"
	"net/http"
	"os"
	"time"

	"raonson/db"
	ntf "raonson/notify"

	"github.com/gin-gonic/gin"
)

// NotifyQuestion — «Шумо саволи нав доред», БЕ номи савoлдиҳанда.
func NotifyQuestion(owner, questionID string) {
	NotifyEvent(ntf.Event{UserID: owner, Kind: ntf.QAQuestion, TargetID: questionID})
}

// featureHoldSQL — пинҳон (hide=true) ё баргардондани мӯҳтавои
// имкониятҳои нав аз ҷониби модератсия (holdContent/releaseContent).
func featureHoldSQL(surface string, hide bool) string {
	v := "FALSE"
	if hide {
		v = "TRUE"
	}
	switch surface {
	case "event":
		return `UPDATE invite_events SET hidden=` + v + ` WHERE id=$1`
	case "event_photo":
		return `UPDATE event_photos SET hidden=` + v + ` WHERE id=$1`
	case "question", "qa_answer":
		return `UPDATE profile_questions SET hidden=` + v + ` WHERE id=$1`
	case "capsule":
		return `UPDATE time_capsules SET hidden=` + v + ` WHERE id=$1`
	case "challenge":
		return `UPDATE challenges SET hidden=` + v + ` WHERE id=$1`
	}
	return `SELECT $1::text WHERE FALSE`
}

// miniUsers — {_id, username, avatar, verified} барои рӯйхати id-ҳо.
func miniUsers(ctx context.Context, ids []string) map[string]gin.H {
	out := map[string]gin.H{}
	if len(ids) == 0 {
		return out
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT id, username, COALESCE(avatar,''), COALESCE(verified,false)
		  FROM users WHERE id = ANY($1)`, ids)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var id, uname, avatar string
		var verified bool
		if rows.Scan(&id, &uname, &avatar, &verified) == nil {
			out[id] = gin.H{"_id": id, "username": uname, "avatar": avatar, "verified": verified}
		}
	}
	return out
}

// followsUser — a ба b обуна аст (тасдиқшуда)?
func followsUser(ctx context.Context, a, b string) bool {
	var yes bool
	db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1 AND following_id=$2)`,
		a, b).Scan(&yes)
	return yes
}

// isAdminUser — нақши admin (модератор).
func isAdminUser(ctx context.Context, uid string) bool {
	var role string
	db.Pool.QueryRow(ctx, `SELECT COALESCE(role,'user') FROM users WHERE id=$1`, uid).Scan(&role)
	return role == "admin"
}

// activeUserExists — корбар ҳаст ва манъ нашудааст.
func activeUserExists(ctx context.Context, id string) bool {
	var ok bool
	db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND COALESCE(banned,false)=FALSE)`,
		id).Scan(&ok)
	return ok
}

// parseTimeField — RFC3339 (бо ё бе миллисония). false — нодуруст.
func parseTimeField(s string) (time.Time, bool) {
	if s == "" {
		return time.Time{}, false
	}
	for _, f := range []string{time.RFC3339Nano, time.RFC3339} {
		if t, err := time.Parse(f, s); err == nil {
			return t.UTC(), true
		}
	}
	return time.Time{}, false
}

// badRequest — 400 бо матни хато.
func badRequest(c *gin.Context, msg string) {
	c.JSON(http.StatusBadRequest, gin.H{"message": msg})
}

// notFound — ҳамон 404 барои «нест», «пӯшида» ва «баста»: вуҷуди
// мӯҳтаво фош намешавад.
func notFound(c *gin.Context) {
	c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
}

// heldText — модератсия матнро «шубҳанок» донист. Мисли «Раҳмат»:
// шубҳанок пинҳон нашр намешавад — корбар матнро иваз мекунад.
func heldText(c *gin.Context) {
	c.JSON(http.StatusUnprocessableEntity,
		gin.H{"message": "Ин матнро нашр карда намешавад. Лутфан онро иваз кунед"})
}

// capsuleMinLead — «Мактуб ба оянда» ақаллан чӣ қадар пеш.
//
// Продакшн: 1 соат. Сервери санҷишӣ (GIN_MODE=debug/test, ҳамон шарте,
// ки OTP_ECHO-ро иҷозат медиҳад) — 20 сония, то санҷиши API кушодашавии
// воқеиро бе интизории соатҳо бинад.
func capsuleMinLead() time.Duration {
	switch os.Getenv("GIN_MODE") {
	case gin.DebugMode, gin.TestMode:
		return 20 * time.Second
	}
	return time.Hour
}
