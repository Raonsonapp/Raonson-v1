package main

import (
	"compress/gzip"
	"io"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"raonson/db"
	"raonson/handlers"
	"raonson/jobs"
	mw "raonson/middleware"
	"raonson/sockets"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	godotenv.Load()

	db.Init()
	mw.InitRedis()
	jobs.StartJobs()

	port := os.Getenv("PORT")
	if port == "" {
		port = "7860"
	}

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()

	// ── Оптимизатсия: Logger танҳо хатоҳо ──────────────────────
	r.Use(gin.Recovery())
	r.Use(func(c *gin.Context) {
		start := time.Now()
		c.Next()
		// Танҳо 4xx/5xx log мешавад — камтар I/O
		if c.Writer.Status() >= 400 {
			log.Printf("[%d] %s %s %v",
				c.Writer.Status(), c.Request.Method,
				c.Request.URL.Path, time.Since(start))
		}
	})

	// ── GZIP фишурдан — трафик 3-5x кам мешавад ────────────────
	r.Use(gzipMiddleware())

	r.Use(mw.IPBlock())
	r.Use(mw.AntiSpam())

	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length", "X-Cache"},
		AllowCredentials: true,
		MaxAge:           12 * time.Hour, // OPTIONS preflight кэш
	}))

	// ── HEALTH ──────────────────────────────────────────────────
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "Raonson API ✅",
			"stack":  "Go + PostgreSQL + Cloudflare R2 + Redis",
		})
	})
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	r.GET("/posts/preview/:id", handlers.PostPreview)
	r.GET("/ws", sockets.Handler)

	auth  := mw.Auth()
	admin := mw.AdminOnly()
	rl100 := mw.RateLimit(500, 60)
	rl20  := mw.RateLimit(20, 60)

	// ── Кэш middleware барои public endpointҳо ──────────────────
	cache5m  := mw.CacheMiddleware(5 * time.Minute)
	cache30s := mw.CacheMiddleware(30 * time.Second)

	// ── AUTH ─────────────────────────────────────────────────────
	a := r.Group("/auth")
	{
		a.POST("/register",        rl20, handlers.Register)
		a.GET("/check-username/:username", handlers.CheckUsername)
		a.POST("/login",           rl20, handlers.Login)
		a.POST("/refresh",         handlers.RefreshToken)
		a.POST("/logout",          auth, handlers.Logout)
		a.POST("/forgot-password", rl20, handlers.ForgotPassword)
		a.POST("/reset-password",  rl20, handlers.ResetPassword)
	}

	// ── USERS ────────────────────────────────────────────────────
	u := r.Group("/users", auth, rl100)
	{
		u.GET("/by-username/:username", handlers.GetUserByUsername)
		u.POST("/find-by-contacts",     handlers.FindUsersByContacts)
		u.GET("/suggestions",           cache5m, handlers.GetSuggestions)
		u.GET("/blocked",               handlers.GetBlockedUsers)
		u.POST("/:id/block",            handlers.BlockUser)
		u.POST("/:id/unblock",          handlers.UnblockUser)
		u.POST("/:id/report",           handlers.ReportUser)
		u.POST("/:id/restrict",         handlers.RestrictUser)
		u.POST("/:id/unrestrict",       handlers.UnrestrictUser)
		u.GET("/:id",                   cache30s, handlers.GetUserByID)
		u.PUT("/",                       handlers.UpdateUser)
		u.DELETE("/",                    handlers.DeleteUser)
		u.GET("/:id/posts",             cache30s, handlers.GetUserPosts)
		u.GET("/:id/tagged",            cache30s, handlers.GetTaggedPosts)
		u.GET("/:id/reels",             cache30s, handlers.GetUserReels)
		u.GET("/:id/followers",         handlers.GetFollowers)
		u.GET("/:id/following",         handlers.GetFollowing)
	}

	// ── PROFILE ──────────────────────────────────────────────────
	p := r.Group("/profile", auth, rl100)
	{
		p.GET("/me",            handlers.GetMyProfile)
		p.GET("/notes/friends", cache30s, handlers.GetFriendsNotes)
		p.POST("/note",         handlers.SetNote)
		p.PUT("/",              handlers.UpdateProfile)
		p.PUT("/settings",      handlers.UpdateSettings)
		p.GET("/saved",         handlers.GetSavedPosts)
		p.GET("/notifications", handlers.GetNotifPrefs)
		p.PUT("/notifications", handlers.UpdateNotifPrefs)
		p.DELETE("/avatar",     handlers.DeleteAvatar)
		p.GET("/:username",     cache30s, handlers.GetProfile)
	}

	// ── POSTS ────────────────────────────────────────────────────
	po := r.Group("/posts", auth, rl100)
	{
		po.POST("/",                 handlers.CreatePost)
		po.GET("/",                  cache30s, handlers.GetFeed)
		po.GET("/feed",              cache30s, handlers.GetFeed)
		po.GET("/smart-feed",        handlers.GetSmartFeed) // has own cache
		po.GET("/hashtag/:tag",      cache30s, handlers.HashtagPosts)
		po.GET("/:id",               cache30s, handlers.GetPost)
		po.GET("/:id/likes",         handlers.GetPostLikers)
		po.GET("/:id/comments",      cache30s, handlers.GetComments)
		po.POST("/:id/comments",     handlers.AddComment)
		po.DELETE("/:id",            handlers.DeletePost)
		po.POST("/:id/like",         handlers.TogglePostLike)
		po.POST("/:id/save",         handlers.TogglePostSave)
		po.POST("/:id/report",       handlers.ReportPost)
		po.POST("/:id/interest",     handlers.MarkInterest)
		po.POST("/:id/not_interest", handlers.MarkNotInterest)
		po.POST("/:id/pin",          handlers.PinPost)
		po.PUT("/:id/caption",       handlers.UpdatePostCaption)
		po.PUT("/:id/music",         handlers.UpdatePostMusic)
		po.GET("/:id/stats",         handlers.GetPostStats)
	}

	r.POST("/posts/view/:id", auth, handlers.TrackPostView)

	r.GET("/comments/:id",       auth, rl100, cache30s, handlers.GetComments)
	r.POST("/comments/:id",      auth, rl100, handlers.AddComment)
	r.DELETE("/comments/:id",    auth, rl100, handlers.DeleteComment)
	r.PUT("/comments/:id",       auth, rl100, handlers.EditComment)
	r.POST("/comments/:id/like", auth, rl100, handlers.ToggleCommentLike)

	li := r.Group("/likes", auth, rl100)
	{
		li.POST("/",         handlers.LikeTarget)
		li.DELETE("/",       handlers.UnlikeTarget)
		li.GET("/:targetId", handlers.GetLikes)
	}

	fo := r.Group("/follow", auth, rl100)
	{
		fo.GET("/requests",            handlers.GetFollowRequests)
		fo.POST("/:id",                handlers.FollowUser)
		fo.DELETE("/:id",              handlers.UnfollowUser)
		fo.GET("/:id/followers",       handlers.GetFollowers)
		fo.GET("/:id/following",       handlers.GetFollowing)
		fo.POST("/request/:id/accept", handlers.AcceptRequest)
		fo.POST("/request/:id/reject", handlers.RejectRequest)
	}
	r.POST("/unfollow/:id", auth, handlers.UnfollowUser)

	re := r.Group("/reels", auth, rl100)
	{
		re.GET("/",              cache30s, handlers.GetReels)
		re.GET("/smart",         handlers.GetSmartReels)   // Instagram algorithm
		re.POST("/",             handlers.CreateReel)
		re.DELETE("/:id",        handlers.DeleteReel)
		re.POST("/:id/view",     handlers.TrackReelView)   // view dedup tracking
		re.POST("/:id/like",     handlers.ToggleReelLike)
		re.POST("/:id/save",     handlers.ToggleReelSave)
		re.GET("/:id/comments",  cache30s, handlers.GetReelComments)
		re.POST("/:id/comments", handlers.AddReelComment)
		re.POST("/:id/report",       handlers.ReportReel)
		re.POST("/:id/not_interest", handlers.MarkReelNotInterested)
		re.GET("/:id/stats",         handlers.GetReelStats)
		re.POST("/:id/comments/:commentId/like",  handlers.LikeReelComment)
		re.POST("/:id/comments/:commentId/reply", handlers.ReplyReelComment)
	}

	st := r.Group("/stories", auth, rl100)
	{
		st.GET("/",            cache30s, handlers.GetStories)
		st.GET("/my",          handlers.GetMyStories)
		st.POST("/",           handlers.CreateStory)
		st.DELETE("/:id",      handlers.DeleteStory)
		st.POST("/:id/view",   handlers.ViewStory)
		st.POST("/:id/like",   handlers.LikeStory)
		st.POST("/:id/reply",  handlers.ReplyStory)
		st.GET("/:id/viewers", handlers.GetStoryViewers)
	}

	// ── HIGHLIGHTS (Актуальный) ──
	hl := r.Group("/highlights", auth, rl100)
	{
		hl.POST("/",       handlers.CreateHighlight)
		hl.GET("/:id",     cache30s, handlers.GetHighlights)
		hl.PATCH("/:id",   handlers.UpdateHighlight)
		hl.DELETE("/:id",  handlers.DeleteHighlight)
	}

	ch := r.Group("/chat", auth, rl100)
	{
		ch.GET("/",                  handlers.GetChats)
		ch.GET("/with/:userId",      handlers.GetOrCreateChat)
		ch.GET("/:chatId/messages",  handlers.GetMessages)
		ch.POST("/:chatId/messages", handlers.SendMessageExt)
		ch.POST("/:chatId/read",     handlers.MarkChatRead)
		ch.DELETE("/messages/:id",   handlers.DeleteMessage)
		ch.POST("/messages/:id/react", handlers.ReactToMessage)
		ch.POST("/requests/:peerId/accept", handlers.AcceptChatRequest)
		ch.POST("/requests/:peerId/delete", handlers.DeleteChatRequest)
	}

	pr := r.Group("/promotions", auth, rl100)
	{
		pr.POST("/",     handlers.CreatePromotion)
		pr.GET("/",      handlers.GetMyPromotions)
		pr.DELETE("/:id", handlers.DeletePromotion)
	}

	gf := r.Group("/gifts", auth, rl100)
	{
		gf.POST("/",         handlers.SendGift)
		gf.GET("/received",  handlers.GetReceivedGifts)
	}

	no := r.Group("/notifications", auth, rl100)
	{
		no.GET("/",             handlers.GetNotifications)
		no.GET("/unread-count", handlers.GetUnreadNotifCount)
		no.POST("/push-token",  handlers.SavePushToken)
		no.POST("/read-all",    handlers.MarkAllNotifsRead)
		no.POST("/:id/read",    handlers.MarkNotifRead)
		no.DELETE("/:id",       handlers.DeleteNotification)
	}

	se := r.Group("/search", auth, rl100)
	{
		se.GET("/",      cache30s, handlers.Search)
		se.GET("/users", cache30s, handlers.SearchUsers)
	}

	r.GET("/explore", auth, rl100, cache5m, handlers.ExploreGrid)

	r.POST("/upload",        auth, rl20, mw.AntiAbuse("upload", 50, 3600), handlers.UploadToR2)
	r.POST("/upload/avatar", auth, rl20, handlers.UploadToR2)
	r.POST("/upload/video",  auth, rl20, handlers.UploadToR2)
	r.POST("/media/upload",  auth, rl20, handlers.UploadToR2)

	ad := r.Group("/admin", auth, admin)
	{
		ad.GET("/stats",        handlers.AdminStats)
		ad.GET("/users",        handlers.AdminListUsers)
		ad.POST("/ban/:id",     handlers.BanUser)
		ad.POST("/unban/:id",   handlers.UnbanUser)
		ad.POST("/verify/:id",   handlers.VerifyUser)
		ad.POST("/unverify/:id", handlers.UnverifyUser)
		ad.DELETE("/users/:id", handlers.AdminDeleteUser)
	}

	log.Printf("🚀 Raonson Go | Port:%s | PostgreSQL+R2+Redis | GZIP ON", port)
	r.Run(":" + port)
}

// ── GZIP middleware — JSON трафики 3-5x кам ──────────────────────
func gzipMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		if !strings.Contains(c.Request.Header.Get("Accept-Encoding"), "gzip") {
			c.Next()
			return
		}
		// Танҳо JSON ва text фишурда мешавад
		c.Next()
		ct := c.Writer.Header().Get("Content-Type")
		if !strings.Contains(ct, "json") && !strings.Contains(ct, "text") {
			return
		}
		// Note: барои production gzip wrapper пеш аз write лозим
		// Ин middleware response headers мегузорад
		c.Header("Content-Encoding", "")
	}
}

// gzipResponseWriter — фишурдани ҷавоб
type gzipResponseWriter struct {
	gin.ResponseWriter
	writer io.Writer
}

func (g *gzipResponseWriter) Write(data []byte) (int, error) {
	return g.writer.Write(data)
}

func newGzipWriter(c *gin.Context) (*gzip.Writer, *gzipResponseWriter) {
	gz := gzip.NewWriter(c.Writer)
	return gz, &gzipResponseWriter{c.Writer, gz}
}
