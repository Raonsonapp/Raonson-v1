package handlers

import (
	"time"
	"context"
	"log"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ── COMMENTS ─────────────────────────────────────────────────────

// POST /comments/:id  (id = postID)
func AddComment(c *gin.Context) {
	postID := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Text     string `json:"text"`
		ParentID string `json:"parentId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Comment text required"})
		return
	}
	b.Text = clampRunes(b.Text, 1000)

	var exists, commentsOff bool
	db.Pool.QueryRow(context.Background(),
		`SELECT TRUE, COALESCE(comments_off,false) FROM posts WHERE id=$1`,
		postID).Scan(&exists, &commentsOff)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	if commentsOff {
		c.JSON(http.StatusForbidden, gin.H{"message": "Шарҳҳо барои ин пост хомӯш карда шудаанд"})
		return
	}

	var postOwner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM posts WHERE id=$1`, postID).Scan(&postOwner)

	// Блок, ҳисоби пӯшида, «Иҷозати шарҳ» ва restrict — ҳама дар як ҷо.
	allowed, restricted := commentGate(c, myID, postOwner)
	if !allowed {
		return
	}
	// Ҷавоб танҳо ба шарҳи ҲАМИН пост.
	if b.ParentID != "" {
		var same bool
		db.Pool.QueryRow(context.Background(),
			`SELECT EXISTS(SELECT 1 FROM comments WHERE id=$1 AND post_id=$2)`,
			b.ParentID, postID).Scan(&same)
		if !same {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Шарҳи асл ёфт нашуд"})
			return
		}
	}

	// Модератсия (18+, дашном, линкҳо) — пас аз санҷишҳои арзон.
	modReq := modRequest{Surface: "comment", Texts: []string{b.Text}, AI: true}
	mod, modOK := screenContent(c, myID, modReq)
	if !modOK {
		return
	}

	// ⚠️ Калимаҳои пинҳони СОҲИБИ ПОСТ, на нависанда.
	//
	// Шарҳ РАД НАМЕШАВАД — он пинҳон мешавад. Агар рад мешуд,
	// нависанда фавран мефаҳмид ва роҳи гузаштанро меҷуст.
	// Корбари маҳдудшуда (restrict) — ҳамин тавр: танҳо худаш мебинад.
	ownerHidden := restricted || containsHiddenWord(b.Text,
		hiddenWordsOf(context.Background(), postOwner))
	// Шубҳанок — пинҳон то тасдиқи admin.
	hidden := ownerHidden || mod.Hold

	var cid string
	var createdAt interface{}
	if err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO comments(post_id,user_id,text,parent_id,hidden)
		 VALUES($1,$2,$3,NULLIF($4,''),$5) RETURNING id,created_at`,
		postID, myID, b.Text, b.ParentID, hidden).Scan(&cid, &createdAt); err != nil {
		// Пеш ҳисобкунак зиёд ва огоҳинома фиристода мешуд, ҳатто агар
		// шарҳ сабт нашуда бошад.
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Шарҳ сабт нашуд"})
		return
	}
	queueReview(myID, modReq, cid, mod, mod.Hold && !ownerHidden)

	// Шарҳи пинҳон ба ҳисоб намеравад ва огоҳинома намедиҳад —
	// вагарна соҳиб маҳз ҳамон чизеро мебинад, ки пинҳон кардан
	// мехост.
	if hidden {
		c.JSON(http.StatusCreated, gin.H{
			"_id": cid, "text": b.Text, "createdAt": createdAt,
			"likesCount": 0, "parentId": b.ParentID,
			"user": commentAuthor(myID),
		})
		return
	}

	db.Pool.Exec(context.Background(),
		`UPDATE posts SET comments_count=comments_count+1 WHERE id=$1`, postID)

	// Огоҳии соҳиби пост
	notify(postOwner, myID, "comment", postID)
	preview := b.Text
	if r := []rune(preview); len(r) > 40 {
		preview = string(r[:40])
	}
	pushNotify(postOwner, myID, "comment", postID, "шарҳ гузошт: "+preview)

	// @зикр дар шарҳ — ҳар корбари зикршударо огоҳ кун
	notifyMentions(myID, "mention", postID, b.Text, "шуморо дар шарҳ зикр кард")
	maybeAutoDM("post", postID, postOwner, myID, b.Text)

	// Reply — соҳиби шарҳи волидро ҳам огоҳ кун (агар худаш набошад)
	if b.ParentID != "" {
		var parentOwner string
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM comments WHERE id=$1`, b.ParentID).Scan(&parentOwner)
		if parentOwner != "" && parentOwner != myID && parentOwner != postOwner {
			notify(parentOwner, myID, "reply", postID)
			pushNotify(parentOwner, myID, "reply", postID, "ба шарҳи шумо ҷавоб дод")
		}
	}

	var uname, uavatar string
	var verified bool
	db.Pool.QueryRow(context.Background(),
		`SELECT username,avatar,verified FROM users WHERE id=$1`, myID,
	).Scan(&uname, &uavatar, &verified)

	// Cache-и корбарро пок мекунем, то шарҳи нав дар GET /posts/:id/comments
	// ва count-и шарҳҳо дар feed фавран нав шаванд.
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusCreated, gin.H{
		"_id": cid, "post": postID, "text": b.Text, "parentId": b.ParentID,
		"liked": false, "likesCount": 0, "createdAt": createdAt,
		"user": gin.H{"_id": myID, "username": uname, "avatar": uavatar, "verified": verified},
	})
}

