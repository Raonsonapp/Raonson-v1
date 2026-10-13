package handlers

// «Мактуб ба оянда» — паём/пост бо медиа, ки дар санаи оянда кушода
// мешавад: ба худ, ба дӯст ё ба обуначиён.
//
//   POST   /capsules                 — мӯҳр кардан {audience, recipientId, note, text, media, unlockAt}
//   GET    /capsules?box=inbox|sent  — ба ман / аз ман
//   GET    /capsules/:id
//   PUT    /capsules/:id             — ҳамеша 409: мактуби мӯҳршуда таҳрир намешавад
//   DELETE /capsules/:id             — муаллиф
//   GET    /users/:id/capsules       — мактубҳои «ба обуначиён»-и ин корбар
//
// То санаи кушодан сервер матн ва медиаро ба ҲЕҶ КАС намедиҳад — ҳатто
// ба муаллиф; гирандагон танҳо лифофа (кӣ, кай, сатри рӯи лифофа) ва
// ҳисоби баръаксро мебинанд. Кушодан аз рӯи вақт аст (кори вақтӣ танҳо
// огоҳинома мефиристад), бинобар ин таъхири кор мактубро банд намекунад.

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	"raonson/features"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

type capsuleRow struct {
	ID, Author, Audience, Recipient, Note, Text string
	Media                                       string
	UnlockAt, CreatedAt                         time.Time
	Hidden                                      bool
}

const capsuleCols = `id, author_id, audience, recipient_id, note, text, media::text, unlock_at, created_at, hidden`

func scanCapsule(row interface{ Scan(...any) error }) (*capsuleRow, error) {
	var r capsuleRow
	if err := row.Scan(&r.ID, &r.Author, &r.Audience, &r.Recipient, &r.Note, &r.Text,
		&r.Media, &r.UnlockAt, &r.CreatedAt, &r.Hidden); err != nil {
		return nil, err
	}
	return &r, nil
}

// canSeeCapsule — ин тамошобин лифофаро мебинад?
func canSeeCapsule(ctx context.Context, r *capsuleRow, viewer string) bool {
	if r == nil || viewer == "" {
		return false
	}
	if viewer == r.Author {
		return true
	}
	if r.Hidden || IsBlockedBetween(viewer, r.Author) {
		return false
	}
	follows := false
	if r.Audience == features.CapsuleFollowers {
		if ok, _ := CanSeeProfileContent(viewer, r.Author); !ok {
			return false
		}
		follows = followsUser(ctx, viewer, r.Author)
	}
	return features.CapsuleAudienceAllows(viewer, r.Author, r.Audience, r.Recipient, follows)
}

func capsuleJSON(ctx context.Context, r *capsuleRow, viewer string, now time.Time, users map[string]gin.H) gin.H {
	if users == nil {
		users = miniUsers(ctx, []string{r.Author, r.Recipient})
	}
	open := features.CapsuleOpen(now, r.UnlockAt)
	left := int64(0)
	if !open {
		left = int64(r.UnlockAt.Sub(now).Seconds())
	}
	out := gin.H{
		"_id": r.ID, "author": users[r.Author], "audience": r.Audience,
		"note": r.Note, "unlockAt": r.UnlockAt, "createdAt": r.CreatedAt,
		"opened": open, "secondsLeft": left, "isAuthor": viewer == r.Author,
		"sealed": !open,
	}
	if r.Recipient != "" {
		out["recipient"] = users[r.Recipient]
	}
	if viewer == r.Author && r.Hidden {
		out["pendingReview"] = true
	}
	// Мӯҳр: матн ва медиа танҳо пас аз кушодан ва на дар ҳолати санҷиш.
	if features.CapsuleContentVisible(now, r.UnlockAt, true) && !r.Hidden {
		out["text"] = r.Text
		var media any
		if json.Unmarshal([]byte(r.Media), &media) != nil || media == nil {
			media = []any{}
		}
		out["media"] = media
	}
	return out
}

