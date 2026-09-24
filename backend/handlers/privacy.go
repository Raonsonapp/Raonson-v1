package handlers

// Махфият: бастан ва ҳисоби пӯшида.
//
// ═══════════════════════════════════════════════════════════════════
//  Ин файл баъди санҷиши воқеӣ пайдо шуд. Он санҷиш нишон дод, ки
//  БАСТАН амалан танҳо ороиш буд:
//
//    • корбари басташуда постҳои маро МЕДИД;
//    • пости маро лайк карда МЕТАВОНИСТ;
//    • шарҳ навишта МЕТАВОНИСТ;
//    • обуна шуда МЕТАВОНИСТ;
//    • ба ман паём фиристода МЕТАВОНИСТ.
//
//  Ва ҳисоби ПӮШИДА постҳои худро ба ҳар бегона нишон медод —
//  қулфи дар профил ҳеҷ маъно надошт.
//
//  Сабаб: лентаи умумӣ ва Reels бастанро месанҷиданд
//  (`feed_algorithm.go`, `reels_algorithm.go`), вале роҳҳои
//  МУСТАҚИМ — `/users/:id/posts`, `/posts/:id/like`,
//  `/comments/:id`, `/follow/:id`, `/chat/:id/messages` — не.
//
//  Барои ҳамин санҷиш дар ЯК ҶО ҷамъ карда шуд ва аз ҳамон ҷо
//  даъват мешавад.
// ═══════════════════════════════════════════════════════════════════

import (
	"context"
	"net/http"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"

	"raonson/db"
)

// IsBlockedBetween — оё яке дигареро бастааст?
//
// Ҳарду тарафро месанҷад. Дар Instagram бастан ДУТАРАФА кор
// мекунад: касе ки шуморо баст, шумо ҳам ӯро намебинед.
func IsBlockedBetween(a, b string) bool {
	if a == "" || b == "" || a == b {
		return false
	}
	var blocked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM blocks
		  WHERE (blocker_id=$1 AND blocked_id=$2)
		     OR (blocker_id=$2 AND blocked_id=$1))`,
		a, b).Scan(&blocked)
	return blocked
}

// denyIfBlocked — ҳимояи кӯтоҳ барои handler-ҳо.
//
// `404` бармегардонад, на `403`. Ин қасдан аст: `403` худи
// мавҷудияти бастанро ошкор мекунад ва корбар мефаҳмад, ки ӯро
// бастаанд. Instagram низ ҳамин тавр мекунад — мавод танҳо «нест».
func denyIfBlocked(c *gin.Context, me, other string) bool {
	if !IsBlockedBetween(me, other) {
		return false
	}
	c.JSON(http.StatusNotFound, gin.H{"message": "Дастрас нест"})
	return true
}

// CanSeeProfileContent — оё `viewer` метавонад маводи `owner`-ро бинад?
//
// Се ҳолат:
//
//  1. худи соҳиб — ҳа, ҳамеша;
//  2. бастан (ҳар тараф) — не;
//  3. ҳисоби пӯшида ва обуна нашудааст — не.
//
// Бармегардонад: (иҷозат, сабаб).
func CanSeeProfileContent(viewer, owner string) (bool, string) {
	if owner == "" {
		return false, "not_found"
	}
	if viewer == owner {
		return true, ""
	}
	if IsBlockedBetween(viewer, owner) {
		return false, "blocked"
	}

	var isPrivate bool
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(is_private,false) FROM users WHERE id=$1`,
		owner).Scan(&isPrivate); err != nil {
		return false, "not_found"
	}
	if !isPrivate {
		return true, ""
	}

	// Ҳисоби пӯшида: танҳо обунашудагони ТАСДИҚШУДА мебинанд.
	if viewer == "" {
		return false, "private"
	}
	var follows bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM follows
		  WHERE follower_id=$1 AND following_id=$2)`,
		viewer, owner).Scan(&follows)
	if !follows {
		return false, "private"
	}
	return true, ""
}

// ownerOfPost — соҳиби пост. Барои санҷиши бастан пеш аз лайк.
//
// Ном `postOwner` НЕСТ: дар `AddComment` тағйирёбандаи маҳаллӣ бо
// ҳамон ном ҳаст ва функсияро мепӯшонад — хониш душвор мешуд.
func ownerOfPost(postID string) string {
	var uid string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id::text FROM posts WHERE id=$1`, postID).Scan(&uid)
	return uid
}

