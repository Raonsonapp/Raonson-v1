package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"

	"raonson/utils"

	"github.com/gin-gonic/gin"
)

// ══════════════════════════════════════════════════════════════════
//  POST /ai/assistant — «Ёрдамчии Raonson»
//
//  Корбар: «ягон модели ройгон гир, то ба ҳар саволи барнома пурра
//  ҷавоб диҳад, ба интернет дастрасӣ дошта бошад ва хабарҳоро дар
//  наздиктарин вақт гӯяд».
//
//  Пеш ёрдамчӣ ТАНҲО бо калиди пулакии OpenAI кор мекард; бе он ба
//  ҳар савол як ҷавоб медод: «танзим нашудааст». Дар телефон — экрани
//  холӣ.
//
//  Ҳоло се қабат:
//
//   1. ИНТЕРНЕТ — ҳар савол аввал ба манбаъҳои зинда меравад:
//        • хабар  → RSS-и Asia-Plus, Озодӣ, Ховар, Sputnik ва ғ.
//                   (ҳамон кэши `/news`, 10 дақиқа)
//        • далел  → Википедия (тоҷикӣ → русӣ → англисӣ)
//      Ҳар ҷавоб манбаъҳоро бо линк бармегардонад.
//
//   2. ДОНИШИ БАРНОМА — ҳар функсияи Raonson ва роҳи ёфтани он.
//
//   3. МОДЕЛ — агар калиди LLM бошад (ройгон: Groq, Llama 3.3 70B;
//      AI_API_KEY), модел бо ҳамин маълумот ҷавоби табиӣ менависад.
//      Агар набошад ё хато диҳад — ҷавоб аз ду қабати аввал сохта
//      мешавад. Ёрдамчӣ ҲЕҶ ГОҲ холӣ намемонад.
//
//  Модел ҳеҷ гоҳ хабари бе манбаъ ихтироъ намекунад: дар system
//  prompt гуфта шудааст, ки танҳо аз маълумоти додашуда истифода
//  барад.
// ══════════════════════════════════════════════════════════════════

type assistantSource struct {
	Title string `json:"title"`
	URL   string `json:"url"`
}

// Суроғаҳои Википедия — тағйирёбанда барои тест.
var wikiBase = map[string]string{
	"tg": "https://tg.wikipedia.org",
	"ru": "https://ru.wikipedia.org",
	"en": "https://en.wikipedia.org",
}

var assistantHTTP = &http.Client{Timeout: 6 * time.Second}

// ── Қасд ──────────────────────────────────────────────────────────

var newsWords = []string{
	"хабар", "ахбор", "навигарӣ", "навигари", "имрӯз чӣ", "чӣ гап",
	"новост", "что случилось", "что нового", "news", "headline", "today",
	"ҳодиса", "событи",
}

func isNewsQuestion(q string) bool {
	q = strings.ToLower(q)
	for _, w := range newsWords {
		if strings.Contains(q, w) {
			return true
		}
	}
	return false
}

// ── Хабарҳо ───────────────────────────────────────────────────────

// latestNews — ҳамон кэше, ки `/news` истифода мебарад.
func latestNews(limit int) []newsItem {
	newsMu.Lock()
	fresh := len(newsCache) > 0 && time.Since(newsCacheTime) < newsCacheTTL
	items := newsCache
	newsMu.Unlock()
	if !fresh {
		if fetched := fetchAllNews(); len(fetched) > 0 {
			newsMu.Lock()
			newsCache, newsCacheTime = fetched, time.Now()
			newsMu.Unlock()
			items = fetched
		}
	}
	// Навтарин аввал.
	sorted := append([]newsItem(nil), items...)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].ts.After(sorted[j].ts) })
	if len(sorted) > limit {
		sorted = sorted[:limit]
	}
	return sorted
}

// ── Википедия ─────────────────────────────────────────────────────

