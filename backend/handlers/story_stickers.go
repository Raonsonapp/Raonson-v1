package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/url"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  Стикерҳои сторис, ки Instagram дорад ва Raonson надошт.
//
//    question  — «Аз ман пурсед»: тамошобин матн менависад, ҷавобҳоро
//                ТАНҲО соҳиб мебинад.
//    quiz      — викторина: 2–4 вариант, як дуруст. Ҷавоб ЯК БОР,
//                иваз намешавад; баъд аз ҷавоб дуруст нишон дода
//                мешавад.
//    slider    — слайдери эмодзи 0..100. Ҷавоб як бор; баъд миёна
//                нишон дода мешавад.
//    countdown — ҳисоби баръакс то вақти муайян.
//    addyours  — «Навбати ту» (Add Yours): мавзӯъ («Акси аввали
//                телефонат»); тамошобин тугмаро зада сторияшро бо ҳамон
//                стикер мегузорад ва ба занҷир ҳамроҳ мешавад.
//
//  Пурсиш (poll) дар ҷои худ монд — ниг. VoteStoryPoll.
//  Соҳиби сторис ба стикери худ ҷавоб намедиҳад.
// ══════════════════════════════════════════════════════════════════

type stickerInput struct {
	Kind    string   `json:"kind"`
	Prompt  string   `json:"prompt"`
	Options []string `json:"options"`
	Correct int      `json:"correct"`
	Emoji   string   `json:"emoji"`
	EndsAt  string   `json:"endsAt"`
	URL     string   `json:"url"`
	// addyours: сторие, ки корбар ба занҷираш ҳамроҳ мешавад.
	JoinOf  string   `json:"joinOf"`
	X       float64  `json:"x"`
	Y       float64  `json:"y"`
}

// normalized — стикери тоза ва санҷидашуда, ё хато.
type stickerClean struct {
	Kind    string
	Prompt  string
	Options []string
	Correct int
	Emoji   string
	EndsAt  *time.Time
	URL     string
	JoinOf  string
	X, Y    float64
}

var errBadSticker = errors.New("стикер нодуруст")

func clamp01(v float64) float64 {
	if v < 0 || v != v {
		return 0.5
	}
	if v > 1 {
		return 1
	}
	return v
}

// validateSticker — ҳамаи қоидаҳо ин ҷо. Санҷида мешавад дар тест.
func validateSticker(in stickerInput, now time.Time) (*stickerClean, error) {
	out := &stickerClean{
		Kind:    strings.TrimSpace(in.Kind),
		Prompt:  clampRunes(strings.TrimSpace(in.Prompt), 80),
		Correct: -1,
		X:       clamp01(in.X),
		Y:       clamp01(in.Y),
	}
	if in.X == 0 && in.Y == 0 {
		out.X, out.Y = 0.5, 0.5
	}
	switch out.Kind {
	case "question":
		if out.Prompt == "" {
			out.Prompt = "Аз ман пурсед"
		}
	case "quiz":
		if out.Prompt == "" {
			return nil, errBadSticker
		}
		opts := []string{}
		for _, o := range in.Options {
			o = clampRunes(strings.TrimSpace(o), 30)
			if o != "" {
				opts = append(opts, o)
			}
		}
		if len(opts) < 2 || len(opts) > 4 {
			return nil, errBadSticker
		}
		if in.Correct < 0 || in.Correct >= len(opts) {
			return nil, errBadSticker
		}
		out.Options, out.Correct = opts, in.Correct
	case "slider":
		e := clampRunes(strings.TrimSpace(in.Emoji), 4)
		if e == "" {
			e = "😍"
		}
		out.Emoji = e
	case "countdown":
		if out.Prompt == "" {
			return nil, errBadSticker
		}
		t, err := time.Parse(time.RFC3339, in.EndsAt)
		if err != nil || !t.After(now) || t.After(now.Add(365*24*time.Hour)) {
			return nil, errBadSticker
		}
		out.EndsAt = &t
	case "link":
		// Стикери линк — танҳо https ва суроғаи воқеӣ.
		u, err := url.Parse(strings.TrimSpace(in.URL))
		if err != nil || u.Scheme != "https" || u.Host == "" ||
			!strings.Contains(u.Host, ".") || len(in.URL) > 500 {
			return nil, errBadSticker
		}
		out.URL = u.String()
		if out.Prompt == "" {
			out.Prompt = u.Host
		}
	case "addyours":
		// Мавзӯъ аз худи занҷир гирифта мешавад (saveSticker), агар
		// корбар ҳамроҳ шавад; барои занҷири нав — ҳатмист.
		out.JoinOf = strings.TrimSpace(in.JoinOf)
		if out.Prompt == "" && out.JoinOf == "" {
			return nil, errBadSticker
		}
	default:
		return nil, errBadSticker
	}
	return out, nil
}

