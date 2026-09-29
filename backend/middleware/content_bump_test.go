package middleware

import "testing"

func TestSkipBumpRe(t *testing.T) {
	skip := []string{"/reels/:id/view", "/reels/:id/watch", "/ads/watched", "/auth/login", "/stories/:id/view", "/chat/:chatId/read"}
	bump := []string{"/posts/:id/like", "/reels/:id/hide-likes", "/posts/:id/comments", "/follow/:id", "/posts/", "/profile/", "/users/:id/block", "/posts/:id/save"}
	for _, p := range skip {
		if !skipBumpRe.MatchString(p) {
			t.Errorf("%s must NOT bump the cache", p)
		}
	}
	for _, p := range bump {
		if skipBumpRe.MatchString(p) {
			t.Errorf("%s must bump the cache", p)
		}
	}
}
