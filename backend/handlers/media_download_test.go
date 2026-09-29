package handlers

import (
	"strings"
	"testing"
)

// Сервер танҳо аз анбори худамон медиа мегирад — на аз суроғаи дилхоҳ.
func TestMediaHostAllowed(t *testing.T) {
	t.Setenv("CF_R2_PUBLIC_URL", "https://pub-abc.r2.dev")
	t.Setenv("MEDIA_ALLOWED_HOSTS", "")
	t.Setenv("MEDIA_ALLOW_HTTP", "")
	cases := map[string]bool{
		"https://pub-abc.r2.dev/v/1.mp4":            true,
		"https://evil.example.com/1.mp4":            false,
		"http://pub-abc.r2.dev/v/1.mp4":             false,
		"http://169.254.169.254/latest/meta-data":   false,
		"file:///etc/passwd":                        false,
		"https://pub-abc.r2.dev.evil.com/1.mp4":     false,
	}
	for u, want := range cases {
		if got := mediaHostAllowed(u); got != want {
			t.Errorf("%s: got %v want %v", u, got, want)
		}
	}
	// http танҳо бо иҷозати ошкоро ва на дар release.
	t.Setenv("MEDIA_ALLOWED_HOSTS", "127.0.0.1:8123")
	t.Setenv("MEDIA_ALLOW_HTTP", "1")
	t.Setenv("GIN_MODE", "release")
	if mediaHostAllowed("http://127.0.0.1:8123/v.mp4") {
		t.Error("http must be refused in release")
	}
}

func TestWatermarkFilterHasOwnerAndLogo(t *testing.T) {
	f := watermarkFilter("ali.rahim", "/f.ttf", 720, 1280)
	for _, want := range []string{"text='@ali.rahim'", "text='Raonson'", "overlay=", "[out]"} {
		if !strings.Contains(f, want) {
			t.Errorf("filter missing %q: %s", want, f)
		}
	}
}