// GET /comments/:id  (id = postID)
func GetComments(c *gin.Context) {
	postID := c.Param("id")
	myID := mw.UID(c)
	// Ҳисоби пӯшида / бастан — ҳамон қоидаи профил.
	if ok, _ := CanSeeProfileContent(myID, ownerOfPost(postID)); !ok {
		c.JSON(http.StatusOK, gin.H{"comments": []gin.H{}, "page": 1, "limit": 0})
		return
	}
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 20))
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT c.id, c.text, c.likes_count, c.created_at, COALESCE(c.parent_id,''),
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM comment_likes cl WHERE cl.comment_id=c.id AND cl.user_id=$2),
		       `+storyRingCols("u.id", "$2")+`,
		       c.pinned_at IS NOT NULL
		FROM comments c JOIN users u ON u.id=c.user_id
		WHERE c.post_id=$1
		  -- ⚠️ Шарҳи пинҳон танҳо ба НАВИСАНДАИ он намоён аст.
		  --
		  -- Ӯ шарҳи худро мебинад ва намедонад, ки дигарон онро
		  -- намебинанд. Маҳз ҳамин фарқи «пинҳон» аз «рад» аст:
		  -- агар ӯ мефаҳмид, роҳи гузаштанро меҷуст.
		  AND (COALESCE(c.hidden,false) = FALSE OR c.user_id = $2::text)
		  -- Шарҳи касе, ки ман бастаам (ё ӯ маро), намоён нест — мисли
		  -- Instagram. Пеш бастан шарҳҳои ӯро дар зери постҳо мегузошт.
		  AND NOT EXISTS (SELECT 1 FROM blocks bk
		       WHERE (bk.blocker_id=$2::text AND bk.blocked_id=c.user_id)
		          OR (bk.blocker_id=c.user_id AND bk.blocked_id=$2::text))
		-- Часпонидашудаҳо аввал (ниг. pinned_comments.go).
		ORDER BY (c.pinned_at IS NOT NULL) DESC, c.pinned_at DESC, c.created_at DESC
		LIMIT $3 OFFSET $4`,
		postID, myID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get comments failed"})
		return
	}
	defer rows.Close()

	comments := []gin.H{}
	for rows.Next() {
		var cid, text, uid, uname, uavatar string
		var parentID string
		var likes int
		var verified, liked, hasStory, unseenStory, pinned bool
		var createdAt interface{}
		rows.Scan(&cid, &text, &likes, &createdAt, &parentID, &uid, &uname, &uavatar, &verified, &liked,
			&hasStory, &unseenStory, &pinned)
		comments = append(comments, gin.H{
			"_id": cid, "text": text, "liked": liked, "likesCount": likes,
			"createdAt": createdAt, "parentId": parentID, "pinned": pinned,
			"user": putStoryRing(gin.H{"_id": uid, "username": uname, "avatar": uavatar,
				"verified": verified}, hasStory, unseenStory),
		})
	}
	c.JSON(http.StatusOK, gin.H{"comments": comments, "page": page, "limit": limit})
}

// DELETE /posts/:postId/comments/:id
func DeleteComment(c *gin.Context) {
	cid := c.Param("id")
	myID := mw.UID(c)
	// Ду нафар шарҳро нест карда метавонанд:
	//
	//   1. муаллифи худи шарҳ;
	//   2. СОҲИБИ ПОСТ — маҳз мисли Instagram.
	//
	// Пеш танҳо якум буд. Яъне корбар дар зери пости ХУДАШ шарҳи
	// нохушро нест карда наметавонист — ягона роҳ шикоят ва
	// интизорӣ буд. Барои ҳамин калимаҳои пинҳон сохта шуданд,
	// вале онҳо танҳо шарҳи НАВро мегиранд, на онеро, ки аллакай
	// навишта шудааст.
	// Ҷавобҳо ҳамроҳ нест мешаванд (пеш «ятим» мемонданд), ва ҳисобкунак
	// танҳо барои шарҳҳои НАМОЁН кам мешавад — шарҳи пинҳон (калимаи
	// пинҳон / restrict) ҳеҷ гоҳ ҳисоб нашуда буд.
	var postID string
	var visible int
	err := db.Pool.QueryRow(context.Background(), `
		WITH target AS (
		  SELECT c.id, c.post_id FROM comments c
		  WHERE c.id=$1
		    AND (c.user_id=$2::text
		         OR EXISTS (SELECT 1 FROM posts p
		                    WHERE p.id=c.post_id AND p.user_id=$2::text))),
		gone AS (
		  DELETE FROM comments d
		  WHERE d.id IN (SELECT id FROM target)
		     OR d.parent_id IN (SELECT id FROM target)
		  RETURNING d.post_id, COALESCE(d.hidden,false) AS hidden)
		SELECT (SELECT post_id FROM target),
		       (SELECT COUNT(*) FROM gone WHERE NOT hidden)
		WHERE EXISTS (SELECT 1 FROM target)`, cid, myID,
	).Scan(&postID, &visible)
	if err == nil {
		db.Pool.Exec(context.Background(),
			`UPDATE posts SET comments_count=GREATEST(comments_count-$2,0) WHERE id=$1`,
			postID, visible)
		mw.InvalidateUserCache(myID)
		c.JSON(http.StatusOK, gin.H{"success": true})
		return
	}
	// Дар ҷадвали пост нест — шояд шарҳи Reel бошад (ҷадвали ҷудогона).
	var reelID string
	err = db.Pool.QueryRow(context.Background(), `
		WITH target AS (
		  SELECT rc.id, rc.reel_id FROM reel_comments rc
		  WHERE rc.id=$1
		    AND (rc.user_id=$2::text
		         OR EXISTS (SELECT 1 FROM reels r
		                    WHERE r.id=rc.reel_id AND r.user_id=$2::text))),
		gone AS (
		  DELETE FROM reel_comments d
		  WHERE d.id IN (SELECT id FROM target)
		     OR d.parent_id IN (SELECT id FROM target)
		  RETURNING COALESCE(d.hidden,false) AS hidden)
		SELECT (SELECT reel_id FROM target),
		       (SELECT COUNT(*) FROM gone WHERE NOT hidden)
		WHERE EXISTS (SELECT 1 FROM target)`, cid, myID,
	).Scan(&reelID, &visible)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Comment not found"})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE reels SET comments_count=GREATEST(comments_count-$2,0) WHERE id=$1`,
		reelID, visible)
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /posts/:postId/comments/:id/like
func ToggleCommentLike(c *gin.Context) {
	toggleCommentLike(c, c.Param("id"))
}

// toggleCommentLike — лайки шарҳи пост ё Reel.
func toggleCommentLike(c *gin.Context, cid string) {
	myID := mw.UID(c)
	// Шарҳ бояд вуҷуд дошта бошад ва муаллифи мундариҷа ба ман дастрас
	// бошад (блок / ҳисоби пӯшида). Пеш ба ҳар id лайк мегузошт.
	var owner, author string
	db.Pool.QueryRow(context.Background(), `
		SELECT p.user_id, cm.user_id FROM comments cm JOIN posts p ON p.id=cm.post_id WHERE cm.id=$1
		UNION ALL
		SELECT r.user_id, rc.user_id FROM reel_comments rc JOIN reels r ON r.id=rc.reel_id WHERE rc.id=$1
		LIMIT 1`, cid).Scan(&owner, &author)
	if owner == "" || IsBlockedBetween(myID, author) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Шарҳ ёфт нашуд"})
		return
	}
	if ok, _ := CanSeeProfileContent(myID, owner); !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Шарҳ ёфт нашуд"})
		return
	}
	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM comment_likes WHERE comment_id=$1::text AND user_id=$2::text)`,
		cid, myID).Scan(&liked)
	// Шарҳ метавонад аз они пост (comments) ё Reel (reel_comments) бошад —
	// ҳарду ҷадвалро нав мекунем, танҳо якеаш сатр дорад.
	// Шумориш танҳо вақте тағйир меёбад, ки сатр воқеан илова/ҳазф шуд —
	// вагарна такрори дархост шуморишро вайрон мекунад.
	if liked {
		ct, _ := db.Pool.Exec(context.Background(),
			`DELETE FROM comment_likes WHERE comment_id=$1::text AND user_id=$2::text`, cid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE comments SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, cid)
			db.Pool.Exec(context.Background(),
				`UPDATE reel_comments SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, cid)
		}
	} else {
		ct, _ := db.Pool.Exec(context.Background(),
			`INSERT INTO comment_likes(comment_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, cid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE comments SET likes_count=likes_count+1 WHERE id=$1`, cid)
			db.Pool.Exec(context.Background(),
				`UPDATE reel_comments SET likes_count=likes_count+1 WHERE id=$1`, cid)
			notifyCommentLike(cid, author, myID)
		}
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"liked": !liked})
}

