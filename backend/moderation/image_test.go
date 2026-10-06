package moderation

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// pngWith — PNG-и ҳақиқӣ (сарлавҳа) бо нишонаи санҷишӣ дар охир.
func pngWith(marker string) []byte {
	sig := []byte("\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00")
	return append(sig, []byte(marker)...)
}

func clearProviders(t *testing.T) {
	t.Helper()
	for _, k := range []string{"MODERATION_IMAGE_PROVIDER", "MODERATION_IMAGE_URL", "HF_TOKEN",
		"SIGHTENGINE_USER", "SIGHTENGINE_SECRET", "MODERATION_SIGHTENGINE_URL",
		"OPENAI_API_KEY", "MODERATION_OPENAI_URL", "SAFE_BROWSING_KEY"} {
		t.Setenv(k, "")
	}
}

// fakeHF — classifier: нишонаи «NSFW» → 0.97, «MAYBE» → 0.6, дигар → 0.02.
func fakeHF(t *testing.T, gotAuth *string) *httptest.Server {
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if gotAuth != nil {
			*gotAuth = r.Header.Get("Authorization")
		}
		b, _ := io.ReadAll(r.Body)
		s := 0.02
		switch {
		case bytes.Contains(b, []byte("NSFW")):
			s = 0.97
		case bytes.Contains(b, []byte("MAYBE")):
			s = 0.6
		case bytes.Contains(b, []byte("BROKEN")):
			w.WriteHeader(http.StatusServiceUnavailable)
			w.Write([]byte(`{"error":"model loading"}`))
			return
		}
		json.NewEncoder(w).Encode([]map[string]any{
			{"label": "nsfw", "score": s}, {"label": "normal", "score": 1 - s}})
	}))
}

func TestNoProviderIsUnscanned(t *testing.T) {
	clearProviders(t)
	v := CheckImageBytes(context.Background(), pngWith("x"))
	if v.Action != Review || !v.Unscanned {
		t.Fatalf("бе provider: REVIEW+Unscanned: %+v", v)
	}
	if v := CheckImageURL(context.Background(), "https://cdn.example/x.png"); !v.Unscanned {
		t.Fatalf("URL бе provider: %+v", v)
	}
	if v := CheckVideoURL(context.Background(), "https://cdn.example/x.mp4"); !v.Unscanned {
		t.Fatalf("видео бе provider: %+v", v)
	}
	if ImageProviderConfigured() {
		t.Fatal("provider набояд бошад")
	}
}

func TestHuggingFaceAdapter(t *testing.T) {
	clearProviders(t)
	var auth string
	srv := fakeHF(t, &auth)
	defer srv.Close()
	t.Setenv("MODERATION_IMAGE_URL", srv.URL)
	t.Setenv("HF_TOKEN", "hf-test")

	ctx := context.Background()
	if v := CheckImageBytes(ctx, pngWith("NSFW")); v.Action != Block || !v.Strikeable() || v.Provider != "huggingface" {
		t.Fatalf("nsfw → BLOCK: %+v", v)
	}
	if auth != "Bearer hf-test" {
		t.Fatalf("token фиристода нашуд: %q", auth)
	}
	if v := CheckImageBytes(ctx, pngWith("MAYBE")); v.Action != Review || v.Unscanned {
		t.Fatalf("норавшан → REVIEW (пинҳон): %+v", v)
	}
	if v := CheckImageBytes(ctx, pngWith("ok")); v.Action != Allow {
		t.Fatalf("тоза → ALLOW: %+v", v)
	}
	// Хатои provider — пинҳон то санҷиш, на иҷозат.
	if v := CheckImageBytes(ctx, pngWith("BROKEN")); v.Action != Review || v.Unscanned {
		t.Fatalf("хатои provider → REVIEW: %+v", v)
	}
	// На расм — ба provider фиристода намешавад.
	if v := CheckImageBytes(ctx, []byte("<html>")); v.Action != Review {
		t.Fatalf("на расм: %+v", v)
	}
}

