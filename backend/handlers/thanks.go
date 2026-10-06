package handlers

// «Раҳмат» — ташаккурномаи кӯтоҳ, ки дар профил мемонад.
//
// Дар фарҳанги тоҷикӣ «раҳмат» гуфтан ба устод, ҳамсоя, ҳамкор ё касе,
// ки кӯмак кард, қадр дорад. Лайк ин корро намекунад: он ба пост аст,
// на ба одам, ва зуд фаромӯш мешавад. «Раҳмат» ба худи ОДАМ аст ва дар
// профили ӯ ҳамчун «Раҳматҳо» мемонад — мисли дафтари ташаккур.
//
// Қоидаҳо (кӯтоҳ ва бехатар):
//   - як нафар ба як нафар — ЯК раҳмат (такрор матнро нав мекунад, на
//     рӯйхатро дароз); то 140 аломат; ҳадди 20 раҳмат дар рӯз;
//   - матн аз ҳамон модератсияи шарҳҳо мегузарад;
//   - ба худ, ба басташуда ва ба ҳисоби пӯшидаи бегона — не;
//   - гиранда ҳар раҳматро пинҳон карда метавонад (фиристанда
//     намефаҳмад ва дубора фиристодан онро боз намекунад);
//   - фиристанда раҳмати худро бозпас гирифта метавонад.

import (
	"context"
	"net/http"
	"strings"
	"time"
	"unicode/utf8"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// MaxThanksRunes — дарозии раҳмат.
const MaxThanksRunes = 140

// POST /users/:id/thanks {text}
func SendThanks(c *gin.Context) {
	myID := mw.UID(c)
	toID := c.Param("id")
	if toID == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ба худ раҳмат гуфтан мумкин нест"})
		return
	}
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text лозим аст"})
		return
	}
	text := strings.TrimSpace(b.Text)
	if n := utf8.RuneCountInString(text); n < 2 || n > MaxThanksRunes {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Раҳмат бояд аз 2 то 140 аломат бошад"})
		return
	}
	var exists bool
	db.Pool.QueryRow(c.Request.Context(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND COALESCE(banned,false)=FALSE)`,
		toID).Scan(&exists)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	// Блок ва ҳисоби пӯшида: ҳамон қоидаи дидани профил.
	if ok, _ := CanSeeProfileContent(myID, toID); !ok {
		c.JSON(http.StatusForbidden, gin.H{"message": "Дастрас нест"})
		return
	}
	if !otpSendAllowed("thanks:"+myID, 20, 24*time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{"message": "Имрӯз раҳмат бисёр шуд — фардо боз"})
		return
	}
	if !captionAllowed(c, text) {
		return
	}
	var id string
	var fresh bool
	if err := db.Pool.QueryRow(c.Request.Context(), `
		INSERT INTO thanks(from_id, to_id, text) VALUES ($1,$2,$3)
		ON CONFLICT (from_id, to_id) DO UPDATE
		   SET text=EXCLUDED.text, updated_at=NOW()
		RETURNING id, (xmax = 0)`, myID, toID, text).Scan(&id, &fresh); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	notify(toID, myID, "thanks", toID)
	pushNotify(toID, myID, "thanks", toID, "")
	c.JSON(http.StatusCreated, gin.H{"_id": id, "text": text, "new": fresh})
}

// GET /users/:id/thanks?page=&limit=
//
// {count, thanks:[…], mine:{_id,text}|null, canThank}
func GetThanks(c *gin.Context) {
	myID := mw.UID(c)
	toID := c.Param("id")
	if ok, _ := CanSeeProfileContent(myID, toID); !ok {
		c.JSON(http.StatusOK, gin.H{"count": 0, "thanks": []gin.H{},
			"mine": nil, "canThank": false})
		return
	}
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 20))
	ctx := c.Request.Context()

	// Пинҳоншуда ва аз басташудагон (нисбат ба ТАМОШОБИН ё гиранда) —
	// нишон дода намешаванд.
	const visible = `
		t.to_id=$1 AND t.hidden=FALSE
		AND COALESCE(u.banned,false)=FALSE
		AND NOT EXISTS (SELECT 1 FROM blocks b
		     WHERE (b.blocker_id=$2 AND b.blocked_id=t.from_id)
		        OR (b.blocker_id=t.from_id AND b.blocked_id=$2)
		        OR (b.blocker_id=$1 AND b.blocked_id=t.from_id)
		        OR (b.blocker_id=t.from_id AND b.blocked_id=$1))`

	var count int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM thanks t
		JOIN users u ON u.id=t.from_id WHERE `+visible, toID, myID).Scan(&count)

	rows, err := db.Pool.Query(ctx, `
		SELECT t.id, t.text, t.updated_at, u.id, u.username,
		       COALESCE(u.avatar,''), COALESCE(u.verified,false)
		  FROM thanks t JOIN users u ON u.id=t.from_id
		 WHERE `+visible+`
		 ORDER BY t.updated_at DESC LIMIT $3 OFFSET $4`,
		toID, myID, limit, (page-1)*limit)
	list := []gin.H{}
	if err == nil {
		for rows.Next() {
			var id, text, uid, uname, avatar string
			var verified bool
			var at time.Time
			if rows.Scan(&id, &text, &at, &uid, &uname, &avatar, &verified) != nil {
				continue
			}
			list = append(list, gin.H{
				"_id": id, "text": text, "createdAt": at,
				"fromUser": gin.H{"_id": uid, "username": uname,
					"avatar": avatar, "verified": verified},
				// Гиранда пинҳон мекунад, фиристанда бозпас мегирад.
				"canRemove": myID == toID || myID == uid,
			})
		}
		rows.Close()
	}

	var mine gin.H
	if myID != toID {
		var id, text string
		if db.Pool.QueryRow(ctx,
			`SELECT id, text FROM thanks WHERE from_id=$1 AND to_id=$2`,
			myID, toID).Scan(&id, &text) == nil {
			mine = gin.H{"_id": id, "text": text}
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"count": count, "thanks": list, "mine": mine,
		"canThank": myID != toID, "page": page,
	})
}

// DELETE /thanks/:id — фиристанда бозпас мегирад (нест), гиранда
// пинҳон мекунад (сатр мемонад, то дубора фиристодан онро барнагардонад).
func DeleteThanks(c *gin.Context) {
	myID := mw.UID(c)
	id := c.Param("id")
	ctx := context.Background()
	if tag, err := db.Pool.Exec(ctx,
		`DELETE FROM thanks WHERE id=$1 AND from_id=$2`, id, myID); err == nil &&
		tag.RowsAffected() > 0 {
		c.JSON(http.StatusOK, gin.H{"removed": true})
		return
	}
	if tag, err := db.Pool.Exec(ctx,
		`UPDATE thanks SET hidden=TRUE WHERE id=$1 AND to_id=$2`, id, myID); err == nil &&
		tag.RowsAffected() > 0 {
		c.JSON(http.StatusOK, gin.H{"hidden": true})
		return
	}
	c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
}
