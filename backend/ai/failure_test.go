package ai

// Матритсаи нокомии AI.
//
// Савол: агар провайдер вайрон шавад, оё барнома кор мекунад?
//
// Ҳар ҳолат бо сервери сохта санҷида мешавад — бе шабакаи воқеӣ ва
// бе калиди воқеӣ. Талабот дар ҳама ҳолат якхела аст:
//   • crash нашавад
//   • сир ошкор нашавад
//   • «муваффақияти бардурӯғ» надиҳад

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// withProvider серверро ба ҷои провайдер мегузорад.
func withProvider(t *testing.T, h http.HandlerFunc) {
	t.Helper()
	srv := httptest.NewServer(h)
	t.Cleanup(srv.Close)
	t.Setenv("AI_API_KEY", "test-key-not-real")
	t.Setenv("AI_API_URL", srv.URL)
	t.Setenv("AI_MODEL", "test-model")
}

func ask(t *testing.T) (string, error) {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()
	return Complete(ctx, TaskChat,
		[]Message{{Role: "user", Content: "салом"}}, Options{})
}

// Бе калид: хатои возеҳ, на «ҷавоби холии муваффақ».
func TestNoKeyIsAnHonestError(t *testing.T) {
	t.Setenv("AI_API_KEY", "")
	t.Setenv("AI_CHAT_API_KEY", "")
	t.Setenv("TUTOR_API_KEY", "")
	t.Setenv("OPENAI_API_KEY", "")
	out, err := ask(t)
	if err == nil {
		t.Fatal("бе калид хато набояд холӣ бошад")
	}
	if out != "" {
		t.Errorf("бе калид ҷавоб дод: %q", out)
	}
	if !Enabled(TaskChat) {
		return // дуруст
	}
	t.Error("бе калид Enabled бояд false бошад")
}

// Провайдер хато медиҳад — матни он ба корбар НАМЕРАСАД.
func TestProviderErrorLeaksNothing(t *testing.T) {
	const secret = "sk-REAL-KEY-LEAKED-IN-ERROR"
	withProvider(t, func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusUnauthorized)
		w.Write([]byte(`{"error":{"message":"Invalid key ` + secret + `"}}`))
	})
	out, err := ask(t)
	if err == nil {
		t.Fatal("хатои провайдер пинҳон монд")
	}
	if strings.Contains(err.Error(), secret) {
		t.Errorf("хато сирро ошкор кард: %v", err)
	}
	if out != "" {
		t.Errorf("ҳангоми хато ҷавоб дод: %q", out)
	}
}

// Ҷавоби вайрон — хато, на матни бемаънӣ.
func TestMalformedResponse(t *testing.T) {
	cases := map[string]string{
		"JSON нест":      `не JSON аст`,
		"холӣ":           ``,
		"choices нест":   `{"id":"x"}`,
		"choices холӣ":   `{"choices":[]}`,
		"навъи нодуруст": `{"choices":"матн"}`,
	}
	for name, body := range cases {
		t.Run(name, func(t *testing.T) {
			withProvider(t, func(w http.ResponseWriter, r *http.Request) {
				w.Write([]byte(body))
			})
			out, err := ask(t)
			if err == nil && out == "" {
				t.Error("ҳам хато нест, ҳам ҷавоб холист")
			}
			if err == nil && out != "" {
				t.Errorf("ҷавоби вайрон қабул шуд: %q", out)
			}
		})
	}
}

// Ҷавоби бепоён набояд хотираро тамом кунад.
func TestHugeResponseIsBounded(t *testing.T) {
	withProvider(t, func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"choices":[{"message":{"content":"`))
		chunk := strings.Repeat("A", 64*1024)
		// Аз ҳадди 4 МБ хеле зиёдтар.
		for i := 0; i < 200; i++ {
			if _, err := w.Write([]byte(chunk)); err != nil {
				return
			}
		}
		w.Write([]byte(`"}}]}`))
	})
	// Талабот: баргардад ва хотираро нахӯрад. Натиҷа хато аст,
	// чунки JSON бо буриш нопурра мемонад.
	done := make(chan struct{})
	go func() {
		ask(t)
		close(done)
	}()
	select {
	case <-done:
	case <-time.After(25 * time.Second):
		t.Fatal("ҷавоби бепоён барномаро нигоҳ дошт")
	}
}

// Провайдери суст набояд дархостро абадӣ нигоҳ дорад.
func TestSlowProviderTimesOut(t *testing.T) {
	t.Setenv("AI_TIMEOUT_SECONDS", "2")
	withProvider(t, func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
		case <-time.After(5 * time.Second):
		}
	})
	// httpClient дар вақти боркунии пакет сохта мешавад, бинобар ин
	// context худаш ҳадди вақтро таъмин мекунад.
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()

	start := time.Now()
	_, err := Complete(ctx, TaskChat,
		[]Message{{Role: "user", Content: "x"}}, Options{})
	elapsed := time.Since(start)

	if err == nil {
		t.Error("провайдери суст хато надод")
	}
	if elapsed > 10*time.Second {
		t.Errorf("дархост %v нигоҳ дошта шуд — хеле дароз", elapsed)
	}
}

// Провайдер маҳдудият гузошт (429) — хатои возеҳ, бе такрори беохир.
func TestRateLimitedProvider(t *testing.T) {
	calls := 0
	withProvider(t, func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.WriteHeader(http.StatusTooManyRequests)
		w.Write([]byte(`{"error":"rate limited"}`))
	})
	if _, err := ask(t); err == nil {
		t.Error("429 хато надод")
	}
	// Такрори беохир вуҷуд надорад: як дархост — як даъват.
	if calls > 3 {
		t.Errorf("%d даъват — такрори аз ҳад зиёд", calls)
	}
}

// Провайдер тамоман дастнорас — хато, на осебдиданӣ.
func TestUnreachableProvider(t *testing.T) {
	t.Setenv("AI_API_KEY", "test-key")
	// Порти пӯшида.
	t.Setenv("AI_API_URL", "http://127.0.0.1:1/v1/chat/completions")
	if _, err := ask(t); err == nil {
		t.Error("провайдери дастнорас хато надод")
	}
}

// Вуруди ғайримунтазир барномаро намепартояд.
func TestOddInputs(t *testing.T) {
	withProvider(t, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"choices":[{"message":{"content":"ok"}}]}`))
	})
	ctx := context.Background()
	cases := [][]Message{
		nil,
		{},
		{{Role: "user", Content: ""}},
		{{Role: "user", Content: strings.Repeat("матни дароз ", 50000)}},
		{{Role: "", Content: "бе нақш"}},
	}
	for i, msgs := range cases {
		if _, err := Complete(ctx, TaskChat, msgs, Options{}); err != nil {
			t.Logf("ҳолати %d хато дод (қобили қабул): %v", i, err)
		}
	}
}

// JSON-и печонидашуда дар ```json тоза мешавад.
func TestJSONFencesAreStripped(t *testing.T) {
	withProvider(t, func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("{\"choices\":[{\"message\":{\"content\":" +
			"\"```json\\n{\\\"a\\\":1}\\n```\"}}]}"))
	})
	var out struct {
		A int `json:"a"`
	}
	ctx := context.Background()
	if err := CompleteJSON(ctx, TaskChat,
		[]Message{{Role: "user", Content: "x"}}, Options{}, &out); err != nil {
		t.Fatalf("JSON таҷзия нашуд: %v", err)
	}
	if out.A != 1 {
		t.Errorf("натиҷа: %+v", out)
	}
}
