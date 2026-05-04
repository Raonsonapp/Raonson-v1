package db

import (
	"context"
	"fmt"
	"os"
	"time"
	"github.com/jackc/pgx/v5/pgxpool"
)

var Pool *pgxpool.Pool

func Init(maxConns int32) error {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" { return fmt.Errorf("DATABASE_URL not set") }
	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil { return err }
	cfg.MaxConns = maxConns
	cfg.MinConns = 2
	cfg.MaxConnLifetime = 30 * time.Minute
	cfg.MaxConnIdleTime = 5 * time.Minute
	cfg.HealthCheckPeriod = 30 * time.Second
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	Pool, err = pgxpool.NewWithConfig(ctx, cfg)
	if err != nil { return err }
	return Pool.Ping(ctx)
}

func Close() {
	if Pool != nil { Pool.Close() }
}
