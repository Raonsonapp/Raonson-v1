package handlers

import (
	"strconv"
	"context"
	"log"
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/sockets"
	"raonson/utils"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgconn"
)

// POST /posts
func CreatePost(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Caption       string                   `json:"caption"`
		Media         []map[string]interface{} `json:"media"`
		MusicTitle    string                   `json:"musicTitle"`
		MusicArtist   string                   `json:"musicArtist"`
		// Порчаи интихобкардаи муаллиф. Бе ин суруд ҳамеша аз сари
		// худ мехонд ва суроғааш умуман сабт намешуд.
		Song          *songInfo                `json:"song"`
		Location      string                   `json:"location"`
		// id-и ҷой аз рӯйхати /places (ихтиёрӣ; барномаҳои кӯҳна танҳо матн).
		LocationID    string                   `json:"locationId"`
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
		// Паёми худкор ба Direct аз рӯи калимаи шарҳ (ихтиёрӣ).
		AutoDM         *AutoDMInput            `json:"autoDm"`
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

	if b.AutoDM != nil {
		if msg := b.AutoDM.normalize(); msg != "" {
			c.JSON(http.StatusBadRequest, gin.H{"message": msg})
			return
		}
	}
	if b.IsProduct && !validPrice(b.Price) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Нарх бояд аз 0 то 100000 бошад"})
		return
	}
	// Ҳадди медиа ва номҳо — пеш маҳдуд набуд.
	if len(b.Media) > 10 || len(b.TaggedUsers) > 20 || len(b.Collaborators) > 5 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Аз ҳад зиёд: то 10 медиа, 20 нишон, 5 ҳамкор"})
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

	// Шакли нав `song`-ро мефиристад; барномаҳои кӯҳна танҳо ном ва
	// хонандаро — ҳарду қабул мешаванд.
	song := b.Song
	if song == nil {
		song = &songInfo{Title: b.MusicTitle, Artist: b.MusicArtist, EndMs: 15000}
	}
	song.clean()

	// «Ҷой»: матн + id ва координатаҳои ХУДИ ҶОЙ (на GPS-и корбар).
	locName, locID, locLat, locLon := resolvePostLocation(b.Location, b.LocationID)

	var postID string
	if err = tx.QueryRow(context.Background(),
		`INSERT INTO posts(user_id,caption,music_title,music_artist,music_url,music_art,
		                   music_track_ms,music_start_ms,music_end_ms,
		                   location,tagged_users,collaborators,scheduled_at,
		                   location_id,location_lat,location_lon)
		 VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16) RETURNING id`,
		// Ҳамкорон холӣ оғоз мешаванд: ном танҳо пас аз розигии
		// худи одам ба пост баста мешавад (ниг. collab.go).
		myID, b.Caption, song.Title, song.Artist, song.URL, song.ArtURL,
		song.TrackMs, song.StartMs, song.EndMs,
		locName, b.TaggedUsers,
		[]string{}, scheduledAt, locID, locLat, locLon).Scan(&postID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}

	for i, m := range b.Media {
		url, _ := m["url"].(string)
		t, _   := m["type"].(string)
		if t == "" { t = "image" }
		ar, _  := m["aspectRatio"].(float64) // JSON number → float64, default 0
		// Alt text — тавсифи расм барои нобиноён (TalkBack), мисли
		// Instagram. То 100 ҳарф.
		alt, _ := m["alt"].(string)
		alt = clampRunes(strings.TrimSpace(alt), 100)
		tx.Exec(context.Background(),
			`INSERT INTO post_media(post_id,url,type,position,aspect_ratio,alt_text)
			 VALUES($1,$2,$3,$4,$5,$6)`,
			postID, url, t, i, ar, alt)
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
	if scheduledAt != nil {
		// Огоҳиномаҳо дар вақти нашр мераванд (ниг. announceScheduledPosts).
		tx.Exec(context.Background(),
			`UPDATE posts SET announce_pending=TRUE WHERE id=$1`, postID)
	}
	if err := tx.Commit(context.Background()); err != nil {
		// Пеш хатои commit нодида гирифта мешуд ва 201 бармегашт.
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}

	// Invalidate feed cache for this user
	// Калидҳои воқеии кэши лента (feed:<id>:<mode>:<page>) — пеш
	// калиди нодуруст пок мешуд ва пости нав то 30 сония дида намешуд.
	invalidateFeedCache(myID)
	// ва cache-и middleware-и корбар (то пости нав фавран дар profile/feed
	// худи ӯ намоён шавад).
	mw.InvalidateUserCache(myID)
	if b.AutoDM != nil {
		saveAutoDM("post", postID, myID, *b.AutoDM)
	}

	// ⚠️ Пости вақтбандишуда: пеш зикрҳо ва паёми сокет ФАВРАН мерафтанд —
	// одамон пеш аз нашр мефаҳмиданд ва постро медиданд.
	if scheduledAt != nil {
		inviteCollaborators(postID, myID, b.Collaborators)
		c.JSON(http.StatusCreated, gin.H{"_id": postID, "caption": b.Caption,
			"scheduledAt": scheduledAt, "scheduled": true})
		return
	}

	// @зикр дар тавсиф — ҳар корбари зикршударо огоҳ кун
	notifyMentions(myID, "mention", postID, b.Caption, "шуморо дар публикатсия зикр кард")

	// ⚠️ Ин НАБУД. Зикр дар МАТН огоҳинома медод, вале зикр дар худи
	// АКС («На этом фото») не — одам ҳеҷ гоҳ намедонист, ки ӯро дар
	// пост нишон додаанд.
	//
	// `notifyMentions` матнро таҳлил мекунад, пас номҳоро ҳамчун
	// матни «@ном» медиҳем ва ҳамон роҳ кор мекунад.
	notifyTagged(myID, postID, b.TaggedUsers)
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
	"musicTitle":    song.Title,
	"musicArtist":   song.Artist,
	"song": songJSON(song.Title, song.Artist, song.ArtURL, song.URL,
		song.TrackMs, song.StartMs, song.EndMs),
	"location":      locName,
	"locationId":    locID,
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
	page   := clampPage(toInt(c.Query("page"), 1))
	limit  := clampLimit(toInt(c.Query("limit"), 20))
	offset := (page - 1) * limit

	// Cache key per user+page (30 sec TTL — fresh but fast)
	// ?mode=following — танҳо обунаҳо; ?mode=favorites — танҳо
	// дӯстдоштаҳо. Ҳарду бо тартиби ВАҚТ, мисли Instagram.
	mode := c.Query("mode")
	if mode != "following" && mode != "favorites" {
		mode = ""
	}
	cacheKey := "feed:" + myID + ":" + mode + ":" + strconv.Itoa(page) + mw.ContentEpoch()
	if page == 1 {
		if cached, ok := mw.CacheGet(cacheKey); ok {
			c.Header("X-Cache", "HIT")
			c.Data(http.StatusOK, "application/json", cached)
			return
		}
	}

	// Ҳамон шакли пост, ки профил ва ҳаштаг доранд (feedPostCols). Пеш
	// лента шакли худашро дошт — бе нишонҳо, ҳамкорон, пин, ҳалқаи
	// сторис ва шумораи паҳн (ҳамеша 0).
	rows, err := db.Pool.Query(context.Background(), feedPostCols+`
		WHERE COALESCE(p.archived,false) = FALSE
		  AND COALESCE(p.hidden,false) = FALSE
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())
		  AND `+visibleAuthorSQL("p.user_id", "u", "$1")+`
		  AND ($4 = '' OR p.user_id = $1::text AND $4 = 'following'
		       OR ($4 = 'following' AND EXISTS (SELECT 1 FROM follows ff
		             WHERE ff.follower_id=$1::text AND (ff.following_id=p.user_id
		               OR ff.following_id = ANY(COALESCE(p.collaborators,'{}')))))
		       OR ($4 = 'favorites' AND EXISTS (SELECT 1 FROM favorites fv
		             WHERE fv.user_id=$1::text AND fv.fav_id=p.user_id)))
		ORDER BY p.created_at DESC
		LIMIT $2 OFFSET $3`, myID, limit, offset, mode)
	if err != nil {
		log.Printf("[GetFeed] query error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get feed failed"})
		return
	}
	defer rows.Close()

	posts := scanFeedPosts(rows)
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
	// ⚠️ Ин НАБУД. Лента ва профил музикаро бармегардонданд, вале
	// худи пости кушодашуда НЕ — сатри музика нопадид мешуд.
	var mTitle, mArtist, mURL, mArt string
	var mTrackMs, mStartMs, mEndMs, mShares int

	err := db.Pool.QueryRow(context.Background(), `
		SELECT p.id, COALESCE(p.caption,''),
		       CASE WHEN COALESCE(p.hide_likes,false) AND p.user_id <> $2::text
		            THEN -1 ELSE p.likes_count END,
		       p.comments_count, p.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type,'alt',COALESCE(m.alt_text,''),'aspectRatio',COALESCE(m.aspect_ratio,0))
		                ORDER BY m.position),'[]'::json)
		        FROM post_media m WHERE m.post_id=p.id),
		       EXISTS(SELECT 1 FROM post_likes WHERE post_id=p.id AND user_id=$2::text),
		       EXISTS(SELECT 1 FROM post_saves  WHERE post_id=p.id AND user_id=$2::text),
		       COALESCE(p.hide_likes,false), COALESCE(p.comments_off,false),
		       COALESCE(p.is_product,false), COALESCE(p.price,0),
		       COALESCE(p.currency,'TJS'), COALESCE(p.product_name,''),
		       COALESCE(p.contact_raonson,false), COALESCE(p.shop_whatsapp,''),
		       COALESCE(p.shop_phone,''),
		       COALESCE(p.music_title,''), COALESCE(p.music_artist,''),
		       COALESCE(p.music_url,''), COALESCE(p.music_art,''),
		       COALESCE(p.music_track_ms,0), COALESCE(p.music_start_ms,0),
		       COALESCE(p.music_end_ms,0),
		       (SELECT COUNT(*) FROM post_shares sh WHERE sh.post_id=p.id)
		FROM posts p JOIN users u ON u.id=p.user_id WHERE p.id=$1
		  -- Пинҳоншуда (модератор), бойгонӣ ва ҳанӯз нашрнашуда — танҳо
		  -- ба муаллиф. Пеш бо id ба ҳама дастрас буданд.
		  AND (p.user_id=$2::text OR (COALESCE(p.hidden,false)=FALSE
		       AND COALESCE(p.archived,false)=FALSE
		       AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())))
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now() OR p.user_id=$2::text)`,
		pid, myID).Scan(&pid2, &cap, &likes, &comms, &createdAt,
		&uid, &uname, &uavatar, &verified, &media, &liked, &saved,
		&hideLikes, &commentsOff,
		&isProduct, &price, &currency, &productName,
		&contactRaonson, &shopWhatsapp, &shopPhone,
		&mTitle, &mArtist, &mURL, &mArt, &mTrackMs, &mStartMs, &mEndMs,
		&mShares)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	// Ҳисоби пӯшида / бастан. Пеш пости пӯшида аз рӯи ID (линк,
	// огоҳинома, паём) ба ҳар кас кушода мешуд. Ҳамон 404 — то
	// мавҷудияти пост ошкор нашавад.
	if ok, _ := CanSeeProfileContent(myID, uid); !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	// Майдонҳои шакли умумӣ (ҷой, нишонҳо, ҳамкорон, пин, ҳалқаи сторис)
	// аз feedPostCols — пеш пости аз огоҳинома кушодашуда онҳоро гум мекард.
	extra := gin.H{}
	if rows, err := db.Pool.Query(context.Background(),
		feedPostCols+` WHERE p.id=$2`, myID, pid2); err == nil {
		if list := scanFeedPosts(rows); len(list) == 1 {
			extra = list[0]
		}
	}
	userOut := gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified}
	if u, ok := extra["user"].(gin.H); ok {
		for _, k := range []string{"hasStory", "hasUnseenStory", "storySeen", "isFollowing"} {
			userOut[k] = u[k]
		}
	}
	// Тамошо — ҳамон COUNT(post_views), ки профил ва Explore медиҳанд.
	views := extra["viewsCount"]
	if views == nil {
		views = 0
	}
	salePct := extra["salePct"]
	if salePct == nil {
		salePct = 0
	}
	c.JSON(http.StatusOK, gin.H{
		"location": extra["location"], "locationId": extra["locationId"],
		"taggedUsers": extra["taggedUsers"],
		"collaborators": extra["collaborators"], "collaboratorUsers": extra["collaboratorUsers"],
		"isPinned": extra["isPinned"],
		"_id": pid2, "caption": cap, "likesCount": likes, "commentsCount": comms,
		"createdAt": createdAt, "media": nilToEmpty(media), "liked": liked, "saved": saved,
		"hideLikes": hideLikes, "commentsOff": commentsOff,
		"isProduct": isProduct, "price": price, "currency": currency,
		"salePct": salePct,
		"productName": productName, "contactRaonson": contactRaonson,
		"shopWhatsapp": shopWhatsapp, "shopPhone": shopPhone,
		"musicTitle": mTitle, "musicArtist": mArtist,
		"sharesCount": mShares,
		"viewsCount": views, "views": views,
		"song": songJSON(mTitle, mArtist, mArt, mURL,
			mTrackMs, mStartMs, mEndMs),
		"user": userOut,
	})
}

