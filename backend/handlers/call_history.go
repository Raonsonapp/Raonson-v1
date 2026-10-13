package handlers

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"raonson/calllog"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// GET /calls/history?cursor=&limit= → {items, nextCursor}
//
// Таърихи зангҳо (воридотӣ/содиротӣ/аздастрафта бо давомнокӣ). Сабт аз
// ҳодисаҳои сокет меояд (ниг. sockets/ws.go → calllog). Басташудагон ва
// сатрҳои «несткарда» нишон дода намешаванд.
func CallHistory(c *gin.Context) {
	me := mw.UID(c)
	cur, err := calllog.DecodeCursor(c.Query("cursor"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "cursor нодуруст"})
		return
	}
	limit, _ := strconv.Atoi(c.Query("limit"))
	ctx, cancel := context.WithTimeout(c.Request.Context(), 10*time.Second)
	defer cancel()
	entries, next, err := calllog.History(ctx, me, cur, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "таърих хонда нашуд"})
		return
	}
	now := time.Now()
	items := make([]gin.H, 0, len(entries))
	for _, e := range entries {
		v := calllog.Classify(e.Row, me, now)
		item := gin.H{
			"id":          e.ID,
			"direction":   v.Direction,
			"status":      v.Status,
			"type":        e.CallType,
			"videoUsed":   e.VideoUsed,
			"startedAt":   e.StartedAt.UTC().Format(time.RFC3339),
			"answeredAt":  fmtTime(e.AnsweredAt),
			"endedAt":     fmtTime(v.EndedAt),
			"durationSec": v.DurationSec,
			"peer": gin.H{
				"_id": e.Peer.ID, "id": e.Peer.ID,
				"username": e.Peer.Username, "avatar": e.Peer.Avatar,
				"verified": e.Peer.Verified,
			},
		}
		items = append(items, item)
	}
	var nextCursor interface{}
	if next != nil {
		nextCursor = next.Encode()
	}
	c.JSON(http.StatusOK, gin.H{"items": items, "nextCursor": nextCursor})
}

// DELETE /calls/history/:id — як сатр; DELETE /calls/history — ҳама.
// Танҳо аз таърихи худи корбар; ҳамсӯҳбат сабти худро нигоҳ медорад.
func DeleteCallHistory(c *gin.Context) {
	me := mw.UID(c)
	id := c.Param("id")
	n, err := calllog.Hide(c.Request.Context(), me, id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "нест карда нашуд"})
		return
	}
	if id != "" && n == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"removed": n})
}

func fmtTime(t *time.Time) interface{} {
	if t == nil {
		return nil
	}
	return t.UTC().Format(time.RFC3339)
}
