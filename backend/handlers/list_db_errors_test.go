package handlers

// Рӯйхатҳо ҳангоми хатои база 500 медиҳанд, на 200 бо рӯйхати холӣ.
//
// Барнома ҷавоби 200-ро «ҳақиқат» мешуморад: рӯйхати холии сторисҳо
// ба кэши офлайн навишта мешуд ва ҳалқаи сторисҳо то навсозии дигар
// нопадид мешуд; ҷустуҷӯ «касе ёфт нашуд» мегуфт. Бо 500 барнома
// кэши кӯҳнаро нигоҳ медорад ва хатои шабакаро нишон медиҳад.
//
// База лозим нест: пул ба порти баста ишора мекунад, пас ҳар дархост
// хато медиҳад.

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"raonson/db"
)

func brokenDB(t *testing.T) {
	t.Helper()
	pool, err := pgxpool.New(context.Background(),
		"postgres://x:x@127.0.0.1:1/x?sslmode=disable&connect_timeout=1")
	if err != nil {
		t.Fatal(err)
	}
	prev := db.Pool
	db.Pool = pool
	t.Cleanup(func() { db.Pool = prev; pool.Close() })
}

func TestListEndpointsReport500OnDBError(t *testing.T) {
	brokenDB(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("userID", "viewer-1"); c.Next() })
	r.GET("/stories/", GetStories)
	r.GET("/stories/my", GetMyStories)
	r.GET("/search/users", SearchUsers)

	for _, path := range []string{"/stories/", "/stories/my", "/search/users?q=ali"} {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest(http.MethodGet, path, nil))
		if w.Code != http.StatusInternalServerError {
			t.Errorf("%s: хатои база → %d (%s), бояд 500 бошад",
				path, w.Code, w.Body.String())
		}
	}
}