// visibleAuthorSQL — ЯК шарти SQL, ки дар ҳар рӯйхати пост/Reel
// истифода мешавад: муаллиф барои тамошобин намоён аст?
//
// ⚠️ Чаро ин лозим шуд. Санҷиши систематикии 26 дархост нишон дод,
// ки ТАНҲО профил (GetUserPosts) ҳисоби пӯшидаро ҳимоя мекард.
// Лента, лентаи ҳушманд, explore, ҷустуҷӯ, Reels, AI-ҷустуҷӯ ва
// ҳатто кушодани пост аз рӯи ID — ҳама постҳои ҳисоби пӯшидаро ба
// ҳар кас нишон медоданд. Лентаи оддӣ ҳатто бастшуда ва манъшударо
// филтр намекард. Қулфи «ҳисоби пӯшида» танҳо дар як экран кор мекард.
//
// Қоида (мисли Instagram): худам — ҳамеша; дигарон — танҳо агар
// манъ нашуда, байни мо бастан набошад, ва ҳисоб кушода бошад ё ман
// обуна бошам.
//
// authorCol — сутуни муаллиф (масалан "p.user_id"), userAlias —
// номи ҷадвали users дар дархост ("u"), viewer — параметри
// тамошобин ("$1").
func visibleAuthorSQL(authorCol, userAlias, viewer string) string {
	return `(` + authorCol + ` = ` + viewer + `::text OR (
	    COALESCE(` + userAlias + `.banned,false) = FALSE
	    AND NOT EXISTS (SELECT 1 FROM blocks vb
	         WHERE (vb.blocker_id = ` + viewer + `::text AND vb.blocked_id = ` + authorCol + `)
	            OR (vb.blocker_id = ` + authorCol + ` AND vb.blocked_id = ` + viewer + `::text))
	    AND (COALESCE(` + userAlias + `.is_private,false) = FALSE
	         OR EXISTS (SELECT 1 FROM follows vf
	              WHERE vf.follower_id = ` + viewer + `::text AND vf.following_id = ` + authorCol + `))))`
}

// publicAuthorSQL — барои кашф (explore, ҷустуҷӯ): мисли Instagram,
// дар кашф ТАНҲО ҳисобҳои кушода, ҳатто агар ман обуна бошам.
func publicAuthorSQL(authorCol, userAlias, viewer string) string {
	return `(COALESCE(` + userAlias + `.banned,false) = FALSE
	    AND COALESCE(` + userAlias + `.is_private,false) = FALSE
	    AND NOT EXISTS (SELECT 1 FROM blocks vb
	         WHERE (vb.blocker_id = ` + viewer + `::text AND vb.blocked_id = ` + authorCol + `)
	            OR (vb.blocker_id = ` + authorCol + ` AND vb.blocked_id = ` + viewer + `::text)))`
}

func ownerOfReel(reelID string) string {
	var uid string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id::text FROM reels WHERE id=$1`, reelID).Scan(&uid)
	return uid
}

// commentGate — оё myID дар зери мундариҷаи owner шарҳ навишта метавонад.
//
// Пеш ҳар handler танҳо қисман месанҷид: шарҳи пост блокро месанҷид,
// шарҳи Reel ҳеҷ чизро; танзими «Иҷозати шарҳ» умуман хонда намешуд ва
// ба пости ҳисоби пӯшида бо id шарҳ навиштан мумкин буд.
//
// Бармегардонад: (иҷозат, пинҳон кардан?). «Пинҳон» — корбари маҳдудшуда
// (restrict): шарҳ сабт мешавад, вале танҳо худаш онро мебинад.
func commentGate(c *gin.Context, me, owner string) (bool, bool) {
	if owner == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return false, false
	}
	if denyIfBlocked(c, me, owner) {
		return false, false
	}
	if ok, _ := CanSeeProfileContent(me, owner); !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return false, false
	}
	if me == owner {
		return true, false
	}
	allow := true
	var restricted bool
	db.Pool.QueryRow(context.Background(), `
		SELECT COALESCE(u.allow_comments,true),
		       EXISTS(SELECT 1 FROM user_restricts r
		              WHERE r.user_id=u.id AND r.restricted_id=$2)
		FROM users u WHERE u.id=$1`, owner, me).Scan(&allow, &restricted)
	if !allow {
		c.JSON(http.StatusForbidden, gin.H{"message": "Муаллиф шарҳҳоро хомӯш кардааст"})
		return false, false
	}
	return true, restricted
}

// RequireVisible — middleware барои амалҳо бо пост ё Reel (лайк, сабт,
// паҳн). Пеш ҳар кас бо донистани id метавонист ба пости ҳисоби пӯшида
// ё бастакунанда лайк гузорад, онро сабт ва паҳн кунад.
//
// kind: "post" ё "reel". Ҷавоб барои «нест», «пӯшида» ва «баста» як
// хел аст (404) — вуҷуди мундариҷа фош намешавад.
func RequireVisible(kind string) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		owner := ""
		if kind == "reel" {
			owner = ownerOfReel(id)
		} else {
			owner = ownerOfPost(id)
		}
		if ok, _ := CanSeeProfileContent(mw.UID(c), owner); !ok {
			c.AbortWithStatusJSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
			return
		}
		c.Next()
	}
}
