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
		SELECT l.id, l.channel, l.title, l.viewers,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		FROM live_streams l JOIN users u ON u.id=l.host_id
		WHERE l.active=TRUE ORDER BY l.started_at DESC LIMIT 50`)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, channel, title, hid, uname, uavatar string
			var viewers int
			var verified bool
			rows.Scan(&id, &channel, &title, &viewers, &hid, &uname, &uavatar, &verified)
			out = append(out, gin.H{
				"id": id, "channel": channel, "title": title, "viewers": viewers,
				"host": gin.H{"_id": hid, "username": uname,
					"avatar": uavatar, "verified": verified},
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"streams": out})
}
