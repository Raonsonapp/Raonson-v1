package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

type Config struct {
	AppEnv              string
	Port                string
	DatabaseURL         string
	RedisURL            string
	JWTSecret           string
	JWTRefreshSecret    string
	FeedServiceURL      string
	NotifServiceURL     string
	RealtimeServiceURL  string
	FCMServerKey        string
}

func Load(required ...string) (*Config, error) {
	for _, k := range required {
		if os.Getenv(k) == "" {
			return nil, fmt.Errorf("required env %q not set", k)
		}
	}
	return &Config{
		AppEnv:             getEnv("APP_ENV", "development"),
		Port:               getEnv("PORT", "8080"),
		DatabaseURL:        os.Getenv("DATABASE_URL"),
		RedisURL:           getEnv("REDIS_URL", "redis://localhost:6379/0"),
		JWTSecret:          getEnv("JWT_SECRET", "change_me"),
		JWTRefreshSecret:   getEnv("JWT_REFRESH_SECRET", "refresh_change_me"),
		FeedServiceURL:     os.Getenv("FEED_SERVICE_URL"),
		NotifServiceURL:    os.Getenv("NOTIFICATION_SERVICE_URL"),
		RealtimeServiceURL: os.Getenv("REALTIME_SERVICE_URL"),
		FCMServerKey:       os.Getenv("FCM_SERVER_KEY"),
	}, nil
}
func getEnv(k, fb string) string { if v := os.Getenv(k); v != "" { return v }; return fb }
func GetInt(k string, fb int) int {
	if v := os.Getenv(k); v != "" { if n, e := strconv.Atoi(v); e == nil { return n } }
	return fb
}
func GetDuration(k string, fb time.Duration) time.Duration {
	if v := os.Getenv(k); v != "" { if d, e := time.ParseDuration(v); e == nil { return d } }
	return fb
}
