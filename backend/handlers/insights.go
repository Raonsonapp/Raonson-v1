package handlers

// Аналитикаи read-only барои корбари воридшуда:
//   GET /profile/insights — обзори 30-рӯзаи ҳисоб
//   GET /shop/insights     — панели 30-рӯзаи фурӯшанда

import (
	"context"
	"math"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── GET /profile/insights → обзори 30-рӯза ────────────────────────
func GetProfileInsights(c *gin.Context) {
	myID := mw.UID(c)
	ctx := context.Background()

	// Ангезиши (engagement) постҳо+reels-и дар 30 рӯзи охир сохташуда.
	// Диққат: posts ситуни views_count надорад → view-ҳо аз post_views.
	var postLikes, postComments, reelLikes, reelComments, reelViews int
	db.Pool.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT SUM(likes_count)    FROM posts WHERE user_id=$1 AND created_at > NOW()-INTERVAL '30 days'),0),
		  COALESCE((SELECT SUM(comments_count) FROM posts WHERE user_id=$1 AND created_at > NOW()-INTERVAL '30 days'),0),
		  COALESCE((SELECT SUM(likes_count)    FROM reels WHERE user_id=$1 AND created_at > NOW()-INTERVAL '30 days'),0),
		  COALESCE((SELECT SUM(comments_count) FROM reels WHERE user_id=$1 AND created_at > NOW()-INTERVAL '30 days'),0),
		  COALESCE((SELECT SUM(views_count)    FROM reels WHERE user_id=$1 AND created_at > NOW()-INTERVAL '30 days'),0)`,
		myID).Scan(&postLikes, &postComments, &reelLikes, &reelComments, &reelViews)

	// View-ҳои постҳо (posts.views_count нест) — аз post_views ҳисоб мекунем.
	var postViews int
	db.Pool.QueryRow(ctx, `
		SELECT COALESCE(COUNT(*),0)
		FROM post_views pv JOIN posts p ON p.id=pv.post_id
		WHERE p.user_id=$1 AND p.created_at > NOW()-INTERVAL '30 days'`,
		myID).Scan(&postViews)

	views30d := postViews + reelViews
	likes30d := postLikes + reelLikes
	comments30d := postComments + reelComments

	// Обуначиён ҳозир + бадастомада дар 30 рӯз (follows.following_id = ман).
	var followersNow, followersGained int
	db.Pool.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT COUNT(*) FROM follows WHERE following_id=$1),0),
		  COALESCE((SELECT COUNT(*) FROM follows WHERE following_id=$1 AND created_at > NOW()-INTERVAL '30 days'),0)`,
		myID).Scan(&followersNow, &followersGained)

	base := followersNow - followersGained
	if base < 1 {
		base = 1
	}
	growthPct := math.Round(float64(followersGained)/float64(base)*100*10) / 10

	// Шумораи умумии постҳо/reels.
	var postsCount, reelsCount int
	db.Pool.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT COUNT(*) FROM posts WHERE user_id=$1),0),
		  COALESCE((SELECT COUNT(*) FROM reels WHERE user_id=$1),0)`,
		myID).Scan(&postsCount, &reelsCount)

	// Топ-5 пост бо likes.
	topPosts := []gin.H{}
	if prows, err := db.Pool.Query(ctx, `
		SELECT p.id,
		       COALESCE((SELECT url FROM post_media pm WHERE pm.post_id=p.id
		                 ORDER BY position LIMIT 1),'') AS thumb,
		       COALESCE(p.likes_count,0), COALESCE(p.comments_count,0),
		       COALESCE((SELECT COUNT(*) FROM post_views pv WHERE pv.post_id=p.id),0)
		FROM posts p WHERE p.user_id=$1
		ORDER BY p.likes_count DESC LIMIT 5`, myID); err == nil {
		defer prows.Close()
		for prows.Next() {
			var id, thumb string
			var likes, comments, views int
			prows.Scan(&id, &thumb, &likes, &comments, &views)
			topPosts = append(topPosts, gin.H{
				"id": id, "thumb": thumb, "likes": likes,
				"comments": comments, "views": views,
			})
		}
	}

	// Топ-5 reel бо views (thumb = video_url — ситуни thumbnail нест).
	topReels := []gin.H{}
	if rrows, err := db.Pool.Query(ctx, `
		SELECT id, COALESCE(video_url,''), COALESCE(likes_count,0), COALESCE(views_count,0)
		FROM reels WHERE user_id=$1
		ORDER BY views_count DESC LIMIT 5`, myID); err == nil {
		defer rrows.Close()
		for rrows.Next() {
			var id, thumb string
			var likes, views int
			rrows.Scan(&id, &thumb, &likes, &views)
			topReels = append(topReels, gin.H{
				"id": id, "thumb": thumb, "likes": likes, "views": views,
			})
		}
	}

	// ideas: ҷадвали hashtags/trending вуҷуд надорад → холӣ (fabricate намекунем).
	ideas := []string{}

	c.JSON(http.StatusOK, gin.H{
		"views30d":           views30d,
		"likes30d":           likes30d,
		"comments30d":        comments30d,
		"followersNow":       followersNow,
		"followersGained30d": followersGained,
		"growthPct":          growthPct,
		"postsCount":         postsCount,
		"reelsCount":         reelsCount,
		"topPosts":           topPosts,
		"topReels":           topReels,
		"ideas":              ideas,
	})
}

// ── GET /shop/insights → панели 30-рӯзаи фурӯшанда ────────────────
func GetShopInsights(c *gin.Context) {
	myID := mw.UID(c)
	ctx := context.Background()

	// Фурӯшҳо дар 30 рӯзи охир (seller = ман).
	var salesCount int
	var revenue, commission float64
	db.Pool.QueryRow(ctx, `
		SELECT COALESCE(COUNT(*),0), COALESCE(SUM(price),0), COALESCE(SUM(commission),0)
		FROM orders WHERE seller_id=$1 AND created_at > NOW()-INTERVAL '30 days'`,
		myID).Scan(&salesCount, &revenue, &commission)

	// Асъор: асъори маҳсулоти фурӯшанда ё "TJS".
	var currency string
	db.Pool.QueryRow(ctx, `
		SELECT COALESCE((SELECT currency FROM posts
		                 WHERE user_id=$1 AND is_product=TRUE
		                 ORDER BY created_at DESC LIMIT 1),'TJS')`,
		myID).Scan(&currency)
	if currency == "" {
		currency = "TJS"
	}

	// Шумораи маҳсулот + view-и умумӣ (posts.views_count нест → post_views).
	var productsCount, viewsTotal int
	db.Pool.QueryRow(ctx, `
		SELECT
		  COALESCE((SELECT COUNT(*) FROM posts WHERE user_id=$1 AND is_product=TRUE),0),
		  COALESCE((SELECT COUNT(*) FROM post_views pv JOIN posts p ON p.id=pv.post_id
		            WHERE p.user_id=$1 AND p.is_product=TRUE),0)`,
		myID).Scan(&productsCount, &viewsTotal)

	// Топ-5 маҳсулот бо шумораи фурӯш.
	topProducts := []gin.H{}
	if trows, err := db.Pool.Query(ctx, `
		SELECT p.id, COALESCE(p.product_name,''),
		       COALESCE((SELECT url FROM post_media pm WHERE pm.post_id=p.id
		                 ORDER BY position LIMIT 1),'') AS thumb,
		       COUNT(o.id) AS sold, COALESCE(SUM(o.price),0) AS revenue
		FROM posts p
		LEFT JOIN orders o ON o.post_id=p.id AND o.seller_id=$1
		WHERE p.user_id=$1 AND p.is_product=TRUE
		GROUP BY p.id, p.product_name
		ORDER BY sold DESC, p.created_at DESC LIMIT 5`, myID); err == nil {
		defer trows.Close()
		for trows.Next() {
			var id, name, thumb string
			var sold int
			var rev float64
			trows.Scan(&id, &name, &thumb, &sold, &rev)
			topProducts = append(topProducts, gin.H{
				"id": id, "name": name, "thumb": thumb,
				"sold": sold, "revenue": rev,
			})
		}
	}

	// Фурӯши рӯзона дар 30 рӯзи охир — танҳо рӯзҳое, ки >=1 фурӯш доштанд.
	dailySales := []gin.H{}
	if drows, err := db.Pool.Query(ctx, `
		SELECT to_char(created_at::date,'YYYY-MM-DD') AS d,
		       COUNT(*), COALESCE(SUM(price),0)
		FROM orders
		WHERE seller_id=$1 AND created_at > NOW()-INTERVAL '30 days'
		GROUP BY created_at::date
		ORDER BY created_at::date`, myID); err == nil {
		defer drows.Close()
		for drows.Next() {
			var d string
			var count int
			var rev float64
			drows.Scan(&d, &count, &rev)
			dailySales = append(dailySales, gin.H{
				"date": d, "count": count, "revenue": rev,
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"salesCount30d": salesCount,
		"revenue30d":    revenue,
		"commission30d": commission,
		"currency":      currency,
		"productsCount": productsCount,
		"viewsTotal":    viewsTotal,
		"topProducts":   topProducts,
		"dailySales":    dailySales,
	})
}