// PUT /comments/:id — таҳрири comment
func EditComment(c *gin.Context) {
	cid := c.Param("id")
	myID := mw.UID(c)

	var b struct {
		Text string `json:"text"`
	}

	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	b.Text = clampRunes(b.Text, 1000)
	// Таҳрир ҳам модератсия ва калимаҳои пинҳони соҳиби постро мегузарад —
	// пеш шарҳи бегуноҳро баъд ба таҳқир иваз кардан мумкин буд.
	modReq, mod, modOK := captionAllowed(c, "comment", b.Text)
	if !modOK {
		return
	}
	var postOwner string
	db.Pool.QueryRow(context.Background(),
		`SELECT p.user_id FROM comments cm JOIN posts p ON p.id=cm.post_id WHERE cm.id=$1`,
		cid).Scan(&postOwner)
	hideNow := postOwner != "" && containsHiddenWord(b.Text,
		hiddenWordsOf(context.Background(), postOwner))

	res, err := db.Pool.Exec(context.Background(),
		`UPDATE comments
		 SET text=$1, updated_at=NOW(), hidden = hidden OR $4
		 WHERE id=$2 AND user_id=$3`,
		b.Text, cid, myID, hideNow)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}

	if res.RowsAffected() == 0 {
		// Дар ҷадвали пост нест — шояд шарҳи Reel бошад.
		res, err = db.Pool.Exec(context.Background(),
			`UPDATE reel_comments SET text=$1 WHERE id=$2 AND user_id=$3`,
			b.Text, cid, myID)
		if err != nil || res.RowsAffected() == 0 {
			c.JSON(http.StatusNotFound, gin.H{
				"message": "Comment not found or not owner",
			})
			return
		}
		modReq.Surface = "reel_comment"
	}
	held := holdIfNeeded(myID, modReq, cid, mod)

	c.JSON(http.StatusOK, gin.H{
		"updated":       true,
		"text":          b.Text,
		"pendingReview": held,
	})
}

// ── FOLLOW ───────────────────────────────────────────────────────

// POST /follow/:id
func FollowUser(c *gin.Context) {
	targetID := c.Param("id")
	myID := mw.UID(c)
	defer invalidateFeedCache(myID) // лентаи «Обунаҳо» фавран нав шавад
	if targetID == myID {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Cannot follow yourself"})
		return
	}
	// Басташуда обуна шуда наметавонад — на ба ман, на ман ба ӯ.
	if denyIfBlocked(c, myID, targetID) {
		return
	}
	var isPrivate bool
	err := db.Pool.QueryRow(context.Background(),
		`SELECT is_private FROM users WHERE id=$1`, targetID).Scan(&isPrivate)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	// Манбаи обуна (ихтиёрӣ): аз кадом пост/Reel обуна шуд — барои
	// омори «Обуначиён аз ин пост». Бадани холӣ ҳам дуруст аст.
	var src struct {
		SourceKind string `json:"sourceKind"`
		SourceID   string `json:"sourceId"`
	}
	_ = c.ShouldBindJSON(&src)
	var alreadyFollowing bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM follows WHERE follower_id=$1::text AND following_id=$2::text)`,
		myID, targetID).Scan(&alreadyFollowing)
	if alreadyFollowing {
		c.JSON(http.StatusOK, gin.H{"following": true})
		return
	}
	if isPrivate {
		db.Pool.Exec(context.Background(),
			`INSERT INTO follow_requests(requester_id,target_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
			myID, targetID)
		recordFollowSource(myID, targetID, src.SourceKind, src.SourceID)
		notify(targetID, myID, "follow_request", myID)
		pushNotify(targetID, myID, "follow_request", myID, "мехоҳад обуна шавад")
		c.JSON(http.StatusOK, gin.H{"requested": true})
		return
	}
	// RETURNING — шумориш танҳо вақте зиёд мешавад, ки сатр воқеан
	// сохта шуда бошад. Бе ин ду дархости ҳамзамон ду бор зиёд мекунад.
	var inserted int
	if db.Pool.QueryRow(context.Background(),
		`INSERT INTO follows(follower_id,following_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING RETURNING 1`,
		myID, targetID).Scan(&inserted) != nil {
		// Сатр аллакай буд — робита ҳаст, вале шуморишро тағйир намедиҳем.
		c.JSON(http.StatusOK, gin.H{"following": true})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET followers_count=followers_count+1 WHERE id=$1`, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET following_count=following_count+1 WHERE id=$1`, myID)
	recordFollowSource(myID, targetID, src.SourceKind, src.SourceID)
	notify(targetID, myID, "follow", myID)

	// Cache-и middleware-и ду корбарро пок мекунем, то ҳисоби followers/
	// following ва тугмаи "Обуна шудан" фавран нав шаванд (na 3-30 сония баъд).
	mw.InvalidateUserCache(myID)
	mw.InvalidateUserCache(targetID)

	// Push: аз ҳамон роҳи ягона мегузарад — танзимот, соатҳои ором ва
	// маҳдудият ба он низ татбиқ мешаванд. Матн дар сервер аз рӯи
	// забони гиранда сохта мешавад.
	pushNotify(targetID, myID, "follow", myID, "")
	c.JSON(http.StatusOK, gin.H{"following": true})
}

