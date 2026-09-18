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
			if id == "" || seen[id] {
				continue
			}
			seen[id] = true
			if _, err := db.Pool.Exec(ctx, `
				INSERT INTO post_collab_invites(post_id, user_id)
				VALUES ($1,$2) ON CONFLICT DO NOTHING`, postID, id); err != nil {
				continue
			}
			sent++
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
		       COALESCE(p.caption,''), i.created_at
		FROM post_collab_invites i
		JOIN posts p ON p.id = i.post_id
		JOIN users u ON u.id = p.user_id
		WHERE i.user_id=$1 AND i.status='pending'
		ORDER BY i.created_at DESC
		LIMIT 50`, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	defer rows.Close()

	out := []gin.H{}
	for rows.Next() {
		var postID, ownerID, username, avatar, caption string
		var at any
		if err := rows.Scan(&postID, &ownerID, &username, &avatar,
			&caption, &at); err != nil {
			continue
		}
		out = append(out, gin.H{
			"postId": postID, "ownerId": ownerID,
			"username": username, "avatar": avatar,
			"caption": caption,
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
	ct, err := db.Pool.Exec(ctx, `
		UPDATE post_collab_invites SET status=$1
		WHERE post_id=$2 AND user_id=$3`, status, postID, myID)
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
	if accept {
		if owner := postOwner(ctx, postID); owner != "" && owner != myID {
			notify(owner, myID, "collab_accepted", postID)
			pushNotify(owner, myID, "collab_accepted", postID, "")
		}
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "status": status})
}

// postOwner шиносаи соҳиби постро медиҳад (холӣ, агар ёфт нашавад).
func postOwner(ctx context.Context, postID string) string {
	var id string
	db.Pool.QueryRow(ctx, `SELECT user_id FROM posts WHERE id=$1`, postID).Scan(&id)
	return id
}
