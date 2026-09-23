package handlers

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func askAssistant(t *testing.T, q string) map[string]any {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/ai/assistant", AiAssistant)
	body, _ := json.Marshal(map[string]any{"messages": []map[string]string{{"role": "user", "content": q}}})
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodPost, "/ai/assistant", bytes.NewReader(body)))
	if w.Code != 200 {
		t.Fatalf("HTTP %d: %s", w.Code, w.Body.String())
	}
	var out map[string]any
	_ = json.Unmarshal(w.Body.Bytes(), &out)
	return out
}

func withNews(t *testing.T) {
	newsMu.Lock()
	newsCache = []newsItem{
		{Title: "Дар Душанбе пули нав кушода шуд", Source: "Asia-Plus", Link: "https://asiaplustj.info/x", ts: time.Now()},
		{Title: "Обу ҳаво: гарм", Source: "Ховар", Link: "https://khovar.tj/y", ts: time.Now().Add(-time.Hour)},
	}
	newsCacheTime = time.Now()
	newsMu.Unlock()
	t.Cleanup(func() { newsMu.Lock(); newsCache = nil; newsMu.Unlock() })
}

// Бе калиди LLM ёрдамчӣ ХОЛӢ НАМЕМОНАД.
func TestAssistantOfflineNews(t *testing.T) {
	t.Setenv("AI_API_KEY", ""); t.Setenv("TUTOR_API_KEY", ""); t.Setenv("OPENAI_API_KEY", "")
	withNews(t)
	out := askAssistant(t, "Имрӯз чӣ хабар?")
	reply, _ := out["reply"].(string)
	if !strings.Contains(reply, "пули нав") || out["mode"] != "offline" {
		t.Fatalf("хабар нарасид: %v", out)
	}
	if src, _ := out["sources"].([]any); len(src) != 2 {
		t.Fatalf("манбаъҳо бояд 2 бошанд: %v", out["sources"])
	}
}

func TestAssistantOfflineAppHelp(t *testing.T) {
	t.Setenv("AI_API_KEY", ""); t.Setenv("TUTOR_API_KEY", ""); t.Setenv("OPENAI_API_KEY", "")
	out := askAssistant(t, "Чӣ тавр лайкҳоро пинҳон кунам?")
	if r, _ := out["reply"].(string); !strings.Contains(r, "Лайкҳоро пинҳон кун") {
		t.Fatalf("ҷавоби барнома нодуруст: %v", out)
	}
	out = askAssistant(t, "Кӣ ин барномаро сохт?")
	if r, _ := out["reply"].(string); !strings.Contains(r, "Ehson Mahmadmurodov") {
		t.Fatalf("қоидаи соҳиб вайрон: %v", out)
	}
}

func TestAssistantWikipedia(t *testing.T) {
	t.Setenv("AI_API_KEY", ""); t.Setenv("TUTOR_API_KEY", ""); t.Setenv("OPENAI_API_KEY", "")
	wiki := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if strings.Contains(r.URL.Path, "/search/page") {
			io.WriteString(w, `{"pages":[{"key":"Помир","title":"Помир"}]}`)
			return
		}
		io.WriteString(w, `{"title":"Помир","extract":"Помир — системаи кӯҳӣ дар Осиёи Марказӣ."}`)
	}))
	defer wiki.Close()
	old := wikiBase
	wikiBase = map[string]string{"tg": wiki.URL, "ru": wiki.URL, "en": wiki.URL}
	defer func() { wikiBase = old }()
	out := askAssistant(t, "Помир дар куҷост?")
	if r, _ := out["reply"].(string); !strings.Contains(r, "системаи кӯҳӣ") {
		t.Fatalf("Википедия истифода нашуд: %v", out)
	}
}

// Бо калид: маълумоти ЗИНДА ба модел мерасад ва ҷавоби модел бармегардад.
func TestAssistantLLMGetsLiveFacts(t *testing.T) {
	withNews(t)
	var seen string
	llm := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		seen = string(b)
		io.WriteString(w, `{"choices":[{"message":{"role":"assistant","content":"Имрӯз дар Душанбе пули нав кушода шуд (Asia-Plus)."}}]}`)
	}))
	defer llm.Close()
	t.Setenv("AI_API_KEY", "test-key")
	t.Setenv("AI_API_URL", llm.URL)
	t.Setenv("AI_FAST_API_URL", llm.URL)
	out := askAssistant(t, "What's the news today?")
	if out["mode"] != "ai" {
		t.Fatalf("модел истифода нашуд: %v", out)
	}
	if !strings.Contains(seen, "пули нав") || !strings.Contains(seen, "МАЪЛУМОТИ ЗИНДА") {
		t.Fatalf("хабарҳои зинда ба модел нарасиданд: %s", seen[:min(300, len(seen))])
	}
	if !strings.Contains(seen, "Ehson Mahmadmurodov") {
		t.Fatal("қоидаи соҳиб дар prompt нест")
	}
}

// Модел хато диҳад — ёрдамчӣ ба ҷавоби бе модел мегузарад, холӣ намемонад.
func TestAssistantLLMFailureFallsBack(t *testing.T) {
	withNews(t)
	llm := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(500)
	}))
	defer llm.Close()
	t.Setenv("AI_API_KEY", "test-key")
	t.Setenv("AI_API_URL", llm.URL)
	t.Setenv("AI_FAST_API_URL", llm.URL)
	out := askAssistant(t, "хабарҳо")
	if r, _ := out["reply"].(string); !strings.Contains(r, "пули нав") {
		t.Fatalf("бе модел ҷавоб нашуд: %v", out)
	}
}
