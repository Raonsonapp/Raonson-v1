package redis

import (
	"context"
	"log"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

var Client *redis.Client
var ctx = context.Background()

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
	if err := Client.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis ping: %v", err)
	}
	log.Println("✅ Redis connected")
}

func Set(key, value string, ttl time.Duration) error {
	return Client.Set(ctx, key, value, ttl).Err()
}
func Get(key string) (string, error) {
	return Client.Get(ctx, key).Result()
}
func Del(keys ...string) {
	Client.Del(ctx, keys...)
}
func Exists(key string) bool {
	n, _ := Client.Exists(ctx, key).Result()
	return n > 0
}
func Incr(key string, ttl time.Duration) int64 {
	v, _ := Client.Incr(ctx, key).Result()
	Client.Expire(ctx, key, ttl)
	return v
}
func Decr(key string) int64 {
	v, _ := Client.Decr(ctx, key).Result()
	return v
}
func SAdd(key, member string, ttl time.Duration) {
	Client.SAdd(ctx, key, member)
	if ttl > 0 {
		Client.Expire(ctx, key, ttl)
	}
}
func SRem(key, member string) {
	Client.SRem(ctx, key, member)
}
func SIsMember(key, member string) bool {
	v, _ := Client.SIsMember(ctx, key, member).Result()
	return v
}
func ZAdd(key string, score float64, member string) {
	Client.ZAdd(ctx, key, redis.Z{Score: score, Member: member})
}
func ZRevRange(key string, start, stop int64) []string {
	v, _ := Client.ZRevRange(ctx, key, start, stop).Result()
	return v
}
func ZRemRangeByRank(key string, start, stop int64) {
	Client.ZRemRangeByRank(ctx, key, start, stop)
}
func Expire(key string, ttl time.Duration) {
	Client.Expire(ctx, key, ttl)
}
func Publish(channel string, msg interface{}) {
	Client.Publish(ctx, channel, msg)
}
func Subscribe(channels ...string) *redis.PubSub {
	return Client.Subscribe(ctx, channels...)
}
func Pipeline() redis.Pipeliner {
	return Client.Pipeline()
}
