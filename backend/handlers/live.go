package handlers

import (
	"context"
	"net/http"
	"strings"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/utils"

	"github.com/gin-gonic/gin"
)

// Live-стримҳо — канали Agora broadcast. Ҳост стрим мекунад, дигарон тамошо.

// POST /live/start {title} → {id, channel}
func StartLive(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Title string `json:"title"`
	}
	c.ShouldBindJSON(&b)
	title := strings.TrimSpace(b.Title)
	title = clampRunes(title, 100) // ҳарф, на байт (кириллӣ нимта намешавад)
	// Стримҳои қаблии ҳамин корбарро мебандем.
	db.Pool.Exec(context.Background(),
		`UPDATE live_streams SET active=FALSE, ended_at=NOW()
		 WHERE host_id=$1 AND active=TRUE`, myID)

	var id string
	err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO live_streams(host_id, channel, title)
		VALUES($1, '', $2) RETURNING id`, myID, title).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "стрим сар нашуд"})
		return
	}
	channel := "live_" + id
	db.Pool.Exec(context.Background(),
		`UPDATE live_streams SET channel=$1 WHERE id=$2`, channel, id)

	c.JSON(http.StatusOK, gin.H{"id": id, "channel": channel})
}

// POST /live/:id/end
func EndLive(c *gin.Context) {
	myID := mw.UID(c)
	id := c.Param("id")
	// Натиҷа САНҶИДА мешавад. Маълумот ҳимоя буд (`AND host_id=$2`),
	// вале ҷавоб ҳамеша 200 буд — яъне бегона тугмаро мезад, барнома
	// «эфир хотима ёфт» нишон медод, ҳол он ки эфир давом дошт.
	// Ҳамон камбудии `pin`, дар ҷои дигар.
	tag, err := db.Pool.Exec(context.Background(),
		`UPDATE live_streams SET active=FALSE, ended_at=NOW()
		 WHERE id=$1 AND host_id=$2`, id, myID)
	if err != nil || tag.RowsAffected() == 0 {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо соҳиби эфир"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// liveHost — ҳости эфири ФАЪОЛ, агар тамошобин онро дида тавонад.
func liveHost(streamID, viewer string) string {
	var host string
	db.Pool.QueryRow(context.Background(),
		`SELECT host_id FROM live_streams WHERE id=$1 AND active=TRUE`, streamID).Scan(&host)
	if host == "" {
		return ""
	}
	if ok, _ := CanSeeProfileContent(viewer, host); !ok {
		return ""
	}
	return host
}

// refreshViewers — шумораи бинандагон аз рӯи одамони ВОҚЕӢ.
func refreshViewers(streamID string) int {
	var n int
	db.Pool.QueryRow(context.Background(), `
		UPDATE live_streams SET viewers =
		  (SELECT COUNT(*) FROM live_viewers WHERE stream_id=$1 AND active)
		WHERE id=$1 RETURNING viewers`, streamID).Scan(&n)
	return n
}

// POST /live/:id/join
//
// ⚠️ Пеш ҳар дархост +1 мекард — бо такрор ҳазорҳо «бинанда» сохтан
// мумкин буд. Акнун ҳар корбар як бор ҳисоб мешавад.
func JoinLive(c *gin.Context) {
	id := c.Param("id")
	me := mw.UID(c)
	if liveHost(id, me) == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Эфир ёфт нашуд"})
		return
	}
	db.Pool.Exec(context.Background(), `
		INSERT INTO live_viewers(stream_id,user_id,active) VALUES($1,$2,TRUE)
		ON CONFLICT (stream_id,user_id) DO UPDATE SET active=TRUE`, id, me)
	c.JSON(http.StatusOK, gin.H{"ok": true, "viewers": refreshViewers(id)})
}

// POST /live/:id/leave
func LeaveLive(c *gin.Context) {
	id := c.Param("id")
	db.Pool.Exec(context.Background(),
		`UPDATE live_viewers SET active=FALSE WHERE stream_id=$1 AND user_id=$2`,
		id, mw.UID(c))
	c.JSON(http.StatusOK, gin.H{"ok": true, "viewers": refreshViewers(id)})
}

// GET /live → стримҳои фаъол
func ListLive(c *gin.Context) {
	rows, err := db.Pool.Query(context.Background(), `
		SELECT l.id, l.channel, l.title, l.viewers, COALESCE(l.likes,0),
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		FROM live_streams l JOIN users u ON u.id=l.host_id
		WHERE l.active=TRUE
		  -- Бастагон ва ҳисобҳои пӯшидаи бегона дар рӯйхат нестанд.
		  AND `+visibleAuthorSQL("l.host_id", "u", "$1")+`
		ORDER BY l.started_at DESC LIMIT 50`, mw.UID(c))
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, channel, title, hid, uname, uavatar string
			var viewers, likes int
			var verified bool
			rows.Scan(&id, &channel, &title, &viewers, &likes, &hid, &uname, &uavatar, &verified)
			out = append(out, gin.H{
				"id": id, "channel": channel, "title": title,
				"viewers": viewers, "likes": likes,
				"host": gin.H{"_id": hid, "username": uname,
					"avatar": uavatar, "verified": verified},
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"streams": out})
}

// POST /live/:id/comment {text} → шарҳи live
func LiveComment(c *gin.Context) {
	myID := mw.UID(c)
	id := c.Param("id")
	var b struct {
		Text string `json:"text"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}
	text := strings.TrimSpace(b.Text)
	if text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "холӣ"})
		return
	}
	text = clampRunes(text, 300) // пеш байт мебурид — ҳарфи кириллӣ нимта мешуд
	// Танҳо ба эфири фаъол ва на аз бастагон.
	if liveHost(id, myID) == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Эфир ёфт нашуд"})
		return
	}
	if flagged, _ := utils.ModerateText(context.Background(), text); flagged {
		c.JSON(http.StatusForbidden, gin.H{"message": "Шарҳ қоидаҳои ҷамъиятиро вайрон мекунад"})
		return
	}
	if _, err := db.Pool.Exec(context.Background(),
		`INSERT INTO live_comments(stream_id, user_id, text) VALUES($1,$2,$3)`,
		id, myID, text); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Шарҳ сабт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /live/:id/comments → 50 шарҳи охирин