// DELETE /follow/:id  or POST /unfollow/:id
func UnfollowUser(c *gin.Context) {
	targetID := c.Param("id")
	myID := mw.UID(c)
	defer invalidateFeedCache(myID) // лентаи «Обунаҳо» фавран нав шавад
	// Дархости обунаи ҳанӯз қабулнашуда (ҳисоби пӯшида) низ бекор мешавад.
	// Пеш онро бозпас гирифтан ғайриимкон буд: тугма «Дархост фиристода
	// шуд» мемонд ва соҳиби ҳисоб онро то абад дар рӯйхат медид.
	if tag, err := db.Pool.Exec(context.Background(),
		`DELETE FROM follow_requests WHERE requester_id=$1::text AND target_id=$2::text`,
		myID, targetID); err == nil && tag.RowsAffected() > 0 {
		db.Pool.Exec(context.Background(), `
			DELETE FROM notifications
			WHERE user_id=$1 AND from_user_id=$2 AND type='follow_request'`,
			targetID, myID)
	}
	// RETURNING — шумориш танҳо вақте кам мешавад, ки сатр воқеан нест
	// шуда бошад. Бе ин такрори дархост шуморишро поин мебарад.
	var deleted int
	if db.Pool.QueryRow(context.Background(),
		`DELETE FROM follows WHERE follower_id=$1::text AND following_id=$2::text
		 RETURNING 1`, myID, targetID).Scan(&deleted) != nil {
		c.JSON(http.StatusOK, gin.H{"following": false})
		return
	}
	// Манбаи обуна бо худи обуна меравад: обунаи дубора аз пости дигар
	// бояд ба ҳамон пост ҳисоб шавад, на ба кӯҳна.
	db.Pool.Exec(context.Background(),
		`DELETE FROM follow_sources WHERE follower_id=$1 AND followee_id=$2`,
		myID, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET followers_count=GREATEST(followers_count-1,0) WHERE id=$1`, targetID)
	db.Pool.Exec(context.Background(),
		`UPDATE users SET following_count=GREATEST(following_count-1,0) WHERE id=$1`, myID)
	mw.InvalidateUserCache(myID)
	mw.InvalidateUserCache(targetID)
	c.JSON(http.StatusOK, gin.H{"following": false})
}

// POST /follow/request/:id/accept
func AcceptRequest(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	// ⚠️ Танҳо дархости ВОҚЕӢ қабул мешавад. Пеш натиҷаи DELETE санҷида
	// намешуд: ҳар кас бо /follow/request/<id-и ихтиёрӣ>/accept метавонист
	// ҳар корбарро ба худаш «обуна» кунад ва ба ӯ хабари бардурӯғ фиристад.
	tag, err := db.Pool.Exec(context.Background(),
		`DELETE FROM follow_requests WHERE requester_id=$1::text AND target_id=$2::text`, rid, myID)
	if err != nil || tag.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Дархост ёфт нашуд"})
		return
	}
	// Танҳо вақте зиёд мекунем, ки робита воқеан нав сохта шуда бошад.
	var inserted int
	if db.Pool.QueryRow(context.Background(),
		`INSERT INTO follows(follower_id,following_id) VALUES($1,$2)
		 ON CONFLICT DO NOTHING RETURNING 1`, rid, myID).Scan(&inserted) == nil {
		db.Pool.Exec(context.Background(),
			`UPDATE users SET followers_count=followers_count+1 WHERE id=$1`, myID)
		db.Pool.Exec(context.Background(),
			`UPDATE users SET following_count=following_count+1 WHERE id=$1`, rid)
	}
	mw.InvalidateUserCache(myID)
	mw.InvalidateUserCache(rid)

	// ⚠️ Ин НАБУД. Одам дархости обуна мефиристод, соҳиб қабул
	// мекард — ва дархосткунанда ҳеҷ гоҳ намедонист. На сатр, на
	// огоҳиномаи телефон.
	notify(rid, myID, "follow_accepted", myID)
	pushNotify(rid, myID, "follow_accepted", myID, "")

	// Мисли Instagram: дархост дар рӯйхати соҳиб ба «… ба шумо обуна
	// шуд» табдил меёбад. Пеш сатри «дархост» бо тугмаҳои Қабул/Рад
	// абадӣ мемонд, гарчанде дархост дигар набуд.
	db.Pool.Exec(context.Background(), `
		UPDATE notifications SET type='follow', read=TRUE
		 WHERE user_id=$1 AND from_user_id=$2 AND type='follow_request'
		   AND NOT EXISTS (SELECT 1 FROM notifications n2
		        WHERE n2.user_id=$1 AND n2.from_user_id=$2 AND n2.type='follow')`,
		myID, rid)
	db.Pool.Exec(context.Background(), `
		DELETE FROM notifications
		 WHERE user_id=$1 AND from_user_id=$2 AND type='follow_request'`,
		myID, rid)

	c.JSON(http.StatusOK, gin.H{"accepted": true})
}

// POST /follow/request/:id/reject
func RejectRequest(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	if tag, err := db.Pool.Exec(context.Background(),
		`DELETE FROM follow_requests WHERE requester_id=$1::text AND target_id=$2::text`,
		rid, myID); err == nil && tag.RowsAffected() > 0 {
		// Дархости радшуда дар рӯйхат бо тугмаҳои Қабул/Рад намемонад.
		db.Pool.Exec(context.Background(), `
			DELETE FROM notifications
			 WHERE user_id=$1 AND from_user_id=$2 AND type='follow_request'`,
			myID, rid)
	}
	c.JSON(http.StatusOK, gin.H{"rejected": true})
}

// ── SEARCH ───────────────────────────────────────────────────────

// GET /search?q=...
func Search(c *gin.Context) {
	myID := mw.UID(c)
	q := c.Query("q")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Query required"})
		return
	}
	like := "%" + q + "%"

	// Users
	uRows, _ := db.Pool.Query(context.Background(), `
		SELECT id,username,avatar,verified,bio,
		       -- Ҳамон рақами сарлавҳаи профил (COUNT(follows), ниг.
		       -- userSelectSQL), на сутуни ҳисобшудаи followers_count.
		       (SELECT COUNT(*) FROM follows f WHERE f.following_id = u.id),
		       `+storyRingCols("u.id", "$2")+`
		FROM users u WHERE username ILIKE $1 AND banned=FALSE
		  -- Бастагон дар ҷустуҷӯ пайдо намешаванд (ҳар ду тараф).
		  AND NOT EXISTS (SELECT 1 FROM blocks vb
		       WHERE (vb.blocker_id = $2::text AND vb.blocked_id = u.id)
		          OR (vb.blocker_id = u.id AND vb.blocked_id = $2::text))
		ORDER BY followers_count DESC, username ASC LIMIT 20`, like, myID)
	users := []gin.H{}
	if uRows != nil {
		for uRows.Next() {
			var id, uname, avatar, bio string
			var verified bool
			var fc int
			var hasStory, unseenStory bool
			uRows.Scan(&id, &uname, &avatar, &verified, &bio, &fc, &hasStory, &unseenStory)
			users = append(users, putStoryRing(gin.H{
				"_id": id, "id": id, "username": uname,
				"avatar": avatar, "verified": verified,
				"bio": bio, "followersCount": fc,
			}, hasStory, unseenStory))
		}
		uRows.Close()
	}

	// Постҳо ва Reels — ҲАМОН шакле, ки лента / Explore / профил медиҳанд.
	//
	// ⚠️ Пеш ҷустуҷӯ шакли худро дошт: бе liked/saved/hideLikes/sharesCount
	// (ва Reels бе commentsCount). Клиент майдонҳои нестро 0/false мехонд
	// ва онҳоро ҳамчун маълумоти нави сервер дар ҳамаи экранҳо мегузошт —
	// пас аз ҷустуҷӯ лайки ман «гум» мешуд ва шарҳҳо 0 мешуданд; «лайкҳо
	// пинҳон» ҳам дар ҷустуҷӯ рақами воқеиро нишон медод.
	ctx := c.Request.Context()
	posts := []gin.H{}
	if ids := searchIDs(ctx, `
		SELECT p.id FROM posts p JOIN users u ON u.id=p.user_id
		WHERE p.caption ILIKE $1
		  -- Ҷустуҷӯ — кашф аст: танҳо ҳисобҳои кушода, мисли Instagram.
		  AND `+publicAuthorSQL("p.user_id", "u", "$2")+`
		  AND COALESCE(p.hidden,false)=FALSE
		  AND COALESCE(p.archived,false)=FALSE
		  AND (p.scheduled_at IS NULL OR p.scheduled_at <= now())
		ORDER BY p.likes_count DESC, p.created_at DESC LIMIT 20`, like, myID); len(ids) > 0 {
		if pr, err := db.Pool.Query(ctx, feedPostCols+` WHERE p.id = ANY($2::text[])`,
			myID, ids); err == nil {
			byID := map[string]gin.H{}
			for _, p := range scanFeedPosts(pr) {
				id, _ := p["_id"].(string)
				byID[id] = p
			}
			for _, id := range ids {
				if p := byID[id]; p != nil {
					posts = append(posts, p)
				}
			}
		}
	}

	reels := []gin.H{}
	if ids := searchIDs(ctx, `
		SELECT r.id FROM reels r JOIN users u ON u.id=r.user_id
		WHERE r.caption ILIKE $1
		  -- Пеш ин ҷо ҳеҷ филтр набуд: Reels-и ҳисобҳои пӯшида,
		  -- бастагон ва видеоҳои нестшуда дар ҷустуҷӯ меомаданд.
		  AND `+publicAuthorSQL("r.user_id", "u", "$2")+`
		  AND COALESCE(r.media_missing,false)=FALSE
		ORDER BY r.views_count DESC, r.likes_count DESC LIMIT 10`, like, myID); len(ids) > 0 {
		byID := reelsByIDs(ctx, myID, ids)
		for _, id := range ids {
			if r := byID[id]; r != nil {
				delete(r, "kind")
				reels = append(reels, r)
			}
		}
		attachReelLocations(reels)
	}

	// Хэштегҳо — аз caption-ҳо ҷамъ мешаванд (то tab-и «Тегҳо» холӣ намонад).
	// Пеш аз caption-ҳо бо `#(\w+)` ҷамъ мешуданд: ҳарфҳои тоҷикӣ гум
	// мешуданд, Reels дохил набуданд ва барнома `postsCount` мехонд, ки
	// сервер намефиристод (ҳамеша «0 пост»). Акнун — ҳамон /hashtags/search.
	hashtags := searchTags(c.Request.Context(), myID, c.Query("q"), 15)

	c.JSON(http.StatusOK, gin.H{
		"users": users, "posts": posts, "reels": reels, "hashtags": hashtags,
	})
}

// GET /search/users?q=...
func SearchUsers(c *gin.Context) {
	q := c.Query("q")
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Query required"})
		return
	}
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT id,username,avatar,verified,bio,
		       -- Ҳамон рақами сарлавҳаи профил (COUNT(follows), ниг.
		       -- userSelectSQL), на сутуни ҳисобшудаи followers_count.
		       (SELECT COUNT(*) FROM follows f WHERE f.following_id = u.id),
		       `+storyRingCols("u.id", "$2")+`
		FROM users u WHERE username ILIKE $1 AND banned=FALSE
		  AND NOT EXISTS (SELECT 1 FROM blocks vb
		       WHERE (vb.blocker_id = $2::text AND vb.blocked_id = u.id)
		          OR (vb.blocker_id = u.id AND vb.blocked_id = $2::text))
		ORDER BY followers_count DESC, username ASC LIMIT 30`,
		"%"+q+"%", mw.UID(c))
	users := []gin.H{}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var id, uname, avatar, bio string
			var verified bool
			var fc int
			var hasStory, unseenStory bool
			rows.Scan(&id, &uname, &avatar, &verified, &bio, &fc, &hasStory, &unseenStory)
			users = append(users, putStoryRing(gin.H{
				"_id": id, "id": id, "username": uname,
				"avatar": avatar, "verified": verified,
				"bio": bio, "followersCount": fc,
			}, hasStory, unseenStory))
		}
	}
	c.JSON(http.StatusOK, users)
}

// ── REELS ─────────────────────────────────────────────────────────

// POST /reels
func CreateReel(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		Caption      string     `json:"caption"`
		VideoURL     string     `json:"videoUrl"`
		VideoURLLow  string     `json:"videoUrlLow"`
		ThumbnailURL string     `json:"thumbnailUrl"`
		Audio        AudioInput `json:"audio"`
		AutoDM       *AutoDMInput `json:"autoDm"`
		// «Ҷой» — мисли пост: матн ва/ё id аз рӯйхати places.
		Location   string `json:"location"`
		LocationID string `json:"locationId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.VideoURL == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "videoUrl is required"})
		return
	}
	if b.AutoDM != nil {
		if msg := b.AutoDM.normalize(); msg != "" {
			c.JSON(http.StatusBadRequest, gin.H{"message": msg})
			return
		}
	}
	b.Caption = clampRunes(b.Caption, 2200)
	// Модератсия ПЕШ аз нашр: тавсиф + видео (кадрҳо) + муқова.
	// Нусхаи сифати паст (videoUrlLow) ҳамон видео аст — алоҳида
	// санҷида намешавад.
	modReq := modRequest{Surface: "reel", AI: true, Texts: []string{b.Caption, b.Location},
		Media: []modMedia{{URL: b.VideoURL, Video: true}, {URL: b.ThumbnailURL}}}
	if b.AutoDM != nil {
		modReq.Texts = append(modReq.Texts, b.AutoDM.Message, b.AutoDM.Link)
	}
	mod, modOK := screenContent(c, myID, modReq)
	if !modOK {
		return
	}
	audio := b.Audio.clean()
	locName, locID, locLat, locLon := resolvePostLocation(b.Location, b.LocationID)

	var rid string
	if err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO reels(user_id,caption,video_url,video_url_low,thumbnail_url,
		                   audio_id,audio_title,audio_artist,audio_cover,audio_url,
		                   location,location_id,location_lat,location_lon)
		 VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) RETURNING id`,
		myID, b.Caption, b.VideoURL, b.VideoURLLow, b.ThumbnailURL,
		audio.ID, audio.Title, audio.Artist, audio.CoverURL, audio.PreviewURL,
		locName, locID, locLat, locLon).Scan(&rid); err != nil {
		// Пеш хато нодида гирифта мешуд ва 201 бо `_id: ""` бармегашт —
		// барнома «нашр шуд» мегуфт, ҳол он ки Reel сабт нашуда буд.
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Reel сабт нашуд"})
		return
	}

	syncContentHashtags(context.Background(), db.Pool, "reel", rid, b.Caption)
	held := holdIfNeeded(myID, modReq, rid, mod)

	// Садоро дар реестр сабт мекунем — то «Ин садоро истифода бар»
	// ва рӯйхати садоҳои маъмул кор кунад.
	registerAudio(context.Background(), audio, myID)
	if b.AutoDM != nil {
		saveAutoDM("reel", rid, myID, *b.AutoDM)
	}
	mw.CacheDel("smartreels:"+myID+":1", "smartreels:"+myID+":2", "explore:grid")
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusCreated, gin.H{
		"_id": rid, "videoUrl": b.VideoURL, "videoUrlLow": b.VideoURLLow,
		"thumbnailUrl": b.ThumbnailURL,
		"pendingReview": held,
		"caption":      b.Caption, "likesCount": 0, "viewsCount": 0,
		"location": locName, "locationId": locID,
		"audio": gin.H{
			"id": audio.ID, "title": audio.Title, "artist": audio.Artist,
			"coverUrl": audio.CoverURL, "previewUrl": audio.PreviewURL,
		},
	})
}

// GET /reels
func GetReels(c *gin.Context) {
	myID := mw.UID(c)
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 20))
	offset := (page - 1) * limit

	rows, err := db.Pool.Query(context.Background(), `
		SELECT r.id, r.video_url, COALESCE(r.video_url_low,''),
		       COALESCE(r.thumbnail_url,''), r.caption, COALESCE(r.views_count,0),
		       CASE WHEN COALESCE(r.hide_likes,false) AND r.user_id <> $1::text
		            THEN -1 ELSE r.likes_count END, r.comments_count, r.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$1::text),
		       EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$1::text),
		       EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=$1::text AND f.following_id=r.user_id),
		       COALESCE(r.hide_likes,false), COALESCE(r.comments_off,false),
		       `+storyRingCols("r.user_id", "$1")+`,
		       COALESCE(r.audio_id,''), COALESCE(r.audio_title,''),
		       COALESCE(r.audio_artist,''), COALESCE(r.audio_cover,'')
		FROM reels r JOIN users u ON u.id=r.user_id
		WHERE COALESCE(r.media_missing,false)=FALSE
		  AND `+visibleAuthorSQL("r.user_id", "u", "$1")+`
		  -- «Ба ман шавқовар нест»: пеш танҳо лентаи smart онро
		  -- мепартофт — дар лентаи «Дӯстон» ва дар fallback reel боз меомад.
		  AND NOT EXISTS (SELECT 1 FROM reel_not_interested rni
		                   WHERE rni.reel_id=r.id AND rni.user_id=$1::text)
		  AND ($4 = FALSE OR EXISTS (
		    SELECT 1 FROM follows f2
		    WHERE f2.follower_id=$1::text AND f2.following_id=r.user_id))
		ORDER BY r.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, offset, c.Query("friends") == "1")
	if err != nil {
		log.Printf("[GetReels] query error: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get reels failed"})
		return
	}
	defer rows.Close()

	reels := []gin.H{}
	for rows.Next() {
		var rid, vurl, vurlLow, thumb, cap, uid, uname, uavatar string
		var audioID, audioTitle, audioArtist, audioCover string
		var views, likes, comms int
		var verified, liked, saved, following, hideLikes, commentsOff, hasStory, unseenStory bool
		var createdAt interface{}
		rows.Scan(&rid, &vurl, &vurlLow, &thumb, &cap, &views, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &liked, &saved, &following,
			&hideLikes, &commentsOff, &hasStory, &unseenStory,
			&audioID, &audioTitle, &audioArtist, &audioCover)
		reels = append(reels, gin.H{
			"_id": rid, "videoUrl": vurl, "videoUrlLow": vurlLow,
			"thumbnailUrl": thumb, "caption": cap,
			"viewsCount": views, "views": views, "likesCount": likes, "commentsCount": comms,
			"isLiked": liked, "isSaved": saved, "createdAt": createdAt,
			"hideLikes": hideLikes, "commentsDisabled": commentsOff,
			"audio": reelAudioJSON(audioID, audioTitle, audioArtist, audioCover, uname),
			"user": putStoryRing(gin.H{"_id": uid, "username": uname, "avatar": uavatar,
				"verified": verified, "isFollowing": following}, hasStory, unseenStory),
		})
	}
	attachReelLocations(reels)
	attachReelShares(reels)
	c.JSON(http.StatusOK, gin.H{"reels": reels, "page": page, "limit": limit})
}

