package main

import (
	"context"
	"encoding/json"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"feed-service/pkg/config"
	"feed-service/pkg/db"
	"feed-service/pkg/logger"
	rdb "feed-service/pkg/redis"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	gojwt "github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	goredis "github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

func main() {
	godotenv.Load()
	logger.Init("feed-service")
	defer logger.Sync()

	cfg, err := config.Load("DATABASE_URL")
	if err != nil {
		logger.Fatal("config", zap.Error(err))
	}

	if err := db.Init(15); err != nil {
		logger.Fatal("db", zap.Error(err))
	}
	defer db.Close()

	if err := rdb.Init(); err != nil {
		logger.Fatal("redis", zap.Error(err))
	}
	defer rdb.Close()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(reqLogger(), recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins: true,
		AllowMethods:    []string{"GET", "POST", "OPTIONS"},
		AllowHeaders:    []string{"Origin", "Content-Type", "Authorization", "X-Request-ID", "X-User-ID"},
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"service": "feed-service", "status": "ok"})
	})

	authMW := authMiddleware(cfg.JWTSecret)
	rl := rateLimit(120, time.Minute)

	r.GET("/feed",         authMW, rl, getFeed)
	r.GET("/feed/explore", authMW, rl, getExplore)
	r.POST("/internal/fanout", fanOutHandler) // internal — no auth

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 15 * time.Second,
	}

	go func() {
		logger.Info("feed-service started", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server", zap.Error(err))
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	logger.Info("feed-service shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	srv.Shutdown(ctx)
}

// ── GET FEED — Redis ZSET O(log N) ───────────────────────────────
func getFeed(c *gin.Context) {
	myID := uid(c)
	page := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 20)
	start := int64((page - 1) * limit)
	stop := start + int64(limit) - 1

	postIDs := rdb.ZRevRange("feed:"+myID, start, stop)
	if len(postIDs) == 0 {
		go rebuildFeed(myID)
		dbFeed(c, myID, page, limit)
		return
	}

	// Batch fetch post data + liked/saved status via pipeline
	pipe := rdb.C.Pipeline()
	ctx := context.Background()
	postCmds := make([]*goredis.StringCmd, len(postIDs))
	likedCmds := make([]*goredis.BoolCmd, len(postIDs))
	savedCmds := make([]*goredis.BoolCmd, len(postIDs))
	for i, id := range postIDs {
		postCmds[i] = pipe.Get(ctx, "post:"+id)
		likedCmds[i] = pipe.SIsMember(ctx, "post:likes:"+id, myID)
		savedCmds[i] = pipe.SIsMember(ctx, "post:saves:"+id, myID)
	}
	pipe.Exec(ctx)

	posts := make([]map[string]interface{}, 0, len(postIDs))
	for i, cmd := range postCmds {
		b, err := cmd.Bytes()
		if err != nil {
			continue
		}
		var p map[string]interface{}
		if json.Unmarshal(b, &p) == nil {
			p["liked"] = likedCmds[i].Val()
			p["saved"] = savedCmds[i].Val()
			posts = append(posts, p)
		}
	}

	c.Header("X-Cache", "HIT")
	c.JSON(200, gin.H{"success": true, "posts": posts, "page": page, "limit": limit})
}

// ── GET EXPLORE ───────────────────────────────────────────────────
func getExplore(c *gin.Context) {
	const cacheKey = "explore:grid"
	if data, err := rdb.Get(cacheKey); err == nil {
		c.Header("X-Cache", "HIT")
		c.Data(200, "application/json", []byte(data))
		return
	}

	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id,
		  (SELECT url FROM post_media WHERE post_id=p.id ORDER BY position LIMIT 1) AS thumb,
		  COALESCE(p.likes_count,0), COALESCE(p.comments_count,0)
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE u.banned=FALSE AND p.hidden=FALSE
		  AND p.created_at > NOW() - INTERVAL '7 days'
		ORDER BY p.likes_count DESC LIMIT 60`)
	if err != nil {
		c.JSON(500, gin.H{"success": false, "error": gin.H{"message": "explore failed"}}); return
	}
	defer rows.Close()
	posts := []gin.H{}
	for rows.Next() {
		var id, thumb string
		var likes, comms int
		rows.Scan(&id, &thumb, &likes, &comms)
		posts = append(posts, gin.H{"_id": id, "thumb": thumb, "likesCount": likes, "commentsCount": comms})
	}
	res := gin.H{"success": true, "posts": posts}
	if b, err := json.Marshal(res); err == nil {
		rdb.Set(cacheKey, string(b), 5*time.Minute)
	}
	c.JSON(200, res)
}

// ── FAN-OUT ON WRITE ─────────────────────────────────────────────
// Called by post-service via POST /internal/fanout
// Strategy:
//   user < 1000 followers  → push to ALL feeds immediately
//   user >= 1000 followers → push to first 500, rest lazy-load from DB
func fanOutHandler(c *gin.Context) {
	var payload struct {
		PostID string      `json:"postID" binding:"required"`
		UserID string      `json:"userID" binding:"required"`
		Post   interface{} `json:"post"`
		Score  float64     `json:"score"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(400, gin.H{"error": err.Error()}); return
	}

	go func() {
		ctx := context.Background()
		// Cache post JSON
		if b, err := json.Marshal(payload.Post); err == nil {
			rdb.Set("post:"+payload.PostID, string(b), 7*24*time.Hour)
		}

		// Count followers to decide strategy
		var followerCount int
		db.Pool.QueryRow(ctx,
			`SELECT COUNT(*) FROM follows WHERE following_id=$1`, payload.UserID).Scan(&followerCount)

		limit := 0 // 0 = no limit (all followers)
		if followerCount >= 1000 {
			limit = 500 // fan-out to first 500 only
		}

		var rows interface{ Next() bool }
		if limit == 0 {
			rows, _ = db.Pool.Query(ctx,
				`SELECT follower_id FROM follows WHERE following_id=$1`, payload.UserID)
		} else {
			rows, _ = db.Pool.Query(ctx,
				`SELECT follower_id FROM follows WHERE following_id=$1
				 ORDER BY created_at DESC LIMIT $2`, payload.UserID, limit)
		}

		pgRows := rows.(interface {
			Next() bool; Scan(...any) error; Close()
		})
		defer pgRows.Close()

		pipe := rdb.C.Pipeline()
		score := float64(time.Now().Unix())
		count := 0

		for pgRows.Next() {
			var followerID string
			pgRows.Scan(&followerID)
			feedKey := "feed:" + followerID
			pipe.ZAdd(ctx, feedKey, goredis.Z{Score: score, Member: payload.PostID})
			pipe.ZRemRangeByRank(ctx, feedKey, 0, -501) // max 500 items
			pipe.Expire(ctx, feedKey, 7*24*time.Hour)
			count++
			if count%200 == 0 {
				pipe.Exec(ctx)
				pipe = rdb.C.Pipeline()
			}
		}
		pipe.Exec(ctx)
		logger.Info("fan-out done",
			zap.String("postID", payload.PostID),
			zap.Int("followers", count))
	}()

	c.JSON(200, gin.H{"ok": true})
}

