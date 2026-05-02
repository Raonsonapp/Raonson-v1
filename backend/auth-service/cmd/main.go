package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"auth-service/internal/handler"
	"auth-service/internal/middleware"
	"auth-service/internal/repository"
	"auth-service/internal/service"
	"auth-service/pkg/db"
	rdb "auth-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	godotenv.Load()
	db.Init()
	rdb.Init()

	// Wire up dependencies
	repo := repository.NewAuthRepository(db.Pool)
	svc := service.NewAuthService(repo)
	h := handler.NewAuthHandler(svc)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
	}))

	// Health check
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"service": "auth-service", "status": "ok"})
	})

	// Strict rate limit for auth routes: 20 req/min per IP
	rl := middleware.RateLimit(20, time.Minute)

	// ── AUTH ROUTES ───────────────────────────────────────────
	auth := r.Group("/auth")
	{
		auth.POST("/register",        rl, h.Register)
		auth.POST("/login",           rl, h.Login)
		auth.POST("/refresh",         h.RefreshToken)
		auth.POST("/logout",          middleware.Auth(), h.Logout)
		auth.POST("/forgot-password", rl, h.ForgotPassword)
		auth.POST("/reset-password",  rl, h.ResetPassword)
	}

	// Internal: Nginx auth_request calls this
	r.GET("/internal/validate", h.ValidateToken)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8001"
	}
	log.Printf("🔐 auth-service running on :%s", port)
	r.Run(":" + port)
}
