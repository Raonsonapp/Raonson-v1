package handlers

// Реклама / Тарғиб (Promote) — мисли "Рекламные инструменты"-и Instagram.
// Корбар як пости худро тарғиб мекунад: ҳадаф, буҷет, давомнокӣ.
// (Пардохти воқеӣ ҳоло симуляция мешавад — фармоиш «in_review» сабт мешавад.)

import (
	"context"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// POST /promotions  — фармоиши нави реклама
func CreatePromotion(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		PostID       string `json:"postId"`
		Goal         string `json:"goal"`
		ActionURL    string `json:"actionUrl"`
		Audience     string `json:"audience"`
		BudgetCents  int    `json:"budgetCents"`
		DurationDays int    `json:"durationDays"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.PostID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "postId лозим аст"})
		return
	}

	// Танҳо пости худи корбарро метавон тарғиб кард.
	var owner string
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM posts WHERE id=$1`, b.PostID).Scan(&owner); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Пост ёфт нашуд"})
		return
	}
	if owner != myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Танҳо пости худро тарғиб карда метавонед"})
		return
	}

	if b.Goal == "" {
		b.Goal = "profile"
	}
	if b.Audience == "" {
		b.Audience = "auto"
	}
	if b.BudgetCents <= 0 {
		b.BudgetCents = 100
	}
	if b.DurationDays <= 0 {
		b.DurationDays = 1
	}
	endsAt := time.Now().AddDate(0, 0, b.DurationDays)

	var id string
	var createdAt interface{}
	err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO promotions
		  (user_id,post_id,goal,action_url,audience,budget_cents,duration_days,status,ends_at)
		VALUES($1,$2,$3,$4,$5,$6,$7,'in_review',$8)
		RETURNING id,created_at`,
		myID, b.PostID, b.Goal, b.ActionURL, b.Audience,
		b.BudgetCents, b.DurationDays, endsAt).Scan(&id, &createdAt)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабти реклама ноком шуд"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":           id,
		"postId":       b.PostID,
		"goal":         b.Goal,
		"status":       "in_review",
		"budgetCents":  b.BudgetCents,
		"durationDays": b.DurationDays,
		"endsAt":       endsAt,
		"createdAt":    createdAt,
	})
}

// GET /promotions  — рӯйхати рекламаҳои ман
func GetMyPromotions(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT pr.id,pr.post_id,pr.goal,pr.status,pr.budget_cents,pr.duration_days,
		       pr.impressions,pr.clicks,pr.created_at,pr.ends_at,
		       COALESCE(pm.url,'') AS thumb
		FROM promotions pr
		LEFT JOIN LATERAL (
		  SELECT url FROM post_media WHERE post_id=pr.post_id ORDER BY position ASC LIMIT 1
		) pm ON TRUE
		WHERE pr.user_id=$1
		ORDER BY pr.created_at DESC
		LIMIT 100`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Дарёфт ноком шуд"})
		return
	}
	defer rows.Close()

	out := []gin.H{}
	for rows.Next() {
		var id, postID, goal, status, thumb string
		var budget, dur, impressions, clicks int
		var createdAt, endsAt interface{}
		rows.Scan(&id, &postID, &goal, &status, &budget, &dur,
			&impressions, &clicks, &createdAt, &endsAt, &thumb)
		out = append(out, gin.H{
			"id": id, "postId": postID, "goal": goal, "status": status,
			"budgetCents": budget, "durationDays": dur,
			"impressions": impressions, "clicks": clicks,
			"thumb": thumb, "createdAt": createdAt, "endsAt": endsAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"promotions": out})
}

// DELETE /promotions/:id  — бекор кардани реклама
func DeletePromotion(c *gin.Context) {
	myID := mw.UID(c)
	id := c.Param("id")
	ct, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM promotions WHERE id=$1 AND user_id=$2`, id, myID)
	if ct.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Реклама ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}
