package handlers

// Шарҳҳои часпонидашуда — мисли Instagram.
//
//   POST /comments/:id/pin                     — шарҳи пост (toggle)
//   POST /reels/:id/comments/:commentId/pin    — шарҳи Reel (toggle)
//
// Танҳо соҳиби пост/Reel; танҳо шарҳи асосӣ (на ҷавоб) ва намоён (на
// пинҳони модератсия/калимаҳои пинҳон); то 3 шарҳ. Часпонидашудаҳо дар
// GET-и шарҳҳо аввал меоянд ва "pinned": true доранд.

import (
	"context"
	"errors"
	"net/http"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// MaxPinnedComments — ҳадди шарҳҳои часпонидашуда дар як пост/Reel.
const MaxPinnedComments = 3

type pinTable struct {
	comments, content, fk string
}

var (
	pinPost = pinTable{"comments", "posts", "post_id"}
	pinReel = pinTable{"reel_comments", "reels", "reel_id"}
)

// POST /comments/:id/pin
func TogglePinComment(c *gin.Context) {
	togglePin(c, pinPost, c.Param("id"), "")
}

// POST /reels/:id/comments/:commentId/pin
func TogglePinReelComment(c *gin.Context) {
	togglePin(c, pinReel, c.Param("commentId"), c.Param("id"))
}

func togglePin(c *gin.Context, t pinTable, commentID, contentID string) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var cid, owner, parent string
	var pinned, hidden bool
	err := db.Pool.QueryRow(ctx, `
		SELECT x.`+t.fk+`, o.user_id, COALESCE(x.parent_id,''),
		       x.pinned_at IS NOT NULL, COALESCE(x.hidden,false)
		  FROM `+t.comments+` x JOIN `+t.content+` o ON o.id = x.`+t.fk+`
		 WHERE x.id = $1 AND ($2 = '' OR x.`+t.fk+` = $2)`,
		commentID, contentID).Scan(&cid, &owner, &parent, &pinned, &hidden)
	if errors.Is(err, pgx.ErrNoRows) || (err == nil && owner != me) {
		// Бегона ҳам 404 мегирад — мавҷудияти шарҳро ошкор намекунем.
		c.JSON(http.StatusNotFound, gin.H{"message": "Шарҳ ёфт нашуд"})
		return
	}
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	if pinned {
		db.Pool.Exec(ctx, `UPDATE `+t.comments+` SET pinned_at = NULL WHERE id = $1`, commentID)
		c.JSON(http.StatusOK, gin.H{"pinned": false})
		return
	}
	if parent != "" || hidden {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Танҳо шарҳи асосиро часпондан мумкин аст"})
		return
	}
	tag, err := db.Pool.Exec(ctx, `
		UPDATE `+t.comments+` SET pinned_at = NOW()
		 WHERE id = $1
		   AND (SELECT COUNT(*) FROM `+t.comments+`
		         WHERE `+t.fk+` = $2 AND pinned_at IS NOT NULL) < $3`,
		commentID, cid, MaxPinnedComments)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	if tag.RowsAffected() == 0 {
		c.JSON(http.StatusConflict, gin.H{
			"message": "То 3 шарҳро часпондан мумкин аст", "code": "pin_limit"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"pinned": true})
}

// unpinOnHide — шарҳи пинҳоншуда (модератсия) часпонида намемонад.
func unpinOnHide(ctx context.Context, table, id string) {
	db.Pool.Exec(ctx, `UPDATE `+table+` SET pinned_at = NULL WHERE id = $1`, id)
}
