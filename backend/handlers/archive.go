package handlers

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ═══════════════════════ БОЙГОНӢ (Archive) ═══════════════════════
//
// Тугмаи «Ба бойгонӣ» дар менюи пост ва сторис кайҳо буд, вале роҳ
// ЯКТАРАФА буд: пост пинҳон мешуд ва дигар ҳеҷ ҷо — на дар профил, на
// дар танзимот — дида ё барқарор карда намешуд. Мисли Instagram акнун
// «Бойгонӣ» ду таб дорад: постҳо (барқароркунӣ) ва сторисҳо (ҳамаи
// сторисҳои гузаштаи худам — барои актуалӣ).

// GET /archive/posts — постҳои бойгонии ХУДАМ.
//
// Постҳои аз ҷониби модератсия ё ҳангоми ҳазфи маҳсули фармоишдор
// пинҳоншуда (hidden) ин ҷо нестанд — онҳо «бойгонӣ» нестанд ва
// барқарор карда намешаванд.
func GetArchivedPosts(c *gin.Context) {
	myID := mw.UID(c)
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 24))
	rows, err := db.Pool.Query(context.Background(),
		feedPostCols+`
		WHERE p.user_id = $1::text
		  AND COALESCE(p.archived,false) = TRUE
		  AND COALESCE(p.hidden,false) = FALSE
		ORDER BY p.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, (page-1)*limit)
	posts := []gin.H{}
	if err == nil {
		posts = scanFeedPosts(rows)
	} else {
		log.Printf("[GetArchivedPosts] %v", err)
	}
	for _, p := range posts {
		p["archived"] = true
	}
	c.JSON(http.StatusOK, gin.H{"posts": posts, "page": page, "limit": limit})
}

// GET /archive/stories — сторисҳои гузашта як сол мемонанд (ниг.
// jobs/cleanup.go); пеш баъди 1 соат комилан нест мешуданд.
//
// GET /archive/stories — ҳамаи сторисҳои ХУДАМ: гузашта, бойгонишуда ва
// ҳозира. Ҳар сторис `expired` ва `archived` дорад.
func GetArchivedStories(c *gin.Context) {
	myID := mw.UID(c)
	page := clampPage(toInt(c.Query("page"), 1))
	limit := clampLimit(toInt(c.Query("limit"), 60))
	rows, err := db.Pool.Query(context.Background(), `
		SELECT s.id, s.media_url, COALESCE(s.media_type,'image'), s.expires_at,
		       s.created_at, COALESCE(s.archived,false), COALESCE(s.audience,'all')
		FROM stories s
		WHERE s.user_id = $1::text
		ORDER BY s.created_at DESC LIMIT $2 OFFSET $3`,
		myID, limit, (page-1)*limit)
	out := []gin.H{}
	if err == nil {
		defer rows.Close()
		now := time.Now()
		for rows.Next() {
			var id, url, mtype, audience string
			var exp, created time.Time
			var archived bool
			if rows.Scan(&id, &url, &mtype, &exp, &created, &archived, &audience) != nil {
				continue
			}
			out = append(out, gin.H{
				"_id": id, "id": id, "mediaUrl": url, "mediaType": mtype,
				"expiresAt": exp, "createdAt": created,
				"expired": now.After(exp), "archived": archived,
				"audience": audience,
			})
		}
	} else {
		log.Printf("[GetArchivedStories] %v", err)
	}
	c.JSON(http.StatusOK, gin.H{"stories": out, "page": page, "limit": limit})
}

// POST /highlights/:id/stories {storyId} — сторисро ба актуалии
// МАВҶУДА илова мекунад (мисли Instagram «Ба актуалӣ илова кардан»).
//
// Пеш аз сторис ҳамеша актуалии НАВ сохта мешуд — ба актуалии ҳозира
// илова кардан ғайриимкон буд.
func AddStoryToHighlight(c *gin.Context) {
	myID := mw.UID(c)
	hid := c.Param("id")
	var b struct {
		StoryID string `json:"storyId"`
	}
	if c.ShouldBindJSON(&b) != nil || strings.TrimSpace(b.StoryID) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "storyId лозим аст"})
		return
	}
	ctx := context.Background()
	if !ensureNotSuspended(c, myID) {
		return
	}
	// Танҳо сторисҳои ХУДАМ (ҳатто гузашта — аз бойгонӣ), ки модератсия
	// пинҳон ё нест накардааст (ниг. highlight_guard.go).
	b.StoryID = strings.TrimSpace(b.StoryID)
	m, ok := allowedHighlightStories(ctx, myID, []string{b.StoryID})[b.StoryID]
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"message": "Сторис ёфт нашуд"})
		return
	}
	url, mtype := m.url, m.kind
	var itemsRaw []byte
	var storyIDs []string
	if err := db.Pool.QueryRow(ctx,
		`SELECT COALESCE(items,'[]'::jsonb), COALESCE(story_ids,'{}')
		 FROM highlights WHERE id=$1 AND user_id=$2::text`, hid, myID).
		Scan(&itemsRaw, &storyIDs); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Актуалӣ ёфт нашуд"})
		return
	}
	items := []map[string]interface{}{}
	json.Unmarshal(itemsRaw, &items)
	for _, it := range items {
		if sid, _ := it["storyId"].(string); sid == b.StoryID {
			c.JSON(http.StatusOK, gin.H{"added": false, "items": items})
			return
		}
	}
	items = append(items, map[string]interface{}{
		"url": url, "type": mtype, "storyId": b.StoryID,
	})
	raw, _ := json.Marshal(items)
	if _, err := db.Pool.Exec(ctx, `
		UPDATE highlights SET items = $1::jsonb,
		       story_ids = CASE WHEN $2 = ANY(COALESCE(story_ids,'{}'))
		                        THEN story_ids
		                        ELSE array_append(COALESCE(story_ids,'{}'), $2) END,
		       cover_url = CASE WHEN COALESCE(cover_url,'') = '' THEN $3 ELSE cover_url END
		WHERE id=$4 AND user_id=$5::text`,
		string(raw), b.StoryID, url, hid, myID); err != nil {
		log.Printf("[AddStoryToHighlight] %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Илова нашуд"})
		return
	}
	mw.InvalidateUserCache(myID)
	c.JSON(http.StatusOK, gin.H{"added": true, "items": items})
}

// GET /users/muted — хомӯшшудагон (Танзимот → Махфият). Пеш хомӯш
// кардан танҳо аз профили худи корбар бармегашт ва рӯйхат набуд.
func GetMutedUsers(c *gin.Context) {
	listMine(c, `SELECT u.id, u.username, COALESCE(u.avatar,''),
	        COALESCE(u.verified,false), COALESCE(u.bio,'')
	 FROM muted_users m JOIN users u ON u.id=m.muted_id
	 WHERE m.user_id=$1 ORDER BY u.username`)
}

// GET /users/restricted — маҳдудшудагон (Танзимот → Махфият).
func GetRestrictedUsers(c *gin.Context) {
	listMine(c, `SELECT u.id, u.username, COALESCE(u.avatar,''),
	        COALESCE(u.verified,false), COALESCE(u.bio,'')
	 FROM user_restricts r JOIN users u ON u.id=r.restricted_id
	 WHERE r.user_id=$1 ORDER BY u.username`)
}

func listMine(c *gin.Context, sql string) {
	rows, err := db.Pool.Query(context.Background(), sql, mw.UID(c))
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"users": []gin.H{}})
		return
	}
	defer rows.Close()
	c.JSON(http.StatusOK, gin.H{"users": miniUser(rows)})
}
