package ai

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

// Ҳар тест env-и худро таъин мекунад; t.Setenv худаш баъд тоза мекунад.
func clearEnv(t *testing.T) {
	t.Helper()
	for _, k := range []string{
		"AI_API_KEY", "AI_API_URL", "AI_MODEL",
		"AI_CHAT_API_KEY", "AI_CHAT_MODEL", "AI_CHAT_API_URL",
		"AI_CODE_MODEL", "AI_ANALYSIS_MODEL", "AI_ANALYSIS_API_KEY",
		"AI_FAST_MODEL", "AI_VISION_MODEL",
		"TUTOR_API_KEY", "TUTOR_API_URL", "TUTOR_MODEL",
		"OPENAI_API_KEY",
	} {
		t.Setenv(k, "")
	}
}

func TestDisabledWithoutAnyKey(t *testing.T) {
	clearEnv(t)
	if AnyEnabled() {
		t.Fatal("бе ягон калид AI бояд хомӯш бошад")
	}
	for _, task := range []Task{TaskChat, TaskCode, TaskAnalysis, TaskFast, TaskVision} {
		if Enabled(task) {
			t.Errorf("%s бе калид фаъол намояд", task)
		}
	}
	// Даъват бояд хатои возеҳ диҳад, на panic.
	_, err := Complete(context.Background(), TaskChat,
		[]Message{{Role: "user", Content: "x"}}, Options{})
	if err != ErrNotConfigured {
		t.Fatalf("интизори ErrNotConfigured, гирифтем %v", err)
	}
}

func TestGeneralKeyEnablesEveryTask(t *testing.T) {
	clearEnv(t)
	t.Setenv("AI_API_KEY", "k")
	for _, task := range []Task{TaskChat, TaskCode, TaskAnalysis, TaskFast, TaskVision} {
		if !Enabled(task) {
			t.Errorf("%s бояд бо калиди умумӣ фаъол шавад", task)
		}
	}
}

func TestPerTaskModelOverride(t *testing.T) {
	clearEnv(t)
	t.Setenv("AI_API_KEY", "k")
	t.Setenv("AI_MODEL", "general")
	t.Setenv("AI_CODE_MODEL", "coder")
	t.Setenv("AI_VISION_MODEL", "eyes")

	if got := ConfigFor(TaskCode).Model; got != "coder" {
		t.Errorf("модели code: %q", got)
	}
	if got := ConfigFor(TaskVision).Model; got != "eyes" {
		t.Errorf("модели vision: %q", got)
	}
	// Вазифаи бе override модели умумиро мегирад.
	if got := ConfigFor(TaskChat).Model; got != "general" {
		t.Errorf("модели chat: %q", got)
	}
}

func TestPerTaskKeyAndURLOverride(t *testing.T) {
	clearEnv(t)
	t.Setenv("AI_API_KEY", "general")
	t.Setenv("AI_ANALYSIS_API_KEY", "analysis-only")
	t.Setenv("AI_ANALYSIS_API_URL", "https://example.invalid/v1/chat/completions")

	if got := ConfigFor(TaskAnalysis).APIKey; got != "analysis-only" {
		t.Errorf("калиди analysis: %q", got)
	}
	if got := ConfigFor(TaskChat).APIKey; got != "general" {
		t.Errorf("chat бояд калиди умумиро гирад: %q", got)
	}
	// URL-и махсус танҳо ба ҳамон вазифа.
	if ConfigFor(TaskChat).APIURL == ConfigFor(TaskAnalysis).APIURL {
		t.Error("URL-и analysis бояд аз chat фарқ кунад")
	}
}

// Танзимоти кӯҳна бояд бешикаст кор кунад — вагарна deploy-и ҷорӣ
// ҳангоми навсозӣ AI-ро гум мекард.
func TestLegacyEnvStillWorks(t *testing.T) {
	clearEnv(t)
	t.Setenv("TUTOR_API_KEY", "tutor")
	t.Setenv("TUTOR_MODEL", "tutor-model")
	if !Enabled(TaskChat) {
		t.Fatal("TUTOR_API_KEY бояд AI-ро фаъол кунад")
	}
	if got := ConfigFor(TaskChat).Model; got != "tutor-model" {
		t.Errorf("модел: %q", got)
	}

	clearEnv(t)
	t.Setenv("OPENAI_API_KEY", "openai")
	if !Enabled(TaskFast) {
		t.Fatal("OPENAI_API_KEY бояд AI-ро фаъол кунад")
	}
}