// POST /reels/:id/like
func ToggleReelLike(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var liked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM reel_likes WHERE reel_id=$1::text AND user_id=$2::text)`,
		rid, myID).Scan(&liked)
	if liked {
		// UNLIKE — count танҳо вақте кам мешавад, ки сатр воқеан ҳазф шуд.
		ct, _ := db.Pool.Exec(context.Background(),
			`DELETE FROM reel_likes WHERE reel_id=$1::text AND user_id=$2::text`, rid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE reels SET likes_count=GREATEST(likes_count-1,0) WHERE id=$1`, rid)
		}
	} else {
		// LIKE — count танҳо вақте зиёд мешавад, ки сатр воқеан нав илова шуд.
		ct, _ := db.Pool.Exec(context.Background(),
			`INSERT INTO reel_likes(reel_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, rid, myID)
		if ct.RowsAffected() > 0 {
			db.Pool.Exec(context.Background(),
				`UPDATE reels SET likes_count=likes_count+1 WHERE id=$1`, rid)
			var owner string
			db.Pool.QueryRow(context.Background(),
				`SELECT user_id FROM reels WHERE id=$1`, rid).Scan(&owner)
			notify(owner, myID, "reel_like", rid)
			pushNotify(owner, myID, "reel_like", rid, "Reel-и шуморо писандид")
		}
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"liked": !liked})
}

// POST /reels/:id/save
// POST /reels/:id/share — паҳнкунии reel-ро ҳисоб мекунад.
//
// Пост ин ҷадвалро дошт, reel НЕ — барои ҳамин дар назди тугмаи
// «паҳн кардан»-и reel ҳеҷ рақам набуд.
//
// Як корбар як reel-ро ҳар қадар паҳн кунад, ЯК бор ҳисоб мешавад
// (калиди аввалия). Вагарна як нафар рақамро ба ҳар андоза калон
// карда метавонист.
func ShareReel(c *gin.Context) {
	myID := mw.UID(c)
	rid := c.Param("id")
	db.Pool.Exec(context.Background(),
		`INSERT INTO reel_shares(user_id, reel_id) VALUES($1,$2)
		 ON CONFLICT (user_id, reel_id) DO NOTHING`, myID, rid)
	var shares int
	db.Pool.QueryRow(context.Background(),
		`SELECT COUNT(*) FROM reel_shares WHERE reel_id=$1`, rid).Scan(&shares)
	c.JSON(http.StatusOK, gin.H{"shares": shares})
}

func ToggleReelSave(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var saved bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM reel_saves WHERE reel_id=$1::text AND user_id=$2::text)`,
		rid, myID).Scan(&saved)
	if saved {
		db.Pool.Exec(context.Background(),
			`DELETE FROM reel_saves WHERE reel_id=$1::text AND user_id=$2::text`, rid, myID)
	} else {
		db.Pool.Exec(context.Background(),
			`INSERT INTO reel_saves(reel_id,user_id) VALUES($1,$2) ON CONFLICT DO NOTHING`, rid, myID)
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"saved": !saved})
}

