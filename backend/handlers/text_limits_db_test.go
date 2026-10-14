package handlers

// Ҳадди дарозии матн дар ду роҳе, ки пеш онро надоштанд:
//
//   • PUT /users/ (bio). Модератсия танҳо 150 ҳарфи аввалро медид, вале
//     bio ПУРРА сабт мешуд — дашном баъди ҳарфи 150 аз санҷиш мегузашт.
//     Аватар низ бо ҳар нақша (javascript:) қабул мешуд.
//   • POST /chat/:chatId/messages. Матни паём ҳадде надошт.
//
// Бе RAONSON_TEST_DB тест гузаронда мешавад.

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/gin-gonic/gin"

	mw "raonson/middleware"
)

func sendJSON(t *testing.T, r *gin.Engine, method, path, tok string, body any) *httptest.ResponseRecorder {
	t.Helper()
	b, _ := json.Marshal(body)
	req := httptest.NewRequest(method, path, bytes.NewReader(b))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+tok)
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func TestUpdateUserClampsBioAndRejectsBadAvatar(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("JWT_SECRET", "test-secret-text-limits")
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.PUT("/users/", mw.Auth(), UpdateUser)
	me := adsUser(t, pool)
	tok := tokenFor(t, me)

	w := sendJSON(t, r, http.MethodPut, "/users/", tok,
		map[string]any{"bio": strings.Repeat("ҳ", 5000)})
	if w.Code != http.StatusOK {
		t.Fatalf("PUT /users/ → %d: %s", w.Code, w.Body.String())
	}
	var bio string
	pool.QueryRow(context.Background(), `SELECT bio FROM users WHERE id=$1`, me).Scan(&bio)
	if n := utf8.RuneCountInString(bio); n != 150 {
		t.Fatalf("bio бояд то 150 ҳарф бурида шавад, сабт шуд: %d", n)
	}

	w = sendJSON(t, r, http.MethodPut, "/users/", tok,
		map[string]any{"avatar": "javascript:alert(1)"})
	if w.Code != http.StatusBadRequest {
		t.Fatalf("аватари javascript: бояд 400 гирад, гирифт %d", w.Code)
	}
}

func TestSendMessageTextIsClamped(t *testing.T) {
	pool := adsTestDB(t)
	t.Setenv("JWT_SECRET", "test-secret-text-limits")
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.POST("/chat/:chatId/messages", mw.Auth(), SendMessageExt)
	a, b := adsUser(t, pool), adsUser(t, pool)
	chatID := sortedChatID(a, b)
	t.Cleanup(func() {
		pool.Exec(context.Background(), `DELETE FROM messages WHERE chat_id=$1`, chatID)
	})

	w := sendJSON(t, r, http.MethodPost, "/chat/"+chatID+"/messages", tokenFor(t, a),
		map[string]any{"text": strings.Repeat("я", maxDMRunes+2000)})
	if w.Code >= 400 {
		t.Fatalf("фиристодан → %d: %s", w.Code, w.Body.String())
	}
	var text string
	if err := pool.QueryRow(context.Background(),
		`SELECT text FROM messages WHERE chat_id=$1 ORDER BY created_at DESC LIMIT 1`,
		chatID).Scan(&text); err != nil {
		t.Fatal(err)
	}
	if n := utf8.RuneCountInString(text); n != maxDMRunes {
		t.Fatalf("паём бояд то %d ҳарф бурида шавад, сабт шуд: %d", maxDMRunes, n)
	}
}
