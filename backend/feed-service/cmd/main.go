package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
	"github.com/redis/go-redis/v9"
)

// ── globals ───────────────────────────────────────────────────────
var (
	DB  *pgxpool.Pool
	RDB *redis.Client
	bg  = context.Background()
)

// ── models ────────────────────────────────────────────────────────
type PostSummary struct {
	ID            string      `json:"_id"`
	Caption       string      `json:"caption"`
	LikesCount    int         `json:"likesCount"`
	CommentsCount int         `json:"commentsCount"`
	CreatedAt     time.Time   `json:"createdAt"`
	Media         interface{} `json:"media"`
	User          FeedUser    `json:"user"`
}

type FeedUser struct {
	ID       string `json:"_id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
	Verified bool   `json:"verified"`
}

// ── main ──────────────────────────────────────────────────────────
func main() {
	godotenv.Load()
	initDB()
	initRedis()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "OPTIONS"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		AllowCredentials: true,
	}))

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"service": "feed-service", "status": "ok"})
	})

	auth := authMiddleware()
	rl := rateLimit(120, time.Minute)

	// Public feed endpoints
	r.GET("/feed", auth, rl, getFeed)
	r.GET("/feed/explore", auth, rl, getExploreFeed)

	// Internal: called by post-service when new post created
	r.POST("/internal/fanout", fanOutHandler)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8003"
	}
	log.Printf("📰 feed-service :%s", port)
	r.Run(":" + port)
}

// ── GET FEED — Redis ZSET, O(log N) ──────────────────────────────
func getFeed(c *gin.Context) {
	myID := uid(c)
	page := toInt(c.Query("page"), 1)
	limit := toInt(c.Query("limit"), 20)

	start := int64((page - 1) * limit)
	stop := start + int64(limit) - 1

	feedKey := "feed:" + myID
	postIDs := ZRevRange(feedKey, start, stop)

	if len(postIDs) == 0 {
		// Cache miss — rebuild async, return from DB
		go rebuildFeed(myID)
		dbFeed(c, myID, page, limit)
		return
	}

	// Batch fetch post data from Redis
	pipe := RDB.Pipeline()
	cmds := make([]*redis.StringCmd, len(postIDs))
	likedCmds := make([]*redis.BoolCmd, len(postIDs))
	savedCmds := make([]*redis.BoolCmd, len(postIDs))
	for i, id := range postIDs {
		cmds[i] = pipe.Get(bg, "post:"+id)
		likedCmds[i] = pipe.SIsMember(bg, "post:likes:"+id, myID)
		savedCmds[i] = pipe.SIsMember(bg, "post:saves:"+id, myID)
	}
	pipe.Exec(bg)

	posts := make([]map[string]interface{}, 0, len(postIDs))
	for i, cmd := range cmds {
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
	c.JSON(http.StatusOK, gin.H{
		"posts": posts,
		"page":  page,
		"limit": limit,
	})
}

// ── GET EXPLORE — top posts ───────────────────────────────────────
func getExploreFeed(c *gin.Context) {
	cacheKey := "explore:grid"
	if data, err := RDB.Get(bg, cacheKey).Bytes(); err == nil {
		c.Header("X-Cache", "HIT")
		c.Data(http.StatusOK, "application/json", data)
		return
	}

	rows, err := DB.Query(bg, `
		SELECT p.id,
		  (SELECT url FROM post_media WHERE post_id=p.id ORDER BY position LIMIT 1) AS thumb,
		  COALESCE(p.likes_count,0), COALESCE(p.comments_count,0)
		FROM posts p
		JOIN users u ON u.id=p.user_id
		WHERE u.banned=FALSE AND p.hidden=FALSE
		  AND p.created_at > NOW() - INTERVAL '7 days'
		ORDER BY p.likes_count DESC
		LIMIT 60`)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "explore failed"})
		return
	}
	defer rows.Close()

	posts := []gin.H{}
	for rows.Next() {
		var id, thumb string
		var likes, comms int
		rows.Scan(&id, &thumb, &likes, &comms)
		posts = append(posts, gin.H{
			"_id": id, "thumb": thumb,
			"likesCount": likes, "commentsCount": comms,
		})
	}
	result := gin.H{"posts": posts}
	if b, err := json.Marshal(result); err == nil {
		RDB.Set(bg, cacheKey, b, 5*time.Minute)
	}
	c.JSON(http.StatusOK, result)
}

// ── FAN-OUT ON WRITE — called by post-service ────────────────────
//
// Algorithm:
//  1. Store post JSON in Redis (post:{id})
//  2. Fetch all followers from DB
//  3. ZADD feed:{followerID} score=timestamp postID
//  4. Keep max 500 items per feed
func fanOutHandler(c *gin.Context) {
	var payload struct {
		PostID string      `json:"postID"`
		UserID string      `json:"userID"`
		Post   interface{} `json:"post"`
		Score  float64     `json:"score"`
	}
	if err := c.ShouldBindJSON(&payload); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Async — respond immediately
	go func() {
		// 1. Cache post data
		b, _ := json.Marshal(payload.Post)
		RDB.Set(bg, "post:"+payload.PostID, b, 7*24*time.Hour)

		// 2. Fetch followers
		rows, err := DB.Query(bg,
			`SELECT follower_id FROM follows WHERE following_id=$1`, payload.UserID)
		if err != nil {
			log.Printf("[fan-out] query error: %v", err)
			return
		}
		defer rows.Close()

		pipe := RDB.Pipeline()
		score := float64(time.Now().Unix())
		count := 0

		for rows.Next() {
			var followerID string
			rows.Scan(&followerID)

			feedKey := "feed:" + followerID
			pipe.ZAdd(bg, feedKey, redis.Z{Score: score, Member: payload.PostID})
			pipe.ZRemRangeByRank(bg, feedKey, 0, -501) // keep max 500
			pipe.Expire(bg, feedKey, 7*24*time.Hour)

			count++
			if count%200 == 0 {
				pipe.Exec(bg)
				pipe = RDB.Pipeline()
			}
		}
		pipe.Exec(bg)
		log.Printf("[fan-out] post=%s distributed to %d followers", payload.PostID, count)
	}()

	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// ── REBUILD FEED — DB fallback ────────────────────────────────────
func rebuildFeed(userID string) {
	rows, err := DB.Query(bg, `
		SELECT p.id, p.created_at
		FROM posts p
		JOIN follows f ON f.follower_id=$1 AND f.following_id=p.user_id
		WHERE p.hidden=FALSE
		  AND p.created_at > NOW() - INTERVAL '7 days'
		ORDER BY p.created_at DESC
		LIMIT 200`, userID)
	if err != nil {
		return
	}
	defer rows.Close()

	pipe := RDB.Pipeline()
	feedKey := "feed:" + userID
	for rows.Next() {
		var postID string
		var createdAt time.Time
		rows.Scan(&postID, &createdAt)
		pipe.ZAdd(bg, feedKey, redis.Z{
			Score:  float64(createdAt.Unix()),
			Member: postID,
		})
	}
	pipe.Expire(bg, feedKey, 7*24*time.Hour)
	pipe.Exec(bg)
	log.Printf("[feed] rebuilt for user=%s", userID)
}

// ── DB FEED FALLBACK ──────────────────────────────────────────────
func dbFeed(c *gin.Context, myID string, page, limit int) {
	offset := (page - 1) * limit
	rows, err := DB.Query(bg, `
		SELECT p.id, p.caption,
		  COALESCE(p.likes_count,0), COALESCE(p.comments_count,0), p.created_at,
		  u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		  (SELECT COALESCE(json_agg(
		     json_build_object('url',m.url,'type',m.type)
		     ORDER BY m.position),'[]'::json)
		   FROM post_media m WHERE m.post_id=p.id) AS media,
		  EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1) AS liked,
		  EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$1) AS saved
		FROM posts p
		JOIN users u ON u.id=p.user_id
		JOIN follows f ON f.follower_id=$1 AND f.following_id=p.user_id
		WHERE p.hidden=FALSE AND u.banned=FALSE
		  AND p.created_at > NOW() - INTERVAL '7 days'
		ORDER BY p.created_at DESC
		LIMIT $2 OFFSET $3`, myID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "feed unavailable"})
		return
	}
	defer rows.Close()

	posts := []gin.H{}
	for rows.Next() {
		var pid, cap, uid2, uname, uavatar string
		var likes, comms int
		var verified, liked, saved bool
		var createdAt time.Time
		var media interface{}
		rows.Scan(&pid, &cap, &likes, &comms, &createdAt,
			&uid2, &uname, &uavatar, &verified,
			&media, &liked, &saved)
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap,
			"likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt,
			"media":     media,
			"liked":     liked,
			"saved":     saved,
			"user": gin.H{
				"_id": uid2, "username": uname,
				"avatar": uavatar, "verified": verified,
			},
		})
	}
	c.Header("X-Cache", "MISS")
	c.JSON(http.StatusOK, gin.H{"posts": posts, "page": page, "limit": limit})
}

// ── HELPERS ───────────────────────────────────────────────────────
func uid(c *gin.Context) string {
	v, _ := c.Get("userID")
	s, _ := v.(string)
	return s
}

func toInt(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil && n > 0 {
		return n
	}
	return def
}

func ZRevRange(key string, start, stop int64) []string {
	v, _ := RDB.ZRevRange(bg, key, start, stop).Result()
	return v
}

func authMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if id := c.GetHeader("X-User-ID"); id != "" {
			c.Set("userID", id)
			c.Next()
			return
		}
		header := c.GetHeader("Authorization")
		if header == "" || !strings.HasPrefix(header, "Bearer ") {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "No token"})
			c.Abort()
			return
		}
		secret := os.Getenv("JWT_SECRET")
		if secret == "" {
			secret = "raonson-secret-change-in-prod"
		}
		tok, err := jwt.Parse(header[7:],
			func(t *jwt.Token) (interface{}, error) { return []byte(secret), nil },
			jwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !tok.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
			c.Abort()
			return
		}
		claims := tok.Claims.(jwt.MapClaims)
		c.Set("userID", claims["id"].(string))
		c.Next()
	}
}

func rateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type entry struct {
		count int
		reset time.Time
	}
	store := map[string]*entry{}
	var mu sync.Mutex
	return func(c *gin.Context) {
		k := uid(c)
		if k == "" {
			k = c.ClientIP()
		}
		now := time.Now()
		mu.Lock()
		e, ok := store[k]
		if !ok || now.After(e.reset) {
			store[k] = &entry{1, now.Add(window)}
			mu.Unlock()
			c.Next()
			return
		}
		e.count++
		n := e.count
		mu.Unlock()
		if n > limit {
			c.JSON(http.StatusTooManyRequests, gin.H{"message": "Too many requests"})
			c.Abort()
			return
		}
		c.Next()
	}
}

func initDB() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL not set")
	}
	cfg, _ := pgxpool.ParseConfig(dsn)
	cfg.MaxConns = 15
	cfg.MinConns = 2
	cfg.MaxConnLifetime = 30 * time.Minute
	var err error
	DB, err = pgxpool.NewWithConfig(bg, cfg)
	if err != nil {
		log.Fatalf("DB init: %v", err)
	}
	if err = DB.Ping(bg); err != nil {
		log.Fatalf("DB ping: %v", err)
	}
	log.Println("✅ PostgreSQL connected")
}

func initRedis() {
	url := os.Getenv("REDIS_URL")
	if url == "" {
		url = "redis://localhost:6379/0"
	}
	opt, _ := redis.ParseURL(url)
	opt.PoolSize = 15
	RDB = redis.NewClient(opt)
	if err := RDB.Ping(bg).Err(); err != nil {
		log.Fatalf("Redis ping: %v", err)
	}
	log.Println("✅ Redis connected")
}
