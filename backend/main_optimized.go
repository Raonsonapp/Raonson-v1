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
	// ── Realtime feel: user-personalized endpoints (feed, stories, post,
	// user profile) hozir танҳо 3 сония cache мешаванд, то like/follow/
	// story-и нав дар 1-3 сония ба ҳама намоён шаванд. Пеш аз 30с cache
	// боиси "лайкҳо мемонанд/гум мешаванд" ва "стори реалтайм нест" шуд.
	cache3s  := mw.CacheMiddleware(3 * time.Second)

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
		a.POST("/send-phone-otp",   rl20, handlers.SendPhoneOTP)      // Telegram OTP
		a.POST("/verify-phone-otp", rl20, handlers.VerifyPhoneOTP)    // тасдиқи телефон
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
		u.GET("/:id",                   cache3s, handlers.GetUserByID)
		u.PUT("/",                       handlers.UpdateUser)
		u.DELETE("/",                    handlers.DeleteUser)
		u.GET("/:id/posts",             cache3s, handlers.GetUserPosts)
		u.GET("/:id/tagged",            cache3s, handlers.GetTaggedPosts)
		u.GET("/:id/reels",             cache3s, handlers.GetUserReels)
		u.GET("/:id/followers",         handlers.GetFollowers)
		u.GET("/:id/following",         handlers.GetFollowing)
	}

	// ── PROFILE ──────────────────────────────────────────────────
	p := r.Group("/profile", auth, rl100)
	{
		p.GET("/me",            handlers.GetMyProfile)
		p.GET("/insights",      handlers.GetProfileInsights) // обзори 30-рӯза
		p.GET("/notes/friends", cache3s, handlers.GetFriendsNotes)
		p.POST("/note",         handlers.SetNote)
		p.PUT("/",              handlers.UpdateProfile)
		p.PUT("/settings",      handlers.UpdateSettings)
		p.GET("/saved",         handlers.GetSavedPosts)
		p.GET("/notifications", handlers.GetNotifPrefs)
		p.PUT("/notifications", handlers.UpdateNotifPrefs)
		p.PUT("/username",      handlers.ChangeUsername)
		p.PUT("/phone",         handlers.ChangePhone)
		p.PUT("/email",         handlers.ChangeEmail)
		p.GET("/auto-reply",    handlers.GetAutoReply)
		p.PUT("/auto-reply",    handlers.SetAutoReply)
		p.DELETE("/avatar",     handlers.DeleteAvatar)
		p.DELETE("/me",         handlers.DeleteUser)
		p.GET("/:username",     cache3s, handlers.GetProfile)
	}

	// ── CLOSE FRIENDS (Близкие друзья) ──────────────────────────
	// ── SAVED COLLECTIONS (папкаҳои захирашуда) ─────────────────
	col := r.Group("/collections", auth, rl100)
	{
		col.GET("",                    handlers.GetCollections)
		col.POST("",                   handlers.CreateCollection)
		col.DELETE("/:id",             handlers.DeleteCollection)
		col.POST("/:id/posts",         handlers.AddPostToCollection)
		col.DELETE("/:id/posts/:postId", handlers.RemovePostFromCollection)
	}

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
		po.GET("/",                  cache3s, handlers.GetFeed)
		po.GET("/feed",              cache3s, handlers.GetFeed)
		po.GET("/smart-feed",        handlers.GetSmartFeed) // has own cache
		po.GET("/scheduled",         handlers.GetScheduledPosts)
		po.GET("/hashtag/:tag",      cache3s, handlers.HashtagPosts)
		po.GET("/:id",               cache3s, handlers.GetPost)
		po.GET("/:id/likes",         handlers.GetPostLikers)
		po.GET("/:id/comments",      cache3s, handlers.GetComments)
		po.POST("/:id/comments",     handlers.AddComment)
		po.POST("/:id/collab/accept",  handlers.AcceptCollab)
		po.POST("/:id/collab/decline", handlers.DeclineCollab)
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
		po.DELETE("/:id/tag",        handlers.RemoveMyTag) // қайди худро бардор
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

	r.GET("/comments/:id",       auth, rl100, cache3s, handlers.GetComments)
	r.POST("/comments/:id",      auth, rl100, handlers.AddComment)
	r.DELETE("/comments/:id",    auth, rl100, handlers.DeleteComment)
	r.PUT("/comments/:id",       auth, rl100, handlers.EditComment)
	r.POST("/comments/:id/like", auth, rl100, handlers.ToggleCommentLike)
	r.POST("/comments/:id/report", auth, rl20, handlers.ReportComment)

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
		re.GET("/",              cache3s, handlers.GetReels)
		re.GET("/smart",         handlers.GetSmartReels)   // Instagram algorithm
		// ── Садои рилс («Ин садоро истифода бар») ──
		// Роҳҳои статикӣ ПЕШ аз "/:id" меоянд, то "audio" ҳамчун id
		// фаҳмида нашавад.
		re.GET("/audio/trending",       cache30s, handlers.GetTrendingAudios)
		re.GET("/audio/saved",          handlers.GetSavedAudios)
		re.GET("/audio/:audioId",       cache3s, handlers.GetReelAudio)
		re.POST("/audio/:audioId/save", handlers.ToggleSaveAudio)
		re.GET("/:id",           cache3s, handlers.GetReelByID)
		re.POST("/",             handlers.CreateReel)
		re.DELETE("/:id",        handlers.DeleteReel)
		re.POST("/:id/view",     handlers.TrackReelView)   // view dedup tracking
		re.POST("/:id/watch",    handlers.TrackReelWatch)  // watch-time tracking
		re.POST("/:id/like",     handlers.ToggleReelLike)
		re.POST("/:id/save",     handlers.ToggleReelSave)
		re.GET("/:id/comments",  cache3s, handlers.GetReelComments)
		re.POST("/:id/comments", handlers.AddReelComment)
		re.POST("/:id/report",       handlers.ReportReel)
		re.POST("/:id/hide-likes",   handlers.ToggleReelHideLikes)
		re.POST("/:id/toggle-comments", handlers.ToggleReelComments)
		re.POST("/:id/interest",     handlers.MarkReelInterested)
		re.POST("/:id/not_interest", handlers.MarkReelNotInterested)
		re.GET("/:id/stats",         handlers.GetReelStats)
		re.POST("/:id/comments/:commentId/like",  handlers.LikeReelComment)
		re.POST("/:id/comments/:commentId/reply", handlers.ReplyReelComment)
		re.PUT("/:id/caption",    handlers.UpdateReelCaption)
	}

	st := r.Group("/stories", auth, rl100)
	{
		st.GET("/",            cache3s, handlers.GetStories)
		st.GET("/my",          handlers.GetMyStories)
		st.POST("/",           handlers.CreateStory)
		st.DELETE("/:id",      handlers.DeleteStory)
		st.POST("/:id/view",   handlers.ViewStory)
		st.POST("/:id/like",   handlers.LikeStory)
		st.POST("/:id/reply",  handlers.ReplyStory)
		st.POST("/:id/archive", handlers.ToggleStoryArchive)
		st.POST("/:id/toggle-replies", handlers.ToggleStoryReplies)
		st.GET("/:id/viewers", handlers.GetStoryViewers)
		st.POST("/:id/poll/vote", handlers.VoteStoryPoll) // овоз ба пурсиш
		st.POST("/:id/report", handlers.ReportStory)
	}

	// ── HIGHLIGHTS (Актуальный) ──
	hl := r.Group("/highlights", auth, rl100)
	{
		hl.POST("/",       handlers.CreateHighlight)
		hl.GET("/:id",     cache3s, handlers.GetHighlights)
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
		ch.POST("/messages/:id/opened", handlers.MarkViewOnceOpened)
		ch.POST("/messages/:id/report", handlers.ReportMessage)
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
		no.DELETE("/push-token", handlers.DeletePushToken)
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

	// AI-хизматҳо (OpenAI): модератсия дар handler-ҳои пост/шарҳ, инҷо
	// ҳэштег ва тарҷума. Калид дар env: OPENAI_API_KEY (ҳеҷ гоҳ дар код нест).
	ai := r.Group("/ai", auth, rl100)
	{
		ai.POST("/hashtags", handlers.SuggestHashtags)
		ai.POST("/translate", handlers.TranslateComment)
		ai.POST("/assistant", handlers.AiAssistant)
		ai.POST("/post-creator", handlers.GeneratePost)
		ai.POST("/comment-suggest", handlers.SuggestPostComment)
		ai.POST("/profile-bio", handlers.GenerateBio)
		ai.POST("/search", handlers.AiSearch)
	}

	// ── ЛЕНТАИ AI — қабати идорашавандаи тавсия ─────────────────
	// Рейтинги мавҷуда (GetSmartFeed/GetSmartReels) бетағйир мемонад;
	// ин endpoint-ҳо танҳо афзалияти корбарро идора мекунанд.
	fa := r.Group("/feed", auth, rl100)
	{
		fa.GET("/preferences",         handlers.GetFeedPreferences)
		fa.PUT("/preferences",         handlers.UpdateFeedPreferences)
		fa.PUT("/preferences/topic",   handlers.SetFeedTopicPreference)
		fa.PUT("/preferences/creator", handlers.SetFeedCreatorPreference)
		// Таҷзияи забони табиӣ гаронтар аст — маҳдудияти сахттар.
		fa.POST("/preferences/natural-language", rl20, handlers.ParseFeedCommand)
		fa.POST("/feedback",           handlers.RecordFeedFeedback)
		fa.POST("/reset",              rl20, handlers.ResetFeedPreferences)
		fa.GET("/explanation/:contentType/:contentId", handlers.GetFeedExplanation)
		fa.POST("/find-people",        rl20, handlers.FindMyPeople)
	}

	// ── CREATOR STUDIO ──────────────────────────────────────────
	// Эҷодкор ТАНҲО маълумоти худро мебинад — id аз токен меояд.
	cs := r.Group("/creator", auth, rl100)
	{
		cs.GET("/studio",    handlers.GetCreatorStudio)
		cs.GET("/analytics", handlers.GetCreatorAnalytics)
		cs.GET("/insights",  handlers.GetCreatorInsights)
		cs.GET("/recap/week", handlers.GetCreatorRecap)
		cs.GET("/achievements", handlers.GetCreatorAchievements)
		// Даъвати LLM — маҳдудияти сахттар.
		cs.POST("/ideas",    rl20, handlers.GenerateCreatorIdeas)
	}

	// ── ҶАМЪБАСТИ ҲАФТАГӢ ───────────────────────────────────────
	r.GET("/recap/week", auth, rl100, handlers.GetViewerRecap)

	// ── ДАЪВАТ ──────────────────────────────────────────────────
	r.GET("/referrals/me", auth, rl100, handlers.GetMyReferrals)

	// ── ҲАМКОРӢ ─────────────────────────────────────────────────
	r.GET("/collabs/pending", auth, rl100, handlers.GetPendingCollabs)

	// ── КАШФИЁТ ─────────────────────────────────────────────────
	dc := r.Group("/discover", auth, rl100)
	{
		dc.GET("",           handlers.GetDiscoverToday)
		dc.GET("/trending",  cache30s, handlers.GetTrendRadar)
		dc.GET("/people",    handlers.GetDiscoverPeople)
	}

	r.GET("/explore", auth, rl100, cache5m, handlers.ExploreGrid)

	// Ахбор — RSS-и манбаъҳои боэътимод (cache дар худи handler).
	r.GET("/news", auth, rl100, handlers.GetNews)

	// AI-муаллими коднависӣ (proxy ба LLM-и open-source; калид дар env).
	r.POST("/tutor/chat", auth, rl100, handlers.TutorChat)
	r.POST("/ai/text", auth, rl100, handlers.AIText) // AI абзорҳо (Pro)
	r.POST("/ai/moderate",  auth, rl100, handlers.AIModerate)  // модератсия (OpenAI)

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
		ad.GET("/reports",          handlers.AdminGetReports)
		ad.POST("/reports/resolve", handlers.AdminResolveReport)
		ad.GET("/reports/count",    handlers.AdminReportCount)

		// Creator Marketplace — интиқолҳои дастӣ ва омори молиявӣ.
		// Тафтиши танзимоти AI — танҳо админ.
		ad.GET("/ai/health",   handlers.GetAIHealth)
		ad.GET("/ai/selftest", handlers.GetAISelfTest)

		ad.GET("/marketplace/stats",             handlers.AdminMarketplaceStats)
		ad.GET("/marketplace/payouts",           handlers.AdminListPayouts)
		ad.POST("/marketplace/payouts/:id/settle", handlers.AdminSettlePayout)
		ad.POST("/marketplace/payouts/:id/fail",   handlers.AdminFailPayout)
	}

	// ── CREATOR MARKETPLACE ─────────────────────────────────────
	// Рекламадиҳанда кампания месозад ва пардохт мекунад; эҷодкор
	// даъватро қабул мекунад ва мӯҳтаво месупорад.
	mp := r.Group("/marketplace", auth, rl100)
	{
		mp.GET("/advertiser",  handlers.GetAdvertiser)
		mp.PUT("/advertiser",  handlers.UpdateAdvertiser)

		mp.POST("/campaigns",     rl20, handlers.CreateCampaign)
		mp.GET("/campaigns",            handlers.ListCampaigns)
		mp.GET("/campaigns/:id",        handlers.GetCampaignDetail)
		mp.POST("/campaigns/:id/checkout", rl20, handlers.CheckoutCampaign)
		mp.POST("/campaigns/:id/cancel",         handlers.CancelCampaign)
		mp.POST("/campaigns/:id/complete",       handlers.CompleteCampaign)
		mp.GET("/campaigns/:id/candidates",      handlers.GetCampaignCandidates)
		mp.GET("/campaigns/:id/metrics",         handlers.GetCampaignMetrics)
		mp.POST("/campaigns/:id/invite",         handlers.InviteCreator)

		mp.GET("/creator/me", handlers.GetCreatorMarketplaceProfile)
		mp.PUT("/creator/me", handlers.UpdateCreatorMarketplaceProfile)
		mp.GET("/wallet",     handlers.GetMarketplaceWallet)

		mp.GET("/creator/campaigns", handlers.ListMyCampaigns)
		mp.GET("/creator/earnings",  handlers.GetMyEarnings)
		mp.GET("/creator/payouts",   handlers.ListMyPayouts)

		mp.GET("/offers",              handlers.ListMyOffers)
		mp.POST("/offers/:id/respond", handlers.RespondToOffer)
		mp.POST("/offers/:id/accept",  handlers.AcceptOffer)
		mp.POST("/offers/:id/reject",  handlers.RejectOffer)
		mp.POST("/offers/:id/content", handlers.SubmitOfferContent)
		mp.POST("/offers/:id/approve", handlers.ApproveOfferContent)
	}

	// ── /api/v1 — ҳамон handler-ҳо бо роҳҳои versiondor ────────────
	// Raonson-и мавҷуда роҳҳои ҳамворро истифода мебарад ва онҳо
	// нигоҳ дошта мешаванд, то client-и ҳозира нашиканад. Ин гурӯҳ
	// ҳамон handler-ҳоро зери роҳҳои /api/v1 медиҳад — ду роҳ, як код.
	v1 := r.Group("/api/v1", auth, rl100)
	{
		adv := v1.Group("/advertiser")
		{
			adv.GET("/profile",   handlers.GetAdvertiser)
			adv.PUT("/profile",   handlers.UpdateAdvertiser)
			adv.POST("/campaigns", rl20, handlers.CreateCampaign)
			adv.GET("/campaigns",        handlers.ListCampaigns)
			adv.GET("/campaigns/:id",    handlers.GetCampaignDetail)
			adv.POST("/campaigns/:id/payment", rl20, handlers.CheckoutCampaign)
			adv.POST("/campaigns/:id/match",         handlers.MatchCampaign)
			adv.GET("/campaigns/:id/candidates",     handlers.GetCampaignCandidates)
			adv.POST("/campaigns/:id/cancel",        handlers.CancelCampaign)
			adv.POST("/campaigns/:id/complete",      handlers.CompleteCampaign)
			adv.POST("/campaigns/:id/creators/:offerId/approve",
				handlers.ApproveOfferContentByParam)
		}
		cr := v1.Group("/creator")
		{
			cr.GET("/profile",  handlers.GetCreatorMarketplaceProfile)
			cr.PUT("/profile",  handlers.UpdateCreatorMarketplaceProfile)
			cr.GET("/campaign-offers", handlers.ListMyOffers)
			cr.POST("/campaign-offers/:id/accept", handlers.AcceptOffer)
			cr.POST("/campaign-offers/:id/reject", handlers.RejectOffer)
			cr.POST("/campaign-offers/:id/content", handlers.SubmitOfferContent)
			cr.GET("/campaigns", handlers.ListMyCampaigns)
			cr.GET("/earnings",  handlers.GetMyEarnings)
			cr.GET("/payouts",   handlers.ListMyPayouts)
		}
		v1.GET("/campaigns/:id/analytics", handlers.GetCampaignMetrics)
	}

	// Webhook-ҳо БЕ auth — онҳоро provider даъват мекунад, на корбар.
	// Ҳимоя аз имзои криптографӣ + тасдиқи мустақим аз provider меояд.
	r.POST("/payments/webhook/:provider", handlers.PaymentWebhook)
	r.POST("/payouts/webhook/:provider",  handlers.PayoutWebhook)
	r.POST("/api/v1/payments/webhook/:provider", handlers.PaymentWebhook)
	r.POST("/api/v1/payouts/webhook/:provider",  handlers.PayoutWebhook)

	// Child Safety Standards & Community Guidelines (public, no auth)
	r.GET("/child-safety", handlers.GetChildSafetyPolicy)
	r.GET("/community-guidelines", handlers.GetCommunityGuidelines)

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
		// WebSocket upgrade-ро печонида намешавад — hijack-и пайвастро
		// вайрон мекунад.
		if c.Request.Header.Get("Upgrade") != "" {
			c.Next()
			return
		}
		// Writer БОЯД пеш аз c.Next() печонида шавад — вагарна ҷавоб
		// аллакай фишурданашуда навишта мешавад (хатои қаблӣ: middleware
		// баъд аз навиштан танҳо header мегузошт ва ҳеҷ чиз фишурда намешуд).
		c.Header("Content-Encoding", "gzip")
		c.Header("Vary", "Accept-Encoding")
		c.Writer.Header().Del("Content-Length") // андоза пас аз фишурдан дигар аст
		gz, gw := newGzipWriter(c)
		c.Writer = gw
		defer gz.Close()
		c.Next()
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
