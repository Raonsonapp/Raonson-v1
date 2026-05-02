package main

import (
	"log"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"post-service/internal/handler"
	"post-service/internal/repository"
	"post-service/internal/service"
	"post-service/pkg/db"
	rdb "post-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/joho/godotenv"
)

func main() {
	godotenv.Load()
	db.Init()
	rdb.Init()

	repo := repository.NewPostRepository(db.Pool)
	svc := service.NewPostService(repo)
	h := handler.NewPostHandler(svc)

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
		c.JSON(http.StatusOK, gin.H{"service": "post-service", "status": "ok"})
	})

	auth := authMiddleware()
	rl := rateLimit(100, time.Minute)
	uploadRL := rateLimit(20, time.Hour)

	r.POST("/posts", auth, uploadRL, h.CreatePost)
	r.GET("/posts/:id", auth, rl, h.GetPost)
	r.DELETE("/posts/:id", auth, rl, h.DeletePost)
	r.PUT("/posts/:id/caption", auth, rl, h.UpdateCaption)
	r.POST("/posts/:id/like", auth, rl, h.ToggleLike)
	r.POST("/posts/:id/save", auth, rl, h.ToggleSave)
	r.POST("/posts/:id/report", auth, rl, h.ReportPost)
	r.POST("/posts/view/:id", auth, h.TrackView)
	r.GET("/users/:id/posts", auth, rl, h.GetUserPosts)

	r.GET("/comments/:id", auth, rl, h.GetComments)
	r.POST("/comments/:id", auth, rl, h.AddComment)
	r.DELETE("/comments/:id", auth, rl, h.DeleteComment)
	r.POST("/comments/:id/like", auth, rl, h.ToggleCommentLike)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8002"
	}
	log.Printf("📝 post-service :%s", port)
	r.Run(":" + port)
}

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if uid := c.GetHeader("X-User-ID"); uid != "" {
			c.Set("userID", uid)
			c.Next()
			return
		}
		header := c.GetHeader("Authorization")
		if header == "" || !strings.HasPrefix(header, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "No token"})
			c.Abort()
			return
		}
		secret := os.Getenv("JWT_SECRET")
		if secret == "" {
			secret = "raonson-secret-change-in-prod"
		}
		tok, err := jwt.Parse(header[7:],
			func(t *jwt.Token) (interface{}, error) { return []byte(secret), nil },
			jwt.WithValidMethods([]string{"HS256"}))
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

func rateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct {
		count int
		reset time.Time
	}
	store := map[string]*entry{}
	var mu sync.Mutex
	return func(c *gin.Context) {
		key, _ := c.Get("userID")
		k, _ := key.(string)
		if k == "" {
			k = c.ClientIP()
		}
		now := time.Now()
		mu.Lock()
		e, ok := store[k]
		if !ok || now.After(e.reset) {
			store[k] = &entry{1, now.Add(window)}
			mu.Unlock()
			c.Next()
			return
		}
		e.count++
		count := e.count
		mu.Unlock()
		if count > limit {
			c.JSON(http.StatusTooManyRequests, gin.H{"message": "Too many requests"})
			c.Abort()
			return
		}
		c.Next()
	}
}
