package redis

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

var Client *redis.Client

func Init() {
	url := os.Getenv("REDIS_URL")
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	opt, err := redis.ParseURL(url)
	if err != nil {
		log.Fatalf("redis parse url: %v", err)
	}
	opt.PoolSize = 10
	opt.MinIdleConns = 2
	Client = redis.NewClient(opt)
	if err := Client.Ping(context.Background()).Err(); err != nil {
		log.Fatalf("redis ping failed: %v", err)
	}
	log.Println("✅ Redis connected")
}

func Set(key string, value interface{}, ttl time.Duration) error {
	return Client.Set(context.Background(), key, value, ttl).Err()
}

func Get(key string) (string, error) {
	return Client.Get(context.Background(), key).Result()
}

func Del(keys ...string) error {
	return Client.Del(context.Background(), keys...).Err()
}

func Exists(key string) bool {
	n, _ := Client.Exists(context.Background(), key).Result()
	return n > 0
}