func wikiLookup(ctx context.Context, q string) (title, extract, link string) {
	for _, lang := range []string{"tg", "ru", "en"} {
		base := wikiBase[lang]
		su := base + "/w/rest.php/v1/search/page?limit=1&q=" + url.QueryEscape(q)
		req, _ := http.NewRequestWithContext(ctx, http.MethodGet, su, nil)
		req.Header.Set("User-Agent", "RaonsonAssistant/1.0 (raonson.app)")
		res, err := assistantHTTP.Do(req)
		if err != nil {
			continue
		}
		var sr struct {
			Pages []struct {
				Key   string `json:"key"`
				Title string `json:"title"`
			} `json:"pages"`
		}
		_ = json.NewDecoder(res.Body).Decode(&sr)
		res.Body.Close()
		if len(sr.Pages) == 0 {
			continue
		}
		key := sr.Pages[0].Key
		req2, _ := http.NewRequestWithContext(ctx, http.MethodGet,
			base+"/api/rest_v1/page/summary/"+url.PathEscape(key), nil)
		req2.Header.Set("User-Agent", "RaonsonAssistant/1.0 (raonson.app)")
		res2, err := assistantHTTP.Do(req2)
		if err != nil {
			continue
		}
		var sum struct {
			Title   string `json:"title"`
			Extract string `json:"extract"`
		}
		_ = json.NewDecoder(res2.Body).Decode(&sum)
		res2.Body.Close()
		if strings.TrimSpace(sum.Extract) == "" {
			continue
		}
		return sum.Title, clampRunes(sum.Extract, 900), base + "/wiki/" + url.PathEscape(key)
	}
	return "", "", ""
}

// ── Дониши барнома ────────────────────────────────────────────────

type appFAQ struct {
	keys   []string
	answer string
}

