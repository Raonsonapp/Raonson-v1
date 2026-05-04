package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"auth-service/internal/handler"
	"auth-service/internal/middleware"
	"auth-service/internal/repository"
	"auth-service/internal/service"
	"auth-service/pkg/config"
	"auth-service/pkg/db"
	"auth-service/pkg/logger"
	rdb "auth-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
	"go.uber.org/zap"
)

func main() {
	godotenv.Load()
	logger.Init("auth-service")
	defer logger.Sync()

	cfg, err := config.Load("DATABASE_URL", "JWT_SECRET")
	if err != nil {
		logger.Fatal("config error", zap.Error(err))
	}

	if err := db.Init(10); err != nil {
		logger.Fatal("db init failed", zap.Error(err))
	}
	defer db.Close()

	if err := rdb.Init(); err != nil {
		logger.Fatal("redis init failed", zap.Error(err))
	}
	defer rdb.Close()

	repo := repository.New(db.Pool)
	svc := service.New(repo)
	h := handler.New(svc)

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(middleware.RequestLogger(logger.L))
	r.Use(middleware.Recovery(logger.L))
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization", "X-Request-ID"},
		AllowCredentials: true,
	}))

	r.GET("/health", h.Health)

	authRL := middleware.RateLimit(20, time.Minute)
	apiRL := middleware.RateLimit(100, time.Minute)
	auth := r.Group("/auth")
	{
		auth.POST("/register",        authRL, h.Register)
		auth.POST("/login",           authRL, h.Login)
		auth.POST("/refresh",         apiRL, h.Refresh)
		auth.POST("/logout",          middleware.Auth(), h.Logout)
		auth.POST("/forgot-password", authRL, h.ForgotPassword)
		auth.POST("/reset-password",  authRL, h.ResetPassword)
	}
	r.GET("/internal/validate", h.ValidateToken)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		logger.Info("auth-service started", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server error", zap.Error(err))
		}
	}()

	// ── Graceful shutdown ─────────────────────────────────────
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("auth-service shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		logger.Error("shutdown error", zap.Error(err))
	}
	logger.Info("auth-service stopped")
}
