package handlers

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

// Муаллим бояд бо AI_API_KEY кор кунад (на танҳо бо TUTOR_API_KEY-и кӯҳна).
func TestTutorUsesAIAPIKey(t *testing.T) {
	var gotAuth, gotModel string
	llm := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotAuth = r.Header.Get("Authorization")
		var in map[string]any
		_ = json.NewDecoder(r.Body).Decode(&in)
		gotModel, _ = in["model"].(string)
		_, _ = w.Write([]byte(`{"choices":[{"message":{"content":"Салом! Биёед Python омӯзем."}}]}`))
	}))
	defer llm.Close()

	t.Setenv("TUTOR_API_KEY", "")
	t.Setenv("AI_CHAT_API_KEY", "")
	t.Setenv("AI_API_KEY", "test-key")
	t.Setenv("AI_API_URL", llm.URL)
	t.Setenv("AI_MODEL", "test-model")

	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/tutor/chat", TutorChat)
	body, _ := json.Marshal(map[string]any{"track": "python", "lang": "tg",
		"messages": []map[string]string{{"role": "user", "content": "Салом"}}})
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodPost, "/tutor/chat", bytes.NewReader(body)))

	if w.Code != 200 {
		t.Fatalf("HTTP %d: %s", w.Code, w.Body.String())
	}
	if gotAuth != "Bearer test-key" || gotModel != "test-model" {
		t.Fatalf("LLM called with auth=%q model=%q", gotAuth, gotModel)
	}
	if !strings.Contains(w.Body.String(), "Python") || strings.Contains(w.Body.String(), "танзим нашудааст") {
		t.Fatalf("unexpected reply: %s", w.Body.String())
	}
}

func TestTutorNotConfiguredWithoutKey(t *testing.T) {
	for _, k := range []string{"AI_CHAT_API_KEY", "AI_API_KEY", "TUTOR_API_KEY", "OPENAI_API_KEY"} {
		t.Setenv(k, "")
	}
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/tutor/chat", TutorChat)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(http.MethodPost, "/tutor/chat",
		strings.NewReader(`{"messages":[{"role":"user","content":"hi"}]}`)))
	if !strings.Contains(w.Body.String(), `"configured":false`) {
		t.Fatalf("expected configured:false, got %s", w.Body.String())
	}
}
