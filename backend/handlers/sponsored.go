package handlers

// Рекламаи дохилӣ (sponsored) — мисли Instagram: пости тарғибшуда
// дар байни постҳои лента ва саҳифаҳои Reels.
//
// Қоидаҳо:
//   • танҳо промоушни ТАСДИҚШУДА (status='active') ва мӯҳлаташ
//     нагузашта — «in_review» ҳеҷ гоҳ ба корбар намеравад;
//   • корбари VIP/Pro (ва соҳиб @raonson) умуман реклама намегирад —
//     сервер рӯйхати холӣ медиҳад, на танҳо барнома пинҳон мекунад;
//   • намоиш ва клик як бор дар рӯз барои ҳар корбар ҳисоб мешаванд,
//     то scroll-и боло-поён ҳисобро сохта наафзояд.
//
// Ин ба мукофоти Yandex (/ads/watch-session, /ads/watched) ҳеҷ
// дахл надорад.

import (
	"context"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// IsAdsFreeUsername — соҳиби барнома ҳамеша бе реклама аст, ҳатто
// агар is_vip дар база гузошта нашуда бошад.
func IsAdsFreeUsername(username string) bool {
	return strings.EqualFold(strings.TrimSpace(username), "raonson")
}

// adsFreeFor — оё ба ин корбар реклама нишон дода намешавад.
//
// Хатои база ҳамчун «на VIP» ҳисоб мешавад: беҳтар аст реклама
// нишон дода шавад, аз он ки ҳамаи корбарон бе сабаб VIP шаванд.
func adsFreeFor(ctx context.Context, uid string) bool {
	if uid == "" || db.Pool == nil {
		return false
	}
	var vip bool
	var username string
	if err := db.Pool.QueryRow(ctx,
		`SELECT COALESCE(is_vip,false), COALESCE(username,'')
		   FROM users WHERE id=$1`, uid).Scan(&vip, &username); err != nil {
		return false
	}
	return vip || IsAdsFreeUsername(username)
}

// sponsoredLimit — ҳадди ҳар дархост; барнома зиёдтар намепурсад.
func sponsoredLimit(raw string) int {
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return 6
	}
	if n > 10 {
		return 10
	}
	return n
}

// ctaFor — матни тугма аз рӯи ҳадафи промоушн.
func ctaFor(goal string) string {
	switch goal {
	case "website":
		return "Бештар"
	case "messages":
		return "Паём фиристед"
	case "install", "app":
		return "Насб кардан"
	default:
		return "Дидани профил"
	}
}

// GET /ads/sponsored?placement=feed|reels&limit=6
func GetSponsored(c *gin.Context) {
	myID := mw.UID(c)
	ctx := c.Request.Context()
	if adsFreeFor(ctx, myID) {
		// Ҷавоби холӣ, на 403: барнома ҳамин тавр мефаҳмад, ки
		// ҷойҳои рекламаро умуман насозад.
		c.JSON(http.StatusOK, gin.H{"adsFree": true, "items": []gin.H{}})
		return
	}
	placement := c.DefaultQuery("placement", "feed")
	limit := sponsoredLimit(c.Query("limit"))

	// Reels — танҳо постҳое, ки видео доранд: расми статикӣ дар
	// байни видеоҳо ҳамчун «видеои шикаста» менамояд.
	mediaFilter := `EXISTS (SELECT 1 FROM post_media m WHERE m.post_id=p.id)`
	if placement == "reels" {
		mediaFilter = `EXISTS (SELECT 1 FROM post_media m
		                        WHERE m.post_id=p.id AND m.type='video')`
	}

	rows, err := db.Pool.Query(ctx, `
		SELECT pr.id, pr.post_id, COALESCE(pr.goal,'profile'),
		       COALESCE(pr.action_url,''),
		       u.id, u.username, COALESCE(u.avatar,''),
		       COALESCE(u.verified,false),
		       COALESCE(p.caption,''), COALESCE(p.likes_count,0),
		       COALESCE(p.comments_count,0),
		       EXISTS (SELECT 1 FROM post_likes l
		                WHERE l.user_id=$1 AND l.post_id=p.id),
		       COALESCE((SELECT json_agg(json_build_object(
		                   'url', m.url, 'type', COALESCE(m.type,'image'),
		                   'aspectRatio', COALESCE(m.aspect_ratio,0))
		                   ORDER BY m.position)
		                 FROM post_media m WHERE m.post_id=p.id)::text, '[]')
		FROM promotions pr
		JOIN posts p ON p.id = pr.post_id
		JOIN users u ON u.id = pr.user_id
		WHERE pr.status = 'active'
		  AND (pr.ends_at IS NULL OR pr.ends_at > NOW())
		  AND pr.user_id <> $1
		  AND COALESCE(u.banned,false) = false
		  AND COALESCE(p.archived,false) = false
		  AND NOT EXISTS (SELECT 1 FROM sponsored_hides h
		                   WHERE h.user_id=$1 AND h.promotion_id=pr.id)
		  AND `+mediaFilter+`
		ORDER BY random() * GREATEST(pr.budget_cents,1) DESC
		LIMIT $2`, myID, limit)
	if err != nil {
		// Реклама набошад ҳам лента бояд кор кунад.
		c.JSON(http.StatusOK, gin.H{"adsFree": false, "items": []gin.H{}})
		return
	}
	defer rows.Close()

	items := []gin.H{}
	for rows.Next() {
		var id, postID, goal, actionURL, uid, username, avatar string
		var caption, mediaJSON string
		var verified, liked bool
		var likes, comments int
		if rows.Scan(&id, &postID, &goal, &actionURL, &uid, &username,
			&avatar, &verified, &caption, &likes, &comments, &liked,
			&mediaJSON) != nil {
			continue
		}
		media := []map[string]any{}
		_ = json.Unmarshal([]byte(mediaJSON), &media)
		items = append(items, gin.H{
			"id": id, "postId": postID, "goal": goal,
			"actionUrl": actionURL, "cta": ctaFor(goal),
			"advertiser": gin.H{
				"id": uid, "username": username, "avatar": avatar,
				"verified": verified,
			},
			"caption": caption, "likesCount": likes,
			"commentsCount": comments, "liked": liked, "media": media,
		})
	}
	c.JSON(http.StatusOK, gin.H{"adsFree": false, "items": items})
}

