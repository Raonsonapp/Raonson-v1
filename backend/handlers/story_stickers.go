package handlers

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
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
	db.Pool.Exec(context.Background(), `
		INSERT INTO story_stickers(story_id,kind,prompt,options,correct,emoji,ends_at,pos_x,pos_y)
		VALUES($1,$2,$3,$4::jsonb,$5,$6,$7,$8,$9)
		ON CONFLICT (story_id) DO NOTHING`,
		storyID, s.Kind, s.Prompt, string(opts), s.Correct, s.Emoji, s.EndsAt, s.X, s.Y)
}

// attachSticker — стикерро ба ҷавоби сторис илова мекунад.
//
// ⚠️ Ҷавоби дурусти викторина ТАНҲО баъд аз ҷавоб додан (ё ба
// соҳиб) фиристода мешавад — вагарна ҳар кас онро дар ҷавоби сервер
// медид.
func attachSticker(storyID, viewerID, ownerID string, out gin.H) {
	var kind, prompt, emoji string
	var optsRaw []byte
	var correct int
	var endsAt *time.Time
	var x, y float64
	err := db.Pool.QueryRow(context.Background(), `
		SELECT kind, prompt, options, correct, emoji, ends_at, pos_x, pos_y
		FROM story_stickers WHERE story_id=$1`, storyID).
		Scan(&kind, &prompt, &optsRaw, &correct, &emoji, &endsAt, &x, &y)
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
	if err != nil || time.Now().After(expires) {
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
