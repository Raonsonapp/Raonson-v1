package handlers

// Актуалӣ (highlights) ва модератсия.
//
// ⚠️ Чаро ин лозим шуд. Актуалӣ аз модератсия комилан берун буд:
//
//   - POST /highlights/:id/stories ва POST /highlights/ сторисеро, ки
//     модератсия пинҳон кардааст (stories.mod_hold_until) ё admin нест
//     кардааст, қабул мекарданд. Сторис аз лента нопадид мешуд, вале
//     соҳиб онро ба актуалӣ мегузошт ва он дар профил ба ҳама намоён
//     мемонд — «Нест кардан»-и admin бефоида буд.
//   - items (суроғаи расм) аз барнома бе ягон санҷиш сабт мешуданд:
//     расми 18+ аз галерея ва номи дашномдор мустақим ба профил мерафт,
//     ҳатто аз корбари муваққатан маҳдудшуда.
//   - storyIds ҳар id-ро қабул мекард (сториси бегона ҳам).
//
// Акнун: унсури сторис танҳо аз сториси ХУДАМ, ки на интизори санҷиш ва
// на несткарда аст — суроға аз худи сторис гирифта мешавад, на аз
// барнома. Расмҳои нав аз галерея ва ном аз ҳамон санҷиши пост мегузаранд
// (block → 403, шубҳанок → 422, корбари маҳдуд → 403).

import (
	"context"
	"net/http"
	"net/url"
	"strings"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

const (
	maxHighlightItems = 100
	maxHighlightTitle = 40
)

// HighlightHeldMessage — расм ё номи шубҳанок дар актуалӣ.
const HighlightHeldMessage = "Ин расм ё номро ба актуалӣ гузоштан мумкин нест. Лутфан дигарашро интихоб кунед"

type highlightMedia struct{ url, kind string }

// allowedHighlightStories — аз [ids] танҳо сторисҳои худи [uid], ки
// модератсия пинҳон ё нест накардааст: id → медиа.
func allowedHighlightStories(ctx context.Context, uid string, ids []string) map[string]highlightMedia {
	out := map[string]highlightMedia{}
	if len(ids) == 0 {
		return out
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT s.id::text, s.media_url, COALESCE(s.media_type,'image')
		  FROM stories s
		 WHERE s.user_id = $1::text AND s.id::text = ANY($2::text[])
		   AND s.mod_hold_until IS NULL
		   AND NOT EXISTS (SELECT 1 FROM moderation_queue q
		        WHERE q.surface = 'story' AND q.target_id = s.id::text
		          AND (q.status IN ('removed','banned')
		               OR (q.status = 'pending' AND q.held)))`, uid, ids)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var id, u, k string
		if rows.Scan(&id, &u, &k) == nil {
			out[id] = highlightMedia{u, k}
		}
	}
	return out
}

// moderatedStories — аз [ids] онҳое, ки модератсия пинҳон (интизори
// санҷиш) ё admin нест кардааст.
func moderatedStories(ctx context.Context, ids []string) map[string]bool {
	out := map[string]bool{}
	if len(ids) == 0 {
		return out
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT s.id::text FROM stories s
		 WHERE s.id::text = ANY($1::text[]) AND s.mod_hold_until IS NOT NULL
		UNION
		SELECT q.target_id FROM moderation_queue q
		 WHERE q.surface = 'story' AND q.target_id = ANY($1::text[])
		   AND (q.status IN ('removed','banned') OR (q.status = 'pending' AND q.held))`, ids)
	if err != nil {
		return out
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			out[id] = true
		}
	}
	return out
}

func validHighlightURL(s string) bool {
	if s == "" || len(s) > 1000 || strings.ContainsAny(s, " \n\t") {
		return false
	}
	u, err := url.Parse(s)
	return err == nil && u.Scheme == "https" && u.Host != ""
}

