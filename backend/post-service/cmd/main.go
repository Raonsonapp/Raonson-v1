package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"post-service/internal/handler"
	"post-service/internal/middleware"
	"post-service/internal/repository"
	"post-service/internal/service"
	"post-service/pkg/config"
	"post-service/pkg/db"
	"post-service/pkg/logger"
	rdb "post-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

func main() {
	godotenv.Load()
	logger.Init("post-service")
	defer logger.Sync()

	cfg, err := config.Load("DATABASE_URL", "JWT_SECRET")
	if err != nil {
		logger.Fatal("config", zap.Error(err))
	}

	if err := db.Init(20); err != nil {
		logger.Fatal("db", zap.Error(err))
	}
	defer db.Close()

	if err := rdb.Init(); err != nil {
		logger.Fatal("redis", zap.Error(err))
	}
	defer rdb.Close()

	repo := repository.NewPostRepository(db.Pool)
	svc := service.New(repo, cfg.FeedServiceURL, cfg.NotifServiceURL)
	h := handler.NewPostHandler(svc)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.RequestLogger(logger.L))
	r.Use(middleware.Recovery(logger.L))
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Request-ID", "X-User-ID"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"service": "post-service", "status": "ok"})
	})

	authMW := middleware.Auth(cfg.JWTSecret)
	rl     := middleware.RateLimit(100, time.Minute)
	uploadRL := middleware.RateLimit(20, time.Hour)

	r.POST("/posts",                authMW, uploadRL, h.CreatePost)
	r.GET("/posts/:id",             authMW, rl, h.GetPost)
	r.DELETE("/posts/:id",          authMW, rl, h.DeletePost)
	r.PUT("/posts/:id/caption",     authMW, rl, h.UpdateCaption)
	r.POST("/posts/:id/like",       authMW, rl, h.ToggleLike)
	r.POST("/posts/:id/save",       authMW, rl, h.ToggleSave)
	r.POST("/posts/:id/report",     authMW, rl, h.ReportPost)
	r.POST("/posts/view/:id",       authMW, h.TrackView)
	r.GET("/users/:id/posts",       authMW, rl, h.GetUserPosts)
	r.GET("/comments/:id",          authMW, rl, h.GetComments)
	r.POST("/comments/:id",         authMW, rl, h.AddComment)
	r.DELETE("/comments/:id",       authMW, rl, h.DeleteComment)
	r.POST("/comments/:id/like",    authMW, rl, h.ToggleCommentLike)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("post-service started", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server error", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("post-service shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
	logger.Info("post-service stopped")
}