func TestParseHFNestedAndLabels(t *testing.T) {
	s, _, err := parseHF([]byte(`[[{"label":"porn","score":0.9},{"label":"neutral","score":0.1}]]`))
	if err != nil || s != 0.9 {
		t.Fatalf("nested: %v %v", s, err)
	}
	s, _, _ = parseHF([]byte(`[{"label":"sexy","score":1.0}]`))
	if s != 0.6 {
		t.Fatalf("sexy ×0.6: %v", s)
	}
	if _, _, err := parseHF([]byte(`{"error":"x"}`)); err == nil {
		t.Fatal("ҷавоби нофаҳмо бояд хато бошад")
	}
}

func TestSightengineAdapter(t *testing.T) {
	clearProviders(t)
	var fields map[string]string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseMultipartForm(1 << 20); err != nil {
			t.Errorf("multipart: %v", err)
		}
		fields = map[string]string{
			"models": r.FormValue("models"), "api_user": r.FormValue("api_user"),
			"api_secret": r.FormValue("api_secret"),
		}
		f, _, err := r.FormFile("media")
		if err != nil {
			t.Errorf("media: %v", err)
			return
		}
		b, _ := io.ReadAll(f)
		if bytes.Contains(b, []byte("NSFW")) {
			w.Write([]byte(`{"status":"success","nudity":{"sexual_activity":0.92,"sexual_display":0.1,"erotica":0.2,"very_suggestive":0.3,"none":0.01}}`))
			return
		}
		w.Write([]byte(`{"status":"success","nudity":{"sexual_activity":0.01,"sexual_display":0.01,"erotica":0.02,"very_suggestive":0.05,"none":0.95}}`))
	}))
	defer srv.Close()
	t.Setenv("SIGHTENGINE_USER", "u1")
	t.Setenv("SIGHTENGINE_SECRET", "s1")
	t.Setenv("MODERATION_SIGHTENGINE_URL", srv.URL)

	if v := CheckImageBytes(context.Background(), pngWith("NSFW")); v.Action != Block || v.Provider != "sightengine" {
		t.Fatalf("sightengine nsfw: %+v", v)
	}
	if fields["models"] != "nudity-2.1" || fields["api_user"] != "u1" || fields["api_secret"] != "s1" {
		t.Fatalf("майдонҳо: %v", fields)
	}
	if v := CheckImageBytes(context.Background(), pngWith("ok")); v.Action != Allow {
		t.Fatalf("sightengine тоза: %+v", v)
	}
	if _, _, err := parseSightengine([]byte(`{"status":"failure","error":{"message":"bad"}}`)); err == nil {
		t.Fatal("status failure бояд хато бошад")
	}
}

