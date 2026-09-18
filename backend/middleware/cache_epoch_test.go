package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

// Пост ҳазф мешуд, вале дар экрани дигарон то 5 дақиқа мемонд.
//
// Сабаб: `InvalidateUserCache` танҳо калидҳои ХУДИ соҳибро пок
// мекард, вале `/explore` барои ҳар тамошобин калиди ҷудогона дорад
// ва 5 дақиқа кэш мешуд. Соҳиб ҳазф мекард — тамошобин ҳанӯз медид.
//
// `BumpContentEpoch` калидҳои кӯҳнаро дастнорас мекунад.

func cachedRouter(t *testing.T, body *string) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/explore", func(c *gin.Context) {
		c.Set("userID", c.Query("as"))
		c.Next()
	}, CacheMiddleware(5*time.Minute), func(c *gin.Context) {
		c.Data(http.StatusOK, "application/json", []byte(*body))
	})
	return r
}

func get(t *testing.T, r *gin.Engine, as string) (string, string) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/explore?as="+as, nil)
	r.ServeHTTP(w, req)
	return w.Body.String(), w.Header().Get("X-Cache")
}

func TestBumpContentEpochDropsEveryViewersCache(t *testing.T) {
	body := `["post-1"]`
	r := cachedRouter(t, &body)

	// Ду тамошобини гуногун — ҳарду пости соҳибро мебинанд.
	if got, _ := get(t, r, "viewer-a"); got != `["post-1"]` {
		t.Fatalf("виюери A: %s", got)
	}
	if got, _ := get(t, r, "viewer-b"); got != `["post-1"]` {
		t.Fatalf("виюери B: %s", got)
	}
	// Ҳарду акнун кэш шудаанд.
	if _, hit := get(t, r, "viewer-a"); hit != "HIT" {
		t.Fatal("виюери A бояд кэш мешуд")
	}

	// Соҳиб постро ҳазф мекунад.
	body = `[]`
	InvalidateUserCache("owner")

	// Бе бумп тамошобинон ҳанӯз пости ҳазфшударо мебинанд —
	// маҳз ҳамин камбудӣ буд.
	if got, _ := get(t, r, "viewer-a"); got != `["post-1"]` {
		t.Fatalf("тест худаш кӯҳна шуд: %s", got)
	}

	BumpContentEpoch()

	for _, v := range []string{"viewer-a", "viewer-b"} {
		got, hit := get(t, r, v)
		if hit == "HIT" {
			t.Errorf("%s: кэши кӯҳна боз дода шуд", v)
		}
		if got != `[]` {
			t.Errorf("%s: пости ҳазфшуда ҳанӯз ҳаст: %s", v, got)
		}
	}
}

// Бумп набояд ҷавобҳои корбаронро омехта кунад.
func TestCacheStaysPerUserAfterBump(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.GET("/feed", func(c *gin.Context) {
		c.Set("userID", c.Query("as"))
		c.Next()
	}, CacheMiddleware(time.Minute), func(c *gin.Context) {
		c.Data(http.StatusOK, "application/json",
			[]byte(`"`+c.Query("as")+`"`))
	})

	BumpContentEpoch()
	a, _ := get2(t, r, "/feed?as=alice")
	b, _ := get2(t, r, "/feed?as=bob")
	if a != `"alice"` || b != `"bob"` {
		t.Fatalf("ҷавобҳо омехта шуданд: %s %s", a, b)
	}
	// Такрор — ҳар кас ҷавоби ХУДашро мегирад, на ҷавоби дигареро.
	if a2, _ := get2(t, r, "/feed?as=alice"); a2 != `"alice"` {
		t.Errorf("alice ҷавоби бегона гирифт: %s", a2)
	}
}

func get2(t *testing.T, r *gin.Engine, path string) (string, string) {
	t.Helper()
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("GET", path, nil))
	return w.Body.String(), w.Header().Get("X-Cache")
}
