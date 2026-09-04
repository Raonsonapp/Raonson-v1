package handlers

// Тафтиши танзимоти AI.
//
// Ин endpoint барои он аст, ки соҳиби барнома БОВАРӢ ҳосил кунад:
// кадом вазифа кор мекунад, кадом модел истифода мешавад ва оё
// provider воқеан ҷавоб медиҳад.
//
// Ҳеҷ калид дар ҷавоб намеояд — танҳо ҳақиқати «танзим шудааст ё не»
// ва host-и provider.

import (
	"context"
	"net/http"
	"net/url"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/ai"
	"raonson/utils"
)

// taskStatus — ҳолати як вазифа.
type taskStatus struct {
	Task       string `json:"task"`
	Configured bool   `json:"configured"`
	Model      string `json:"model"`
	// Host — танҳо host, бе роҳ ва бе калид.
	Host string `json:"host"`
	// Майдонҳои зерин танҳо ҳангоми probe пур мешаванд.
	Probed  bool   `json:"probed"`
	OK      bool   `json:"ok"`
	Latency string `json:"latencyMs,omitempty"`
	Error   string `json:"error,omitempty"`
	Reply   string `json:"reply,omitempty"`
}

// GET /admin/ai/health?probe=1
//
// Бе probe: танҳо танзимот нишон дода мешавад (арзон, бехатар).
// Бо probe=1: ба ҲАР вазифаи танзимшуда як дархости воқеӣ меравад.
func GetAIHealth(c *gin.Context) {
	probe := c.Query("probe") == "1"
	ctx := c.Request.Context()

	tasks := []ai.Task{
		ai.TaskChat, ai.TaskCode, ai.TaskAnalysis, ai.TaskFast, ai.TaskVision,
	}
	out := make([]taskStatus, 0, len(tasks))

	for _, t := range tasks {
		cfg := ai.ConfigFor(t)
		st := taskStatus{
			Task:       string(t),
			Configured: cfg.APIKey != "",
			Model:      cfg.Model,
			Host:       hostOf(cfg.APIURL),
		}
		if probe && st.Configured {
			st.Probed = true
			start := time.Now()
			pctx, cancel := context.WithTimeout(ctx, 30*time.Second)
			reply, err := ai.Complete(pctx, t, []ai.Message{
				{Role: "user", Content: "Reply with the single word: OK"},
			}, ai.Options{MaxTokens: 8, Temperature: 0})
			cancel()
			st.Latency = time.Since(start).Truncate(time.Millisecond).String()
			if err != nil {
				st.Error = err.Error()
			} else {
				st.OK = true
				st.Reply = clampRunes(reply, 40)
			}
		}
		out = append(out, st)
	}

	c.JSON(http.StatusOK, gin.H{
		"anyConfigured": ai.AnyEnabled(),
		"tasks":         out,
		// Кадом env лозим аст — то соҳиб набояд кодро хонад.
		"envVars": gin.H{
			"general":  []string{"AI_API_KEY", "AI_API_URL", "AI_MODEL"},
			"perTask":  []string{"AI_<TASK>_API_KEY", "AI_<TASK>_API_URL", "AI_<TASK>_MODEL"},
			"tasks":    []string{"CHAT", "CODE", "ANALYSIS", "FAST", "VISION"},
			"legacy":   []string{"TUTOR_API_KEY", "TUTOR_API_URL", "TUTOR_MODEL", "OPENAI_API_KEY"},
			"moderate": "OPENAI_API_KEY — танҳо барои /moderations; бе он модератсия бо модели чат кор мекунад",
		},
	})
}

// GET /admin/ai/selftest
//
// Функсияҳои ВОҚЕИИ барномаро месанҷад, на танҳо пайвастро: хэштег,
// тарҷума ва холи сифат. Ҳамон роҳе, ки корбар истифода мебарад.
func GetAISelfTest(c *gin.Context) {
	ctx, cancel := context.WithTimeout(c.Request.Context(), 90*time.Second)
	defer cancel()

	type result struct {
		Feature string `json:"feature"`
		OK      bool   `json:"ok"`
		Output  string `json:"output,omitempty"`
		Error   string `json:"error,omitempty"`
		Skipped bool   `json:"skipped,omitempty"`
	}
	results := []result{}

	if !ai.AnyEnabled() {
		c.JSON(http.StatusOK, gin.H{
			"configured": false,
			"message":    "Ҳеҷ provider-и AI танзим нашудааст",
			"results":    results,
		})
		return
	}

	// 1. Хэштег — ҳамон функсияи /ai/hashtags.
	tags, err := utils.GenerateHashtags(ctx,
		"Имрӯз дар кӯҳҳои Помир сафар кардем", "")
	r := result{Feature: "hashtags"}
	if err != nil {
		r.Error = err.Error()
	} else {
		r.OK = len(tags) > 0
		r.Output = joinLimited(tags, 6)
		if !r.OK {
			r.Error = "рӯйхати холӣ"
		}
	}
	results = append(results, r)

	// 2. Тарҷума — ҳамон функсияи /ai/translate.
	tr2, err := utils.TranslateText(ctx, "Hello, how are you?", "Tajik")
	r = result{Feature: "translate"}
	if err != nil {
		r.Error = err.Error()
	} else {
		r.OK = tr2 != ""
		r.Output = clampRunes(tr2, 80)
	}
	results = append(results, r)

	// 3. Холи сифат — ҳамон чизе, ки ҳангоми сохтани пост иҷро мешавад.
	score, err := utils.ScorePostQuality(ctx,
		"Дастури пурраи коднависӣ барои навомӯзон бо мисолҳои амалӣ")
	r = result{Feature: "qualityScore"}
	if err != nil {
		r.Error = err.Error()
	} else {
		r.OK = score >= 0 && score <= 100
		r.Output = itoa(score)
	}
	results = append(results, r)

	// 4. Модератсия — бояд матни бехатарро ИҶОЗАТ диҳад.
	flagged, _ := utils.ModerateText(ctx, "Салом, чӣ хел?")
	results = append(results, result{
		Feature: "moderation.safeText",
		OK:      !flagged,
		Output:  boolStr(flagged),
	})

	allOK := true
	for _, x := range results {
		if !x.OK && !x.Skipped {
			allOK = false
		}
	}
	c.JSON(http.StatusOK, gin.H{
		"configured": true,
		"allPassed":  allOK,
		"results":    results,
	})
}

func hostOf(raw string) string {
	u, err := url.Parse(raw)
	if err != nil || u.Host == "" {
		return ""
	}
	return u.Host
}

func joinLimited(items []string, max int) string {
	if len(items) > max {
		items = items[:max]
	}
	out := ""
	for i, s := range items {
		if i > 0 {
			out += " "
		}
		out += s
	}
	return out
}

func itoa(v int) string {
	if v == 0 {
		return "0"
	}
	neg := v < 0
	if neg {
		v = -v
	}
	var b []byte
	for v > 0 {
		b = append([]byte{byte('0' + v%10)}, b...)
		v /= 10
	}
	if neg {
		return "-" + string(b)
	}
	return string(b)
}

func boolStr(b bool) string {
	if b {
		return "flagged"
	}
	return "allowed"
}
