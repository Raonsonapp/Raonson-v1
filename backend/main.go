package main

import (
	"log"
	"net/http"
	"os"

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

	// Init services
	db.Init()
	mw.InitRedis()
	jobs.StartJobs()

	port := os.Getenv("PORT")
	if port == "" { port = "10000" }

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())

	// Security middleware (global)
	r.Use(mw.IPBlock())
	r.Use(mw.AntiSpam())

	// CORS
	r.Use(cors.New(cors.Config{
		AllowAllOrigins:  true,
		AllowMethods:     []string{"GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"},
		AllowHeaders:     []string{"Origin", "Content-Type", "Authorization"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
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

	// ── PUBLIC ───────────────────────────────────────────────────
	r.GET("/posts/preview/:id", handlers.PostPreview) // public HTML

	// ── WEBSOCKET ────────────────────────────────────────────────
	r.GET("/ws", sockets.Handler)

	auth  := mw.Auth()
	admin := mw.AdminOnly()
	rl100 := mw.RateLimit(500, 60) // 100 req/min
	rl20  := mw.RateLimit(20, 60)  // 20 req/min (uploads, auth)

	// ── AUTH ─────────────────────────────────────────────────────
	a := r.Group("/auth")
	{
		a.POST("/register",         rl20, handlers.Register)
		a.POST("/login",            rl20, handlers.Login)
		a.POST("/refresh",          handlers.RefreshToken)
		a.POST("/logout",           auth, handlers.Logout)
		a.POST("/forgot-password",  rl20, handlers.ForgotPassword)
		a.POST("/reset-password",   rl20, handlers.ResetPassword)
	}

	// ── USERS ────────────────────────────────────────────────────
	u := r.Group("/users", auth, rl100)
	{
		u.GET("/:id",           handlers.GetUserByID)
		u.PUT("/",              handlers.UpdateUser)
		u.DELETE("/",           handlers.DeleteUser)
		u.GET("/:id/posts",     handlers.GetUserPosts)
		u.GET("/:id/reels",     handlers.GetUserReels)
		u.GET("/:id/followers", handlers.GetFollowers)
		u.GET("/:id/following", handlers.GetFollowing)
	}

	// ── PROFILE ──────────────────────────────────────────────────
	p := r.Group("/profile", auth, rl100)
	{
		p.GET("/me",            handlers.GetMyProfile)
		p.GET("/notes/friends", handlers.GetFriendsNotes)
		p.POST("/note",         handlers.SetNote)
		p.PUT("/",              handlers.UpdateProfile)
		p.GET("/:username",     handlers.GetProfile)
	}

	// ── POSTS ────────────────────────────────────────────────────
	po := r.Group("/posts", auth, rl100)
	{
		po.POST("/",                           handlers.CreatePost)
		po.GET("/",                            handlers.GetFeed)
		po.GET("/feed",                        handlers.GetFeed)
		po.GET("/smart-feed",                  handlers.GetSmartFeed)
		po.GET("/:id",                         handlers.GetPost)
		po.DELETE("/:id",                      handlers.DeletePost)
		po.POST("/:id/like",                   handlers.TogglePostLike)
		po.POST("/:id/save",                   handlers.TogglePostSave)
	}

	// Post view tracking
	r.POST("/posts/view/:id", auth, handlers.TrackPostView)

	// ── COMMENTS ─────────────────────────────────────────────────
	// Comments — separate routes to avoid wildcard conflict
	r.GET("/comments/:id",       auth, rl100, handlers.GetComments)
	r.POST("/comments/:id",      auth, rl100, handlers.AddComment)
	r.DELETE("/comments/:id",    auth, rl100, handlers.DeleteComment)
	r.POST("/comments/:id/like", auth, rl100, handlers.ToggleCommentLike)

	// ── LIKES (generic) ──────────────────────────────────────────
	li := r.Group("/likes", auth, rl100)
	{
		li.POST("/",            handlers.LikeTarget)
		li.DELETE("/",          handlers.UnlikeTarget)
		li.GET("/:targetId",    handlers.GetLikes)
	}

	// ── FOLLOW ───────────────────────────────────────────────────
	fo := r.Group("/follow", auth, rl100)
	{
		fo.POST("/:id",                  handlers.FollowUser)
		fo.DELETE("/:id",                handlers.UnfollowUser)
		fo.GET("/:id/followers",         handlers.GetFollowers)
		fo.GET("/:id/following",         handlers.GetFollowing)
		fo.POST("/request/:id/accept",   handlers.AcceptRequest)
		fo.POST("/request/:id/reject",   handlers.RejectRequest)
	}
	r.POST("/unfollow/:id", auth, handlers.UnfollowUser)

	// ── REELS ────────────────────────────────────────────────────
	re := r.Group("/reels", auth, rl100)
	{
		re.GET("/",              handlers.GetReels)
		re.POST("/",             handlers.CreateReel)
		re.DELETE("/:id",        handlers.DeleteReel)
		re.POST("/:id/view",     handlers.AddReelView)
		re.POST("/:id/like",     handlers.ToggleReelLike)
		re.POST("/:id/save",     handlers.ToggleReelSave)
		re.GET("/:id/comments",  handlers.GetReelComments)
		re.POST("/:id/comments", handlers.AddReelComment)
	}

	// ── STORIES ──────────────────────────────────────────────────
	st := r.Group("/stories", auth, rl100)
	{
		st.GET("/",              handlers.GetStories)
		st.GET("/my",            handlers.GetMyStories)
		st.POST("/",             handlers.CreateStory)
		st.DELETE("/:id",        handlers.DeleteStory)
		st.POST("/:id/view",     handlers.ViewStory)
		st.POST("/:id/like",     handlers.LikeStory)
		st.GET("/:id/viewers",   handlers.GetStoryViewers)
	}

	// ── CHAT ─────────────────────────────────────────────────────
	ch := r.Group("/chat", auth, rl100)
	{
		ch.GET("/",                  handlers.GetChats)
		ch.GET("/with/:userId",      handlers.GetOrCreateChat)
		ch.GET("/:chatId/messages",  handlers.GetMessages)
		ch.POST("/:chatId/messages", handlers.SendMessage)
		ch.POST("/:chatId/read",     handlers.MarkChatRead)
		ch.DELETE("/messages/:id",   handlers.DeleteMessage)
	}

	// ── NOTIFICATIONS ─────────────────────────────────────────────
	no := r.Group("/notifications", auth, rl100)
	{
		no.GET("/",            handlers.GetNotifications)
		no.POST("/push-token", handlers.SavePushToken)
		no.POST("/read-all",   handlers.MarkAllNotifsRead)
		no.POST("/:id/read",   handlers.MarkNotifRead)
		no.DELETE("/:id",      handlers.DeleteNotification)
	}

	// ── SEARCH ────────────────────────────────────────────────────
	se := r.Group("/search", auth, rl100)
	{
		se.GET("/",      handlers.Search)
		se.GET("/users", handlers.SearchUsers)
	}

	// ── EXPLORE ───────────────────────────────────────────────────
	r.GET("/explore", auth, rl100, handlers.ExploreGrid)

	// ── UPLOAD (Cloudflare R2) ────────────────────────────────────
	r.POST("/upload",        auth, rl20, mw.AntiAbuse("upload", 50, 3600), handlers.UploadToR2)
	r.POST("/upload/avatar", auth, rl20, handlers.UploadToR2)
	r.POST("/upload/video",  auth, rl20, handlers.UploadToR2)
	r.POST("/media/upload",  auth, rl20, handlers.UploadToR2)

	// ── ADMIN ──────────────────────────────────────────────────────
	ad := r.Group("/admin", auth, admin)
	{
		ad.GET("/stats",       handlers.AdminStats)
		ad.POST("/ban/:id",    handlers.BanUser)
		ad.POST("/unban/:id",  handlers.UnbanUser)
	}

	log.Printf("🚀 Raonson Go | Port:%s | PostgreSQL+R2+Redis", port)
	r.Run(":" + port)
}
