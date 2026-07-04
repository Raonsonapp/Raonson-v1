package handlers

import (
	"context"
	"net/http"
	"strings"

	"raonson/db"
	mw "raonson/middleware"

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
	if len(title) > 100 {
		title = title[:100]
	}
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
	db.Pool.Exec(context.Background(),
		`UPDATE live_streams SET active=FALSE, ended_at=NOW()
		 WHERE id=$1 AND host_id=$2`, id, myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// POST /live/:id/join → шумораи бинандаро +1 (best-effort)
func JoinLive(c *gin.Context) {
	id := c.Param("id")
	db.Pool.Exec(context.Background(),
		`UPDATE live_streams SET viewers=viewers+1 WHERE id=$1 AND active=TRUE`, id)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /live → стримҳои фаъол
func ListLive(c *gin.Context) {
	rows, err := db.Pool.Query(context.Background(), `
		SELECT l.id, l.channel, l.title, l.viewers, COALESCE(l.likes,0),
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		FROM live_streams l JOIN users u ON u.id=l.host_id
		WHERE l.active=TRUE ORDER BY l.started_at DESC LIMIT 50`)
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
	if len(text) > 300 {
		text = text[:300]
	}
	db.Pool.Exec(context.Background(),
		`INSERT INTO live_comments(stream_id, user_id, text) VALUES($1,$2,$3)`,
		id, myID, text)
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
func LiveLike(c *gin.Context) {
	id := c.Param("id")
	db.Pool.Exec(context.Background(),
		`UPDATE live_streams SET likes=COALESCE(likes,0)+1 WHERE id=$1 AND active=TRUE`, id)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
