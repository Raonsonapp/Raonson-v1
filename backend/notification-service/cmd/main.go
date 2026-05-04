package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"notification-service/internal/handler"
	"notification-service/internal/middleware"
	"notification-service/internal/repository"
	"notification-service/internal/service"
	"notification-service/pkg/config"
	"notification-service/pkg/db"
	"notification-service/pkg/logger"
	rdb "notification-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

func main() {
	godotenv.Load()
	logger.Init("notification-service")
	defer logger.Sync()

	cfg, err := config.Load("DATABASE_URL")
	if err != nil {
		logger.Fatal("config", zap.Error(err))
	}

	if err := db.Init(8); err != nil {
		logger.Fatal("db", zap.Error(err))
	}
	defer db.Close()

	if err := rdb.Init(); err != nil {
		logger.Fatal("redis", zap.Error(err))
	}
	defer rdb.Close()

	repo := repository.New(db.Pool)
	svc := service.New(repo, cfg.RealtimeServiceURL, cfg.FCMServerKey)
	h := handler.New(svc)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.RequestLogger(logger.L))
	r.Use(middleware.Recovery(logger.L))
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Request-ID", "X-User-ID"},
		AllowCredentials: true,
	}))

	r.GET("/health", h.Health)

	authMW := middleware.Auth()
	rl := middleware.RateLimit(60, time.Minute)

	r.GET("/notifications",               authMW, rl, h.GetNotifications)
	r.POST("/notifications/read-all",     authMW, h.MarkAllRead)
	r.POST("/notifications/:id/read",     authMW, h.MarkOneRead)
	r.DELETE("/notifications/:id",        authMW, h.Delete)
	r.POST("/notifications/push-token",   authMW, h.SavePushToken)

	// Internal — no auth (service-to-service only, not exposed by nginx)
	r.POST("/internal/notify", h.CreateNotification)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("notification-service started", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server error", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("notification-service shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("shutdown error", zap.Error(err))
	}
	logger.Info("notification-service stopped")
}
