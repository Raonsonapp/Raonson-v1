package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// GET /profile/me — with 30s personal cache
func GetMyProfile(c *gin.Context) {
	myID := mw.UID(c)

	// Personal cache key
	cacheKey := "profile:me:" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", myID)
	u, err := scanFullUser(row)
	if err != nil {
		log.Printf("[Profile] GetMyProfile error: %v", err)
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	clearExpiredNote(myID, u)
	u["isFollowing"] = false

	// Постҳо ва маълумот якҷо — 1 trip to DB
	posts := postsForUser(myID, 30)
	result := gin.H{"user": u, "posts": posts}

	// Cache барои 30 сония
	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 30*time.Second)
	}

	c.JSON(http.StatusOK, result)
}

// GET /profile/:username — with cache
func GetProfile(c *gin.Context) {
	username := c.Param("username")
	myID := mw.UID(c)

	cacheKey := "profile:u:" + username + ":" + myID
	if cached, ok := mw.CacheGet(cacheKey); ok {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", cached)
		return
	}

	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE username=$1", username)
	u, err := scanFullUser(row)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Profile not found"})
		return
	}

	uid := u["id"].(string)
	clearExpiredNote(uid, u)
	setIsFollowing(u, myID, uid)

	posts := postsForUser(uid, 30)
	result := gin.H{"user": u, "posts": posts}

	if b, err := json.Marshal(result); err == nil {
		mw.CacheSet(cacheKey, b, 30*time.Second)
	}

	c.JSON(http.StatusOK, result)
}

// PUT /profile/ — invalidate cache after update
func UpdateProfile(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Bio       *string `json:"bio"`
		Avatar    *string `json:"avatar"`
		IsPrivate *bool   `json:"isPrivate"`
		Username  *string `json:"username"`
		Website   *string `json:"website"`
		Location  *string `json:"location"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	_, err := db.Pool.Exec(context.Background(), `
		UPDATE users SET
		  bio        = COALESCE($1, bio),
		  avatar     = COALESCE($2, avatar),
		  is_private = COALESCE($3, is_private),
		  username   = COALESCE($4, username),
		  website    = COALESCE($5, website),
		  location   = COALESCE($6, location),
		  updated_at = NOW()
		WHERE id=$7`,
		b.Bio, b.Avatar, b.IsPrivate, b.Username,
		b.Website, b.Location, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	// Кэшро нест кун
	mw.CacheDel("profile:me:"+myID)

	// Return updated profile
	row := db.Pool.QueryRow(context.Background(),
		userSelectSQL+" WHERE id=$1", myID)
	u, _ := scanFullUser(row)
	c.JSON(http.StatusOK, gin.H{"user": u})
}