// appKnowledge — ҳар функсияи воқеии Raonson ва роҳи он. Танҳо он
// чи ВОҚЕАН ҳаст — ёрдамчӣ набояд функсияи набударо ваъда диҳад.
var appKnowledge = []appFAQ{
	{[]string{"пост", "публикац", "post", "расм гузор", "фото"},
		"Пост: тугмаи «+» дар болои лента → расм ё видеоро интихоб кунед → матн, музика, ҷой, қайди одамон, ҳаммуаллиф ва Alt text илова кунед → «Нашр». Вақтбандӣ ҳам ҳаст."},
	{[]string{"reel", "рилс", "видео"},
		"Reels: «+» → «Reel» → видеоро интихоб кунед, музика ва матн гузоред. Дар Reels як зарба — садо, пахш карда нигоҳ доштан — таваққуф, ду зарба — лайк."},
	{[]string{"стори", "story", "сторис", "истори"},
		"Стори: «+» → «Стори». Стикерҳо: пурсиш, савол, викторина, слайдери эмодзи, ҳисоби баръакс, музика, матн, расмкашӣ. «Дӯстони наздик» — сторӣ танҳо ба онҳо. Сторӣ 24 соат мемонад; «Актуальный» онро дар профил нигоҳ медорад. Пост ё Reel-ро ба сторӣ: менюи ⋯ → «Ба стори гузоштан»."},
	{[]string{"чат", "паём", "сообщен", "message", "direct", "дм"},
		"Чат: паём, расм, видео, овоз, реаксия (дар паём пахш карда нигоҳ доред), ҷавоб (паёмро ба канор кашед), таҳрир (15 дақиқаи аввал), «Фиристодан» ба чати дигар, паёми «як бор дида мешавад», занги овозӣ ва видеоӣ. Дар рӯйхати чатҳо пахш карда нигоҳ доред → пин кардан (то 3) ё хомӯш кардан."},
	{[]string{"лайк", "лайкҳо", "пинҳон", "hide like", "скрыть"},
		"Лайкҳоро пинҳон кардан: дар пости худ ⋯ → «Лайкҳоро пинҳон кун». Шумора танҳо ба шумо дида мешавад. Барои Reels ҳамин тавр."},
	{[]string{"шарҳ", "коммент", "comment", "хомӯш"},
		"Шарҳҳоро хомӯш кардан: дар пости худ ⋯ → «Шарҳҳоро хомӯш кун». Тугмаи шарҳ нопадид мешавад. Шарҳи нохушро соҳиби пост нест карда метавонад; калимаҳои пинҳон — Танзимот → Махфият → Калимаҳои пинҳон."},
	{[]string{"пӯшида", "private", "закрыт", "приват"},
		"Ҳисоби пӯшида: Профил → Таҳрир → «Ҳисоби пӯшида». Он гоҳ постҳо, Reels, сторис, «Актуальный» ва рӯйхати обунаҳо танҳо ба обунаҳои тасдиқшуда дида мешаванд; дар explore ва ҷустуҷӯ намеоянд."},
	{[]string{"бастан", "блок", "block", "заблок"},
		"Бастан: профили корбар → ⋯ → «Бастан». Ӯ шуморо намеёбад, паём фиристода наметавонад ва мундариҷаи шуморо намебинад. Инчунин: хомӯш кардан (mute) ва маҳдуд кардан (restrict)."},
	{[]string{"дӯстдошта", "favorite", "избран", "обунаҳо", "following"},
		"Лента: логои «Raonson»-ро дар боло занед → «Барои шумо», «Обунаҳо» ё «Дӯстдоштаҳо». Ба дӯстдоштаҳо: профили корбар → ⋯ → «Ба дӯстдоштаҳо» (то 50)."},
	{[]string{"галочка", "тасдиқ", "verif", "галка"},
		"Галочка: Танзимот → «Галочка». Бо тамошои реклама ҷамъ мешавад; пешрафт дар ҳамон экран."},
	{[]string{"парол", "пароль", "password"},
		"Паролро иваз кардан: Танзимот → Амният → «Иваз кардани парол». Фаромӯш кардед — дар экрани вуруд «Рамзро фаромӯш кардед?». Ҳифзи дуқабата ҳам дар Амният аст."},
	{[]string{"забон", "язык", "language"},
		"Забон: Танзимот → «Забон» — тоҷикӣ, русӣ, англисӣ."},
	{[]string{"мағоза", "шоп", "shop", "магазин", "фурӯш", "продаж"},
		"Мағоза: логои Tajikshop дар болои лента. Фурӯш: пост бо «Маҳсулот» — нарх, промокод, фармоишҳо ва омори фурӯшанда."},
	{[]string{"live", "эфир", "лайв"},
		"Live: «+» → «Live». Тамошобинон шарҳ ва лайк мефиристанд; танҳо шумо эфирро хотима медиҳед."},
	{[]string{"ҷонишин", "pronoun", "местоим"},
		"Ҷонишинҳо: Профил → Таҳрир → «Ҷонишинҳо» (то 4, бо «/»). Дар паҳлӯи ном дида мешаванд."},
	{[]string{"вуруд", "login", "войти", "ворид"},
		"Вуруд: почта, номи корбар (бо ё бе «@») ё рақами телефон ва парол."},
	{[]string{"ҳисобро нест", "удалить аккаунт", "delete account"},
		"Нест кардани ҳисоб: Танзимот → Ҳисоб → «Нест кардани ҳисоб». Ин амал бозгашт надорад."},
}

func matchApp(q string) (string, bool) {
	q = strings.ToLower(q)
	best, bestN := "", 0
	for _, f := range appKnowledge {
		n := 0
		for _, k := range f.keys {
			if strings.Contains(q, k) {
				n++
			}
		}
		if n > bestN {
			best, bestN = f.answer, n
		}
	}
	return best, bestN > 0
}

func appKnowledgeText() string {
	var b strings.Builder
	for _, f := range appKnowledge {
		b.WriteString("• ")
		b.WriteString(f.answer)
		b.WriteString("\n")
	}
	return b.String()
}

// ── Ҷавоб ─────────────────────────────────────────────────────────