// ── REBUILD FEED from DB (cache miss fallback) ───────────────────
func rebuildFeed(userID string) {
	ctx := context.Background()
	rows, err := db.Pool.Query(ctx, `
		SELECT p.id, p.created_at
		FROM posts p
		JOIN follows f ON f.follower_id=$1 AND f.following_id=p.user_id
		WHERE p.hidden=FALSE AND p.created_at > NOW() - INTERVAL '7 days'
		ORDER BY p.created_at DESC LIMIT 200`, userID)
	if err != nil {
		return
	}
	defer rows.Close()

	pipe := rdb.C.Pipeline()
	feedKey := "feed:" + userID
	for rows.Next() {
		var postID string
		var createdAt time.Time
		rows.Scan(&postID, &createdAt)
		pipe.ZAdd(ctx, feedKey, goredis.Z{Score: float64(createdAt.Unix()), Member: postID})
	}
	pipe.Expire(ctx, feedKey, 7*24*time.Hour)
	pipe.Exec(ctx)
	logger.Info("feed rebuilt", zap.String("userID", userID))
}

// ── DB FEED FALLBACK ─────────────────────────────────────────────
func dbFeed(c *gin.Context, myID string, page, limit int) {
	offset := (page - 1) * limit
	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, p.caption,
		  COALESCE(p.likes_count,0), COALESCE(p.comments_count,0), p.created_at,
		  u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		  (SELECT COALESCE(json_agg(
		     json_build_object('url',m.url,'type',m.type) ORDER BY m.position
		   ),'[]'::json) FROM post_media m WHERE m.post_id=p.id),
		  EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1),
		  EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$1)
		FROM posts p JOIN users u ON u.id=p.user_id
		JOIN follows f ON f.follower_id=$1 AND f.following_id=p.user_id
		WHERE p.hidden=FALSE AND u.banned=FALSE
		  AND p.created_at > NOW() - INTERVAL '7 days'
		ORDER BY p.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, offset)
	if err != nil {
		c.JSON(500, gin.H{"success": false, "error": gin.H{"message": "feed unavailable"}}); return
	}
	defer rows.Close()
	posts := []gin.H{}
	for rows.Next() {
		var pid, cap, uid2, uname, uavatar string
		var likes, comms int
		var verified, liked, saved bool
		var createdAt time.Time
		var media interface{}
		rows.Scan(&pid, &cap, &likes, &comms, &createdAt, &uid2, &uname, &uavatar, &verified, &media, &liked, &saved)
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap, "likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": media, "liked": liked, "saved": saved,
			"user": gin.H{"_id": uid2, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	c.Header("X-Cache", "MISS")
	c.JSON(200, gin.H{"success": true, "posts": posts, "page": page, "limit": limit})
}

// ── middleware helpers ────────────────────────────────────────────
func uid(c *gin.Context) string { v, _ := c.Get("userID"); s, _ := v.(string); return s }
func toInt(s string, d int) int { if n, e := strconv.Atoi(s); e == nil && n > 0 { return n }; return d }

func reqLogger() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now(); c.Next()
		logger.Info("http",
			zap.String("method", c.Request.Method),
			zap.String("path", c.Request.URL.Path),
			zap.Int("status", c.Writer.Status()),
			zap.Duration("ms", time.Since(start)),
		)
	}
}

