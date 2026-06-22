package handlers

// Аналитика — қабули батч-рӯйдодҳо аз client ва нигоҳдорӣ дар events.

import (
	"context"
	"encoding/json"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// POST /analytics/events — батч-INSERT-и рӯйдодҳо.
// Body: {"events":[{"event":"screen_view","params":{...}}, ...]}
func TrackAnalyticsEvents(c *gin.Context) {
	myID := mw.UID(c)

	var body struct {
		Events []struct {
			Event  string                 `json:"event"`
			Params map[string]interface{} `json:"params"`
		} `json:"events"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "events required"})
		return
	}
	if len(body.Events) == 0 {
		c.JSON(http.StatusOK, gin.H{"saved": 0})
		return
	}

	// Батч-INSERT бо як query (multi-row VALUES).
	ctx := context.Background()
	batch := &pgxBatch{}
	saved := 0
	for _, e := range body.Events {
		if e.Event == "" {
			continue
		}
		params := e.Params
		if params == nil {
			params = map[string]interface{}{}
		}
		pj, err := json.Marshal(params)
		if err != nil {
			pj = []byte("{}")
		}
		batch.add(myID, e.Event, string(pj))
		saved++
	}

	if saved == 0 {
		c.JSON(http.StatusOK, gin.H{"saved": 0})
		return
	}

	if _, err := db.Pool.Exec(ctx,
		`INSERT INTO events (user_id, event, params) `+batch.sql(), batch.args...); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "insert failed"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"saved": saved})
}

// pgxBatch — сохтани VALUES ($1,$2,$3),($4,$5,$6),... барои батч-INSERT.
type pgxBatch struct {
	args []interface{}
	rows int
}

func (b *pgxBatch) add(userID, event, paramsJSON string) {
	b.args = append(b.args, userID, event, paramsJSON)
	b.rows++
}

func (b *pgxBatch) sql() string {
	s := "VALUES "
	for i := 0; i < b.rows; i++ {
		if i > 0 {
			s += ","
		}
		n := i * 3
		s += "($" + itoa(n+1) + ",$" + itoa(n+2) + ",$" + itoa(n+3) + "::jsonb)"
	}
	return s
}

func itoa(n int) string {
	if n == 0 {
		return "0"
	}
	buf := [12]byte{}
	i := len(buf)
	for n > 0 {
		i--
		buf[i] = byte('0' + n%10)
		n /= 10
	}
	return string(buf[i:])
}
