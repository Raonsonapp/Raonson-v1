package handlers

// Ҳамкорӣ дар пост.
//
// Қоидаи асосӣ: номи одам ба мӯҳтаво танҳо бо ИҶОЗАТИ ӯ баста
// мешавад. Даъват интизор мемонад; то тасдиқ ҳамкор дар пост нишон
// дода намешавад.
//
// posts.collaborators танҳо тасдиқшударо нигоҳ медорад, бинобар ин
// ҳама ҷои хониши мавҷуд (лента, профил, худи пост) бе тағйир дуруст
// кор мекунад.

import (
	"context"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"raonson/db"
	mw "raonson/middleware"
)

// maxCollaborators — маҳдудияти оқилона.
//
// Бе он як пост метавонист даҳҳо огоҳиномаи ногаҳонӣ фиристад.
const maxCollaborators = 10

// inviteCollaborators даъватҳоро сабт ва одамонро огоҳ мекунад.
//
// Танҳо корбарони ВОҚЕӢ даъват мешаванд; худи муаллиф не. Хато
// бармегардонда намешавад: пост аллакай сохта шуд ва набояд аз
// сабаби даъват нобуд шавад.
//
// ⚠️ Сабаби он ки ҳамкорӣ ҲЕҶ ГОҲ кор намекард.
//
// Ин ҷо `WHERE id=$1` буд — яъне ШИНОСАИ корбар интизор мешуд.
// Вале барнома НОМИ корбарро мефиристад: корбар «@ehson» менависад
// ва ҳамон сатр меравад. Муқоисаи номи корбар бо шиноса ҳеҷ гоҳ
// мувофиқ намеояд, пас ҳар даъват хомӯшона партофта мешавад.
//
// Акнун ҳарду шакл қабул мешавад: агар шиноса набошад, ном ҷустуҷӯ
// мешавад.
func inviteCollaborators(postID, ownerID string, ids []string) {
	if postID == "" || len(ids) == 0 {
		return
	}
	go func() {
		ctx := context.Background()
		seen := map[string]bool{ownerID: true}
		sent := 0
		for _, raw := range ids {
			if sent >= maxCollaborators {
				break
			}
			id := resolveUserRef(ctx, raw)
			if id == "" || seen[id] || IsBlockedBetween(ownerID, id) {
				continue
			}
			seen[id] = true
			if _, err := db.Pool.Exec(ctx, `
				INSERT INTO post_collab_invites(post_id, user_id)
				VALUES ($1,$2) ON CONFLICT DO NOTHING`, postID, id); err != nil {
				continue
			}
			sent++
			// ⚠️ Пеш танҳо push мерафт — дар рӯйхати «Огоҳиномаҳо»
			// даъват умуман намебаромад ва корбар онро намеёфт.
			notify(id, ownerID, "collab_invite", postID)
			pushNotify(id, ownerID, "collab_invite", postID,
				"шуморо ҳамчун ҳамкор даъват кард")
		}
	}()
}

// resolveUserRef сатрро ба шиносаи корбар табдил медиҳад.
//
// Қабул мекунад: шиносаи корбар, «username» ё «@username». Агар
// корбар ёфт нашавад, сатри холӣ бармегардад.
func resolveUserRef(ctx context.Context, ref string) string {
	ref = strings.TrimSpace(strings.TrimPrefix(strings.TrimSpace(ref), "@"))
	if ref == "" {
		return ""
	}
	var id string
	// Аввал ҳамчун шиноса, баъд ҳамчун ном — як дархост.
	db.Pool.QueryRow(ctx,
		`SELECT id FROM users WHERE id=$1 OR lower(username)=lower($1) LIMIT 1`,
		ref).Scan(&id)
	return id
}