// POST /capsules
func CreateCapsule(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	var b struct {
		Audience    string                   `json:"audience"`
		RecipientID string                   `json:"recipientId"`
		Note        string                   `json:"note"`
		Text        string                   `json:"text"`
		Media       []map[string]interface{} `json:"media"`
		UnlockAt    string                   `json:"unlockAt"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		badRequest(c, "Маълумот нодуруст")
		return
	}
	audience, ok := features.NormalizeAudience(b.Audience)
	if !ok {
		badRequest(c, features.ErrCapsuleAudience.Error())
		return
	}
	unlock, ok := parseTimeField(b.UnlockAt)
	if !ok {
		badRequest(c, "Санаи кушодан лозим аст")
		return
	}
	now := time.Now().UTC()
	text := strings.TrimSpace(b.Text)
	note := strings.TrimSpace(b.Note)
	if err := features.ValidateCapsule(now, text, note, len(b.Media), unlock, capsuleMinLead()); err != nil {
		badRequest(c, err.Error())
		return
	}
	recipient := ""
	if audience == features.CapsuleFriend {
		recipient = strings.TrimSpace(b.RecipientID)
		if recipient == "" || recipient == me {
			badRequest(c, "Гирандаро интихоб кунед")
			return
		}
		// Ба бегона мактуб намеравад: ақаллан яке ба дигаре обуна бошад.
		if !activeUserExists(ctx, recipient) || IsBlockedBetween(me, recipient) ||
			!(followsUser(ctx, me, recipient) || followsUser(ctx, recipient, me)) {
			notFound(c)
			return
		}
	}
	if !otpSendAllowed("capsule:"+me, features.CapsulesPerDay, 24*time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{"message": "Имрӯз мактуб бисёр шуд — фардо боз"})
		return
	}
	media := []gin.H{}
	modReq := modRequest{Surface: "capsule", AI: true, Texts: []string{note, text}}
	for _, m := range b.Media {
		u, _ := m["url"].(string)
		t, _ := m["type"].(string)
		u = strings.TrimSpace(u)
		if u == "" {
			continue
		}
		if t != "video" {
			t = "image"
		}
		media = append(media, gin.H{"url": u, "type": t})
		modReq.Media = append(modReq.Media, modMedia{URL: u, Video: t == "video"})
	}
	mod, okMod := screenContent(c, me, modReq)
	if !okMod {
		return
	}
	mediaJSON, _ := json.Marshal(media)
	r, err := scanCapsule(db.Pool.QueryRow(ctx, `
		INSERT INTO time_capsules(author_id, audience, recipient_id, note, text, media, unlock_at)
		VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7) RETURNING `+capsuleCols,
		me, audience, recipient, note, text, string(mediaJSON), unlock))
	if err != nil {
		log.Printf("[capsule] insert: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	held := holdIfNeeded(me, modReq, r.ID, mod)
	if held {
		r.Hidden = true
	}
	if recipient != "" && !held {
		notify(recipient, me, "capsule_sealed", r.ID)
		pushNotify(recipient, me, "capsule_sealed", r.ID, "")
	}
	c.JSON(http.StatusCreated, capsuleJSON(ctx, r, me, now, nil))
}

// GET /capsules?box=inbox|sent
func ListCapsules(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	box := c.DefaultQuery("box", "inbox")
	var where string
	if box == "sent" {
		where = `author_id=$1`
	} else {
		box = "inbox"
		where = `author_id <> $1 AND hidden = FALSE AND (
		    (audience='friend' AND recipient_id=$1)
		 OR (audience='followers' AND EXISTS (SELECT 1 FROM follows f
		      WHERE f.follower_id=$1 AND f.following_id=time_capsules.author_id)))
		  AND NOT EXISTS (SELECT 1 FROM blocks b
		      WHERE (b.blocker_id=$1 AND b.blocked_id=time_capsules.author_id)
		         OR (b.blocker_id=time_capsules.author_id AND b.blocked_id=$1))`
	}
	rows, err := db.Pool.Query(ctx, `SELECT `+capsuleCols+` FROM time_capsules WHERE `+where+`
		ORDER BY (unlock_at <= NOW()), CASE WHEN unlock_at > NOW() THEN unlock_at END ASC,
		         unlock_at DESC LIMIT 200`, me)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	var list []*capsuleRow
	ids := []string{}
	for rows.Next() {
		if r, err := scanCapsule(rows); err == nil {
			list = append(list, r)
			ids = append(ids, r.Author, r.Recipient)
		}
	}
	rows.Close()
	users := miniUsers(ctx, ids)
	now := time.Now().UTC()
	out := []gin.H{}
	for _, r := range list {
		out = append(out, capsuleJSON(ctx, r, me, now, users))
	}
	c.JSON(http.StatusOK, gin.H{"capsules": out, "box": box})
}

func capsuleForViewer(c *gin.Context) (*capsuleRow, bool) {
	r, err := scanCapsule(db.Pool.QueryRow(c.Request.Context(),
		`SELECT `+capsuleCols+` FROM time_capsules WHERE id=$1`, c.Param("id")))
	if err != nil || !canSeeCapsule(c.Request.Context(), r, mw.UID(c)) {
		notFound(c)
		return nil, false
	}
	return r, true
}

// GET /capsules/:id
func GetCapsule(c *gin.Context) {
	r, ok := capsuleForViewer(c)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, capsuleJSON(c.Request.Context(), r, mw.UID(c), time.Now().UTC(), nil))
}

// PUT /capsules/:id — мактуби мӯҳршуда таҳрир намешавад.
func UpdateCapsule(c *gin.Context) {
	if _, ok := capsuleForViewer(c); !ok {
		return
	}
	c.JSON(http.StatusConflict, gin.H{"message": "Мактуб мӯҳр шудааст ва таҳрир намешавад",
		"code": "capsule_sealed"})
}

// DELETE /capsules/:id — танҳо муаллиф.
func DeleteCapsule(c *gin.Context) {
	tag, err := db.Pool.Exec(c.Request.Context(),
		`DELETE FROM time_capsules WHERE id=$1 AND author_id=$2`, c.Param("id"), mw.UID(c))
	if err != nil || tag.RowsAffected() == 0 {
		notFound(c)
		return
	}
	c.JSON(http.StatusOK, gin.H{"removed": true})
}

// GET /users/:id/capsules — лифофаҳои «ба обуначиён» дар профил.
func GetUserCapsules(c *gin.Context) {
	me := mw.UID(c)
	ctx := c.Request.Context()
	owner := c.Param("id")
	if ok, _ := CanSeeProfileContent(me, owner); !ok ||
		(me != owner && !followsUser(ctx, me, owner)) {
		c.JSON(http.StatusOK, gin.H{"capsules": []gin.H{}})
		return
	}
	rows, err := db.Pool.Query(ctx, `SELECT `+capsuleCols+` FROM time_capsules
		WHERE author_id=$1 AND audience='followers' AND (hidden=FALSE OR author_id=$2)
		ORDER BY unlock_at DESC LIMIT 50`, owner, me)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"capsules": []gin.H{}})
		return
	}
	var list []*capsuleRow
	for rows.Next() {
		if r, err := scanCapsule(rows); err == nil {
			list = append(list, r)
		}
	}
	rows.Close()
	users := miniUsers(ctx, []string{owner})
	now := time.Now().UTC()
	out := []gin.H{}
	for _, r := range list {
		out = append(out, capsuleJSON(ctx, r, me, now, users))
	}
	c.JSON(http.StatusOK, gin.H{"capsules": out})
}
