package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// GET /close-friends — рӯйхати дӯстони наздики корбари ҷорӣ
func GetCloseFriends(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, u.avatar, u.verified
		FROM close_friends cf
		JOIN users u ON u.id = cf.friend_id
		WHERE cf.user_id = $1
		ORDER BY cf.created_at DESC`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get close friends failed"})
		return
	}
	defer rows.Close()

	users := []gin.H{}
	for rows.Next() {
		var id, username, avatar string
		var verified bool
		if rows.Scan(&id, &username, &avatar, &verified) == nil {
			users = append(users, gin.H{
				"_id": id, "username": username, "avatar": avatar, "verified": verified,
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"users": users})
}

// GET /close-friends/ids — танҳо ID-ҳо (барои чекмаркҳо)
func GetCloseFriendIDs(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(),
		`SELECT friend_id FROM close_friends WHERE user_id = $1`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get ids failed"})
		return
	}
	defer rows.Close()

	ids := []string{}
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	c.JSON(http.StatusOK, gin.H{"ids": ids})
}

// POST /close-friends/:id — илова кардани дӯст
func AddCloseFriend(c *gin.Context) {
	myID := mw.UID(c)
	friendID := c.Param("id")
	if _, err := db.Pool.Exec(context.Background(),
		`INSERT INTO close_friends(user_id, friend_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING`, myID, friendID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Add failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// DELETE /close-friends/:id — хориҷ кардани дӯст
func RemoveCloseFriend(c *gin.Context) {
	myID := mw.UID(c)
	friendID := c.Param("id")
	if _, err := db.Pool.Exec(context.Background(),
		`DELETE FROM close_friends WHERE user_id=$1 AND friend_id=$2`,
		myID, friendID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Remove failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