func recovery() gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				logger.Error("panic", zap.Any("err", err))
				c.AbortWithStatusJSON(500, gin.H{"success": false, "error": gin.H{"message": "internal error"}})
			}
		}()
		c.Next()
	}
}

func authMiddleware(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		if uid2 := c.GetHeader("X-User-ID"); uid2 != "" {
			c.Set("userID", uid2); c.Next(); return
		}
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(401, gin.H{"success": false, "error": gin.H{"message": "no token"}}); return
		}
		tok, err := gojwt.Parse(header[7:],
			func(t *gojwt.Token) (interface{}, error) { return []byte(secret), nil },
			gojwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !tok.Valid {
			c.AbortWithStatusJSON(401, gin.H{"success": false, "error": gin.H{"message": "invalid token"}}); return
		}
		claims := tok.Claims.(gojwt.MapClaims)
		c.Set("userID", claims["id"].(string)); c.Next()
	}
}

func rateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct{ count int; reset time.Time }
	store := map[string]*entry{}
	var mu sync.Mutex
	go func() {
		t := time.NewTicker(time.Minute)
		for range t.C {
			now := time.Now(); mu.Lock()
			for k, e := range store { if now.After(e.reset) { delete(store, k) } }
			mu.Unlock()
		}
	}()
	return func(c *gin.Context) {
		k := uid(c); if k == "" { k = c.ClientIP() }
		now := time.Now(); mu.Lock()
		e, ok := store[k]
		if !ok || now.After(e.reset) { store[k] = &entry{1, now.Add(window)}; mu.Unlock(); c.Next(); return }
		e.count++; n := e.count; mu.Unlock()
		if n > limit { c.Header("Retry-After","60"); c.AbortWithStatusJSON(429, gin.H{"success": false, "error": gin.H{"message": "rate limited"}}); return }
		c.Next()
	}
}

// pgxpool alias for clarity
var _ *pgxpool.Pool
