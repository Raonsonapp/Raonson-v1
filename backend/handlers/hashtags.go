package handlers

// Хештегҳо — мисли Instagram.
//
//   GET    /hashtags/:tag           — сарлавҳа: шумора, обуна, хештегҳои алоқаманд
//   GET    /hashtags/:tag/top       — «Беҳтарин» (постҳо + Reels, саҳифа-саҳифа)
//   GET    /hashtags/:tag/recent    — «Нав»
//   GET    /hashtags/search?q=      — пешниҳод ва таби «Хештегҳо» (бо шумора)
//   GET    /hashtags/trending       — «Трендҳо» (афзоиши 48 соат бар 48 соати пеш)
//   GET    /hashtags/following      — хештегҳои обунашуда
//   POST   /hashtags/:tag/follow    — обуна
//   DELETE /hashtags/:tag/follow    — бекор
//
// Ҳамаи рӯйхатҳо аз content_hashtags (backend/hashtags — қоидаи ягона бо
// барнома) ва ҳамон қоидаи намоёнӣ, ки лента дорад (visibleAuthorSQL:
// бастан, ҳисоби пӯшида, манъшуда; пости пинҳон/бойгонӣ/вақтбандӣ ва
// Reel-и интизори санҷиш намеояд). Хештеги манъшуда (рӯйхати
// модератсия) — саҳифаи холӣ бо огоҳӣ.

import (
	"context"
	"log"
	"math"
	"net/http"
	"strings"

	"raonson/db"
	"raonson/hashtags"
	mw "raonson/middleware"
	"raonson/moderation"

	"github.com/gin-gonic/gin"
)

// HashtagHiddenNotice — матни саҳифаи хештеги манъшуда.
const HashtagHiddenNotice = "Постҳо барои ин хештег пинҳон карда шудаанд"

// syncContentHashtags — индекси хештегҳои пост/Reel. Хато пинҳон
// намешавад, вале нашрро манъ намекунад.
func syncContentHashtags(ctx context.Context, q hashtags.Execer, kind, id, caption string) {
	if err := hashtags.Sync(ctx, q, kind, id, caption); err != nil {
		log.Printf("[hashtags] sync %s %s: %v", kind, id, err)
	}
}

// dropContentHashtags — пост/Reel нест шуд.
func dropContentHashtags(kind, id string) {
	hashtags.Remove(context.Background(), db.Pool, kind, id)
}

// taggedVisibleSQL — мӯҳтавои намоёни хештегдор:
// (kind, id, user_id, tag, created_at, likes, comments, views).
//
// tagCond — шарт бар `ch` (масалан "ch.tag = $2"), viewer — параметри
// тамошобин. public=true — танҳо ҳисобҳои кушода (тренд — кашфи умумӣ).
func taggedVisibleSQL(tagCond, viewer string, public bool) string {
	author := visibleAuthorSQL
	if public {
		author = publicAuthorSQL
	}
	return `
	  SELECT 'post'::text AS kind, p.id AS id, p.user_id AS user_id, ch.tag AS tag,
	         p.created_at AS created_at,
	         COALESCE(p.likes_count,0)::float8 AS likes,
	         COALESCE(p.comments_count,0)::float8 AS comments,
	         0::float8 AS views
	    FROM content_hashtags ch
	    JOIN posts p ON p.id = ch.content_id
	    JOIN users u ON u.id = p.user_id
	   WHERE ch.content_kind = 'post' AND ` + tagCond + `
	     AND COALESCE(p.hidden,false) = FALSE
	     AND COALESCE(p.archived,false) = FALSE
	     AND (p.scheduled_at IS NULL OR p.scheduled_at <= NOW())
	     AND ` + author("p.user_id", "u", viewer) + `
	  UNION ALL
	  SELECT 'reel'::text, r.id, r.user_id, ch.tag, r.created_at,
	         COALESCE(r.likes_count,0)::float8,
	         COALESCE(r.comments_count,0)::float8,
	         COALESCE(r.views_count,0)::float8
	    FROM content_hashtags ch
	    JOIN reels r ON r.id = ch.content_id
	    JOIN users u ON u.id = r.user_id
	   WHERE ch.content_kind = 'reel' AND ` + tagCond + `
	     AND COALESCE(r.media_missing,false) = FALSE
	     AND ` + author("r.user_id", "u", viewer)
}

