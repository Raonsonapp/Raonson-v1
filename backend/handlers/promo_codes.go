package handlers

import (
	"context"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// Промокодҳо (Business): фурӯшанда месозад, харидор ҳангоми харид истифода мебарад.

// POST /shop/promos {code, discountPct, maxUses, expiresAt}
func CreatePromo(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Code        string `json:"code"`
		DiscountPct int    `json:"discountPct"`
		MaxUses     int    `json:"maxUses"`
		ExpiresAt   string `json:"expiresAt"` // ISO ё холӣ
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}
	code := strings.ToUpper(strings.TrimSpace(b.Code))
	if code == "" || len(code) > 24 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Коди нодуруст"})
		return
	}
	if b.DiscountPct < 1 || b.DiscountPct > 90 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Тахфиф бояд 1–90% бошад"})
		return
	}
	var expires interface{}
	if strings.TrimSpace(b.ExpiresAt) != "" {
		if t, err := time.Parse(time.RFC3339, b.ExpiresAt); err == nil {
			expires = t
		}
	}
	var id string
	err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO promo_codes(seller_id, code, discount_pct, max_uses, expires_at)
		VALUES($1,$2,$3,$4,$5)
		ON CONFLICT (seller_id, code) DO UPDATE
		  SET discount_pct=EXCLUDED.discount_pct, max_uses=EXCLUDED.max_uses,
		      expires_at=EXCLUDED.expires_at
		RETURNING id`,
		myID, code, b.DiscountPct, b.MaxUses, expires).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "сохта нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id": id, "code": code, "discountPct": b.DiscountPct,
		"maxUses": b.MaxUses, "usedCount": 0,
	})
}

// GET /shop/promos → промокодҳои фурӯшанда
func ListPromos(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT id, code, discount_pct, max_uses, used_count, expires_at
		FROM promo_codes WHERE seller_id=$1 ORDER BY created_at DESC`, myID)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var id, code string
			var pct, maxU, used int
			var exp interface{}
			rows.Scan(&id, &code, &pct, &maxU, &used, &exp)
			out = append(out, gin.H{
				"id": id, "code": code, "discountPct": pct,
				"maxUses": maxU, "usedCount": used, "expiresAt": exp,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"promos": out})
}

// DELETE /shop/promos/:id
func DeletePromo(c *gin.Context) {
	myID := mw.UID(c)
	id := c.Param("id")
	db.Pool.Exec(context.Background(),
		`DELETE FROM promo_codes WHERE id=$1 AND seller_id=$2`, id, myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// POST /shop/promos/validate {code, sellerId} → {valid, discountPct}
func ValidatePromo(c *gin.Context) {
	_ = mw.UID(c)
	var b struct {
		Code     string `json:"code"`
		SellerID string `json:"sellerId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"valid": false})
		return
	}
	code := strings.ToUpper(strings.TrimSpace(b.Code))
	var pct, maxU, used int
	var exp *time.Time
	err := db.Pool.QueryRow(context.Background(), `
		SELECT discount_pct, max_uses, used_count, expires_at
		FROM promo_codes WHERE seller_id=$1 AND code=$2`,
		b.SellerID, code).Scan(&pct, &maxU, &used, &exp)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"valid": false, "message": "Код ёфт нашуд"})
		return
	}
	if exp != nil && time.Now().After(*exp) {
		c.JSON(http.StatusOK, gin.H{"valid": false, "message": "Муҳлаташ гузашт"})
		return
	}
	if maxU > 0 && used >= maxU {
		c.JSON(http.StatusOK, gin.H{"valid": false, "message": "Лимит тамом шуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"valid": true, "discountPct": pct})
}
