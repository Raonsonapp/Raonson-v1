package handlers

import (
	"context"
	"net/http"
	"net/url"
	"strings"
	"unicode"

	"raonson/db"
	mw "raonson/middleware"
	ntf "raonson/notify"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Паёми худкор ба Direct аз рӯи калимаи шарҳ — мисли ManyChat/ChatPlace.
//
//  Муаллиф ҳангоми нашр (ё баъд аз ⋯) калимаҳо («1», «салом», «нарх»)
//  ва паём/пайвандро муқаррар мекунад. Касе, ки шарҳ бо яке аз ин
//  калимаҳо менависад, фавран ба Direct паём мегирад.
//
//  Қоидаҳо:
//    • танҳо соҳиби пост/рилс қоидаро мегузорад ва мебинад;
//    • ҳар шарҳнавис барои як мундариҷа танҳо як бор (auto_dm_sent);
//    • ба худ, ба басташуда ва барои шарҳи пинҳон/restrict — не;
//    • пайванд танҳо https; то 300 паём дар соат барои як муаллиф.
// ══════════════════════════════════════════════════════════════════

const (
	autoDMMaxKeywords = 10
	autoDMMaxKeyword  = 40
	autoDMMaxMessage  = 1000
	autoDMMaxLink     = 500
	autoDMHourlyCap   = 300
)

// normalizeForMatch — ҳарфи хурд, аломатҳо ба фосила, фосилаҳои зиёдатӣ нест.
func normalizeForMatch(s string) string {
	var b strings.Builder
	space := true
	for _, r := range strings.ToLower(s) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
			space = false
		} else if !space {
			b.WriteByte(' ')
			space = true
		}
	}
	return strings.TrimSpace(b.String())
}

// autoDMMatches — калима бояд ҳамчун КАЛИМАИ ПУРРА ояд: «1» дар «10»
// ё «салом» дар «саломат» мувофиқ нест.
func autoDMMatches(text string, keywords []string, anyWord bool) bool {
	norm := normalizeForMatch(text)
	if norm == "" {
		return false
	}
	if anyWord {
		return true
	}
	padded := " " + norm + " "
	for _, k := range keywords {
		k = normalizeForMatch(k)
		if k != "" && strings.Contains(padded, " "+k+" ") {
			return true
		}
	}
	return false
}

// cleanKeywords — такрор, холӣ ва дарозро тоза мекунад.
func cleanKeywords(in []string) []string {
	out := []string{}
	seen := map[string]bool{}
	for _, k := range in {
		k = clampRunes(strings.TrimSpace(k), autoDMMaxKeyword)
		n := normalizeForMatch(k)
		if n == "" || seen[n] {
			continue
		}
		seen[n] = true
		out = append(out, k)
		if len(out) == autoDMMaxKeywords {
			break
		}
	}
	return out
}

func validAutoDMLink(s string) bool {
	if s == "" {
		return true
	}
	if len(s) > autoDMMaxLink {
		return false
	}
	u, err := url.Parse(s)
	return err == nil && u.Scheme == "https" && u.Host != "" && !strings.ContainsAny(s, " \n\t")
}

