package redis

import (
	"context"
	"fmt"
	"os"
	"time"
	"github.com/redis/go-redis/v9"
)

var C *redis.Client
var bg = context.Background()

func Init() error {
	url := os.Getenv("REDIS_URL")
	if url == "" { url = "redis://localhost:6379/0" }
	opt, err := redis.ParseURL(url)
	if err != nil { return err }
	opt.PoolSize = 15
	opt.MinIdleConns = 3
	opt.DialTimeout = 5 * time.Second
	opt.ReadTimeout = 3 * time.Second
	opt.WriteTimeout = 3 * time.Second
	C = redis.NewClient(opt)
	if err := C.Ping(bg).Err(); err != nil { return fmt.Errorf("redis ping: %w", err) }
	return nil
}

func Close() { if C != nil { C.Close() } }

func Set(key, val string, ttl time.Duration) error { return C.Set(bg, key, val, ttl).Err() }
func Get(key string) (string, error)               { return C.Get(bg, key).Result() }
func Del(keys ...string)                           { C.Del(bg, keys...) }
func Exists(key string) bool                       { n, _ := C.Exists(bg, key).Result(); return n > 0 }
func Incr(key string, ttl time.Duration) int64     { v, _ := C.Incr(bg, key).Result(); if ttl > 0 { C.Expire(bg, key, ttl) }; return v }
func Decr(key string) int64                        { v, _ := C.Decr(bg, key).Result(); return v }
func SAdd(key, member string, ttl time.Duration)   { C.SAdd(bg, key, member); if ttl > 0 { C.Expire(bg, key, ttl) } }
func SRem(key, member string)                      { C.SRem(bg, key, member) }
func SIsMember(key, member string) bool            { v, _ := C.SIsMember(bg, key, member).Result(); return v }
func ZAdd(key string, score float64, member string){ C.ZAdd(bg, key, redis.Z{Score: score, Member: member}) }
func ZRevRange(key string, s, e int64) []string    { v, _ := C.ZRevRange(bg, key, s, e).Result(); return v }
func ZRemRangeByRank(key string, s, e int64)       { C.ZRemRangeByRank(bg, key, s, e) }
func Expire(key string, ttl time.Duration)         { C.Expire(bg, key, ttl) }
func Publish(ch string, msg interface{})           { C.Publish(bg, ch, msg) }
func Subscribe(channels ...string) *redis.PubSub  { return C.Subscribe(bg, channels...) }
func Pipeline() redis.Pipeliner                   { return C.Pipeline() }
