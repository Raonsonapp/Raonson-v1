package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  «Дӯстдоштаҳо» — мисли Instagram Favorites.
//
//  То 50 ҳисоб. Постҳои онҳо дар лентаи алоҳида (?mode=favorites) бо
//  тартиби вақт. Рӯйхат шахсӣ аст — ҳеҷ кас намедонад, ки ӯро ба
//  дӯстдоштаҳо илова кардаед (огоҳинома фиристода намешавад).
// ══════════════════════════════════════════════════════════════════

const maxFavorites = 50

// POST /users/:id/favorite {favorite}
func ToggleFavorite(c *gin.Context) {
	myID := mw.UID(c)
	target := c.Param("id")
	if target == "" || target == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Худро илова кардан мумкин нест"})
		return
	}
	var b struct {
		Favorite bool `json:"favorite"`
	}
	_ = c.ShouldBindJSON(&b)
	ctx := context.Background()

	if !b.Favorite {
		db.Pool.Exec(ctx, `DELETE FROM favorites WHERE user_id=$1 AND fav_id=$2`, myID, target)
		invalidateFeedCache(myID)
		c.JSON(http.StatusOK, gin.H{"favorite": false})
		return
	}
	if denyIfBlocked(c, myID, target) {
		return
	}
	var exists bool
	db.Pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM users WHERE id=$1)`, target).Scan(&exists)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	var n int
	db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM favorites WHERE user_id=$1 AND fav_id<>$2`,
		myID, target).Scan(&n)
	if n >= maxFavorites {
		c.JSON(http.StatusConflict, gin.H{"message": "Ҳадди аксар 50 дӯстдошта"})
		return
	}
	db.Pool.Exec(ctx, `INSERT INTO favorites(user_id,fav_id) VALUES($1,$2)
		ON CONFLICT DO NOTHING`, myID, target)
	invalidateFeedCache(myID)
	c.JSON(http.StatusOK, gin.H{"favorite": true})
}

// GET /users/favorites
func GetFavorites(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		FROM favorites f JOIN users u ON u.id=f.fav_id
		WHERE f.user_id=$1 ORDER BY f.created_at DESC`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, un, av string
		var ver bool
		rows.Scan(&id, &un, &av, &ver)
		out = append(out, gin.H{"_id": id, "username": un, "avatar": av, "verified": ver})
	}
	c.JSON(http.StatusOK, gin.H{"users": out, "max": maxFavorites})
}

