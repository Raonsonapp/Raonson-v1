package handlers

import (
	"context"
	"log"
	"encoding/json"
	"net/http"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/sockets"
	"raonson/utils"

	"github.com/gin-gonic/gin"
)

// POST /posts
func CreatePost(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Caption       string                   `json:"caption"`
		Media         []map[string]interface{} `json:"media"`
		MusicTitle    string                   `json:"musicTitle"`
		MusicArtist   string                   `json:"musicArtist"`
		Location      string                   `json:"location"`
		TaggedUsers   []string                 `json:"taggedUsers"`
		Collaborators []string                 `json:"collaborators"`
		// Shopping (маҳсулот барои фуруш)
		IsProduct     bool                     `json:"isProduct"`
		Price         float64                  `json:"price"`
		Currency      string                   `json:"currency"`
		ProductName   string                   `json:"productName"`
		ShopLat       float64                  `json:"shopLat"`
		ShopLng       float64                  `json:"shopLng"`
		ShopAddress   string                   `json:"shopAddress"`
		ContactRaonson bool                    `json:"contactRaonson"`
		ShopWhatsApp   string                  `json:"shopWhatsapp"`
		ShopPhone      string                  `json:"shopPhone"`
		// Post scheduling (нашри вақтбандӣ) — RFC3339, оянда
		ScheduledAt    string                  `json:"scheduledAt"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || len(b.Media) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "At least one media item required"})
		return
	}
	b.Caption = clampRunes(b.Caption, 2200)
	if b.TaggedUsers == nil {
		b.TaggedUsers = []string{}
	}
	if b.Collaborators == nil {
		b.Collaborators = []string{}
	}
	if flagged, cats := utils.ModerateText(context.Background(), b.Caption); flagged {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Тавсиф қоидаҳои ҷамъиятиро вайрон мекунад", "categories": cats})
		return
	}

	if b.Caption != "" && !moderateText(b.Caption) {
		c.JSON(http.StatusForbidden, gin.H{
			"message": "Матни пост аз тарафи AI рад шуд. Лутфан мӯҳтаворо тағйир диҳед."})
		return
	}

	// Нашри вақтбандӣ: агар вақти оянда бошад, то он вақт пинҳон мемонад.
	var scheduledAt *time.Time
	if b.ScheduledAt != "" {
		if t, perr := time.Parse(time.RFC3339, b.ScheduledAt); perr == nil && t.After(time.Now()) {
			scheduledAt = &t
		}
	}

	tx, err := db.Pool.Begin(context.Background())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}
	defer tx.Rollback(context.Background())

	var postID string
	if err = tx.QueryRow(context.Background(),
		`INSERT INTO posts(user_id,caption,music_title,music_artist,location,tagged_users,collaborators,scheduled_at)
		 VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id`,
		// Ҳамкорон холӣ оғоз мешаванд: ном танҳо пас аз розигии
		// худи одам ба пост баста мешавад (ниг. collab.go).
		myID, b.Caption, b.MusicTitle, b.MusicArtist, b.Location, b.TaggedUsers,
		[]string{}, scheduledAt).Scan(&postID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}

	for i, m := range b.Media {
		url, _ := m["url"].(string)
		t, _   := m["type"].(string)
		if t == "" { t = "image" }
		ar, _  := m["aspectRatio"].(float64) // JSON number → float64, default 0
		tx.Exec(context.Background(),
			`INSERT INTO post_media(post_id,url,type,position,aspect_ratio) VALUES($1,$2,$3,$4,$5)`,
			postID, url, t, i, ar)
	}
	tx.Exec(context.Background(),
		`UPDATE users SET posts_count=posts_count+1 WHERE id=$1`, myID)

	// Маҳсулот барои фуруш — маълумоти шоппинг + GPS-и магоза.
	if b.IsProduct {
		cur := b.Currency
		if cur == "" {
			cur = "TJS"
		}
		tx.Exec(context.Background(),
			`UPDATE posts SET is_product=TRUE, price=$2, currency=$3,
			 product_name=$4, shop_lat=$5, shop_lng=$6, shop_address=$7,
			 contact_raonson=$8, shop_whatsapp=$9, shop_phone=$10
			 WHERE id=$1`,
			postID, b.Price, cur, clampRunes(b.ProductName, 120),
			b.ShopLat, b.ShopLng, clampRunes(b.ShopAddress, 200),
			b.ContactRaonson, clampRunes(b.ShopWhatsApp, 30),
			clampRunes(b.ShopPhone, 30))
	}
	tx.Commit(context.Background())

	// Invalidate feed cache for this user
	mw.CacheDel("feed:"+myID+":1", "feed:"+myID+":2", "smartfeed:"+myID+":1", "smartfeed:"+myID+":2")
	// ва cache-и middleware-и корбар (то пости нав фавран дар profile/feed
	// худи ӯ намоён шавад).
	mw.InvalidateUserCache(myID)

	// @зикр дар тавсиф — ҳар корбари зикршударо огоҳ кун
	notifyMentions(myID, "mention", postID, b.Caption, "шуморо дар публикатсия зикр кард")
	// Даъвати ҳамкорӣ: то розигӣ ном ба пост баста намешавад.
	inviteCollaborators(postID, myID, b.Collaborators)

// ➕ ИЛОВА
var uname, uavatar string
var verified bool

db.Pool.QueryRow(context.Background(),
	`SELECT username, avatar, verified FROM users WHERE id=$1`, myID,
).Scan(&uname, &uavatar, &verified)

// ➕ ИЛОВА
wsPost := gin.H{
	"_id":           postID,
	"caption":       b.Caption,
	"media":         b.Media,
	"likesCount":    0,
	"commentsCount": 0,
	"liked":         false,
	"saved":         false,
	"musicTitle":    b.MusicTitle,
	"musicArtist":   b.MusicArtist,
	"location":      b.Location,
	"taggedUsers":   b.TaggedUsers,
	// Ҷавоб вазъи ВОҚЕИИ пост аст: даъватҳо ҳанӯз тасдиқ нашудаанд.
	"collaborators": []string{},
	"createdAt":     time.Now().Format(time.RFC3339),
	"user": gin.H{
		"_id":      myID,
		"username": uname,
		"avatar":   uavatar,
		"verified": verified,
	},
}

// ➕ ИЛОВА
go sockets.BroadcastNewPost(myID, wsPost)

// AI Feed: best-effort, дар паснамо — ба посух монеъ намешавад.
go func(pid, caption string) {
	score, err := utils.ScorePostQuality(context.Background(), caption)
	if err != nil {
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE posts SET ai_quality_score=$2 WHERE id=$1`, pid, score)
}(postID, b.Caption)

