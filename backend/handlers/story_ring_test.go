package handlers

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestPutStoryRingStates(t *testing.T) {
	cases := []struct {
		has, unseen          bool
		wantUnseen, wantSeen bool
	}{
		{false, false, false, false},
		{false, true, false, false}, // сторис нест → на ранга, на хокистарӣ
		{true, true, true, false},
		{true, false, false, true},
	}
	for _, c := range cases {
		u := putStoryRing(gin.H{}, c.has, c.unseen)
		if u["hasStory"] != c.has || u["hasUnseenStory"] != c.wantUnseen || u["storySeen"] != c.wantSeen {
			t.Fatalf("has=%v unseen=%v → %v", c.has, c.unseen, u)
		}
	}
}

// Ҳалқа ҳамон филтрро дорад, ки GET /stories (обуна, «наздикон», блок,
// хомӯш, архив, мӯҳлат) ва «дида шуд»-ро аз story_seen мегирад.
func TestStoryRingColsUsesSameRulesAsStories(t *testing.T) {
	sql := storyRingCols("u.id", "$1")
	for _, want := range []string{
		"s.user_id=u.id", "expires_at > NOW()", "archived", "follows",
		"close_friends", "blocks", "muted_users", "story_seen",
		"AS has_story", "AS has_unseen_story", "$1::text",
	} {
		if !strings.Contains(sql, want) {
			t.Errorf("storyRingCols: %q нест", want)
		}
	}
}

// Ҳеҷ handler набояд боз ҳалқаро бо EXISTS-и худ (бе «дида шуд») ҳисоб кунад.
func TestNoHandWrittenHasStory(t *testing.T) {
	files, _ := filepath.Glob("*.go")
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") || f == "story_ring.go" {
			continue
		}
		b, err := os.ReadFile(f)
		if err != nil {
			t.Fatal(err)
		}
		src := string(b)
		if strings.Contains(src, "FROM stories s WHERE s.user_id=") {
			t.Errorf("%s: hasStory бе storyRingCols ҳисоб мешавад", f)
		}
		if strings.Contains(src, `"hasStory": hasStory`) {
			t.Errorf("%s: hasStory бе putStoryRing (storySeen/hasUnseenStory нест)", f)
		}
	}
}