// sanitizeHighlightItems — унсурҳои актуалӣ, ки сабт шуда метавонанд.
//
// [prev] — суроғаҳое, ки аллакай дар ҳамин актуалӣ буданд (таҳрир):
// онҳо дубора санҷида намешаванд. Бармегардонад: унсурҳо, storyIds,
// суроғаҳои НАВИ галерея (барои санҷиш).
func sanitizeHighlightItems(ctx context.Context, uid string, items []map[string]interface{},
	prev map[string]bool) ([]map[string]interface{}, []string, []modMedia) {
	if len(items) > maxHighlightItems {
		items = items[:maxHighlightItems]
	}
	ids := []string{}
	for _, it := range items {
		if sid, _ := it["storyId"].(string); strings.TrimSpace(sid) != "" {
			ids = append(ids, strings.TrimSpace(sid))
		}
	}
	allowed := allowedHighlightStories(ctx, uid, ids)
	blocked := moderatedStories(ctx, ids)

	clean := []map[string]interface{}{}
	storyIDs := []string{}
	fresh := []modMedia{}
	seenStory := map[string]bool{}
	for _, it := range items {
		sid, _ := it["storyId"].(string)
		sid = strings.TrimSpace(sid)
		if sid != "" {
			if seenStory[sid] || blocked[sid] {
				continue // такрор ё пинҳон/несткардаи модератсия
			}
			m, ok := allowed[sid]
			if !ok {
				// Унсуре, ки аллакай дар ҳамин актуалӣ буд, вале сторисаш
				// дигар нест (мӯҳлат/тозакунӣ) — бетағйир мемонад. Бегона
				// ё нав — партофта мешавад.
				u, _ := it["url"].(string)
				if !prev[u] {
					continue
				}
				kind, _ := it["type"].(string)
				m = highlightMedia{u, kind}
			}
			seenStory[sid] = true
			storyIDs = append(storyIDs, sid)
			clean = append(clean, map[string]interface{}{
				"url": m.url, "type": m.kind, "storyId": sid})
			continue
		}
		u, _ := it["url"].(string)
		u = strings.TrimSpace(u)
		if !validHighlightURL(u) {
			continue
		}
		kind, _ := it["type"].(string)
		if kind != "video" {
			kind = "image"
		}
		clean = append(clean, map[string]interface{}{"url": u, "type": kind})
		if !prev[u] {
			fresh = append(fresh, modMedia{URL: u, Video: kind == "video"})
		}
	}
	return clean, storyIDs, fresh
}

// screenHighlight — ном ва расмҳои нав аз ҳамон санҷиши пост мегузаранд.
// false — ҷавоб аллакай навишта шуд.
func screenHighlight(c *gin.Context, title string, media []modMedia) bool {
	uid := mw.UID(c)
	r := modRequest{Surface: "highlight", Media: media, AI: true}
	if strings.TrimSpace(title) != "" {
		r.Texts = []string{title}
	}
	if len(r.Texts) == 0 && len(r.Media) == 0 {
		return ensureNotSuspended(c, uid)
	}
	out, ok := screenContent(c, uid, r)
	if !ok {
		return false
	}
	if out.Hold {
		queueReview(uid, r, "", out, false)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"message": HighlightHeldMessage, "code": "content_review"})
		return false
	}
	queueReview(uid, r, "", out, false)
	return true
}

// coverFor — муқова танҳо аз унсурҳои худи актуалӣ.
func coverFor(want string, items []map[string]interface{}) string {
	first := ""
	for _, it := range items {
		u, _ := it["url"].(string)
		if first == "" {
			first = u
		}
		if want != "" && u == want {
			return u
		}
	}
	return first
}

// dropStoryFromHighlights — admin сторисро нест кард: аз ҳамаи
// актуалиҳо низ бардошта мешавад.
func dropStoryFromHighlights(ctx context.Context, storyID string) {
	if storyID == "" || db.Pool == nil {
		return
	}
	var media string
	db.Pool.QueryRow(ctx, `SELECT media_url FROM stories WHERE id::text=$1`, storyID).Scan(&media)
	db.Pool.Exec(ctx, `
		WITH upd AS (
		  SELECT h.id,
		         COALESCE((SELECT jsonb_agg(e ORDER BY n)
		                     FROM jsonb_array_elements(COALESCE(h.items,'[]'::jsonb)) WITH ORDINALITY AS x(e, n)
		                    WHERE COALESCE(e->>'storyId','') <> $1), '[]'::jsonb) AS items
		    FROM highlights h
		   WHERE $1 = ANY(COALESCE(h.story_ids,'{}'))
		      OR COALESCE(h.items,'[]'::jsonb) @> jsonb_build_array(jsonb_build_object('storyId', $1::text)))
		UPDATE highlights h SET
		  items = upd.items,
		  story_ids = array_remove(COALESCE(h.story_ids,'{}'), $1),
		  cover_url = CASE WHEN $2 <> '' AND h.cover_url = $2
		                   THEN COALESCE(upd.items->0->>'url','') ELSE h.cover_url END
		  FROM upd WHERE upd.id = h.id`, storyID, media)
}
