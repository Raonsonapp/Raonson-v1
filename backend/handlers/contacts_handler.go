package handlers

import (
	"context"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ─────────────────────────────────────────────────────────────────
// POST /users/find-by-contacts
//
// Клиент рӯйхати рақамҳои телефон мефиристад,
// бэкенд корбарони сабтшударо бармегардонад.
// ─────────────────────────────────────────────────────────────────
func FindUsersByContacts(c *gin.Context) {
	myID := mw.UID(c)

	var body struct {
		Phones []string `json:"phones"` // ["992901234567", "+992901234567", ...]
	}
	if err := c.ShouldBindJSON(&body); err != nil || len(body.Phones) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "phones array required"})
		return
	}

	// Рақамҳоро тоза мекунем (+, пробелҳо)
	cleaned := make([]string, 0, len(body.Phones))
	for _, p := range body.Phones {
		n := cleanPhone(p)
		if len(n) >= 7 {
			cleaned = append(cleaned, n)
		}
	}
	if len(cleaned) == 0 {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}

	// Корбаронеро меёбем, ки:
	// 1. Рақамашон дар рӯйхат аст
	// 2. Худи man не
	// 3. Дигар пайрав нашудаем
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, u.avatar, u.verified, u.bio,
		       EXISTS(
		           SELECT 1 FROM follows
		           WHERE follower_id=$1 AND following_id=u.id
		       ) AS is_following
		FROM users u
		WHERE u.phone = ANY($2::text[])
		  AND u.id <> $1
		ORDER BY u.username
		LIMIT 100
	`, myID, cleaned)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "query failed"})
		return
	}
	defer rows.Close()

	users := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, bio string
		var verified, isFollowing bool
		rows.Scan(&id, &uname, &avatar, &verified, &bio, &isFollowing)
		users = append(users, gin.H{
			"id":          id,
			"_id":         id,
			"username":    uname,
			"avatar":      avatar,
			"verified":    verified,
			"bio":         bio,
			"isFollowing": isFollowing,
		})
	}

	c.JSON(http.StatusOK, gin.H{"users": users})
}

// ─────────────────────────────────────────────────────────────────
// GET /users/by-username/:username
// Барои @mention клик → профил
// ─────────────────────────────────────────────────────────────────
func GetUserByUsername(c *gin.Context) {
	username := c.Param("username")
	myID := mw.UID(c)

	var id string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id FROM users WHERE username=$1`, username).Scan(&id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}

	u, err := getUserByID(id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	setIsFollowing(u, myID, id)
	c.JSON(http.StatusOK, u)
}

// cleanPhone — рақамро ба формати рақамӣ меорад
func cleanPhone(p string) string {
	out := make([]byte, 0, len(p))
	for i := 0; i < len(p); i++ {
		if p[i] >= '0' && p[i] <= '9' {
			out = append(out, p[i])
		}
	}
	return string(out)
}

// ─────────────────────────────────────────────────────────────────
// GET /users/suggestions
// Корбарони тавсияшаванда (на пайрав нашудаем)
// ─────────────────────────────────────────────────────────────────
func GetSuggestions(c *gin.Context) {
	myID := mw.UID(c)

	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, u.avatar, u.verified, u.bio,
		       (SELECT COUNT(*) FROM follows f2
		        WHERE f2.following_id=u.id) AS followers_count
		FROM users u
		WHERE u.id <> $1
		  AND NOT EXISTS (
		      SELECT 1 FROM follows
		      WHERE follower_id=$1 AND following_id=u.id
		  )
		  AND u.is_private = false
		ORDER BY followers_count DESC, RANDOM()
		LIMIT 20
	`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}
	defer rows.Close()

	users := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, bio string
		var verified bool
		var followers int
		rows.Scan(&id, &uname, &avatar, &verified, &bio, &followers)
		users = append(users, gin.H{
			"id": id, "_id": id,
			"username": uname, "avatar": avatar,
			"verified": verified, "bio": bio,
			"followersCount": followers,
			"isFollowing":    false,
		})
	}
	c.JSON(http.StatusOK, gin.H{"users": users})
}

// ─────────────────────────────────────────────────────────────────
// GET /follow/requests
// Дархостҳои пайравӣ барои корбари private
// ─────────────────────────────────────────────────────────────────
func GetFollowRequests(c *gin.Context) {
	myID := mw.UID(c)

	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, u.avatar, u.verified, u.bio
		FROM follow_requests fr
		JOIN users u ON u.id = fr.requester_id
		WHERE fr.target_id = $1
		ORDER BY fr.created_at DESC
		LIMIT 50
	`, myID)
	if err != nil {
		// Агар ҷадвал вуҷуд надошта бошад - рӯйхати холӣ
		c.JSON(http.StatusOK, gin.H{"requests": []gin.H{}})
		return
	}
	defer rows.Close()

	requests := []gin.H{}
	for rows.Next() {
		var id, uname, avatar, bio string
		var verified bool
		rows.Scan(&id, &uname, &avatar, &verified, &bio)
		requests = append(requests, gin.H{
			"id": id, "_id": id,
			"username": uname, "avatar": avatar,
			"verified": verified, "bio": bio,
		})
	}
	c.JSON(http.StatusOK, gin.H{"requests": requests})
}

// ─────────────────────────────────────────────────────────────────
// GET /notifications/unread-count
// Шумораи огоҳиномаҳои нахондашуда
// ─────────────────────────────────────────────────────────────────
func GetUnreadNotifCount(c *gin.Context) {
	myID := mw.UID(c)

	var count int
	err := db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND is_read=false`,
		myID).Scan(&count)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"count": 0})
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": count})
}