// saveSticker — дар CreateStory даъват мешавад.
func saveSticker(storyID string, s *stickerClean) {
	if s == nil || storyID == "" {
		return
	}
	opts, _ := json.Marshal(s.Options)
	if s.Options == nil {
		opts = []byte("[]")
	}
	chain := ""
	if s.Kind == "addyours" {
		chain = storyID
		if s.JoinOf != "" {
			// Ҳамроҳшавӣ: мавзӯъ ва chain_id аз стикери асл. Агар он
			// ёфт нашавад (нест шуд) — занҷири нав бо мавзӯи худ.
			var root, prompt string
			if db.Pool.QueryRow(context.Background(), `
				SELECT COALESCE(NULLIF(chain_id,''), story_id), prompt
				FROM story_stickers WHERE story_id=$1 AND kind='addyours'`,
				s.JoinOf).Scan(&root, &prompt) == nil && root != "" {
				chain, s.Prompt = root, prompt
			}
		}
		if s.Prompt == "" {
			s.Prompt = "Навбати ту"
		}
	}
	db.Pool.Exec(context.Background(), `
		INSERT INTO story_stickers(story_id,kind,prompt,options,correct,emoji,ends_at,pos_x,pos_y,link_url,chain_id)
		VALUES($1,$2,$3,$4::jsonb,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (story_id) DO NOTHING`,
		storyID, s.Kind, s.Prompt, string(opts), s.Correct, s.Emoji, s.EndsAt, s.X, s.Y, s.URL, chain)
	if chain != "" && chain != storyID {
		notifyChainStarter(chain, storyID)
	}
}

// notifyChainStarter — ба касе, ки занҷирро сар кард, хабар медиҳад.
func notifyChainStarter(chainID, storyID string) {
	var starter, joiner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM stories WHERE id=$1`, chainID).Scan(&starter)
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM stories WHERE id=$1`, storyID).Scan(&joiner)
	if starter == "" || joiner == "" || starter == joiner || IsBlockedBetween(starter, joiner) {
		return
	}
	notify(starter, joiner, "story_addyours", storyID)
	pushNotify(starter, joiner, "story_addyours", storyID, "")
}

// addYoursInfo — шумораи иштирокчиён, 3 аватари охирин ва оё
// тамошобин аллакай ҳамроҳ шудааст. Бастагон ҳисоб намешаванд.
func addYoursInfo(chainID, viewerID string) gin.H {
	ctx := context.Background()
	var total int
	var joined bool
	db.Pool.QueryRow(ctx, `
		SELECT COUNT(DISTINCT s.user_id),
		       COALESCE(BOOL_OR(s.user_id=$2::text), false)
		FROM story_stickers st JOIN stories s ON s.id=st.story_id
		WHERE st.chain_id=$1`, chainID, viewerID).Scan(&total, &joined)
	avatars := []string{}
	rows, err := db.Pool.Query(ctx, `
		SELECT u.avatar FROM (
		  SELECT DISTINCT ON (s.user_id) s.user_id, s.created_at
		  FROM story_stickers st JOIN stories s ON s.id=st.story_id
		  WHERE st.chain_id=$1 ORDER BY s.user_id, s.created_at DESC) x
		JOIN users u ON u.id=x.user_id
		WHERE COALESCE(u.avatar,'') <> ''
		ORDER BY x.created_at DESC LIMIT 3`, chainID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var a string
			rows.Scan(&a)
			avatars = append(avatars, a)
		}
	}
	return gin.H{"chainId": chainID, "participants": total,
		"joined": joined, "avatars": avatars}
}

