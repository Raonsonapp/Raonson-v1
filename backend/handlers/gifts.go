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
	// ⚠️ Пеш ситора аз ҳеҷ чиз пайдо мешуд: фиристанда ҳеҷ чиз
	// намепардохт ва миқдор ҳадде надошт — ҳар кас метавонист ба
	// дӯсташ миллион ситора «тӯҳфа» кунад. Акнун аз баланси фиристанда
	// кам мешавад, дар як транзаксия.
	if b.Stars <= 0 {
		b.Stars = 1
	}
	if b.Stars > 1000 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ҳадди аксар 1000 ситора"})
		return
	}
	if b.TargetType != "reel" && b.TargetType != "post" && b.TargetType != "live" {
		b.TargetType = "reel"
	}
	b.Message = clampRunes(b.Message, 200)
	var exists bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE id=$1 AND COALESCE(banned,false)=FALSE)`,
		b.ToUserID).Scan(&exists)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	if denyIfBlocked(c, myID, b.ToUserID) {
		return
	}

	ctx := context.Background()
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Фиристодан ноком шуд"})
		return
	}
	defer tx.Rollback(ctx)
	var left int
	if tx.QueryRow(ctx, `
		UPDATE users SET stars_balance = stars_balance - $1
		WHERE id=$2 AND COALESCE(stars_balance,0) >= $1
		RETURNING stars_balance`, b.Stars, myID).Scan(&left) != nil {
		var have int
		db.Pool.QueryRow(ctx,
			`SELECT COALESCE(stars_balance,0) FROM users WHERE id=$1`, myID).Scan(&have)
		c.JSON(http.StatusPaymentRequired, gin.H{
			"message": "Ситораҳо кофӣ нестанд", "balance": have, "need": b.Stars})
		return
	}
	var id string
	if err := tx.QueryRow(ctx, `
		INSERT INTO gifts(from_user_id,to_user_id,target_type,target_id,stars,message)
		VALUES($1,$2,$3,$4,$5,$6) RETURNING id`,
		myID, b.ToUserID, b.TargetType, b.TargetID, b.Stars, b.Message).Scan(&id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Фиристодан ноком шуд"})
		return
	}
	if _, err := tx.Exec(ctx,
		`UPDATE users SET stars_balance = COALESCE(stars_balance,0) + $1 WHERE id=$2`,
		b.Stars, b.ToUserID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Фиристодан ноком шуд"})
		return
	}
	if err := tx.Commit(ctx); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Фиристодан ноком шуд"})
		return
	}

	notify(b.ToUserID, myID, "gift", b.TargetID)
	pushNotify(b.ToUserID, myID, "gift", b.TargetID, "")

	c.JSON(http.StatusOK, gin.H{"id": id, "stars": b.Stars, "sent": true, "balance": left})
	return
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

// GET /gifts/balance — баланси ситораҳои ман (барои фиристодани тӯҳфа).
func GetStarsBalance(c *gin.Context) {
	myID := mw.UID(c)
	var bal, received int
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(stars_balance,0) FROM users WHERE id=$1`, myID).Scan(&bal)
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(SUM(stars),0) FROM gifts WHERE to_user_id=$1`, myID).Scan(&received)
	c.JSON(http.StatusOK, gin.H{"balance": bal, "received": received})
}