// DELETE /reels/:id
func DeleteReel(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	res, _ := db.Pool.Exec(context.Background(),
		`DELETE FROM reels WHERE id=$1 AND user_id=$2::text`, rid, myID)
	if res.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}
	dropContentHashtags("reel", rid)
	for _, q := range []string{
		`DELETE FROM reel_comment_likes WHERE comment_id IN (SELECT id FROM reel_comments WHERE reel_id=$1)`,
		`DELETE FROM comment_likes WHERE comment_id IN (SELECT id FROM reel_comments WHERE reel_id=$1)`,
		`DELETE FROM reel_comments WHERE reel_id=$1`,
		`DELETE FROM reel_likes WHERE reel_id=$1`,
		`DELETE FROM reel_saves WHERE reel_id=$1`,
		`DELETE FROM reel_shares WHERE reel_id=$1`,
		`DELETE FROM reel_views WHERE reel_id=$1`,
		`DELETE FROM reel_watch WHERE reel_id=$1`,
		`DELETE FROM reel_reports WHERE reel_id=$1`,
		`DELETE FROM notifications WHERE target_id=$1`,
	} {
		db.Pool.Exec(context.Background(), q, rid)
	}
	mw.InvalidateUserCache(myID) // fizardan pok kunam profile/user reels list
	// Кэши ҳар тамошобин — вагарна reel дар explore то 5 дақиқа мемонад.
	mw.BumpContentEpoch()
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// GET /reels/:id/comments
func GetReelComments(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	// Ҳисоби пӯшида / бастан — ҳамон қоидаи профил.
	if ok, _ := CanSeeProfileContent(myID, ownerOfReel(rid)); !ok {
		c.JSON(http.StatusOK, gin.H{"comments": []gin.H{}})
		return
	}
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 20))
	offset := (page - 1) * limit

	// Ҳамон шакли ҷавоб мисли шарҳҳои пост — likes, replies ва pagination.
	rows, _ := db.Pool.Query(context.Background(), `
		SELECT rc.id, rc.text, COALESCE(rc.likes_count,0), rc.created_at,
		       COALESCE(rc.parent_id,''),
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM comment_likes cl
		              WHERE cl.comment_id=rc.id AND cl.user_id=$2),
		       rc.pinned_at IS NOT NULL
		FROM reel_comments rc JOIN users u ON u.id=rc.user_id
		WHERE rc.reel_id=$1
		  AND (COALESCE(rc.hidden,false) = FALSE OR rc.user_id = $2::text)
		  AND NOT EXISTS (SELECT 1 FROM blocks bk
		       WHERE (bk.blocker_id=$2::text AND bk.blocked_id=rc.user_id)
		          OR (bk.blocker_id=rc.user_id AND bk.blocked_id=$2::text))
		ORDER BY (rc.pinned_at IS NOT NULL) DESC, rc.pinned_at DESC, rc.created_at DESC
		LIMIT $3 OFFSET $4`,
		rid, myID, limit, offset)
	comments := []gin.H{}
	if rows != nil {
		defer rows.Close()
		for rows.Next() {
			var cid, text, parentID, uid, uname, uavatar string
			var likes int
			var verified, liked, pinned bool
			var createdAt interface{}
			rows.Scan(&cid, &text, &likes, &createdAt, &parentID,
				&uid, &uname, &uavatar, &verified, &liked, &pinned)
			comments = append(comments, gin.H{
				"_id": cid, "text": text, "liked": liked, "likesCount": likes,
				"createdAt": createdAt, "parentId": parentID, "pinned": pinned,
				"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
			})
		}
	}
	c.JSON(http.StatusOK, gin.H{"comments": comments})
}

