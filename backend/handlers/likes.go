package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// POST /likes  { targetId, targetType }
func LikeTarget(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		TargetID   string `json:"targetId"`
		TargetType string `json:"targetType"` // post|comment|story|reel
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.TargetID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "targetId required"})
		return
	}
	var likeID string
	db.Pool.QueryRow(context.Background(),
		`INSERT INTO likes(user_id,target_id,target_type)
		 VALUES($1,$2,$3) ON CONFLICT DO NOTHING RETURNING id`,
		myID, b.TargetID, b.TargetType).Scan(&likeID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// DELETE /likes  { targetId }
func UnlikeTarget(c *gin.Context) {
	myID := mw.UID(c)
	var b struct{ TargetID string `json:"targetId"` }
	c.ShouldBindJSON(&b)
	db.Pool.Exec(context.Background(),
		`DELETE FROM likes WHERE user_id=$1 AND target_id=$2`, myID, b.TargetID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// GET /likes/:targetId
func GetLikes(c *gin.Context) {
	var count int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM likes WHERE target_id=$1`,
		c.Param("targetId")).Scan(&count)
	c.JSON(http.StatusOK, gin.H{"likes": count})
}