func AiAssistant(c *gin.Context) {
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
	q := ""
	for i := len(b.Messages) - 1; i >= 0; i-- {
		if b.Messages[i].Role != "assistant" {
			q = clampRunes(strings.TrimSpace(b.Messages[i].Content), 500)
			break
		}
	}
	if q == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "савол холӣ аст"})
		return
	}
	ctx, cancel := context.WithTimeout(c.Request.Context(), 25*time.Second)
	defer cancel()

	// 1. Маълумоти зинда.
	sources := []assistantSource{}
	var facts strings.Builder
	news := isNewsQuestion(q)
	if news {
		items := latestNews(8)
		for _, n := range items {
			fmt.Fprintf(&facts, "- %s (%s, %s)\n", n.Title, n.Source, n.PubDate)
			sources = append(sources, assistantSource{Title: n.Source + ": " + n.Title, URL: n.Link})
		}
	}
	appAns, isApp := matchApp(q)
	var wikiTitle, wikiText, wikiURL string
	if !news && !isApp && !isCreatorQuestion(q) {
		wikiTitle, wikiText, wikiURL = wikiLookup(ctx, q)
		if wikiText != "" {
			fmt.Fprintf(&facts, "Википедия — %s: %s\n", wikiTitle, wikiText)
			sources = append(sources, assistantSource{Title: "Википедия: " + wikiTitle, URL: wikiURL})
		}
	}

	// 2. Модел (агар калид бошад).
	if utils.OpenAIEnabled() {
		sys := assistantSystemPrompt + `

ДОНИШИ БАРНОМА (танҳо ин функсияҳо ҳастанд — чизи дигарро ваъда надеҳ):
` + appKnowledgeText() + `
ҚОИДАҲО:
- Ба забони саволи корбар ҷавоб деҳ (тоҷикӣ, русӣ ё англисӣ).
- Хабар ва далелҳоро ТАНҲО аз «МАЪЛУМОТИ ЗИНДА» гир; агар он ҷо набошад, рост бигӯ, ки намедонӣ. Ҳеҷ гоҳ хабар ихтироъ накун.
- Санаи имрӯз: ` + time.Now().Format("2006-01-02") + `.`
		hist := make([]utils.ChatTurn, 0, len(b.Messages))
		for _, m := range b.Messages {
			hist = append(hist, utils.ChatTurn{Role: m.Role, Content: clampRunes(m.Content, 2000)})
		}
		if facts.Len() > 0 {
			hist[len(hist)-1].Content += "\n\nМАЪЛУМОТИ ЗИНДА (аз интернет, ҳозир):\n" + facts.String()
		}
		if reply, err := utils.AskAssistant(ctx, sys, hist); err == nil && strings.TrimSpace(reply) != "" {
			c.JSON(http.StatusOK, gin.H{"reply": reply, "sources": sources, "mode": "ai"})
			return
		}
	}

	// 3. Бе модел — ҷавоб аз маълумоти воқеӣ.
	c.JSON(http.StatusOK, gin.H{
		"reply":   fallbackReply(q, news, sources, appAns, isApp, wikiText),
		"sources": sources, "mode": "offline",
	})
}

func fallbackReply(q string, news bool, sources []assistantSource,
	appAns string, isApp bool, wikiText string) string {
	if isCreatorQuestion(q) {
		return "Ин барномаро Ehson Mahmadmurodov сохтааст."
	}
	if news {
		if len(sources) == 0 {
			return "Ҳозир хабарҳоро гирифта натавонистам — манбаъҳо ҷавоб намедиҳанд. Каме баъд боз пурсед."
		}
		var b strings.Builder
		b.WriteString("📰 Хабарҳои охирин:\n\n")
		for i, s := range sources {
			fmt.Fprintf(&b, "%d. %s\n", i+1, s.Title)
		}
		return b.String()
	}
	if isApp {
		return appAns
	}
	if wikiText != "" {
		return wikiText
	}
	return "Ба ин савол ҳоло ҷавоби дақиқ надорам. Дар бораи барнома (пост, Reels, сторис, чат, махфият, мағоза) ё хабарҳои охирин пурсед."
}

// isCreatorQuestion — «кӣ сохт?» ба ҳар шакл ва ҳар забон.
func isCreatorQuestion(q string) bool {
	lq := strings.ToLower(q)
	has := func(ws ...string) bool {
		for _, w := range ws {
			if strings.Contains(lq, w) {
				return true
			}
		}
		return false
	}
	return (has("кӣ ", "ки ") && has("сохт", "эҷод", "офарид")) ||
		has("соҳиби барнома", "муаллифи барнома") ||
		(has("кто") && has("созда", "сделал", "разработ", "автор")) ||
		(has("who") && has("made", "created", "built", "developed", "owner"))
}