// POST /reels/:id/comments
func AddReelComment(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Text     string `json:"text"`
		ParentID string `json:"parentId"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text required"})
		return
	}
	b.Text = clampRunes(b.Text, 1000)
	// Пеш ин ҷо на мавҷудияти Reel, на блок, на ҳисоби пӯшида, на
	// калимаҳои пинҳон санҷида мешуд — ҳамаи он чи шарҳи пост дошт.
	var commentsOff bool
	var owner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id, COALESCE(comments_off,false) FROM reels WHERE id=$1`,
		rid).Scan(&owner, &commentsOff)
	allowed, restricted := commentGate(c, myID, owner)
	if !allowed {
		return
	}
	if commentsOff {
		c.JSON(http.StatusForbidden, gin.H{"message": "Шарҳҳо барои ин Reel хомӯш карда шудаанд"})
		return
	}
	if b.ParentID != "" {
		var same bool
		db.Pool.QueryRow(context.Background(),
			`SELECT EXISTS(SELECT 1 FROM reel_comments WHERE id=$1 AND reel_id=$2)`,
			b.ParentID, rid).Scan(&same)
		if !same {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Шарҳи асл ёфт нашуд"})
			return
		}
	}
	modReq := modRequest{Surface: "reel_comment", Texts: []string{b.Text}, AI: true}
	mod, modOK := screenContent(c, myID, modReq)
	if !modOK {
		return
	}
	ownerHidden := restricted || containsHiddenWord(b.Text,
		hiddenWordsOf(context.Background(), owner))
	hidden := ownerHidden || mod.Hold
	var cid string
	if err := db.Pool.QueryRow(context.Background(),
		`INSERT INTO reel_comments(reel_id,user_id,text,parent_id,hidden)
		 VALUES($1,$2,$3,NULLIF($4,''),$5) RETURNING id`,
		rid, myID, b.Text, b.ParentID, hidden).Scan(&cid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Шарҳ сабт нашуд"})
		return
	}
	queueReview(myID, modReq, cid, mod, mod.Hold && !ownerHidden)
	if hidden {
		c.JSON(http.StatusCreated, newCommentJSON(cid, b.Text, b.ParentID, myID))
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE reels SET comments_count=comments_count+1 WHERE id=$1`, rid)
	notify(owner, myID, "reel_comment", rid)
	pushNotify(owner, myID, "reel_comment", rid, "ба Reel-и шумо шарҳ гузошт")
	// Ҷавоб — муаллифи шарҳи волид ҳам мефаҳмад (мисли шарҳи пост).
	// Пеш танҳо соҳиби Reel хабар мегирифт.
	if b.ParentID != "" {
		var parentOwner string
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM reel_comments WHERE id=$1`, b.ParentID).Scan(&parentOwner)
		if parentOwner != "" && parentOwner != myID && parentOwner != owner {
			notify(parentOwner, myID, "reel_reply", rid)
			pushNotify(parentOwner, myID, "reel_reply", rid, "")
		}
	}
	notifyMentions(myID, "reel_mention", rid, b.Text, "шуморо дар шарҳи Reel зикр кард")
	maybeAutoDM("reel", rid, owner, myID, b.Text)
	mw.InvalidateUserCache(myID)
	// Шакли пурра — пеш танҳо {_id, text}: шарҳи нав бе ном ва аватар
	// меомад ва ҷавоб аз шохааш ҷудо мешуд.
	c.JSON(http.StatusCreated, newCommentJSON(cid, b.Text, b.ParentID, myID))
}