func LiveComments(c *gin.Context) {
	id := c.Param("id")
	rows, err := db.Pool.Query(context.Background(), `
		SELECT c.id, c.text, u.username, COALESCE(u.avatar,'')
		FROM live_comments c JOIN users u ON u.id=c.user_id
		WHERE c.stream_id=$1 ORDER BY c.created_at DESC LIMIT 50`, id)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var cid, text, uname, uavatar string
			rows.Scan(&cid, &text, &uname, &uavatar)
			out = append(out, gin.H{
				"id": cid, "text": text, "username": uname, "avatar": uavatar,
			})
		}
	}
	// Тартиби кӯҳна→нав барои намоиш.
	for i, j := 0, len(out)-1; i < j; i, j = i+1, j-1 {
		out[i], out[j] = out[j], out[i]
	}
	c.JSON(http.StatusOK, gin.H{"comments": out})
}

// POST /live/:id/like → +1 дил
//
// Мисли Instagram дилҳоро борҳо зада мешавад, вале аз як нафар то 300 —
// пеш бо такрори дархост шумораро беохир баланд кардан мумкин буд.
func LiveLike(c *gin.Context) {
	id := c.Param("id")
	me := mw.UID(c)
	if liveHost(id, me) == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Эфир ёфт нашуд"})
		return
	}
	var counted bool
	db.Pool.QueryRow(context.Background(), `
		INSERT INTO live_viewers(stream_id,user_id,active,likes) VALUES($1,$2,TRUE,1)
		ON CONFLICT (stream_id,user_id) DO UPDATE SET likes = live_viewers.likes + 1
		WHERE live_viewers.likes < 300
		RETURNING TRUE`, id, me).Scan(&counted)
	if counted {
		db.Pool.Exec(context.Background(),
			`UPDATE live_streams SET likes=COALESCE(likes,0)+1 WHERE id=$1 AND active=TRUE`, id)
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
