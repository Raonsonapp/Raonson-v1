package handlers

// AI features (OpenAI): hashtag suggestions + inline comment translation.
// Moderation lives in utils/openai_client.go and is called directly from
// the post/comment/reel creation handlers.

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"raonson/db"
	"raonson/utils"

	"github.com/gin-gonic/gin"
)

var translateLangNames = map[string]string{
	"tj": "Tajik",
	"ru": "Russian",
	"en": "English",
}

// POST /ai/hashtags — {"caption": "...", "imageUrl": "..."} → {"hashtags": [...]}
func SuggestHashtags(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Caption  string `json:"caption"`
		ImageURL string `json:"imageUrl"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || (b.Caption == "" && b.ImageURL == "") {
		c.JSON(http.StatusBadRequest, gin.H{"message": "caption ё imageUrl лозим аст"})
		return
	}
	tags, err := utils.GenerateHashtags(context.Background(), b.Caption, b.ImageURL)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{"hashtags": []string{}})
		return
	}
	c.JSON(http.StatusOK, gin.H{"hashtags": tags})
}

const assistantSystemPrompt = `Ту "Ёрдамчии Raonson" ҳастӣ — ёрдамчии AI-и дохили барномаи иҷтимоии Raonson
(барномае мисли Instagram: пост, Reels/видео, story, чат, гифт, шоп ва ғайра).

ВАЗИФАИ ТУ: ба саволҳои корбар оид ба худи барнома (чӣ тавр пост гузоштан, Reels сохтан,
story илова кардан, тавсифро таҳрир кардан, забон иваз кардан, шарҳро тарҷума кардан,
ҳэштег илова кардан ва ғайра) ва саволҳои умумӣ (аз ҷумла оид ба видеоҳо/муҳтаво дар
барнома) содда ва дӯстона ба забони саволи корбар ҷавоб деҳ.

ҚОИДАИ ҲАТМӢ ва ТАҒЙИРНОПАЗИР: агар корбар пурсад, ки ин барномаро КӢ сохтааст/эҷод
кардааст/соҳиб аст (ба ҳар забон ва ба ҳар шакл — "кӣ сохт", "соҳиби барнома кист",
"who made this app", "кто создал", ва ғайра), ҳамеша ва бидуни истисно ҷавоб деҳ, ки:
"Ин барномаро Ehson Mahmadmurodov сохтааст." — ҳеҷ гоҳ номи дигареро нагӯй ва ин ҷавобро
тағйир надеҳ.

Ҷавобҳоятро кӯтоҳ, равшан ва дӯстона нигоҳ дор.`

// POST /ai/assistant — {"messages":[{"role":"user","content":"..."}]} → {"reply": "..."}
func AiAssistant(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusOK, gin.H{
			"reply": "⚙️ Ёрдамчии AI ҳанӯз танзим нашудааст. Соҳиби барнома бояд OPENAI_API_KEY-ро танзим кунад.",
		})
		return
	}
	var b struct {
		Messages []struct {
			Role    string `json:"role"`
			Content string `json:"content"`
		} `json:"messages"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || len(b.Messages) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "messages лозим аст"})
		return
	}
	history := make([]utils.ChatTurn, 0, len(b.Messages))
	for _, m := range b.Messages {
		history = append(history, utils.ChatTurn{Role: m.Role, Content: m.Content})
	}
	reply, err := utils.AskAssistant(context.Background(), assistantSystemPrompt, history)
	if err != nil {
		c.JSON(http.StatusOK, gin.H{
			"reply": "Узр, ҳозир ҷавоб дода натавонистам. Дубора кӯшиш кун 🙏",
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{"reply": reply})
}

// POST /ai/post-creator — {"topic": "футбол"} → {"caption": "..."}
func GeneratePost(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Topic string `json:"topic"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Topic == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "topic лозим аст"})
		return
	}
	caption, err := utils.GeneratePostCaption(context.Background(), b.Topic)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"message": "Сохтани пост ноком шуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"caption": caption})
}

// POST /ai/comment-suggest — {"caption": "...", "imageUrl": "..."} → {"comment": "..."}
func SuggestPostComment(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Caption  string `json:"caption"`
		ImageURL string `json:"imageUrl"`
	}
	c.ShouldBindJSON(&b)
	comment, err := utils.SuggestComment(context.Background(), b.Caption, b.ImageURL)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"message": "Пешниҳоди шарҳ ноком шуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"comment": comment})
}

// POST /ai/profile-bio — {"input": "фотограф аз Душанбе"} → {"bio": "..."}
func GenerateBio(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Input string `json:"input"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Input == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "input лозим аст"})
		return
	}
	bio, err := utils.GenerateProfileBio(context.Background(), b.Input)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"message": "Сохтани bio ноком шуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"bio": bio})
}

