package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"user-service/internal/handler"
	"user-service/internal/repository"
	"user-service/internal/service"
	"user-service/pkg/config"
	"user-service/pkg/db"
	"user-service/pkg/logger"
	rdb "user-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

func main() {
	godotenv.Load()
	logger.Init("user-service")
	defer logger.Sync()

	cfg, err := config.Load("DATABASE_URL", "JWT_SECRET")
	if err != nil {
		logger.Fatal("config", zap.Error(err))
	}

	if err := db.Init(10); err != nil {
		logger.Fatal("db", zap.Error(err))
	}
	defer db.Close()

	if err := rdb.Init(); err != nil {
		logger.Fatal("redis", zap.Error(err))
	}
	defer rdb.Close()

	repo := repository.NewUserRepository(db.Pool)
	svc := service.NewUserService(repo)
	h := handler.NewUserHandler(svc)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(reqLogger(), recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Request-ID", "X-User-ID"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"service": "user-service", "status": "ok"})
	})

	authMW := authMiddleware(cfg.JWTSecret)
	rl := rateLimit(100, time.Minute)

	r.GET("/profile/me",              authMW, h.GetMyProfile)
	r.GET("/profile/notes/friends",   authMW, rl, h.GetFriendsNotes)
	r.POST("/profile/note",           authMW, rl, h.SetNote)
	r.PUT("/profile",                 authMW, rl, h.UpdateProfile)
	r.GET("/profile/:username",       authMW, rl, h.GetProfile)
	r.GET("/users/:id",               authMW, rl, h.GetUserByID)
	r.DELETE("/users",                authMW, h.DeleteUser)
	r.POST("/follow/:id",             authMW, rl, h.Follow)
	r.DELETE("/follow/:id",           authMW, rl, h.Unfollow)
	r.GET("/follow/:id/followers",    authMW, rl, h.GetFollowers)
	r.GET("/follow/:id/following",    authMW, rl, h.GetFollowing)
	r.POST("/follow/request/:id/accept", authMW, rl, h.AcceptRequest)
	r.POST("/follow/request/:id/reject", authMW, rl, h.RejectRequest)
	r.GET("/search/users",            authMW, rl, h.SearchUsers)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
	}

	go func() {
		logger.Info("user-service started", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("user-service shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	logger.Info("user-service stopped")
}
