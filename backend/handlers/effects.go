package handlers

import (
	"context"
	"encoding/json"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── GET /effects → эффектҳои ҷамъиятӣ ─────────────────────────────
func GetEffects(c *gin.Context) {
	page := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 40)
	offset := (page - 1) * limit
	rows, err := db.Pool.Query(context.Background(), `
		SELECT e.id, e.name, e.matrix, COALESCE(e.price,0), COALESCE(e.downloads,0),
		       u.id, u.username, COALESCE(u.avatar,''), u.verified
		FROM effects e JOIN users u ON u.id=e.creator_id
		ORDER BY e.downloads DESC, e.created_at DESC LIMIT $1 OFFSET $2`,
		limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "effects failed"})
		return
	}
	defer rows.Close()
	items := []gin.H{}
	for rows.Next() {
		var id, name, matrix, uid, uname, uavatar string
		var price float64
		var downloads int
		var verified bool
		rows.Scan(&id, &name, &matrix, &price, &downloads,
			&uid, &uname, &uavatar, &verified)
		items = append(items, gin.H{
			"_id": id, "name": name, "matrix": json.RawMessage(matrix),
			"price": price, "downloads": downloads,
			"creator": gin.H{"_id": uid, "username": uname,
				"avatar": uavatar, "verified": verified},
		})
	}
	c.JSON(http.StatusOK, gin.H{"effects": items})
}

// ── POST /effects → сохтани эффект (танҳо галочкадорон) ───────────
func CreateEffect(c *gin.Context) {
	myID := mw.UID(c)
	var verified bool
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(verified,FALSE) FROM users WHERE id=$1`, myID).Scan(&verified)
	if !verified {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Танҳо корбарони тасдиқшуда (галочкадор) эффект сохта метавонанд"})
		return
	}
	var b struct {
		Name   string    `json:"name"`
		Matrix []float64 `json:"matrix"`
		Price  float64   `json:"price"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || len(b.Matrix) != 20 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid effect (matrix must be 20)"})
		return
	}
	b.Name = clampRunes(b.Name, 40)
	if b.Name == "" {
		b.Name = "Эффект"
	}
	mjson, _ := json.Marshal(b.Matrix)
	var id string
	err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO effects(creator_id,name,matrix,price)
		 VALUES($1,$2,$3,$4) RETURNING id`,
		myID, b.Name, string(mjson), b.Price).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "create failed"})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"_id": id, "name": b.Name})
}

// ── POST /effects/:id/use → истифода (ройгон) ё харид (премиум) ───
func UseEffect(c *gin.Context) {
	myID := mw.UID(c)
	eid := c.Param("id")
	var creatorID string
	var price float64
	err := db.Pool.QueryRow(context.Background(),
		`SELECT creator_id, COALESCE(price,0) FROM effects WHERE id=$1`,
		eid).Scan(&creatorID, &price)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "effect not found"})
		return
	}
	// Премиум ва аз они ман нест → харид + комиссия (як бор).
	if price > 0 && creatorID != myID {
		var already bool
		db.Pool.QueryRow(context.Background(),
			`SELECT EXISTS(SELECT 1 FROM effect_purchases WHERE effect_id=$1 AND buyer_id=$2)`,
			eid, myID).Scan(&already)
		if !already {
			commission := price * commissionRate
			db.Pool.Exec(context.Background(),
				`INSERT INTO effect_purchases(effect_id,buyer_id,creator_id,price,commission)
				 VALUES($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING`,
				eid, myID, creatorID, price, commission)
			notify(creatorID, myID, "effect_sale", eid)
			pushNotify(creatorID, myID, "effect_sale", eid, "эффекти шуморо харид")
		}
	}
	db.Pool.Exec(context.Background(),
		`UPDATE effects SET downloads=downloads+1 WHERE id=$1`, eid)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ── GET /effects/mine → эффектҳои сохтаи ман ──────────────────────
func GetMyEffects(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT id, name, matrix, COALESCE(price,0), COALESCE(downloads,0)
		FROM effects WHERE creator_id=$1 ORDER BY created_at DESC`, myID)
	items := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, name, matrix string
			var price float64
			var downloads int
			rows.Scan(&id, &name, &matrix, &price, &downloads)
			items = append(items, gin.H{
				"_id": id, "name": name, "matrix": json.RawMessage(matrix),
				"price": price, "downloads": downloads,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"effects": items})
}
