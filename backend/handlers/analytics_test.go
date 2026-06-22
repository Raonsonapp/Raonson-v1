package handlers

import (
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestItoa(t *testing.T) {
	cases := map[int]string{0: "0", 5: "5", 42: "42", 100: "100"}
	for in, want := range cases {
		if got := strconv.Itoa(in); got != want {
			t.Fatalf("strconv.Itoa(%d) = %q, want %q", in, got, want)
		}
	}
}

func TestPgxBatchSQL(t *testing.T) {
	mk := func(rows int) string {
		b := &pgxBatch{}
		for i := 0; i < rows; i++ {
			b.add("u", "e", "{}")
		}
		return b.sql()
	}
	want1 := "VALUES ($1,$2,$3::jsonb)"
	want2 := "VALUES ($1,$2,$3::jsonb),($4,$5,$6::jsonb)"
	want3 := "VALUES ($1,$2,$3::jsonb),($4,$5,$6::jsonb),($7,$8,$9::jsonb)"
	if got := mk(1); got != want1 {
		t.Fatalf("1 row: got %q want %q", got, want1)
	}
	if got := mk(2); got != want2 {
		t.Fatalf("2 rows: got %q want %q", got, want2)
	}
	if got := mk(3); got != want3 {
		t.Fatalf("3 rows: got %q want %q", got, want3)
	}
}

func TestTrackAnalyticsEvents_EmptyBody(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodPost, "/analytics/events", strings.NewReader(""))
	c.Request.Header.Set("Content-Type", "application/json")

	TrackAnalyticsEvents(c)

	if w.Code != http.StatusBadRequest {
		t.Fatalf("empty body status = %d, want 400", w.Code)
	}
}

func TestTrackAnalyticsEvents_EmptyEvents(t *testing.T) {
	gin.SetMode(gin.TestMode)
	w := httptest.NewRecorder()
	c, _ := gin.CreateTestContext(w)
	c.Request = httptest.NewRequest(http.MethodPost, "/analytics/events", strings.NewReader(`{"events":[]}`))
	c.Request.Header.Set("Content-Type", "application/json")

	TrackAnalyticsEvents(c)

	if w.Code != http.StatusOK {
		t.Fatalf("empty events status = %d, want 200", w.Code)
	}
	if !strings.Contains(w.Body.String(), `"saved":0`) {
		t.Fatalf("empty events body = %q, want saved:0", w.Body.String())
	}
}
