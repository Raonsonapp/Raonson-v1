package handlers

import (
	"os"
	"strings"
	"testing"
)

// Explore дар телефон комилан сиёҳ буд ва reel ҳеҷ гоҳ намебозид.
//
// Ду сабаб, ҳарду дар ҳамин дархост:
//
//  1. Reels ҳеҷ JOIN ба `users` надоштанд — на ном, на аватар, на
//     галочка, на матн. Барои ҳамин экрани кушодашуда холӣ буд.
//
//  2. Агар reel тасвири пешнамоиш надошта бошад, дархост суроғаи
//     ВИДЕО-ро ҳамчун «тасвир» бармегардонд. Телефон онро ҳамчун
//     расм мекушод, MP4 кушода намешуд ва плитка сиёҳ мемонд.
//
// Ин камбудиҳо дар ягон тести воҳидӣ дида намешуданд, чунки онҳо
// дар матни SQL буданд.

func exploreSQL(t *testing.T) string {
	t.Helper()
	src, err := os.ReadFile("story_chat_notif_admin.go")
	if err != nil {
		t.Fatalf("сарчашма хонда нашуд: %v", err)
	}
	s := string(src)
	i := strings.Index(s, "func ExploreGrid(")
	if i < 0 {
		t.Fatal("ExploreGrid ёфт нашуд — тест кӯҳна шудааст")
	}
	j := strings.Index(s[i:], "\n}\n")
	if j < 0 {
		t.Fatal("охири ExploreGrid ёфт нашуд")
	}
	return s[i : i+j]
}

func TestExploreReelsCarryAuthor(t *testing.T) {
	body := exploreSQL(t)

	// Дархости reels бояд ба users пайваст шавад.
	if !strings.Contains(body, "FROM reels r JOIN users u") {
		t.Error("reels ба users пайваст намешаванд — экрани reel " +
			"бе ном, аватар ва галочка мемонад")
	}
	for _, field := range []string{
		"u.username", "u.avatar", "u.verified", "r.caption",
		"r.comments_count",
		// Бе инҳо нишонҳои дил ва захира ҳамеша холӣ менамуданд,
		// ҳатто агар корбар аллакай зада бошад.
		"reel_likes", "reel_saves",
	} {
		if !strings.Contains(body, field) {
			t.Errorf("reels %s-ро намегиранд", field)
		}
	}
}

func TestExploreNeverSendsVideoAsThumbnail(t *testing.T) {
	body := exploreSQL(t)

	// Маҳз ин сабаби плиткаҳои сиёҳ буд.
	if strings.Contains(body, "NULLIF(r.thumbnail_url,''), r.video_url") {
		t.Error("суроғаи видео ҳамчун тасвир бармегардад — " +
			"телефон MP4-ро ҳамчун расм мекушояд ва плитка сиёҳ мемонад")
	}
	if !strings.Contains(body, "COALESCE(r.thumbnail_url,'')") {
		t.Error("тасвири reel хонда намешавад")
	}
}

// `liked`/`saved` ба ҲАР тамошобин вобастаанд. Кэши муштараки
// «explore:grid» онҳоро байни корбарон омехта мекард — корбари A
// лайкҳои корбари B-ро медид.
func TestExploreHasNoSharedCache(t *testing.T) {
	body := exploreSQL(t)

	if strings.Contains(body, `"explore:grid"`) {
		t.Error("кэши муштарак баргашт — бо `liked`/`saved` он " +
			"маълумоти як корбарро ба дигаре нишон медиҳад")
	}
	// Агар шахсӣ бармегардонад, бояд ҳатман аз рӯи тамошобин бошад.
	if strings.Contains(body, "liked") && !strings.Contains(body, "mw.UID(c)") {
		t.Error("`liked` бармегардад, вале тамошобин муайян намешавад")
	}
}
