package handlers

// Тӯҳфаҳо (Gifts / звёзды) — мисли «Подарки»-и Instagram Reels.
// Корбар ба муаллиф ситора мефиристад; ба муаллиф нотификатсия меравад
// ва ситораҳо ба баланси ӯ илова мешаванд.

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// POST /gifts  — фиристодани тӯҳфа
func SendGift(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		ToUserID   string `json:"toUserId"`
		TargetType string `json:"targetType"`
		TargetID   string `json:"targetId"`
		Stars      int    `json:"stars"`
		Message    string `json:"message"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.ToUserID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "toUserId лозим аст"})
		return
	}
	if b.ToUserID == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ба худатон тӯҳфа фиристода намешавад"})
		return
	}
	if b.Stars <= 0 {
		b.Stars = 1
	}
	if b.TargetType == "" {
		b.TargetType = "reel"
	}

	var id string
	err := db.Pool.QueryRow(context.Background(), `
		INSERT INTO gifts(from_user_id,to_user_id,target_type,target_id,stars,message)
		VALUES($1,$2,$3,$4,$5,$6) RETURNING id`,
		myID, b.ToUserID, b.TargetType, b.TargetID, b.Stars, b.Message).Scan(&id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Фиристодан ноком шуд"})
		return
	}

	// Баланси ситораи муаллифро зиёд кардан (best-effort).
	db.Pool.Exec(context.Background(),
		`UPDATE users SET stars_balance = COALESCE(stars_balance,0) + $1 WHERE id=$2`,
		b.Stars, b.ToUserID)

	// Нотификатсия (best-effort, агар ҷадвал мавҷуд бошад).
	db.Pool.Exec(context.Background(), `
		INSERT INTO notifications(user_id,from_user_id,type,target_id,created_at)
		VALUES($1,$2,'gift',$3,NOW())`, b.ToUserID, myID, b.TargetID)

	c.JSON(http.StatusOK, gin.H{"id": id, "stars": b.Stars, "sent": true})
}

// GET /gifts/received  — тӯҳфаҳои гирифташуда (омор)
func GetReceivedGifts(c *gin.Context) {
	myID := mw.UID(c)
	var total int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(SUM(stars),0) FROM gifts WHERE to_user_id=$1`, myID).Scan(&total)

	rows, err := db.Pool.Query(context.Background(), `
		SELECT g.id,g.stars,g.message,g.created_at,u.username,u.avatar
		FROM gifts g JOIN users u ON u.id=g.from_user_id
		WHERE g.to_user_id=$1 ORDER BY g.created_at DESC LIMIT 100`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"totalStars": total, "gifts": []gin.H{}})
		return
	}
	defer rows.Close()

	out := []gin.H{}
	for rows.Next() {
		var id, msg, uname, avatar string
		var stars int
		var createdAt interface{}
		rows.Scan(&id, &stars, &msg, &createdAt, &uname, &avatar)
		out = append(out, gin.H{
			"id": id, "stars": stars, "message": msg, "createdAt": createdAt,
			"from": gin.H{"username": uname, "avatar": avatar},
		})
	}
	c.JSON(http.StatusOK, gin.H{"totalStars": total, "gifts": out})
}
