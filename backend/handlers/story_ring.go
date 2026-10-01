package handlers

import (
	"context"
	"fmt"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── Ҳалқаи сторис: ЯК қоида барои ҳамаи экранҳо ──────────────────
//
// ⚠️ Пеш ҳар handler `hasStory`-ро бо EXISTS-и худ ҳисоб мекард ва
// ҲЕҶ кадоме намегуфт, ки тамошобин сторисҳоро аллакай дидааст. Пас
// баъди тамошои сторис ҳалқа дар лентаи Home (PostCard), Reels,
// Explore ва профил ранга (teal) мемонд, гарчанде дар сатри сторис
// хокистарӣ шуда буд.
//
// Ҳоло ҳамаи payload-ҳо (лента, reels, профил, explore, ҷустуҷӯ,
// чатҳо, шарҳҳо) аз ҳамин ду ифода мегузаранд:
//
//	hasStory        — муаллиф сториси фаъоли ба тамошобин намоён дорад
//	                  (ҳамон филтри GET /stories: обуна, «наздикон»,
//	                  блок, хомӯш, архив, мӯҳлат);
//	hasUnseenStory  — ақаллан яке аз онҳо дар story_seen-и тамошобин нест.
//
// ва ба JSON ҳамчун `hasStory`, `hasUnseenStory`, `storySeen` мераванд.

// storyVisibleSQL — шарти «сториси s ба тамошобин намоён аст» (alias s).
func storyVisibleSQL(userCol, viewer string) string {
	return fmt.Sprintf(`s.user_id=%[1]s AND s.expires_at > NOW()
	   AND COALESCE(s.archived,false)=FALSE
	   AND (s.user_id=%[2]s OR EXISTS(SELECT 1 FROM follows hf
	        WHERE hf.follower_id=%[2]s AND hf.following_id=s.user_id))
	   AND (s.user_id=%[2]s OR COALESCE(s.audience,'all')='all'
	        OR EXISTS(SELECT 1 FROM close_friends hcf
	           WHERE hcf.user_id=s.user_id AND hcf.friend_id=%[2]s))
	   AND (s.user_id=%[2]s OR NOT EXISTS(SELECT 1 FROM blocks hb
	        WHERE (hb.blocker_id=%[2]s AND hb.blocked_id=s.user_id)
	           OR (hb.blocker_id=s.user_id AND hb.blocked_id=%[2]s)))
	   AND (s.user_id=%[2]s OR NOT EXISTS(SELECT 1 FROM muted_users hmu
	        WHERE hmu.user_id=%[2]s AND hmu.muted_id=s.user_id))`, userCol, viewer)
}

// storyRingCols — ду сутун: has_story, has_unseen_story.
//
//	userCol — сутуни муаллиф (мас. "u.id", "r.user_id");
//	viewer  — параметри тамошобин (мас. "$1").
func storyRingCols(userCol, viewer string) string {
	v := viewer + "::text"
	vis := storyVisibleSQL(userCol, v)
	return fmt.Sprintf(`EXISTS(SELECT 1 FROM stories s WHERE %[1]s) AS has_story,
	   EXISTS(SELECT 1 FROM stories s WHERE %[1]s
	          AND NOT EXISTS(SELECT 1 FROM story_seen hss
	                 WHERE hss.story_id=s.id AND hss.user_id=%[2]s)) AS has_unseen_story`, vis, v)
}

// putStoryRing — майдонҳои ҳалқаро ба объекти корбар менависад.
func putStoryRing(u gin.H, has, unseen bool) gin.H {
	u["hasStory"] = has
	u["hasUnseenStory"] = has && unseen
	u["storySeen"] = has && !unseen
	return u
}

// setStoryRing — ҳалқаи як корбар (профил, /users/:id) барои тамошобин.
func setStoryRing(u gin.H, viewer, target string) {
	var has, unseen bool
	if target != "" {
		db.Pool.QueryRow(context.Background(),
			`SELECT `+storyRingCols("$2::text", "$1"), viewer, target).
			Scan(&has, &unseen)
	}
	putStoryRing(u, has, unseen)
}

// invalidateStoryRingCaches — баъди «дидам» кэшҳои шахсии тамошобин
// (middleware ва smart feed/reels) партофта мешаванд, то ҳалқа дар
// дархости навбатӣ ФАВРАН хокистарӣ ояд.
func invalidateStoryRingCaches(viewer string) {
	if viewer == "" {
		return
	}
	mw.InvalidateUserCache(viewer)
	mw.LocalDelPrefix("feed:" + viewer + ":")
	mw.LocalDelPrefix("smartfeed:" + viewer + ":")
	mw.LocalDelPrefix("smartreels:" + viewer + ":")
	mw.LocalDelPrefix("profile:u:" + viewer + ":")
	mw.LocalDelPrefix("profile:me:" + viewer)
}