// 🔁 ИВАЗ
c.JSON(http.StatusCreated, wsPost)
}

// GET /posts  GET /posts/feed
func GetFeed(c *gin.Context) {
	myID   := mw.UID(c)
	page   := toInt(c.Query("page"), 1)
	limit  := toInt(c.Query("limit"), 20)
	offset := (page - 1) * limit

	// Cache key per user+page (30 sec TTL — fresh but fast)
	cacheKey := "feed:" + myID + ":" + c.Query("page")
	if page == 1 {
		if cached, ok := mw.CacheGet(cacheKey); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			return
		}
	}

	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, p.caption,
		       CASE WHEN COALESCE(p.hide_likes,false) AND p.user_id <> $1::text
		            THEN -1 ELSE p.likes_count END,
		       p.comments_count, p.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type,'aspectRatio',COALESCE(m.aspect_ratio,0))
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id),
		       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$1::text),
		       EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$1::text),
		       COALESCE(p.hide_likes,false), COALESCE(p.comments_off,false),
		       COALESCE(p.is_product,false), COALESCE(p.price,0),
		       COALESCE(p.currency,'TJS'), COALESCE(p.product_name,''),
		       COALESCE(p.contact_raonson,false), COALESCE(p.shop_whatsapp,''),
		       COALESCE(p.shop_phone,'')
		FROM posts p JOIN users u ON u.id=p.user_id
		WHERE COALESCE(p.archived,false) = FALSE
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())
		ORDER BY p.created_at DESC
		LIMIT $2 OFFSET $3`, myID, limit, offset)
	if err != nil {
		log.Printf("[GetFeed] query error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get feed failed"})
		return
	}
	defer rows.Close()

	posts := []gin.H{}
	for rows.Next() {
		var pid, cap, uid, uname, uavatar string
		var likes, comms int
		var verified, liked, saved, hideLikes, commentsOff bool
		var createdAt, media interface{}
		var isProduct, contactRaonson bool
		var price float64
		var currency, productName, shopWhatsapp, shopPhone string
		rows.Scan(&pid, &cap, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &media, &liked, &saved,
			&hideLikes, &commentsOff,
			&isProduct, &price, &currency, &productName,
			&contactRaonson, &shopWhatsapp, &shopPhone)
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap, "likesCount": likes, "commentsCount": comms,
			"createdAt": createdAt, "media": nilToEmpty(media),
			"liked": liked, "saved": saved,
			"hideLikes": hideLikes, "commentsOff": commentsOff,
			"isProduct": isProduct, "price": price, "currency": currency,
			"productName": productName, "contactRaonson": contactRaonson,
			"shopWhatsapp": shopWhatsapp, "shopPhone": shopPhone,
			"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
		})
	}
	result := gin.H{"posts": posts, "page": page, "limit": limit}
	if page == 1 {
		if b, err := json.Marshal(result); err == nil {
			mw.CacheSet(cacheKey, b, 30*time.Second)
		}
	}
	c.JSON(http.StatusOK, result)
}

// GET /posts/:id
func GetPost(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	var pid2, cap, uid, uname, uavatar string
	var likes, comms int
	var verified, liked, saved, hideLikes, commentsOff bool
	var createdAt, media interface{}
	var isProduct, contactRaonson bool
	var price float64
	var currency, productName, shopWhatsapp, shopPhone string

	err := db.Pool.QueryRow(context.Background(), `
		SELECT p.id, p.caption,
		       CASE WHEN COALESCE(p.hide_likes,false) AND p.user_id <> $2::text
		            THEN -1 ELSE p.likes_count END,
		       p.comments_count, p.created_at,
		       u.id, u.username, u.avatar, u.verified,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type,'aspectRatio',COALESCE(m.aspect_ratio,0))
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id),
		       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$2::text),
		       EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$2::text),
		       COALESCE(p.hide_likes,false), COALESCE(p.comments_off,false),
		       COALESCE(p.is_product,false), COALESCE(p.price,0),
		       COALESCE(p.currency,'TJS'), COALESCE(p.product_name,''),
		       COALESCE(p.contact_raonson,false), COALESCE(p.shop_whatsapp,''),
		       COALESCE(p.shop_phone,'')
		FROM posts p JOIN users u ON u.id=p.user_id WHERE p.id=$1
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now() OR p.user_id=$2::text)`,
		pid, myID).Scan(&pid2, &cap, &likes, &comms, &createdAt,
		&uid, &uname, &uavatar, &verified, &media, &liked, &saved,
		&hideLikes, &commentsOff,
		&isProduct, &price, &currency, &productName,
		&contactRaonson, &shopWhatsapp, &shopPhone)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"_id": pid2, "caption": cap, "likesCount": likes, "commentsCount": comms,
		"createdAt": createdAt, "media": nilToEmpty(media), "liked": liked, "saved": saved,
		"hideLikes": hideLikes, "commentsOff": commentsOff,
		"isProduct": isProduct, "price": price, "currency": currency,
		"productName": productName, "contactRaonson": contactRaonson,
		"shopWhatsapp": shopWhatsapp, "shopPhone": shopPhone,
		"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
	})
}

// GET /posts/scheduled — постҳои вақтбандишудаи корбар (ҳанӯз нашрнашуда)
func GetScheduledPosts(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, p.caption, p.scheduled_at,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type,'aspectRatio',COALESCE(m.aspect_ratio,0))
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id)
		FROM posts p
		WHERE p.user_id=$1::text AND p.scheduled_at IS NOT NULL AND p.scheduled_at > now()
		ORDER BY p.scheduled_at ASC`, myID)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}})
		return
	}
	defer rows.Close()
	posts := []gin.H{}
	for rows.Next() {
		var pid, cap string
		var scheduledAt, media interface{}
		if rows.Scan(&pid, &cap, &scheduledAt, &media) != nil {
			continue
		}
		posts = append(posts, gin.H{
			"_id": pid, "caption": cap,
			"media": nilToEmpty(media), "scheduledAt": scheduledAt,
		})
	}
	c.JSON(http.StatusOK, gin.H{"posts": posts})
}

