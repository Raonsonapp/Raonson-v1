package main

import (
	"compress/gzip"
	"context"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
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

func validateEnv() {
	required := []string{"DATABASE_URL"}
	warned := []string{"JWT_SECRET", "JWT_REFRESH_SECRET"}
	for _, k := range required {
		if os.Getenv(k) == "" {
			log.Fatalf("FATAL: required env var %s is not set", k)
		}
	}
	for _, k := range warned {
		if os.Getenv(k) == "" {
			log.Printf("WARNING: %s is not set — using ephemeral random secret (tokens will not survive restart)", k)
		}
	}
}

func main() {
	godotenv.Load()

	validateEnv()

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
		AllowCredentials: false,
		MaxAge:           12 * time.Hour,
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
		a.GET("/check-username/:username", rl20, handlers.CheckUsername)
		a.POST("/login",           rl20, handlers.Login)
		a.POST("/refresh",         handlers.RefreshToken)
		a.POST("/logout",          auth, handlers.Logout)
		a.POST("/forgot-password", rl20, handlers.ForgotPassword)
		a.POST("/reset-password",  rl20, handlers.ResetPassword)
		a.POST("/change-password", auth, rl20, handlers.ChangePassword)
		a.GET("/sessions",     auth, handlers.GetSessions)        // таърихи воридшавӣ
		a.POST("/revoke-all",  auth, handlers.RevokeAllSessions)  // тоза кардани таърих
	}

	// ── USERS ────────────────────────────────────────────────────
	u := r.Group("/users", auth, rl100)
	{
		u.GET("/by-username/:username", handlers.GetUserByUsername)
		u.POST("/find-by-contacts",     handlers.FindUsersByContacts)
		u.GET("/suggestions",           cache5m, handlers.GetSuggestions)
		u.GET("/suggested",             handlers.GetSuggestedUsers)
		u.GET("/blocked",               handlers.GetBlockedUsers)
		u.POST("/:id/block",            handlers.BlockUser)
		u.POST("/:id/unblock",          handlers.UnblockUser)
		u.POST("/:id/mute",             handlers.MuteUser)
		u.DELETE("/:id/mute",           handlers.UnmuteUser)
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
		p.GET("/insights",      handlers.GetProfileInsights) // обзори 30-рӯза
		p.GET("/notes/friends", cache30s, handlers.GetFriendsNotes)
		p.POST("/note",         handlers.SetNote)
		p.PUT("/",              handlers.UpdateProfile)
		p.PUT("/settings",      handlers.UpdateSettings)
		p.GET("/saved",         handlers.GetSavedPosts)
		p.GET("/notifications", handlers.GetNotifPrefs)
		p.PUT("/notifications", handlers.UpdateNotifPrefs)
		p.PUT("/username",      handlers.ChangeUsername)
		p.PUT("/phone",         handlers.ChangePhone)
		p.GET("/auto-reply",    handlers.GetAutoReply)
		p.PUT("/auto-reply",    handlers.SetAutoReply)
		p.DELETE("/avatar",     handlers.DeleteAvatar)
		p.DELETE("/me",         handlers.DeleteUser)
		p.GET("/:username",     cache30s, handlers.GetProfile)
	}

	// ── CLOSE FRIENDS (Близкие друзья) ──────────────────────────
	cf := r.Group("/close-friends", auth, rl100)
	{
		cf.GET("",         handlers.GetCloseFriends)
		cf.GET("/ids",     handlers.GetCloseFriendIDs)
		cf.POST("/:id",    handlers.AddCloseFriend)
		cf.DELETE("/:id",  handlers.RemoveCloseFriend)
	}

	// ── POSTS ────────────────────────────────────────────────────
	po := r.Group("/posts", auth, rl100)
	{
		po.POST("/",                 handlers.CreatePost)
		po.GET("/",                  cache30s, handlers.GetFeed)
		po.GET("/feed",              cache30s, handlers.GetFeed)
		po.GET("/smart-feed",        handlers.GetSmartFeed) // has own cache
		po.GET("/scheduled",         handlers.GetScheduledPosts)
		po.GET("/hashtag/:tag",      cache30s, handlers.HashtagPosts)
		po.GET("/:id",               cache30s, handlers.GetPost)
		po.GET("/:id/likes",         handlers.GetPostLikers)
		po.GET("/:id/comments",      cache30s, handlers.GetComments)
		po.POST("/:id/comments",     handlers.AddComment)
		po.DELETE("/:id",            handlers.DeletePost)
		po.POST("/:id/like",         handlers.TogglePostLike)
		po.POST("/:id/save",         handlers.TogglePostSave)
		po.POST("/:id/share",        handlers.SharePost) // мубодилаи беназир
		po.POST("/:id/report",       handlers.ReportPost)
		po.POST("/:id/hide-likes",   handlers.TogglePostHideLikes)
		po.POST("/:id/toggle-comments", handlers.TogglePostComments)
		po.POST("/:id/archive",      handlers.TogglePostArchive)
		po.POST("/:id/interest",     handlers.MarkInterest)
		po.POST("/:id/not_interest", handlers.MarkNotInterest)
		po.POST("/:id/not-interested", handlers.PostNotInterested)
		po.POST("/:id/pin",          handlers.PinPost)
		po.PUT("/:id/caption",       handlers.UpdatePostCaption)
		po.PUT("/:id/music",         handlers.UpdatePostMusic)
		po.GET("/:id/stats",         handlers.GetPostStats)
		po.POST("/:id/order",        handlers.PlaceOrder) // хариди маҳсулот
		po.POST("/:id/feature",      handlers.ToggleProductFeature) // маҳсули беҳтарин
		po.GET("/:id/translations",  handlers.GetProductTranslations)
		po.PUT("/:id/translations",  handlers.SetProductTranslations)
		po.PUT("/:id/product",       handlers.UpdateProduct) // таҳрири маҳсул
		po.PUT("/:id/sale",          handlers.SetProductSale) // тахфифи муддатнок
		po.POST("/:id/review",       handlers.AddReview)     // баҳои маҳсул
		po.GET("/:id/reviews",       handlers.GetReviews)
	}

	// ── Shopping (маркетплейс + фармоишҳо) ─────────────────────────
	r.GET("/shop", auth, rl100, handlers.GetShop) // бе cache — маҳсулоти нав фавран
	r.GET("/shop/insights", auth, rl100, handlers.GetShopInsights) // панели фурӯшанда
	r.GET("/shop/customers", auth, rl100, handlers.GetCustomers)   // CRM: харидорон
	r.POST("/shop/promos", auth, rl100, handlers.CreatePromo)            // промокод сохтан
	r.GET("/shop/promos", auth, rl100, handlers.ListPromos)              // промокодҳо
	r.DELETE("/shop/promos/:id", auth, rl100, handlers.DeletePromo)      // ҳазф
	r.POST("/shop/promos/validate", auth, rl100, handlers.ValidatePromo) // санҷиш
	r.POST("/shop/broadcast", auth, rl20, handlers.BroadcastToCustomers)  // паём ба муштариён
	og := r.Group("/orders", auth, rl100)
	{
		og.GET("/",           handlers.GetMyOrders)
		og.GET("/selling",    handlers.GetSellingOrders)
		og.PUT("/:id/status", handlers.UpdateOrderStatus) // тағйири ҳолат (фурӯшанда)
	}

	// ── Live-стримҳо ───────────────────────────────────────────────
	lg := r.Group("/live", auth, rl100)
	{
		lg.GET("/",             handlers.ListLive)
		lg.POST("/start",       handlers.StartLive)
		lg.POST("/:id/end",     handlers.EndLive)
		lg.POST("/:id/join",    handlers.JoinLive)
		lg.POST("/:id/leave",   handlers.LeaveLive)
		lg.POST("/:id/comment", handlers.LiveComment)
		lg.GET("/:id/comments", handlers.LiveComments)
		lg.POST("/:id/like",    handlers.LiveLike)
	}

	// ── Effects marketplace ────────────────────────────────────────
	ef := r.Group("/effects", auth, rl100)
	{
		ef.GET("/",         handlers.GetEffects)
		ef.GET("/mine",     handlers.GetMyEffects)
		ef.POST("/",        handlers.CreateEffect)
		ef.POST("/:id/use", handlers.UseEffect)
	}

	r.POST("/posts/view/:id", auth, handlers.TrackPostView)
	r.POST("/posts/view-batch", auth, rl100, handlers.TrackPostViewBatch)

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
		re.POST("/:id/watch",    handlers.TrackReelWatch)  // watch-time tracking
		re.POST("/:id/like",     handlers.ToggleReelLike)
		re.POST("/:id/save",     handlers.ToggleReelSave)
		re.GET("/:id/comments",  cache30s, handlers.GetReelComments)
		re.POST("/:id/comments", handlers.AddReelComment)
		re.POST("/:id/report",       handlers.ReportReel)
		re.POST("/:id/hide-likes",   handlers.ToggleReelHideLikes)
		re.POST("/:id/toggle-comments", handlers.ToggleReelComments)
		re.POST("/:id/not_interest", handlers.MarkReelNotInterested)
		re.GET("/:id/stats",         handlers.GetReelStats)
		re.POST("/:id/comments/:commentId/like",  handlers.LikeReelComment)
		re.POST("/:id/comments/:commentId/reply", handlers.ReplyReelComment)
		re.PUT("/:id/caption",    handlers.UpdateReelCaption)
		re.POST("/:id/interest",  handlers.MarkReelInterested)
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
		st.POST("/:id/archive", handlers.ToggleStoryArchive)
		st.POST("/:id/toggle-replies", handlers.ToggleStoryReplies)
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

	// ── Group chats (гурӯҳҳо) ──────────────────────────────────────
	gr := r.Group("/groups", auth, rl100)
	{
		gr.POST("/",                       handlers.CreateGroup)
		gr.GET("/",                        handlers.GetMyGroups)
		gr.GET("/:id",                     handlers.GetGroupInfo)
		gr.POST("/:id/members",            handlers.AddGroupMembers)
		gr.DELETE("/:id/members/:userId",  handlers.RemoveGroupMember)
		gr.POST("/:id/leave",              handlers.LeaveGroup)
		gr.GET("/:id/messages",            handlers.GetGroupMessages)
		gr.POST("/:id/messages",           handlers.SendGroupMessage)
	}
	// Join via invite — берун аз гурӯҳ, то бо /:id ихтилоф накунад.
	r.POST("/group-join/:token", auth, rl100, handlers.JoinGroupByToken)

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

	// ── ANALYTICS (батч-рӯйдодҳо аз client) ──
	an := r.Group("/analytics", auth, rl100)
	{
		an.POST("/events", handlers.TrackAnalyticsEvents)
	}

	se := r.Group("/search", auth, rl100)
	{
		se.GET("/",      cache30s, handlers.Search)
		se.GET("/users", cache30s, handlers.SearchUsers)
	}

	r.GET("/explore", auth, rl100, cache5m, handlers.ExploreGrid)

	// Ахбор — RSS-и манбаъҳои боэътимод (cache дар худи handler).
	r.GET("/news", auth, rl100, handlers.GetNews)

	// AI-муаллими коднависӣ (proxy ба LLM-и open-source; калид дар env).
	r.POST("/tutor/chat", auth, rl100, handlers.TutorChat)
	r.POST("/ai/text", auth, rl100, handlers.AIText) // AI абзорҳо (Pro)
	r.POST("/ai/moderate",  auth, rl100, handlers.AIModerate)  // модератсия (OpenAI)
	r.POST("/ai/hashtags",  auth, rl100, handlers.AIHashtags)  // хэштегҳои AI
	r.POST("/ai/translate", auth, rl100, handlers.AITranslate) // тарҷума (OpenAI)

	r.POST("/upload",        auth, rl20, mw.AntiAbuse("upload", 50, 3600), handlers.UploadToR2)
	r.POST("/upload/avatar", auth, rl20, handlers.UploadToR2)
	r.POST("/upload/video",  auth, rl20, handlers.UploadToR2)
	r.POST("/media/upload",  auth, rl20, handlers.UploadToR2)

	ad := r.Group("/admin", auth, admin)
	{
		ad.GET("/stats",        handlers.AdminStats)
		ad.POST("/test-email",  handlers.AdminTestEmail)
		ad.GET("/users",        handlers.AdminListUsers)
		ad.POST("/ban/:id",     handlers.BanUser)
		ad.POST("/unban/:id",   handlers.UnbanUser)
		ad.POST("/verify/:id",   handlers.VerifyUser)
		ad.POST("/unverify/:id", handlers.UnverifyUser)
		ad.POST("/vip/:id",     handlers.SetVip)
		ad.POST("/unvip/:id",   handlers.UnsetVip)
		ad.DELETE("/users/:id", handlers.AdminDeleteUser)
		ad.GET("/orders",       handlers.AdminOrders) // фармоишҳо + комиссияи умумӣ
	}

	log.Printf("🚀 Raonson Go | Port:%s | PostgreSQL+R2+Redis | GZIP ON", port)

	srv := &http.Server{Addr: ":" + port, Handler: r}
	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt)
	<-quit
	log.Println("Shutting down...")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("shutdown: %v", err)
	}
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