// GET /collabs/pending — даъватҳои интизор.
func GetPendingCollabs(c *gin.Context) {
	myID := mw.UID(c)
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT i.post_id, p.user_id, u.username, COALESCE(u.avatar,''),
		       COALESCE(p.caption,''), i.created_at,
		       COALESCE((SELECT m.url FROM post_media m WHERE m.post_id=p.id
		                 ORDER BY m.position LIMIT 1),''),
		       COALESCE((SELECT m.type FROM post_media m WHERE m.post_id=p.id
		                 ORDER BY m.position LIMIT 1),'image')
		FROM post_collab_invites i
		JOIN posts p ON p.id = i.post_id
		JOIN users u ON u.id = p.user_id
		WHERE i.user_id=$1 AND i.status='pending'
		  AND NOT EXISTS (SELECT 1 FROM blocks b
		        WHERE (b.blocker_id=$1 AND b.blocked_id=p.user_id)
		           OR (b.blocker_id=p.user_id AND b.blocked_id=$1))
		ORDER BY i.created_at DESC
		LIMIT 50`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer rows.Close()

	out := []gin.H{}
	for rows.Next() {
		var postID, ownerID, username, avatar, caption, thumb, mtype string
		var at any
		if err := rows.Scan(&postID, &ownerID, &username, &avatar,
			&caption, &at, &thumb, &mtype); err != nil {
			continue
		}
		out = append(out, gin.H{
			"postId": postID, "ownerId": ownerID,
			"username": username, "avatar": avatar,
			"caption": caption, "thumb": thumb, "mediaType": mtype,
			"createdAt": at,
		})
	}
	c.JSON(http.StatusOK, gin.H{"invites": out})
}

// POST /posts/:id/collab/accept — розигӣ.
//
// Танҳо ҳамин ҷо ном ба пост баста мешавад.
func AcceptCollab(c *gin.Context) {
	setCollabStatus(c, true)
}

// POST /posts/:id/collab/decline — рад.
//
// Рад кардан ҳам пас аз тасдиқ кор мекунад: одам метавонад номи
// худро аз пост гирад.
func DeclineCollab(c *gin.Context) {
	setCollabStatus(c, false)
}

func setCollabStatus(c *gin.Context, accept bool) {
	myID := mw.UID(c)
	postID := c.Param("id")
	ctx := c.Request.Context()

	status := "declined"
	if accept {
		status = "accepted"
	}

	// Танҳо даъвати мавҷуд тағйир меёбад: бе он ҳар кас метавонист
	// худро ба ҳар пост часпонад.
	owner := postOwner(ctx, postID)
	if owner == "" || (accept && IsBlockedBetween(owner, myID)) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Даъват ёфт нашуд"})
		return
	}
	// Қабул танҳо аз ҳолати «интизор» ё «радшуда» — даъвати
	// хориҷкардаи муаллиф ('removed') дубора қабул намешавад.
	cond := ""
	if accept {
		cond = " AND status IN ('pending','accepted','declined')"
	}
	ct, err := db.Pool.Exec(ctx, `
		UPDATE post_collab_invites SET status=$1
		WHERE post_id=$2 AND user_id=$3`+cond, status, postID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	if ct.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Даъват ёфт нашуд"})
		return
	}

	if accept {
		// array_append танҳо вақте, ки ҳанӯз нест — такрор намешавад.
		_, err = db.Pool.Exec(ctx, `
			UPDATE posts
			   SET collaborators = array_append(COALESCE(collaborators,'{}'), $1)
			 WHERE id=$2 AND NOT ($1 = ANY(COALESCE(collaborators,'{}')))`,
			myID, postID)
	} else {
		_, err = db.Pool.Exec(ctx, `
			UPDATE posts
			   SET collaborators = array_remove(COALESCE(collaborators,'{}'), $1)
			 WHERE id=$2`, myID, postID)
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	// ⚠️ Ин НАБУД. Соҳиби пост даъват мефиристод ва ҳеҷ гоҳ
	// намедонист, ки он қабул шуд ё рад.
	// Танҳо ҳангоми ҚАБУЛ. Рад кардан огоҳинома намедиҳад —
	// Instagram ҳам намедиҳад ва он хабари нохуш мебуд.
	// Даъват ҷавоб гирифт — огоҳиномаи «даъват» дигар лозим нест
	// (вагарна тугмаҳои Қабул/Рад абадӣ мемонданд).
	db.Pool.Exec(ctx, `DELETE FROM notifications
		WHERE user_id=$1 AND type='collab_invite' AND target_id=$2`, myID, postID)
	mw.InvalidateUserCache(myID)
	mw.InvalidateUserCache(owner)
	if accept && owner != myID {
		notify(owner, myID, "collab_accepted", postID)
		pushNotify(owner, myID, "collab_accepted", postID, "")
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "status": status})
}

// DELETE /posts/:id/collab/:userId — муаллиф ҳамкорро хориҷ мекунад
// (ё даъвати интизорро бекор мекунад).
func RemoveCollaborator(c *gin.Context) {
	me := mw.UID(c)
	postID, uid := c.Param("id"), c.Param("userId")
	ctx := c.Request.Context()
	if postOwner(ctx, postID) != me {
		c.JSON(http.StatusNotFound, gin.H{"message": "Пост ёфт нашуд"})
		return
	}
	ct, _ := db.Pool.Exec(ctx, `UPDATE post_collab_invites SET status='removed'
		WHERE post_id=$1 AND user_id=$2`, postID, uid)
	db.Pool.Exec(ctx, `UPDATE posts
		SET collaborators = array_remove(COALESCE(collaborators,'{}'), $1)
		WHERE id=$2`, uid, postID)
	db.Pool.Exec(ctx, `DELETE FROM notifications
		WHERE user_id=$1 AND type='collab_invite' AND target_id=$2`, uid, postID)
	if ct.RowsAffected() == 0 {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ҳамкор ёфт нашуд"})
		return
	}
	mw.InvalidateUserCache(me)
	mw.InvalidateUserCache(uid)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// GET /posts/:id/collabs — муаллиф: ҳамаи даъватҳо бо ҳолат.
func GetPostCollabs(c *gin.Context) {
	me := mw.UID(c)
	postID := c.Param("id")
	ctx := c.Request.Context()
	if postOwner(ctx, postID) != me {
		c.JSON(http.StatusNotFound, gin.H{"message": "Пост ёфт нашуд"})
		return
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT u.id, u.username, COALESCE(u.avatar,''), i.status
		FROM post_collab_invites i JOIN users u ON u.id=i.user_id
		WHERE i.post_id=$1 AND i.status IN ('pending','accepted')
		ORDER BY i.created_at`, postID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, name, avatar, st string
		if rows.Scan(&id, &name, &avatar, &st) == nil {
			out = append(out, gin.H{"_id": id, "username": name, "avatar": avatar, "status": st})
		}
	}
	c.JSON(http.StatusOK, gin.H{"collaborators": out})
}