// contentOwner — соҳиби пост/рилс ё "".
func contentOwner(kind, id string) string {
	var owner string
	switch kind {
	case "post":
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM posts WHERE id=$1`, id).Scan(&owner)
	case "reel":
		db.Pool.QueryRow(context.Background(),
			`SELECT user_id FROM reels WHERE id=$1`, id).Scan(&owner)
	}
	return owner
}

func autoDMKind(c *gin.Context) (string, bool) {
	k := c.Param("kind")
	if k != "post" && k != "reel" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "kind: post ё reel"})
		return "", false
	}
	return k, true
}

// GET /auto-dm/:kind/:id — танҳо соҳиб.
func GetAutoDM(c *gin.Context) {
	me := mw.UID(c)
	kind, ok := autoDMKind(c)
	if !ok {
		return
	}
	id := c.Param("id")
	if contentOwner(kind, id) != me {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	var kw []string
	var anyWord, enabled bool
	var msg, link string
	var sent int
	err := db.Pool.QueryRow(context.Background(), `
		SELECT keywords, any_word, message, link, enabled, sent_count
		FROM auto_dm_rules WHERE kind=$1 AND content_id=$2`, kind, id).
		Scan(&kw, &anyWord, &msg, &link, &enabled, &sent)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"enabled": false, "keywords": []string{},
			"anyWord": false, "message": "", "link": "", "sentCount": 0, "exists": false})
		return
	}
	if kw == nil {
		kw = []string{}
	}
	c.JSON(http.StatusOK, gin.H{"enabled": enabled, "keywords": kw, "anyWord": anyWord,
		"message": msg, "link": link, "sentCount": sent, "exists": true})
}

// PUT /auto-dm/:kind/:id {keywords[], anyWord, message, link, enabled}
func SetAutoDM(c *gin.Context) {
	me := mw.UID(c)
	kind, ok := autoDMKind(c)
	if !ok {
		return
	}
	id := c.Param("id")
	if contentOwner(kind, id) != me {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	var b AutoDMInput
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}
	if msg := b.normalize(); msg != "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": msg})
		return
	}
	// Паёми худкор ба ДМ-и бегонаҳо меравад — ҳамон модератсияи паём.
	// Пеш он бе санҷиш сабт мешуд: матни дашномдор ё линки 18+ аз
	// модератсияи чат мегузашт, ҳатто аз корбари маҳдудшуда.
	r := modRequest{Surface: "auto_dm", Texts: []string{b.Message, b.Link}}
	out, ok := screenContent(c, me, r)
	if !ok {
		return
	}
	if out.Hold {
		queueReview(me, r, kind+":"+id, out, false)
		c.JSON(http.StatusUnprocessableEntity, gin.H{
			"message": "Ин паёмро фиристодан мумкин нест. Лутфан онро иваз кунед",
			"code":    "content_review"})
		return
	}
	queueReview(me, r, kind+":"+id, out, false)
	if err := saveAutoDM(kind, id, me, b); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Сабт нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"enabled": *b.Enabled, "keywords": b.Keywords, "anyWord": b.AnyWord,
		"message": b.Message, "link": b.Link, "exists": true})
}

// AutoDMInput — ҳам дар PUT /auto-dm, ҳам ҳангоми нашр («autoDm»).
type AutoDMInput struct {
	Keywords []string `json:"keywords"`
	AnyWord  bool     `json:"anyWord"`
	Message  string   `json:"message"`
	Link     string   `json:"link"`
	Enabled  *bool    `json:"enabled"`
}

// normalize — тоза мекунад; хато бошад, матни хаторо бармегардонад.
func (b *AutoDMInput) normalize() string {
	b.Keywords = cleanKeywords(b.Keywords)
	b.Message = clampRunes(strings.TrimSpace(b.Message), autoDMMaxMessage)
	b.Link = strings.TrimSpace(b.Link)
	if b.Enabled == nil {
		t := true
		b.Enabled = &t
	}
	switch {
	case !validAutoDMLink(b.Link):
		return "Пайванд бояд бо https:// оғоз шавад"
	case b.Message == "" && b.Link == "":
		return "Паём ё пайванд лозим"
	case !b.AnyWord && len(b.Keywords) == 0:
		return "Ақаллан як калима нависед ё «Ҳар шарҳ»-ро интихоб кунед"
	}
	return ""
}

func saveAutoDM(kind, id, owner string, b AutoDMInput) error {
	_, err := db.Pool.Exec(context.Background(), `
		INSERT INTO auto_dm_rules(kind,content_id,owner_id,keywords,any_word,message,link,enabled)
		VALUES($1,$2,$3,$4,$5,$6,$7,$8)
		ON CONFLICT (kind,content_id) DO UPDATE SET
		  keywords=EXCLUDED.keywords, any_word=EXCLUDED.any_word,
		  message=EXCLUDED.message, link=EXCLUDED.link,
		  enabled=EXCLUDED.enabled, updated_at=NOW()`,
		kind, id, owner, b.Keywords, b.AnyWord, b.Message, b.Link, *b.Enabled)
	return err
}

// DELETE /auto-dm/:kind/:id
func DeleteAutoDM(c *gin.Context) {
	me := mw.UID(c)
	kind, ok := autoDMKind(c)
	if !ok {
		return
	}
	id := c.Param("id")
	if contentOwner(kind, id) != me {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	db.Pool.Exec(context.Background(),
		`DELETE FROM auto_dm_rules WHERE kind=$1 AND content_id=$2`, kind, id)
	c.JSON(http.StatusOK, gin.H{"deleted": true})
}

// maybeAutoDM — пас аз шарҳи намоён даъват мешавад (дар goroutine).
func maybeAutoDM(kind, contentID, owner, commenter, text string) {
	if owner == "" || commenter == "" || owner == commenter {
		return
	}
	go func() {
		ctx := context.Background()
		var kw []string
		var anyWord bool
		var msg, link string
		if err := db.Pool.QueryRow(ctx, `
			SELECT keywords, any_word, message, link FROM auto_dm_rules
			WHERE kind=$1 AND content_id=$2 AND owner_id=$3 AND enabled`,
			kind, contentID, owner).Scan(&kw, &anyWord, &msg, &link); err != nil {
			return
		}
		if !autoDMMatches(text, kw, anyWord) || IsBlockedBetween(owner, commenter) {
			return
		}
		// Соҳиби маҳдудшуда ё бандор паём фиристода наметавонад — паёми
		// худкор ҳам не.
		var barred bool
		db.Pool.QueryRow(ctx, `SELECT COALESCE(banned,false) OR COALESCE(suspended_until > NOW(), false)
			FROM users WHERE id=$1`, owner).Scan(&barred)
		if barred {
			return
		}
		var recent int
		db.Pool.QueryRow(ctx, `SELECT COUNT(*) FROM auto_dm_sent
			WHERE owner_id=$1 AND created_at > NOW() - INTERVAL '1 hour'`, owner).Scan(&recent)
		if recent >= autoDMHourlyCap {
			return
		}
		// Як бор барои ҳар шарҳнавис: агар сатр аллакай ҳаст — ҳеҷ чиз.
		tag, err := db.Pool.Exec(ctx, `
			INSERT INTO auto_dm_sent(kind,content_id,user_id,owner_id)
			VALUES($1,$2,$3,$4) ON CONFLICT DO NOTHING`, kind, contentID, commenter, owner)
		if err != nil || tag.RowsAffected() == 0 {
			return
		}
		body := strings.TrimSpace(msg)
		if link != "" {
			if body != "" {
				body += "\n"
			}
			body += link
		}
		chatID := sortedChatID(owner, commenter)
		var msgID string
		if err := db.Pool.QueryRow(ctx, `
			INSERT INTO messages (chat_id, sender_id, receiver_id, text, type, created_at, updated_at)
			VALUES ($1,$2,$3,$4,'text',NOW(),NOW()) RETURNING id`,
			chatID, owner, commenter, body).Scan(&msgID); err != nil {
			db.Pool.Exec(ctx, `DELETE FROM auto_dm_sent WHERE kind=$1 AND content_id=$2 AND user_id=$3`,
				kind, contentID, commenter)
			return
		}
		// Шарҳнавис худаш калимаро навишт, яъне паёмро интизор аст —
		// он дар «Дархостҳо» гум намешавад, балки дар рӯйхати асосӣ меояд.
		db.Pool.Exec(ctx, `INSERT INTO chat_accepts(user_id,peer_id) VALUES($1,$2) ON CONFLICT DO NOTHING`,
			commenter, owner)
		db.Pool.Exec(ctx, `UPDATE auto_dm_rules SET sent_count=sent_count+1 WHERE kind=$1 AND content_id=$2`,
			kind, contentID)
		if m, e := fetchMessageByID(msgID, commenter); e == nil {
			emitChat("chat:new", m, commenter, owner)
		}
		if !chatMuted(commenter, owner) {
			pushNotify(commenter, owner, string(ntf.Message), chatID, "")
		}
	}()
}
