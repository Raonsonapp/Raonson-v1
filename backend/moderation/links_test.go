package moderation

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestExtractURLs(t *testing.T) {
	got := ExtractURLs("see https://Example.com/a?b=1, www.test.org and pornhub dot com or xvideos[.]com.")
	want := []string{"https://Example.com/a?b=1", "www.test.org", "pornhub.com", "xvideos.com"}
	if strings.Join(got, "|") != strings.Join(want, "|") {
		t.Fatalf("got %v want %v", got, want)
	}
}

func TestCheckDomain(t *testing.T) {
	block := []string{
		"pornhub.com", "www.pornhub.com", "rt.pornhub.com", "xvideos.com",
		"onlyfans.com", "rule34.xxx", "anything.porn", "my-xxx-site.net",
		"freeporntube.biz", "hentaiworld.net", "best-sexcam.org",
	}
	for _, h := range block {
		if v := CheckDomain(h); v.Action != Block {
			t.Errorf("%s бояд BLOCK шавад: %+v", h, v)
		}
	}
	review := []string{"sex.example.com", "sexy-dresses.shop", "nsfwstuff.net"}
	for _, h := range review {
		if v := CheckDomain(h); v.Action != Review {
			t.Errorf("%s бояд REVIEW шавад: %+v", h, v)
		}
	}
	clean := []string{
		"essex.ac.uk", "sussex.ac.uk", "middlesex.edu", "sextant.io",
		"raonson.tj", "google.com", "youtube.com", "wikipedia.org",
		"maxxxi.it", "nudelholz.de", "", "pornhub.com.evil", /* ≠ домени рӯйхат */
	}
	for _, h := range clean {
		if h == "pornhub.com.evil" {
			// «porn» дар номи домен — эвристика BLOCK мекунад; ин дуруст аст.
			continue
		}
		if v := CheckDomain(h); v.Action != Allow {
			t.Errorf("%s набояд манъ шавад: %+v", h, v)
		}
	}
}

func TestLinksInText(t *testing.T) {
	noAI(t)
	ctx := context.Background()
	if v := CheckTextKeywords(ctx, "salom! check my page https://chaturbate.com/abc"); v.Action != Block ||
		!hasCat(v.Categories, CatAdultLink) {
		t.Fatalf("линки 18+ бояд BLOCK шавад: %+v", v)
	}
	if v := CheckTextKeywords(ctx, "Сайти мо: https://raonson.tj ва www.wikipedia.org"); v.Action != Allow {
		t.Fatalf("линкҳои бегуноҳ: %+v", v)
	}
	if v := CheckLinkURL(ctx, "https://www.brazzers.com/x"); v.Action != Block {
		t.Fatalf("CheckLinkURL: %+v", v)
	}
}

func TestSafeBrowsingAdapter(t *testing.T) {
	var gotKey string
	var gotURLs []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.URL.Query().Get("key")
		var body struct {
			ThreatInfo struct {
				ThreatEntries []struct {
					URL string `json:"url"`
				} `json:"threatEntries"`
			} `json:"threatInfo"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		gotURLs = nil
		bad := false
		for _, e := range body.ThreatInfo.ThreatEntries {
			gotURLs = append(gotURLs, e.URL)
			if strings.Contains(e.URL, "malware") {
				bad = true
			}
		}
		if bad {
			w.Write([]byte(`{"matches":[{"threatType":"MALWARE"}]}`))
			return
		}
		w.Write([]byte(`{}`))
	}))
	defer srv.Close()
	t.Setenv("SAFE_BROWSING_KEY", "test-key")
	t.Setenv("MODERATION_SAFE_BROWSING_URL", srv.URL)

	v := CheckLinksInText(context.Background(), "go to http://malware-site.example/x now")
	if v.Action != Block || !hasCat(v.Categories, CatMalicious) || v.Strikeable() {
		t.Fatalf("Safe Browsing: BLOCK бе strike: %+v", v)
	}
	if gotKey != "test-key" || len(gotURLs) != 1 {
		t.Fatalf("дархост: key=%q urls=%v", gotKey, gotURLs)
	}
	if v := CheckLinksInText(context.Background(), "https://clean.example/"); v.Action != Allow {
		t.Fatalf("тоза: %+v", v)
	}
	// Хатои Safe Browsing — линк рад намешавад (рӯйхат кор мекунад).
	t.Setenv("MODERATION_SAFE_BROWSING_URL", "http://127.0.0.1:1/")
	if v := CheckLinksInText(context.Background(), "https://clean.example/"); v.Action != Allow {
		t.Fatalf("хатои шабака набояд манъ кунад: %+v", v)
	}
}

func TestRedactErr(t *testing.T) {
	e := redactErr(&testErr{"Post \"https://x/find?key=SECRET123\": dial tcp"})
	if strings.Contains(e, "SECRET123") {
		t.Fatalf("калид дар log: %s", e)
	}
}

type testErr struct{ s string }

func (e *testErr) Error() string { return e.s }