// recordSponsored — намоиш/клик як бор дар рӯз барои ҳар корбар.
func recordSponsored(c *gin.Context, kind, column string) {
	myID := mw.UID(c)
	ctx := c.Request.Context()
	id := c.Param("id")
	// Корбари VIP рекламаро намебинад — пас ҳисоб ҳам намешавад.
	if adsFreeFor(ctx, myID) {
		c.JSON(http.StatusOK, gin.H{"counted": false})
		return
	}
	ct, err := db.Pool.Exec(ctx, `
		INSERT INTO sponsored_events (user_id, promotion_id, kind)
		SELECT $1, pr.id, $3 FROM promotions pr
		 WHERE pr.id=$2 AND pr.status='active'
		ON CONFLICT DO NOTHING`, myID, id, kind)
	if err != nil || ct.RowsAffected() == 0 {
		c.JSON(http.StatusOK, gin.H{"counted": false})
		return
	}
	db.Pool.Exec(ctx,
		`UPDATE promotions SET `+column+`=`+column+`+1 WHERE id=$1`, id)
	c.JSON(http.StatusOK, gin.H{"counted": true})
}

// POST /ads/sponsored/:id/impression — карт воқеан дар экран буд.
func SponsoredImpression(c *gin.Context) {
	recordSponsored(c, "impression", "impressions")
}

// POST /ads/sponsored/:id/click — корбар CTA-ро зер кард.
func SponsoredClick(c *gin.Context) { recordSponsored(c, "click", "clicks") }

// POST /ads/sponsored/:id/hide — «Пинҳон кардан» аз менюи ⋯.
func HideSponsored(c *gin.Context) {
	myID := mw.UID(c)
	db.Pool.Exec(c.Request.Context(), `
		INSERT INTO sponsored_hides (user_id, promotion_id)
		VALUES ($1,$2) ON CONFLICT DO NOTHING`, myID, c.Param("id"))
	c.JSON(http.StatusOK, gin.H{"hidden": true})
}

// ── Admin: тасдиқи промоушн ──────────────────────────────────────
//
// Бе ин ҳеҷ промоушн аз «in_review» берун намеомад ва рекламаи
// дохилӣ ҳеҷ гоҳ намебаромад.

// GET /admin/promotions?status=in_review
func AdminListPromotions(c *gin.Context) {
	status := c.DefaultQuery("status", "in_review")
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT pr.id, pr.post_id, u.username, COALESCE(pr.goal,''),
		       COALESCE(pr.action_url,''), pr.status, pr.budget_cents,
		       pr.duration_days, pr.impressions, pr.clicks, pr.created_at
		FROM promotions pr JOIN users u ON u.id = pr.user_id
		WHERE pr.status = $1
		ORDER BY pr.created_at DESC LIMIT 100`, status)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Дарёфт ноком шуд"})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, postID, username, goal, actionURL, st string
		var budget, dur, imp, clk int
		var createdAt any
		if rows.Scan(&id, &postID, &username, &goal, &actionURL, &st,
			&budget, &dur, &imp, &clk, &createdAt) != nil {
			continue
		}
		out = append(out, gin.H{
			"id": id, "postId": postID, "username": username,
			"goal": goal, "actionUrl": actionURL, "status": st,
			"budgetCents": budget, "durationDays": dur,
			"impressions": imp, "clicks": clk, "createdAt": createdAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"promotions": out})
}

// POST /admin/promotions/:id/approve — мӯҳлат аз лаҳзаи тасдиқ оғоз
// мешавад, на аз фармоиш: вагарна тасдиқи дер рӯзҳои пулиро мехӯрд.
func AdminApprovePromotion(c *gin.Context) {
	ct, _ := db.Pool.Exec(c.Request.Context(), `
		UPDATE promotions
		   SET status='active',
		       ends_at = NOW() + make_interval(days => GREATEST(duration_days,1))
		 WHERE id=$1 AND status IN ('in_review','rejected')`, c.Param("id"))
	if ct.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Реклама ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "active"})
}

// POST /admin/promotions/:id/reject
func AdminRejectPromotion(c *gin.Context) {
	ct, _ := db.Pool.Exec(c.Request.Context(),
		`UPDATE promotions SET status='rejected' WHERE id=$1`, c.Param("id"))
	if ct.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Реклама ёфт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "rejected"})
}