// DELETE /posts/:id
func DeletePost(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM posts WHERE id=$1 AND user_id=$2::text`, pid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET posts_count=GREATEST(posts_count-1,0) WHERE id=$1`, myID)
	// Cache-и корбарро пок мекунем, то пости ҳазфшуда фавран аз ҳама
	// экранҳо (profile, feed, explore) нест шавад.
	mw.InvalidateUserCache(myID)
	mw.CacheDel("explore:grid") // фавран аз search/explore нопадид шавад
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// POST /posts/:id/like
func TogglePostLike(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM post_likes WHERE post_id=$1::text AND user_id=$2::text)`,
		pid, myID).Scan(&liked)

	if liked {
		// UNLIKE — count танҳо вақте кам мешавад, ки сатр воқеан ҳазф шуд.
		ct, _ := db.Pool.Exec(context.Background(),
			`DELETE FROM post_likes WHERE post_id=$1::text AND user_id=$2::text`, pid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE posts SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, pid)
		}
	} else {
		// LIKE — count танҳо вақте зиёд мешавад, ки сатр воқеан нав илова шуд
		// (race-safe: дархостҳои ҳамзамон count-ро дучанд намекунанд).
		ct, _ := db.Pool.Exec(context.Background(),
			`INSERT INTO post_likes(post_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, pid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE posts SET likes_count=likes_count+1 WHERE id=$1`, pid)
			var owner string
			db.Pool.QueryRow(context.Background(),
				`SELECT user_id FROM posts WHERE id=$1`, pid).Scan(&owner)
			notify(owner, myID, "like", pid)
		}
	}

	var cnt int
	db.Pool.QueryRow(context.Background(),
		`SELECT likes_count FROM posts WHERE id=$1`, pid).Scan(&cnt)
	// Cache-и middleware-и корбарро пок мекунем, то дафъаи оянда
	// GET /posts/:id ҳисоби НАВРО баргардонад, na cached-и қаблӣ.
	mw.InvalidateUserCache(myID)
	// Push notification to post owner
	if !liked {
		go func() {
			var ownerID, username string
			db.Pool.QueryRow(context.Background(),
				`SELECT p.user_id, u.username FROM posts p
				 JOIN users u ON u.id=(SELECT id FROM users WHERE id=$2)
				 WHERE p.id=$1`, pid, myID).Scan(&ownerID, &username)
			if ownerID != "" && ownerID != myID {
				SendPushToUser(ownerID, "Raonson", username+" liked your post",
					map[string]string{"type":"like","postId":pid})
			}
		}()
	}
	c.JSON(http.StatusOK, gin.H{"liked": !liked, "likesCount": cnt})
}

// POST /posts/:id/save
func TogglePostSave(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	var saved bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM post_saves WHERE post_id=$1::text AND user_id=$2::text)`,
		pid, myID).Scan(&saved)

	if saved {
		db.Pool.Exec(context.Background(),
			`DELETE FROM post_saves WHERE post_id=$1::text AND user_id=$2::text`, pid, myID)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO post_saves(post_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, pid, myID)
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"saved": !saved})
}