// tagParam — :tag-и URL → шакли муқаррарӣ. false — 400 фиристода шуд.
func tagParam(c *gin.Context) (string, bool) {
	tag, ok := hashtags.Normalize(c.Param("tag"))
	if !ok {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Хештеги нодуруст"})
		return "", false
	}
	return tag, true
}

// countTagged — шумораи постҳо + Reels-и намоён.
func countTagged(ctx context.Context, viewer, tag string) int64 {
	var n int64
	db.Pool.QueryRow(ctx,
		`SELECT COUNT(*) FROM (`+taggedVisibleSQL("ch.tag = $2", "$1", false)+`) v`,
		viewer, tag).Scan(&n)
	return n
}

func isFollowingTag(ctx context.Context, uid, tag string) bool {
	var f bool
	db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM hashtag_follows WHERE user_id=$1 AND tag=$2)`,
		uid, tag).Scan(&f)
	return f
}

// relatedTags — хештегҳое, ки бо ин хештег якҷоя меоянд (то 8).
func relatedTags(ctx context.Context, viewer, tag string) []gin.H {
	out := []gin.H{}
	rows, err := db.Pool.Query(ctx, `
		WITH v AS (`+taggedVisibleSQL("ch.tag = $2", "$1", false)+`)
		SELECT ch2.tag, COUNT(*) AS n
		  FROM v JOIN content_hashtags ch2
		    ON ch2.content_kind = v.kind AND ch2.content_id = v.id AND ch2.tag <> $2
		 GROUP BY ch2.tag
		 ORDER BY n DESC, ch2.tag
		 LIMIT 24`, viewer, tag)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var t string
		var n int64
		if rows.Scan(&t, &n) != nil || moderation.HashtagBlocked(t) {
			continue
		}
		if len(out) < 8 {
			out = append(out, gin.H{"tag": t, "count": n})
		}
	}
	return out
}

// GET /hashtags/:tag
func GetHashtag(c *gin.Context) {
	tag, ok := tagParam(c)
	if !ok {
		return
	}
	myID := mw.UID(c)
	ctx := c.Request.Context()
	if moderation.HashtagBlocked(tag) {
		c.JSON(http.StatusOK, gin.H{
			"tag": tag, "postsCount": 0, "following": false,
			"related": []gin.H{}, "hidden": true, "notice": HashtagHiddenNotice,
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"tag":        tag,
		"postsCount": countTagged(ctx, myID, tag),
		"following":  isFollowingTag(ctx, myID, tag),
		"related":    relatedTags(ctx, myID, tag),
		"hidden":     false,
	})
}

// GET /hashtags/:tag/top
func HashtagTop(c *gin.Context) { hashtagGrid(c, true) }

// GET /hashtags/:tag/recent
func HashtagRecent(c *gin.Context) { hashtagGrid(c, false) }

func hashtagGrid(c *gin.Context, top bool) {
	tag, ok := tagParam(c)
	if !ok {
		return
	}
	myID := mw.UID(c)
	ctx := c.Request.Context()
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 24))
	if limit > 60 {
		limit = 60
	}
	if moderation.HashtagBlocked(tag) {
		c.JSON(http.StatusOK, gin.H{"tag": tag, "items": []gin.H{}, "page": page,
			"limit": limit, "hasMore": false, "hidden": true, "notice": HashtagHiddenNotice})
		return
	}
	// «Беҳтарин»: ҷалб (лайк, шарҳ ×2, тамошои Reel) нисбат ба синну сол —
	// пости кӯҳнаи машҳур поён меравад, нави фаъол боло меояд.
	order := `v.created_at DESC, v.id DESC`
	if top {
		order = `(v.likes + 2*v.comments + LEAST(v.views, 20000)*0.02 + 1)
		         / POWER(GREATEST(EXTRACT(EPOCH FROM (NOW() - v.created_at)), 0)/3600 + 2, 0.5) DESC,
		         v.created_at DESC, v.id DESC`
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT v.kind, v.id FROM (`+taggedVisibleSQL("ch.tag = $2", "$1", false)+`) v
		ORDER BY `+order+`
		LIMIT $3 OFFSET $4`, myID, tag, limit+1, (page-1)*limit)
	if err != nil {
		log.Printf("[hashtags] grid %s: %v", tag, err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	type ref struct{ kind, id string }
	var refs []ref
	var postIDs, reelIDs []string
	for rows.Next() {
		var r ref
		if rows.Scan(&r.kind, &r.id) == nil {
			refs = append(refs, r)
		}
	}
	rows.Close()
	hasMore := len(refs) > limit
	if hasMore {
		refs = refs[:limit]
	}
	for _, r := range refs {
		if r.kind == "reel" {
			reelIDs = append(reelIDs, r.id)
		} else {
			postIDs = append(postIDs, r.id)
		}
	}
	posts := map[string]gin.H{}
	if len(postIDs) > 0 {
		if pr, err := db.Pool.Query(ctx, feedPostCols+` WHERE p.id = ANY($2::text[])`,
			myID, postIDs); err == nil {
			for _, p := range scanFeedPosts(pr) {
				id, _ := p["_id"].(string)
				p["kind"] = "post"
				posts[id] = p
			}
		}
	}
	reels := reelsByIDs(ctx, myID, reelIDs)
	items := make([]gin.H, 0, len(refs))
	for _, r := range refs {
		var it gin.H
		if r.kind == "reel" {
			it = reels[r.id]
		} else {
			it = posts[r.id]
		}
		if it != nil {
			items = append(items, it)
		}
	}
	c.JSON(http.StatusOK, gin.H{"tag": tag, "items": items, "page": page,
		"limit": limit, "hasMore": hasMore, "hidden": false})
}

// reelsByIDs — Reels бо ҳамон шакле, ки /reels медиҳад (+ kind).
func reelsByIDs(ctx context.Context, myID string, ids []string) map[string]gin.H {
	out := map[string]gin.H{}
	if len(ids) == 0 {
		return out
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT r.id, r.video_url, COALESCE(r.video_url_low,''),
		       COALESCE(r.thumbnail_url,''), COALESCE(r.caption,''), COALESCE(r.views_count,0),
		       CASE WHEN COALESCE(r.hide_likes,false) AND r.user_id <> $1::text
		            THEN -1 ELSE COALESCE(r.likes_count,0) END,
		       COALESCE(r.comments_count,0), r.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$1::text),
		       EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$1::text),
		       EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=$1::text AND f.following_id=r.user_id),
		       COALESCE(r.hide_likes,false), COALESCE(r.comments_off,false),
		       `+storyRingCols("r.user_id", "$1")+`,
		       COALESCE(r.audio_id,''), COALESCE(r.audio_title,''),
		       COALESCE(r.audio_artist,''), COALESCE(r.audio_cover,'')
		FROM reels r JOIN users u ON u.id=r.user_id
		WHERE r.id = ANY($2::text[])`, myID, ids)
	if err != nil {
		log.Printf("[hashtags] reels: %v", err)
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var rid, vurl, vurlLow, thumb, cap, uid, uname, uavatar string
		var audioID, audioTitle, audioArtist, audioCover string
		var views, likes, comms int
		var verified, liked, saved, following, hideLikes, commentsOff, hasStory, unseenStory bool
		var createdAt interface{}
		if rows.Scan(&rid, &vurl, &vurlLow, &thumb, &cap, &views, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &liked, &saved, &following,
			&hideLikes, &commentsOff, &hasStory, &unseenStory,
			&audioID, &audioTitle, &audioArtist, &audioCover) != nil {
			continue
		}
		out[rid] = gin.H{
			"kind": "reel",
			"_id":  rid, "videoUrl": vurl, "videoUrlLow": vurlLow,
			"thumbnailUrl": thumb, "caption": cap,
			"viewsCount": views, "views": views, "likesCount": likes, "commentsCount": comms,
			"isLiked": liked, "isSaved": saved, "createdAt": createdAt,
			"hideLikes": hideLikes, "commentsDisabled": commentsOff,
			"audio": reelAudioJSON(audioID, audioTitle, audioArtist, audioCover, uname),
			"user": putStoryRing(gin.H{"_id": uid, "id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "isFollowing": following}, hasStory, unseenStory),
		}
	}
	list := make([]gin.H, 0, len(out))
	for _, r := range out {
		list = append(list, r)
	}
	attachReelShares(list)
	return out
}

// likeEscape — «_» ва «%» дар LIKE ҳарфи оддӣ мешаванд («#hello_» ≠ «#helloX»).
func likeEscape(s string) string {
	return strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(s)
}

// searchTags — хештегҳое, ки бо [prefix] сар мешаванд, аз рӯи истифода.
func searchTags(ctx context.Context, viewer, prefix string, limit int) []gin.H {
	out := []gin.H{}
	q, ok := hashtags.NormalizePrefix(prefix)
	if !ok {
		return out
	}
	rows, err := db.Pool.Query(ctx, `
		WITH v AS (`+taggedVisibleSQL(`ch.tag LIKE $2 ESCAPE '\'`, "$1", false)+`)
		SELECT v.tag, COUNT(*) AS n,
		       EXISTS(SELECT 1 FROM hashtag_follows hf WHERE hf.user_id=$1::text AND hf.tag=v.tag)
		  FROM v
		 GROUP BY v.tag
		 ORDER BY (v.tag = $3) DESC, n DESC, v.tag
		 LIMIT $4`, viewer, likeEscape(q)+"%", q, limit*2)
	if err != nil {
		log.Printf("[hashtags] search: %v", err)
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var t string
		var n int64
		var following bool
		if rows.Scan(&t, &n, &following) != nil || moderation.HashtagBlocked(t) {
			continue
		}
		if len(out) < limit {
			// "count" — шакли кӯҳнаи /search; "postsCount" — шакли нав.
			out = append(out, gin.H{"tag": t, "count": n, "postsCount": n, "following": following})
		}
	}
	return out
}

// GET /hashtags/search?q=
func SearchHashtags(c *gin.Context) {
	limit := clampLimit(toInt(c.Query("limit"), 20))
	if limit > 50 {
		limit = 50
	}
	c.JSON(http.StatusOK, gin.H{
		"hashtags": searchTags(c.Request.Context(), mw.UID(c), c.Query("q"), limit),
	})
}

// GET /hashtags/trending — афзоиши истифода: 48 соати охир бар 48 соати пеш.
//
// Хол = муаллифони гуногун × (истифодаи ҳозира+1)/(пештара+1): як нафар бо
// 50 пост тренд сохта наметавонад, хештеги ҳамешагӣ бе афзоиш поён меравад.
// Танҳо ҳисобҳои кушода (кашфи умумӣ) ва бе хештегҳои манъшуда.
func TrendingHashtags(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(c.Request.Context(), `
		WITH v AS (`+taggedVisibleSQL(`ch.created_at > NOW() - INTERVAL '96 hours'`, "$1", true)+`),
		agg AS (
		  SELECT v.tag,
		         COUNT(*) FILTER (WHERE v.created_at >  NOW() - INTERVAL '48 hours') AS cur,
		         COUNT(*) FILTER (WHERE v.created_at <= NOW() - INTERVAL '48 hours') AS prev,
		         COUNT(DISTINCT v.user_id) FILTER (WHERE v.created_at > NOW() - INTERVAL '48 hours') AS authors
		    FROM v GROUP BY v.tag)
		SELECT tag, cur, prev,
		       EXISTS(SELECT 1 FROM hashtag_follows hf WHERE hf.user_id=$1::text AND hf.tag=agg.tag)
		  FROM agg
		 WHERE cur > 0
		 ORDER BY authors::float8 * (cur + 1) / (prev + 1) DESC, cur DESC, tag
		 LIMIT 60`, myID)
	out := []gin.H{}
	if err != nil {
		log.Printf("[hashtags] trending: %v", err)
		c.JSON(http.StatusOK, gin.H{"trending": out})
		return
	}
	defer rows.Close()
	for rows.Next() {
		var t string
		var cur, prev int64
		var following bool
		if rows.Scan(&t, &cur, &prev, &following) != nil || moderation.HashtagBlocked(t) {
			continue
		}
		if len(out) >= 20 {
			continue
		}
		var growth interface{}
		if prev > 0 {
			growth = math.Round(float64(cur-prev) / float64(prev) * 100)
		}
		out = append(out, gin.H{"tag": t, "postsCount": cur, "count": cur,
			"previousCount": prev, "growthPct": growth, "following": following})
	}
	c.JSON(http.StatusOK, gin.H{"trending": out})
}

// POST /hashtags/:tag/follow
func FollowHashtag(c *gin.Context) {
	tag, ok := tagParam(c)
	if !ok {
		return
	}
	if moderation.HashtagBlocked(tag) {
		c.JSON(http.StatusBadRequest, gin.H{"message": HashtagHiddenNotice, "hidden": true})
		return
	}
	myID := mw.UID(c)
	var n int
	db.Pool.QueryRow(c.Request.Context(),
		`SELECT COUNT(*) FROM hashtag_follows WHERE user_id=$1`, myID).Scan(&n)
	if n >= 500 && !isFollowingTag(c.Request.Context(), myID, tag) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "То 500 хештег обуна шудан мумкин аст"})
		return
	}
	if _, err := db.Pool.Exec(c.Request.Context(),
		`INSERT INTO hashtag_follows(user_id, tag) VALUES($1,$2) ON CONFLICT DO NOTHING`,
		myID, tag); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	invalidateFeedCache(myID)
	c.JSON(http.StatusOK, gin.H{"tag": tag, "following": true})
}

// DELETE /hashtags/:tag/follow
func UnfollowHashtag(c *gin.Context) {
	tag, ok := tagParam(c)
	if !ok {
		return
	}
	myID := mw.UID(c)
	db.Pool.Exec(c.Request.Context(),
		`DELETE FROM hashtag_follows WHERE user_id=$1 AND tag=$2`, myID, tag)
	invalidateFeedCache(myID)
	c.JSON(http.StatusOK, gin.H{"tag": tag, "following": false})
}

// GET /hashtags/following — хештегҳои обунашуда (навтаринҳо аввал).
func FollowedHashtags(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT hf.tag, hf.created_at,
		       (SELECT COUNT(*) FROM (`+taggedVisibleSQL("ch.tag = hf.tag", "$1", false)+`) v)
		  FROM hashtag_follows hf
		 WHERE hf.user_id = $1
		 ORDER BY hf.created_at DESC
		 LIMIT 500`, myID)
	out := []gin.H{}
	if err != nil {
		log.Printf("[hashtags] following: %v", err)
		c.JSON(http.StatusOK, gin.H{"hashtags": out})
		return
	}
	defer rows.Close()
	for rows.Next() {
		var t string
		var at interface{}
		var n int64
		if rows.Scan(&t, &at, &n) != nil {
			continue
		}
		out = append(out, gin.H{"tag": t, "followedAt": at, "postsCount": n, "following": true})
	}
	c.JSON(http.StatusOK, gin.H{"hashtags": out})
}