// GET /stories/addyours/:chainId — сторисҳои ФАЪОЛИ занҷир, ки
// тамошобин дидан метавонад (ҳисоби пӯшида ва бастагон — не).
func GetAddYoursChain(c *gin.Context) {
	chain := c.Param("chainId")
	myID := mw.UID(c)
	var prompt string
	if db.Pool.QueryRow(context.Background(), `
		SELECT prompt FROM story_stickers WHERE story_id=$1 AND kind='addyours'`,
		chain).Scan(&prompt) != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT s.id, s.media_url, s.media_type, s.created_at, s.expires_at,
		       u.id, u.username, COALESCE(u.avatar,''), COALESCE(u.verified,false)
		FROM story_stickers st
		JOIN stories s ON s.id=st.story_id
		JOIN users u ON u.id=s.user_id
		WHERE st.chain_id=$1 AND s.expires_at > NOW()
		  AND (s.audience IS NULL OR s.audience <> 'close' OR s.user_id=$2::text)
		  AND `+visibleAuthorSQL("s.user_id", "u", "$2")+`
		ORDER BY s.created_at DESC LIMIT 100`, chain, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var sid, murl, mtype, uid, uname, avatar string
		var created, expires time.Time
		var ver bool
		rows.Scan(&sid, &murl, &mtype, &created, &expires, &uid, &uname, &avatar, &ver)
		list = append(list, gin.H{
			"_id": sid, "mediaUrl": murl, "mediaType": mtype,
			"createdAt": created, "expiresAt": expires,
			"user": gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": ver},
		})
	}
	info := addYoursInfo(chain, myID)
	info["prompt"] = prompt
	info["stories"] = list
	c.JSON(http.StatusOK, info)
}

// attachSticker — стикерро ба ҷавоби сторис илова мекунад.
//
// ⚠️ Ҷавоби дурусти викторина ТАНҲО баъд аз ҷавоб додан (ё ба
// соҳиб) фиристода мешавад — вагарна ҳар кас онро дар ҷавоби сервер
// медид.
func attachSticker(storyID, viewerID, ownerID string, out gin.H) {
	var kind, prompt, emoji, linkURL, chainID string
	var optsRaw []byte
	var correct int
	var endsAt *time.Time
	var x, y float64
	err := db.Pool.QueryRow(context.Background(), `
		SELECT kind, prompt, options, correct, emoji, ends_at, pos_x, pos_y,
		       COALESCE(link_url,''), COALESCE(chain_id,'')
		FROM story_stickers WHERE story_id=$1`, storyID).
		Scan(&kind, &prompt, &optsRaw, &correct, &emoji, &endsAt, &x, &y, &linkURL, &chainID)
	if err != nil {
		return
	}
	isOwner := viewerID == ownerID
	st := gin.H{"kind": kind, "prompt": prompt, "x": x, "y": y, "isOwner": isOwner}

	var myChoice, myValue *int
	var myAnswer *string
	db.Pool.QueryRow(context.Background(), `
		SELECT choice, value, answer FROM story_sticker_answers
		WHERE story_id=$1 AND user_id=$2`, storyID, viewerID).
		Scan(&myChoice, &myValue, &myAnswer)

	switch kind {
	case "question":
		st["answered"] = myAnswer != nil
		if isOwner {
			var n int
			db.Pool.QueryRow(context.Background(),
				`SELECT COUNT(*) FROM story_sticker_answers WHERE story_id=$1`, storyID).Scan(&n)
			st["answersCount"] = n
		}
	case "quiz":
		var opts []string
		_ = json.Unmarshal(optsRaw, &opts)
		st["options"] = opts
		answered := myChoice != nil
		st["answered"] = answered
		if answered {
			st["myChoice"] = *myChoice
		}
		if answered || isOwner {
			st["correct"] = correct
			st["counts"] = quizCounts(storyID, len(opts))
		}
	case "slider":
		st["emoji"] = emoji
		if myValue != nil {
			st["myValue"] = *myValue
		}
		if myValue != nil || isOwner {
			avg, n := sliderStats(storyID)
			st["average"] = avg
			st["responses"] = n
		}
	case "countdown":
		st["endsAt"] = endsAt
	case "link":
		st["url"] = linkURL
	case "addyours":
		if chainID == "" {
			chainID = storyID
		}
		for k, v := range addYoursInfo(chainID, viewerID) {
			st[k] = v
		}
	}
	out["sticker"] = st
}

func quizCounts(storyID string, n int) []int {
	counts := make([]int, n)
	rows, err := db.Pool.Query(context.Background(), `
		SELECT choice, COUNT(*) FROM story_sticker_answers
		WHERE story_id=$1 AND choice IS NOT NULL GROUP BY choice`, storyID)
	if err != nil {
		return counts
	}
	defer rows.Close()
	for rows.Next() {
		var ch, c int
		rows.Scan(&ch, &c)
		if ch >= 0 && ch < n {
			counts[ch] = c
		}
	}
	return counts
}

func sliderStats(storyID string) (int, int) {
	var avg float64
	var n int
	db.Pool.QueryRow(context.Background(), `
		SELECT COALESCE(AVG(value),0), COUNT(*) FROM story_sticker_answers
		WHERE story_id=$1 AND value IS NOT NULL`, storyID).Scan(&avg, &n)
	return int(avg + 0.5), n
}

// POST /stories/:id/sticker/respond {choice|value|answer}
func RespondStorySticker(c *gin.Context) {
	sid := c.Param("id")
	myID := mw.UID(c)
	var b struct {
		Choice *int    `json:"choice"`
		Value  *int    `json:"value"`
		Answer *string `json:"answer"`
	}
	if c.ShouldBindJSON(&b) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "ҷавоб лозим"})
		return
	}

	var owner, kind, optsRaw string
	var correct int
	var expires time.Time
	err := db.Pool.QueryRow(context.Background(), `
		SELECT s.user_id, st.kind, st.options::text, st.correct, s.expires_at
		FROM stories s JOIN story_stickers st ON st.story_id=s.id
		WHERE s.id=$1`, sid).Scan(&owner, &kind, &optsRaw, &correct, &expires)
	if err != nil || time.Now().After(expires) || canSeeStory(myID, sid) == "" {
		c.JSON(http.StatusNotFound, gin.H{"message": "Стикер ёфт нашуд"})
		return
	}
	if owner == myID {
		c.JSON(http.StatusForbidden, gin.H{"message": "Ба стикери худ ҷавоб дода намешавад"})
		return
	}
	if denyIfBlocked(c, myID, owner) {
		return
	}
	ctx := context.Background()

	switch kind {
	case "question":
		if b.Answer == nil {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Матни ҷавоб лозим"})
			return
		}
		ans := clampRunes(strings.TrimSpace(*b.Answer), 200)
		if ans == "" {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Матни ҷавоб лозим"})
			return
		}
		// Мисли Instagram — ҷавобро метавон нав кард.
		db.Pool.Exec(ctx, `
			INSERT INTO story_sticker_answers(story_id,user_id,answer) VALUES($1,$2,$3)
			ON CONFLICT (story_id,user_id) DO UPDATE SET answer=EXCLUDED.answer, created_at=NOW()`,
			sid, myID, ans)
		notify(owner, myID, "story_answer", sid)
		pushNotify(owner, myID, "story_answer", sid, "")
		c.JSON(http.StatusOK, gin.H{"answered": true})

	case "quiz":
		var opts []string
		_ = json.Unmarshal([]byte(optsRaw), &opts)
		if b.Choice == nil || *b.Choice < 0 || *b.Choice >= len(opts) {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Варианти нодуруст"})
			return
		}
		// Як бор — иваз намешавад (DO NOTHING).
		tag, _ := db.Pool.Exec(ctx, `
			INSERT INTO story_sticker_answers(story_id,user_id,choice) VALUES($1,$2,$3)
			ON CONFLICT (story_id,user_id) DO NOTHING`, sid, myID, *b.Choice)
		var mine int
		db.Pool.QueryRow(ctx, `SELECT choice FROM story_sticker_answers
			WHERE story_id=$1 AND user_id=$2`, sid, myID).Scan(&mine)
		if tag.RowsAffected() > 0 {
			notify(owner, myID, "story_quiz", sid)
			pushNotify(owner, myID, "story_quiz", sid, "")
		}
		c.JSON(http.StatusOK, gin.H{
			"myChoice": mine, "correct": correct, "isCorrect": mine == correct,
			"counts": quizCounts(sid, len(opts)), "locked": tag.RowsAffected() == 0,
		})

	case "slider":
		if b.Value == nil || *b.Value < 0 || *b.Value > 100 {
			c.JSON(http.StatusBadRequest, gin.H{"message": "Қимат бояд 0–100 бошад"})
			return
		}
		tag, _ := db.Pool.Exec(ctx, `
			INSERT INTO story_sticker_answers(story_id,user_id,value) VALUES($1,$2,$3)
			ON CONFLICT (story_id,user_id) DO NOTHING`, sid, myID, *b.Value)
		var mine int
		db.Pool.QueryRow(ctx, `SELECT value FROM story_sticker_answers
			WHERE story_id=$1 AND user_id=$2`, sid, myID).Scan(&mine)
		avg, n := sliderStats(sid)
		c.JSON(http.StatusOK, gin.H{
			"myValue": mine, "average": avg, "responses": n,
			"locked": tag.RowsAffected() == 0,
		})

	default:
		// Ба ҳисоби баръакс ҷавоб дода намешавад.
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ба ин стикер ҷавоб дода намешавад"})
	}
}

// GET /stories/:id/sticker/answers — ТАНҲО соҳиб.
func GetStickerAnswers(c *gin.Context) {
	sid := c.Param("id")
	myID := mw.UID(c)
	var owner string
	db.Pool.QueryRow(context.Background(),
		`SELECT user_id FROM stories WHERE id=$1`, sid).Scan(&owner)
	// Ҳамон ҷавоб барои «нест» ва «бегона» — ҷавобҳо ошкор намешаванд.
	if owner == "" || owner != myID {
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
		return
	}
	rows, err := db.Pool.Query(context.Background(), `
		SELECT u.id, u.username, u.avatar, COALESCE(u.verified,false),
		       a.choice, a.value, a.answer, a.created_at
		FROM story_sticker_answers a JOIN users u ON u.id=a.user_id
		WHERE a.story_id=$1 ORDER BY a.created_at DESC LIMIT 500`, sid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хато"})
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var uid, uname, avatar string
		var ver bool
		var choice, value *int
		var answer *string
		var at time.Time
		rows.Scan(&uid, &uname, &avatar, &ver, &choice, &value, &answer, &at)
		item := gin.H{
			"user": gin.H{"_id": uid, "username": uname, "avatar": avatar, "verified": ver},
			"createdAt": at,
		}
		if choice != nil {
			item["choice"] = *choice
		}
		if value != nil {
			item["value"] = *value
		}
		if answer != nil {
			item["answer"] = *answer
		}
		list = append(list, item)
	}
	c.JSON(http.StatusOK, gin.H{"answers": list})
}

// ── Упоминание (@) ────────────────────────────────────────────────

type mentionInput struct {
	Username string  `json:"username"`
	X        float64 `json:"x"`
	Y        float64 `json:"y"`
}

// saveStoryMentions — номҳоро ба корбарони воқеӣ табдил медиҳад, сабт
// мекунад ва ба ҳар кадом хабар мефиристад.
//
// Пеш «@ном» танҳо ба расм часпонида мешуд: на зада мешуд, на ба он
// шахс хабар мерафт, ва дар стори видеоӣ умуман гум мешуд.
func saveStoryMentions(storyID, authorID string, in []mentionInput) {
	if storyID == "" || len(in) == 0 {
		return
	}
	if len(in) > 10 {
		in = in[:10]
	}
	ctx := context.Background()
	seen := map[string]bool{}
	for _, m := range in {
		uname := normalizeLoginID(m.Username)
		if uname == "" || seen[uname] {
			continue
		}
		seen[uname] = true
		var uid, real string
		allow := true
		if db.Pool.QueryRow(ctx,
			`SELECT id, username, COALESCE(allow_mentions,true) FROM users
			 WHERE lower(username)=$1 AND COALESCE(banned,false)=FALSE`,
			uname).Scan(&uid, &real, &allow) != nil || uid == authorID || !allow {
			continue
		}
		if IsBlockedBetween(authorID, uid) {
			continue
		}
		db.Pool.Exec(ctx, `INSERT INTO story_mentions(story_id,user_id,username,pos_x,pos_y)
			VALUES($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING`,
			storyID, uid, real, clamp01(m.X), clamp01(m.Y))
		notify(uid, authorID, "story_mention", storyID)
		pushNotify(uid, authorID, "story_mention", storyID, "")
	}
}

// attachMentions — рӯйхати упоминаниеҳо барои тамошобин.
func attachMentions(storyID string, out gin.H) {
	rows, err := db.Pool.Query(context.Background(), `
		SELECT user_id, username, pos_x, pos_y FROM story_mentions WHERE story_id=$1`, storyID)
	if err != nil {
		return
	}
	defer rows.Close()
	list := []gin.H{}
	for rows.Next() {
		var uid, un string
		var x, y float64
		rows.Scan(&uid, &un, &x, &y)
		list = append(list, gin.H{"userId": uid, "username": un, "x": x, "y": y})
	}
	if len(list) > 0 {
		out["mentions"] = list
	}
}
