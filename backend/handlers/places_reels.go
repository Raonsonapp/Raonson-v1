package handlers

import (
	"context"
	"net/http"
	"strings"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/places"

	"github.com/gin-gonic/gin"
)

// «Ҷой»-и Reels. Пеш reels умуман ҷой надоштанд: на дар сохтан, на
// дар экрани reel, на дар саҳифаи ҷой.

// attachReelLocations — «Ҷой»-и reels ба рӯйхати тайёр (як дархост).
//
// Reels аз панҷ роҳи гуногун меоянд (лента, smart, профил, explore,
// ягона); ба ҷои иваз кардани ҳар SELECT/Scan ҷой баъдтар илова мешавад.
func attachReelLocations(reels []gin.H) {
	ids := make([]string, 0, len(reels))
	for _, r := range reels {
		r["location"], r["locationId"] = "", ""
		if id, _ := r["_id"].(string); id != "" {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 || db.Pool == nil {
		return
	}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT id, COALESCE(location,''), COALESCE(location_id,'')
		FROM reels WHERE id = ANY($1) AND COALESCE(location,'') <> ''`, ids)
	if err != nil {
		return
	}
	defer rows.Close()
	type loc struct{ name, id string }
	found := map[string]loc{}
	for rows.Next() {
		var id, name, pid string
		if rows.Scan(&id, &name, &pid) == nil {
			found[id] = loc{name, pid}
		}
	}
	for _, r := range reels {
		if id, _ := r["_id"].(string); id != "" {
			if l, ok := found[id]; ok {
				r["location"], r["locationId"] = l.name, l.id
			}
		}
	}
}

// GET /places/:id/reels — таби «Reels»-и саҳифаи ҷой. Ҳамон шартҳои
// кашф, ки постҳо доранд: танҳо ҳисобҳои кушода, бе бастшуда/манъшуда.
func PlaceReels(c *gin.Context) {
	p := places.Get(c.Param("id"))
	if p == nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ҷой ёфт нашуд", "reels": []gin.H{}})
		return
	}
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 24))
	placeReelsQuery(c, `(r.location_id = $2
	       OR (COALESCE(r.location_id,'') = '' AND r.location = ANY($5::text[])))`,
		mw.UID(c), p.ID, limit, (page-1)*limit, p.TextVariants())
}

// GET /places/text/reels?name= — ҷойи дастӣ (бе id), мисли постҳо.
func PlaceTextReels(c *gin.Context) {
	name := strings.TrimSpace(c.Query("name"))
	if name == "" || len([]rune(name)) > 120 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "name лозим аст", "reels": []gin.H{}})
		return
	}
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 24))
	placeReelsQuery(c, `COALESCE(r.location_id,'') = '' AND r.location = $2`,
		mw.UID(c), name, limit, (page-1)*limit)
}

// placeReelsQuery — $1 тамошобин, $2 ҷой, $3 limit, $4 offset.
func placeReelsQuery(c *gin.Context, where string, args ...interface{}) {
	rows, err := db.Pool.Query(context.Background(), `
		SELECT r.id, r.video_url, COALESCE(r.video_url_low,''),
		       COALESCE(r.thumbnail_url,''), COALESCE(r.caption,''),
		       COALESCE(r.views_count,0),
		       CASE WHEN COALESCE(r.hide_likes,false) AND r.user_id <> $1::text
		            THEN -1 ELSE COALESCE(r.likes_count,0) END,
		       COALESCE(r.comments_count,0), r.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$1::text),
		       EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$1::text),
		       EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=$1::text AND f.following_id=r.user_id),
		       COALESCE(r.hide_likes,false), COALESCE(r.comments_off,false),
		       COALESCE(r.audio_id,''), COALESCE(r.audio_title,''),
		       COALESCE(r.audio_artist,''), COALESCE(r.audio_cover,'')
		FROM reels r JOIN users u ON u.id=r.user_id
		WHERE `+where+`
		  AND COALESCE(r.media_missing,false)=FALSE
		  AND `+publicAuthorSQL("r.user_id", "u", "$1")+`
		ORDER BY r.created_at DESC LIMIT $3 OFFSET $4`, args...)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var rid, vurl, vurlLow, thumb, capt, uid, uname, uavatar string
			var aID, aTitle, aArtist, aCover string
			var views, likes, comms int
			var verified, liked, saved, following, hideLikes, commentsOff bool
			var createdAt interface{}
			if rows.Scan(&rid, &vurl, &vurlLow, &thumb, &capt, &views, &likes, &comms,
				&createdAt, &uid, &uname, &uavatar, &verified, &liked, &saved, &following,
				&hideLikes, &commentsOff, &aID, &aTitle, &aArtist, &aCover) != nil {
				continue
			}
			out = append(out, gin.H{
				"_id": rid, "videoUrl": vurl, "videoUrlLow": vurlLow,
				"thumbnailUrl": thumb, "caption": capt,
				"viewsCount": views, "views": views, "likesCount": likes,
				"commentsCount": comms, "createdAt": createdAt,
				"isLiked": liked, "isSaved": saved,
				"hideLikes": hideLikes, "commentsDisabled": commentsOff,
				"audio": reelAudioJSON(aID, aTitle, aArtist, aCover, uname),
				"user": gin.H{"_id": uid, "id": uid, "username": uname,
					"avatar": uavatar, "verified": verified, "isFollowing": following},
			})
		}
	}
	attachReelLocations(out)
	attachReelShares(out)
	c.JSON(http.StatusOK, gin.H{"reels": out})
}