// postOwner шиносаи соҳиби постро медиҳад (холӣ, агар ёфт нашавад).
func postOwner(ctx context.Context, postID string) string {
	var id string
	db.Pool.QueryRow(ctx, `SELECT user_id FROM posts WHERE id=$1`, postID).Scan(&id)
	return id
}

// attachCollabUsers — ба ҳар пост «collaboratorUsers» [{_id, username,
// avatar, verified}] илова мекунад. posts.collaborators шиносаҳоро
// нигоҳ медорад; пеш барнома ҳамон шиносаро ҳамчун ном нишон медод.
// Як дархост барои тамоми рӯйхат.
func attachCollabUsers(posts []gin.H) {
	ids := []string{}
	seen := map[string]bool{}
	for _, p := range posts {
		list, _ := p["collaborators"].([]string)
		for _, id := range list {
			if id != "" && !seen[id] {
				seen[id] = true
				ids = append(ids, id)
			}
		}
	}
	users := map[string]gin.H{}
	if len(ids) > 0 {
		rows, err := db.Pool.Query(context.Background(), `
			SELECT id, username, COALESCE(avatar,''), COALESCE(verified,false)
			FROM users WHERE id = ANY($1)`, ids)
		if err == nil {
			for rows.Next() {
				var id, name, avatar string
				var ver bool
				if rows.Scan(&id, &name, &avatar, &ver) == nil {
					users[id] = gin.H{"_id": id, "username": name, "avatar": avatar, "verified": ver}
				}
			}
			rows.Close()
		}
	}
	for _, p := range posts {
		out := []gin.H{}
		list, _ := p["collaborators"].([]string)
		for _, id := range list {
			if u, ok := users[id]; ok {
				out = append(out, u)
			}
		}
		p["collaboratorUsers"] = out
	}
}
