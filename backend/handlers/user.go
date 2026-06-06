package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// GET /users/:id
func GetUserByID(c *gin.Context) {
	id   := c.Param("id")
	myID := mw.UID(c)

	u, err := getUserByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	setIsFollowing(u, myID, id)
	c.JSON(http.StatusOK, u)
}

// PUT /users/
func UpdateUser(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Bio       *string `json:"bio"`
		Avatar    *string `json:"avatar"`
		IsPrivate *bool   `json:"isPrivate"`
		Username  *string `json:"username"`
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
		  updated_at = NOW()
		WHERE id=$5`,
		b.Bio, b.Avatar, b.IsPrivate, b.Username, myID)
	if err != nil {
		if isUnique(err) {
			c.JSON(http.StatusConflict, gin.H{"message": "Username taken"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	u, _ := getUserByID(myID)
	c.JSON(http.StatusOK, u)
}

// DELETE /users/
func DeleteUser(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(context.Background(), `DELETE FROM users WHERE id=$1`, myID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// GET /users/:id/posts
func GetUserPosts(c *gin.Context) {
	id     := c.Param("id")
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 24)
	offset := (page - 1) * limit

	// Постҳои pinned аввал, баъд аз рӯи сана. Бо маълумоти корбар +
	// liked/saved/isPinned — то дар экрани кушодашуда (мисли home) кор кунад.
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE p.user_id=$2
		ORDER BY COALESCE(p.is_pinned,false) DESC, p.created_at DESC
		LIMIT $3 OFFSET $4`,
		myID, id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get posts failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": scanFeedPosts(rows)})
}

// GET /users/:id/reels
func GetUserReels(c *gin.Context) {
	id     := c.Param("id")
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 24)
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT id, video_url, caption, views_count, likes_count, created_at
		FROM reels WHERE user_id=$1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		id, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get reels failed"})
		return
	}
	defer rows.Close()

	out := []gin.H{}
	for rows.Next() {
		var rid, vurl, cap string
		var views, likes int
		var createdAt interface{}
		rows.Scan(&rid, &vurl, &cap, &views, &likes, &createdAt)
		out = append(out, gin.H{
			"_id": rid, "videoUrl": vurl, "caption": cap,
			"views": views, "likesCount": likes, "createdAt": createdAt,
		})
	}
	c.JSON(http.StatusOK, out)
}

// GET /users/:id/followers
func GetFollowers(c *gin.Context) {
	id := c.Param("id")
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,u.avatar,u.verified,u.bio
		FROM follows f JOIN users u ON u.id=f.follower_id
		WHERE f.following_id=$1`, id)
	defer rows.Close()
	c.JSON(http.StatusOK, miniUser(rows))
}

// GET /users/:id/following
func GetFollowing(c *gin.Context) {
	id := c.Param("id")
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT u.id,u.username,u.avatar,u.verified,u.bio
		FROM follows f JOIN users u ON u.id=f.following_id
		WHERE f.follower_id=$1`, id)
	defer rows.Close()
	c.JSON(http.StatusOK, miniUser(rows))
}