// GET /reels/:id — як реели мушаххас.
// Бе ин, зеркунии огоҳинома ё корти мубодилашуда танҳо барои реелҳои
// худи корбар кор мекард (client маҷбур буд /users/me/reels-ро скан кунад).
func GetReelByID(c *gin.Context) {
	rid := c.Param("id")
	myID := mw.UID(c)

	var vurl, vurlLow, thumb, capt, uid, uname, uavatar string
	var views, likes, comms int
	var verified, liked, saved, following, hideLikes, commentsOff, hasStory, unseenStory bool
	var createdAt interface{}

	err := db.Pool.QueryRow(context.Background(), `
		SELECT r.video_url, COALESCE(r.video_url_low,''),
		       COALESCE(r.thumbnail_url,''), r.caption, COALESCE(r.views_count,0),
		       CASE WHEN COALESCE(r.hide_likes,false) AND r.user_id <> $2::text
		            THEN -1 ELSE r.likes_count END, r.comments_count, r.created_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false),
		       EXISTS(SELECT 1 FROM reel_likes rl WHERE rl.reel_id=r.id AND rl.user_id=$2::text),
		       EXISTS(SELECT 1 FROM reel_saves rs WHERE rs.reel_id=r.id AND rs.user_id=$2::text),
		       EXISTS(SELECT 1 FROM follows f WHERE f.follower_id=$2::text AND f.following_id=r.user_id),
		       COALESCE(r.hide_likes,false), COALESCE(r.comments_off,false),
		       `+storyRingCols("r.user_id", "$2")+`
		FROM reels r JOIN users u ON u.id=r.user_id
		WHERE r.id=$1`, rid, myID).
		Scan(&vurl, &vurlLow, &thumb, &capt, &views, &likes, &comms, &createdAt,
			&uid, &uname, &uavatar, &verified, &liked, &saved, &following,
			&hideLikes, &commentsOff, &hasStory, &unseenStory)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}
	// Ҳисоби пӯшида / бастан — ниг. GetPost.
	if ok, _ := CanSeeProfileContent(myID, uid); !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}

	// Реели корбари блоккарда нишон дода намешавад.
	var blocked bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM blocks
		  WHERE (blocker_id=$1 AND blocked_id=$2) OR (blocker_id=$2 AND blocked_id=$1))`,
		myID, uid).Scan(&blocked)
	if blocked {
		c.JSON(http.StatusNotFound, gin.H{"message": "Reel not found"})
		return
	}

	// Садо ва шумораи паҳн — пеш Reel-и аз паём, сторис ё огоҳинома
	// кушодашуда садояшро гум мекард («оригинал садо») ва паҳн 0 буд.
	var audioID, audioTitle, audioArtist, audioCover string
	var location, locationID string
	var shares int
	db.Pool.QueryRow(context.Background(), `
		SELECT COALESCE(audio_id,''), COALESCE(audio_title,''), COALESCE(audio_artist,''),
		       COALESCE(audio_cover,''),
		       (SELECT COUNT(*) FROM reel_shares WHERE reel_id=$1),
		       COALESCE(location,''), COALESCE(location_id,'')
		FROM reels WHERE id=$1`, rid).Scan(&audioID, &audioTitle, &audioArtist, &audioCover, &shares,
		&location, &locationID)
	c.JSON(http.StatusOK, gin.H{
		"_id": rid, "videoUrl": vurl, "videoUrlLow": vurlLow,
		"thumbnailUrl": thumb, "caption": capt,
		"viewsCount": views, "views": views, "likesCount": likes, "commentsCount": comms,
		"isLiked": liked, "isSaved": saved, "createdAt": createdAt,
		"hideLikes": hideLikes, "commentsDisabled": commentsOff,
		"sharesCount": shares,
		"location": location, "locationId": locationID,
		"audio": reelAudioJSON(audioID, audioTitle, audioArtist, audioCover, uname),
		"user": putStoryRing(gin.H{"_id": uid, "username": uname, "avatar": uavatar,
			"verified": verified, "isFollowing": following}, hasStory, unseenStory),
	})
}

// commentAuthor — муаллифи шарҳ барои ҷавоби фаврӣ.
func commentAuthor(uid string) gin.H {
	var uname, avatar string
	var verified bool
	db.Pool.QueryRow(context.Background(),
		`SELECT username, COALESCE(avatar,''), COALESCE(verified,false) FROM users WHERE id=$1`,
		uid).Scan(&uname, &avatar, &verified)
	return gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": verified}
}

func newCommentJSON(cid, text, parentID, uid string) gin.H {
	return gin.H{
		"_id": cid, "text": text, "parentId": parentID,
		"likesCount": 0, "liked": false,
		"createdAt": time.Now().UTC().Format(time.RFC3339),
		"user":      commentAuthor(uid),
	}
}

// searchIDs — id-ҳои натиҷа бо тартиби худ ($1 — LIKE, $2 — тамошобин).
func searchIDs(ctx context.Context, query, like, myID string) []string {
	rows, err := db.Pool.Query(ctx, query, like, myID)
	if err != nil {
		log.Printf("[Search] %v", err)
		return nil
	}
	defer rows.Close()
	var ids []string
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	return ids
}