func TestSpecificKeyBeatsGeneral(t *testing.T) {
	clearEnv(t)
	t.Setenv("OPENAI_API_KEY", "legacy")
	t.Setenv("AI_API_KEY", "modern")
	// Калиди нав бартарӣ дорад, вале кӯҳна ҳамчун fallback мемонад.
	if got := ConfigFor(TaskChat).APIKey; got != "modern" {
		t.Errorf("интизори калиди нав, гирифтем %q", got)
	}
}

// ── Даъвати воқеӣ ба сервери сохта ───────────────────────────────

func TestCompleteAgainstFakeServer(t *testing.T) {
	var gotAuth, gotModel string
	srv := httptest.NewServer(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			gotAuth = r.Header.Get("Authorization")
			var body map[string]any
			json.NewDecoder(r.Body).Decode(&body)
			gotModel, _ = body["model"].(string)
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(`{"choices":[{"message":{"content":"  салом  "}}]}`))
		}))
	defer srv.Close()

	clearEnv(t)
	t.Setenv("AI_API_KEY", "secret-key")
	t.Setenv("AI_API_URL", srv.URL)
	t.Setenv("AI_MODEL", "my-model")

	out, err := Complete(context.Background(), TaskChat,
		[]Message{{Role: "user", Content: "салом"}}, Options{})
	if err != nil {
		t.Fatalf("хато: %v", err)
	}
	if out != "салом" {
		t.Errorf("ҷавоб бояд буриш шавад: %q", out)
	}
	if gotAuth != "Bearer secret-key" {
		t.Errorf("Authorization: %q", gotAuth)
	}
	if gotModel != "my-model" {
		t.Errorf("модел: %q", gotModel)
	}
}

func TestProviderErrorDoesNotLeakBody(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte(`{"error":"invalid api key sk-SECRET123"}`))
		}))
	defer srv.Close()

	clearEnv(t)
	t.Setenv("AI_API_KEY", "k")
	t.Setenv("AI_API_URL", srv.URL)

	_, err := Complete(context.Background(), TaskChat,
		[]Message{{Role: "user", Content: "x"}}, Options{})
	if err == nil {
		t.Fatal("интизори хато")
	}
	// Матни provider метавонад калид дошта бошад — набояд паҳн шавад.
	if contains(err.Error(), "SECRET123") || contains(err.Error(), "invalid api key") {
		t.Fatalf("хато маълумоти provider-ро фош кард: %v", err)
	}
}

func TestCompleteJSONHandlesWrappedOutput(t *testing.T) {
	// Моделҳо аксаран JSON-ро дар ```json мепечонанд ё матн илова
	// мекунанд — таҷзия набояд аз ин шиканад.
	for _, raw := range []string{
		`{"a":1}`,
		"```json\n{\"a\":1}\n```",
		"Инак ҷавоб:\n```\n{\"a\":1}\n```\nтамом",
		"Ҷавоб: {\"a\":1}",
	} {
		srv := httptest.NewServer(http.HandlerFunc(
			func(w http.ResponseWriter, r *http.Request) {
				resp, _ := json.Marshal(map[string]any{
					"choices": []map[string]any{
						{"message": map[string]string{"content": raw}},
					},
				})
				w.Write(resp)
			}))
		clearEnv(t)
		t.Setenv("AI_API_KEY", "k")
		t.Setenv("AI_API_URL", srv.URL)

		var out struct {
			A int `json:"a"`
		}
		err := CompleteJSON(context.Background(), TaskChat,
			[]Message{{Role: "user", Content: "x"}}, Options{}, &out)
		srv.Close()
		if err != nil || out.A != 1 {
			t.Errorf("вуруди %q: a=%d err=%v", raw, out.A, err)
		}
	}
}

func TestEmptyChoicesIsAnError(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(
		func(w http.ResponseWriter, r *http.Request) {
			w.Write([]byte(`{"choices":[]}`))
		}))
	defer srv.Close()
	clearEnv(t)
	t.Setenv("AI_API_KEY", "k")
	t.Setenv("AI_API_URL", srv.URL)

	if _, err := Complete(context.Background(), TaskChat,
		[]Message{{Role: "user", Content: "x"}}, Options{}); err == nil {
		t.Fatal("ҷавоби холӣ бояд хато диҳад")
	}
}

func contains(s, sub string) bool {
	return len(sub) > 0 && len(s) >= len(sub) &&
		func() bool {
			for i := 0; i+len(sub) <= len(s); i++ {
				if s[i:i+len(sub)] == sub {
					return true
				}
			}
			return false
		}()
}
