package main

import (
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"user-service/internal/handler"
	"user-service/internal/repository"
	"user-service/internal/service"
	"user-service/pkg/db"
	rdb "user-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/joho/godotenv"
)

func main() {
	godotenv.Load()
	db.Init()
	rdb.Init()

	repo := repository.NewUserRepository(db.Pool)
	svc := service.NewUserService(repo)
	h := handler.NewUserHandler(svc)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"service": "user-service", "status": "ok"})
	})

	auth := authMiddleware()
	rl := rateLimitMiddleware(100, time.Minute)

	// Profile
	r.GET("/profile/me",             auth, h.GetMyProfile)
	r.GET("/profile/notes/friends",  auth, rl, h.GetFriendsNotes)
	r.POST("/profile/note",          auth, rl, h.SetNote)
	r.PUT("/profile",                auth, rl, h.UpdateProfile)
	r.GET("/profile/:username",      auth, rl, h.GetProfile)

	// Users
	r.GET("/users/:id", auth, rl, h.GetUserByID)
	r.DELETE("/users",  auth, h.DeleteUser)

	// Follow
	r.POST("/follow/:id",                auth, rl, h.Follow)
	r.DELETE("/follow/:id",              auth, rl, h.Unfollow)
	r.GET("/follow/:id/followers",       auth, rl, h.GetFollowers)
	r.GET("/follow/:id/following",       auth, rl, h.GetFollowing)
	r.POST("/follow/request/:id/accept", auth, rl, h.AcceptRequest)
	r.POST("/follow/request/:id/reject", auth, rl, h.RejectRequest)

	// Search
	r.GET("/search/users", auth, rl, h.SearchUsers)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8004"
	}
	log.Printf("👤 user-service running on :%s", port)
	r.Run(":" + port)
}

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Gateway X-User-ID header inject мекунад
		userID := c.GetHeader("X-User-ID")
		if userID != "" {
			c.Set("userID", userID)
			c.Next()
			return
		}
		// Fallback: parse JWT directly (for direct access)
		header := c.GetHeader("Authorization")
		if header == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "No token"})
			c.Abort()
			return
		}
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token format"})
			c.Abort()
			return
		}
		secret := os.Getenv("JWT_SECRET")
		if secret == "" {
			secret = "raonson-secret-change-in-prod"
		}
		tok, err := jwt.Parse(parts[1],
			func(t *jwt.Token) (interface{}, error) { return []byte(secret), nil },
			jwt.WithValidMethods([]string{"HS256"}),
		)
		if err != nil || !tok.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
			c.Abort()
			return
		}
		claims := tok.Claims.(jwt.MapClaims)
		c.Set("userID", claims["id"].(string))
		c.Next()
	}
}

func rateLimitMiddleware(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct{ count int; reset time.Time }
	store := map[string]*entry{}
	var mu sync.Mutex
	return func(c *gin.Context) {
		key, _ := c.Get("userID")
		k, _ := key.(string)
		if k == "" { k = c.ClientIP() }
		now := time.Now()
		mu.Lock()
		e, ok := store[k]
		if !ok || now.After(e.reset) { store[k] = &entry{1, now.Add(window)}; mu.Unlock(); c.Next(); return }
		e.count++; count := e.count; mu.Unlock()
		if count > limit { c.JSON(http.StatusTooManyRequests, gin.H{"message": "Too many requests"}); c.Abort(); return }
		c.Next()
	}
}