// GET /posts/scheduled — постҳои вақтбандишудаи корбар (ҳанӯз нашрнашуда)
func GetScheduledPosts(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT p.id, COALESCE(p.caption,''), p.scheduled_at,
		       (SELECT COALESCE(json_agg(
		                json_build_object('url',m.url,'type',m.type,'alt',COALESCE(m.alt_text,''),'aspectRatio',COALESCE(m.aspect_ratio,0))
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
	ctx := context.Background()
	// Маҳсулоте, ки фармоиш дорад, нест намешавад — пинҳон мешавад: вагарна
	// таърихи фармоишҳои харидор (JOIN posts) нопадид мешуд.
	var hasOrders bool
	db.Pool.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM orders WHERE post_id=$1)`, pid).Scan(&hasOrders)
	var res pgconn.CommandTag
	if hasOrders {
		res, _ = db.Pool.Exec(ctx, `UPDATE posts SET archived=TRUE, hidden=TRUE, in_stock=FALSE
			WHERE id=$1 AND user_id=$2::text`, pid, myID)
	} else {
		res, _ = db.Pool.Exec(ctx,
			`DELETE FROM posts WHERE id=$1 AND user_id=$2::text`, pid, myID)
	}
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	// Сатрҳои вобаста — пеш абадан мемонданд (огоҳиномаҳо ба пости нест
	// ишора мекарданд, папкаҳо муқоваи холӣ нишон медоданд).
	if !hasOrders {
		for _, q := range []string{
			`DELETE FROM post_media WHERE post_id=$1`,
			`DELETE FROM comment_likes WHERE comment_id IN (SELECT id FROM comments WHERE post_id=$1)`,
			`DELETE FROM comments WHERE post_id=$1`,
			`DELETE FROM post_likes WHERE post_id=$1`,
			`DELETE FROM post_saves WHERE post_id=$1`,
			`DELETE FROM post_shares WHERE post_id=$1`,
			`DELETE FROM post_views WHERE post_id=$1`,
			`DELETE FROM post_interests WHERE post_id=$1`,
			`DELETE FROM post_reports WHERE post_id=$1`,
			`DELETE FROM post_collab_invites WHERE post_id=$1`,
			`DELETE FROM saved_collection_items WHERE post_id=$1`,
			`DELETE FROM product_reviews WHERE post_id=$1`,
		} {
			db.Pool.Exec(ctx, q, pid)
		}
	}
	db.Pool.Exec(ctx, `DELETE FROM notifications WHERE target_id=$1`, pid)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET posts_count=GREATEST(posts_count-1,0) WHERE id=$1`, myID)
	// Cache-и корбарро пок мекунем, то пости ҳазфшуда фавран аз ҳама
	// экранҳо (profile, feed, explore) нест шавад.
	mw.InvalidateUserCache(myID)
	// ⚠️ Ду сатри боло кофӣ НЕСТ.
	//
	// `InvalidateUserCache` танҳо калидҳои ХУДИ соҳибро мепартояд,
	// вале `/explore` ва ҷустуҷӯ барои ҳар тамошобин калиди ҷудогона
	// доранд — ва `/explore` 5 дақиқа кэш мешуд. Маҳз барои ҳамин
	// пости ҳазфшуда «баъди 5 дақиқа» нест мешуд.
	mw.BumpContentEpoch()
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// POST /posts/:id/like
func TogglePostLike(c *gin.Context) {
	pid  := c.Param("id")
	myID := mw.UID(c)

	// Басташуда пости маро лайк карда наметавонад. Пеш метавонист —
	// ва ман огоҳиномаи лайкро аз ҳамон касе мегирифтам, ки бастам.
	if denyIfBlocked(c, myID, ownerOfPost(pid)) {
		return
	}

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
				pushNotify(ownerID, myID, "like", pid, "")
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

// notifyTagged — касони дар акс нишондодашуда.
func notifyTagged(authorID, postID string, tagged []string) {
	if len(tagged) == 0 {
		return
	}
	var sb strings.Builder
	for _, u := range tagged {
		u = strings.TrimPrefix(strings.TrimSpace(u), "@")
		if u == "" {
			continue
		}
		sb.WriteString("@" + u + " ")
	}
	notifyMentions(authorID, "mention", postID, sb.String(), "шуморо дар акс нишон дод")
}

// announceScheduledPosts — постҳое, ки вақти нашрашон расид: зикрҳо ва
// нишонҳо ҳоло огоҳ мешаванд, кэши лентаи обунаҳо пок мешавад.
func announceScheduledPosts() {
	rows, err := db.Pool.Query(context.Background(), `
		UPDATE posts SET announce_pending=FALSE
		WHERE announce_pending AND scheduled_at <= NOW()
		RETURNING id, user_id, COALESCE(caption,''), COALESCE(tagged_users,'{}')`)
	if err != nil {
		return
	}
	type due struct {
		id, user, caption string
		tagged            []string
	}
	list := []due{}
	for rows.Next() {
		var d due
		if rows.Scan(&d.id, &d.user, &d.caption, &d.tagged) == nil {
			list = append(list, d)
		}
	}
	rows.Close()
	for _, d := range list {
		notifyMentions(d.user, "mention", d.id, d.caption, "шуморо дар публикатсия зикр кард")
		notifyTagged(d.user, d.id, d.tagged)
		mw.InvalidateUserCache(d.user)
		mw.BumpContentEpoch()
	}
}

// StartScheduledPosts — ҳар дақиқа постҳои расидаро эълон мекунад.
func StartScheduledPosts() {
	go func() {
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for range t.C {
			announceScheduledPosts()
		}
	}()
}