func TestOpenAIImageAdapter(t *testing.T) {
	clearProviders(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Model string `json:"model"`
			Input []struct {
				ImageURL struct {
					URL string `json:"url"`
				} `json:"image_url"`
			} `json:"input"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		if body.Model != "omni-moderation-latest" || len(body.Input) != 1 ||
			!strings.HasPrefix(body.Input[0].ImageURL.URL, "data:image/png;base64,") {
			t.Errorf("дархости OpenAI: %+v", body)
		}
		w.Write([]byte(`{"results":[{"categories":{"sexual":true,"sexual/minors":true},"category_scores":{"sexual":0.9,"sexual/minors":0.7}}]}`))
	}))
	defer srv.Close()
	t.Setenv("OPENAI_API_KEY", "sk-test")
	t.Setenv("MODERATION_OPENAI_URL", srv.URL)
	t.Setenv("MODERATION_IMAGE_PROVIDER", "openai")
	v := CheckImageBytes(context.Background(), pngWith("x"))
	if v.Action != Block || !v.Severe || !hasCat(v.Categories, CatMinors) {
		t.Fatalf("openai minors → severe BLOCK: %+v", v)
	}
}

func TestImageURLOnlyFromOurStorage(t *testing.T) {
	clearProviders(t)
	hf := fakeHF(t, nil)
	defer hf.Close()
	t.Setenv("MODERATION_IMAGE_URL", hf.URL)

	hits := 0
	media := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		hits++
		switch r.URL.Path {
		case "/bad.png":
			w.Write(pngWith("NSFW"))
		case "/redirect.png":
			http.Redirect(w, r, "http://169.254.169.254/latest/meta-data", http.StatusFound)
		default:
			w.Write(pngWith("ok"))
		}
	}))
	defer media.Close()

	SetMediaFetchAllowed(func(u string) bool { return strings.HasPrefix(u, media.URL+"/") })
	defer SetMediaFetchAllowed(func(string) bool { return false })

	ctx := context.Background()
	if v := CheckImageURL(ctx, media.URL+"/bad.png"); v.Action != Block {
		t.Fatalf("расми бад аз анбор: %+v", v)
	}
	if v := CheckImageURL(ctx, media.URL+"/good.png"); v.Action != Allow {
		t.Fatalf("расми тоза: %+v", v)
	}
	before := hits
	v := CheckImageURL(ctx, "http://169.254.169.254/latest/meta-data")
	if v.Action != Review || v.Reason != "foreign_host" || hits != before {
		t.Fatalf("суроғаи бегона кушода нашавад: %+v", v)
	}
	// Redirect пайгирӣ намешавад.
	if v := CheckImageURL(ctx, media.URL+"/redirect.png"); v.Action != Review || v.Reason != "fetch_failed" {
		t.Fatalf("redirect: %+v", v)
	}
}

func TestFrameTimes(t *testing.T) {
	got := FrameTimes(20)
	want := []float64{1, 5, 10, 15}
	if len(got) != len(want) {
		t.Fatalf("%v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("%v != %v", got, want)
		}
	}
	// Видеои кӯтоҳ: такрор нест ва аз давомнокӣ берун намеравад.
	for _, d := range []float64{0.5, 2, 4} {
		for _, ts := range FrameTimes(d) {
			if ts >= d {
				t.Fatalf("d=%v: %v", d, FrameTimes(d))
			}
		}
	}
	if len(FrameTimes(0)) == 0 {
		t.Fatal("давомнокии номаълум")
	}
}

// Видеои ҳақиқӣ бо ffmpeg: кадрҳо гирифта ва ба provider фиристода мешаванд.
func TestVideoFramesWithFFmpeg(t *testing.T) {
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		t.Skip("ffmpeg нест")
	}
	clearProviders(t)
	frames := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		b, _ := io.ReadAll(r.Body)
		if !bytes.HasPrefix(b, []byte{0xFF, 0xD8}) {
			t.Errorf("кадр JPEG нест")
		}
		frames++
		s := 0.02
		if os.Getenv("FAKE_VIDEO_NSFW") == "1" {
			s = 0.99
		}
		json.NewEncoder(w).Encode([]map[string]any{{"label": "nsfw", "score": s}})
	}))
	defer srv.Close()
	t.Setenv("MODERATION_IMAGE_URL", srv.URL)

	dir := t.TempDir()
	path := filepath.Join(dir, "v.mp4")
	cmd := exec.Command("ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi",
		"-i", "testsrc=duration=8:size=160x120:rate=10", "-pix_fmt", "yuv420p", path)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Skipf("ffmpeg видео насохт: %v %s", err, out)
	}
	data, _ := os.ReadFile(path)

	v := CheckVideoBytes(context.Background(), data)
	if v.Action != Allow || frames != 4 {
		t.Fatalf("видеои тоза: %+v, кадрҳо=%d", v, frames)
	}
	t.Setenv("FAKE_VIDEO_NSFW", "1")
	frames = 0
	v = CheckVideoBytes(context.Background(), data)
	if v.Action != Block || frames != 1 {
		t.Fatalf("видеои бад: BLOCK баъди кадри аввал: %+v, кадрҳо=%d", v, frames)
	}
}