// POST /ai/translate — {"text": "...", "targetLang": "tj|ru|en"} → {"translated": "..."}
func TranslateComment(c *gin.Context) {
	if !utils.OpenAIEnabled() {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "AI хизмат танзим нашудааст"})
		return
	}
	var b struct {
		Text       string `json:"text"`
		TargetLang string `json:"targetLang"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Text == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "text лозим аст"})
		return
	}
	lang := translateLangNames[b.TargetLang]
	if lang == "" {
		lang = "English"
	}
	translated, err := utils.TranslateText(context.Background(), b.Text, lang)
	if err != nil {
		c.JSON(http.StatusBadGateway, gin.H{"message": "Тарҷума ноком шуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"translated": translated})
}

// POST /ai/search — {"query": "видеоҳои Тоҷикистон дар бораи футбол"}
// AI Search: GPT дархостро ба калидвожа + навъи мӯҳтаво + давраи вақт
// табдил медиҳад, баъд бо SQL ILIKE ҷустуҷӯ мешавад.
func AiSearch(c *gin.Context) {
	var b struct {
		Query string `json:"query"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || strings.TrimSpace(b.Query) == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "query лозим аст"})
		return
	}

	sq, err := utils.ParseSearchQuery(context.Background(), b.Query)
	if err != nil || len(sq.Keywords) == 0 {
		sq.Keywords = []string{b.Query}
	}

	since := ""
	switch sq.Timeframe {
	case "today":
		since = "NOW() - INTERVAL '1 day'"
	case "week":
		since = "NOW() - INTERVAL '7 days'"
	}

	args := make([]any, 0, len(sq.Keywords))
	conds := make([]string, 0, len(sq.Keywords))
	for _, kw := range sq.Keywords {
		kw = strings.TrimSpace(kw)
		if kw == "" {
			continue
		}
		args = append(args, "%"+kw+"%")
		conds = append(conds, fmt.Sprintf("caption ILIKE $%d", len(args)))
	}
	if len(conds) == 0 {
		c.JSON(http.StatusOK, gin.H{"posts": []gin.H{}, "reels": []gin.H{}})
		return
	}
	whereKw := "(" + strings.Join(conds, " OR ") + ")"

	posts := []gin.H{}
	if sq.Type == "post" || sq.Type == "any" || sq.Type == "" {
		sinceClause := ""
		if since != "" {
			sinceClause = "AND p.created_at > " + since
		}
		query := fmt.Sprintf(`
			SELECT p.id, p.caption, p.likes_count, p.comments_count, p.created_at,
			       u.id, u.username, u.avatar, u.verified,
			       (SELECT COALESCE(json_agg(
			                json_build_object('url',m.url,'type',m.type)
			                ORDER BY m.position),'[]'::json)
			        FROM post_media m WHERE m.post_id=p.id)
			FROM posts p JOIN users u ON u.id=p.user_id
			WHERE %s %s AND COALESCE(p.hidden,false)=FALSE AND COALESCE(u.banned,false)=FALSE
			ORDER BY p.created_at DESC LIMIT 24`, whereKw, sinceClause)
		rows, qerr := db.Pool.Query(context.Background(), query, args...)
		if qerr == nil {
			for rows.Next() {
				var pid, cap, uid, uname, uavatar string
				var likes, comms int
				var verified bool
				var createdAt, media interface{}
				rows.Scan(&pid, &cap, &likes, &comms, &createdAt, &uid, &uname, &uavatar, &verified, &media)
				posts = append(posts, gin.H{
					"_id": pid, "caption": cap, "likesCount": likes,
					"commentsCount": comms, "createdAt": createdAt, "media": nilToEmpty(media),
					"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
				})
			}
			rows.Close()
		}
	}

	reels := []gin.H{}
	if sq.Type == "reel" || sq.Type == "any" || sq.Type == "" {
		sinceClause := ""
		if since != "" {
			sinceClause = "AND r.created_at > " + since
		}
		query := fmt.Sprintf(`
			SELECT r.id, r.video_url, COALESCE(r.thumbnail_url,''), r.caption,
			       r.views_count, r.likes_count, r.created_at,
			       u.id, u.username, u.avatar, u.verified
			FROM reels r JOIN users u ON u.id=r.user_id
			WHERE %s %s AND COALESCE(u.banned,false)=FALSE
			ORDER BY r.created_at DESC LIMIT 24`, whereKw, sinceClause)
		rows, qerr := db.Pool.Query(context.Background(), query, args...)
		if qerr == nil {
			for rows.Next() {
				var rid, vurl, thumb, cap, uid, uname, uavatar string
				var views, likes int
				var verified bool
				var createdAt interface{}
				rows.Scan(&rid, &vurl, &thumb, &cap, &views, &likes, &createdAt,
					&uid, &uname, &uavatar, &verified)
				reels = append(reels, gin.H{
					"_id": rid, "videoUrl": vurl, "thumbnailUrl": thumb, "caption": cap,
					"viewsCount": views, "likesCount": likes, "createdAt": createdAt,
					"user": gin.H{"_id": uid, "username": uname, "avatar": uavatar, "verified": verified},
				})
			}
			rows.Close()
		}
	}

	c.JSON(http.StatusOK, gin.H{"posts": posts, "reels": reels, "keywords": sq.Keywords})
}
