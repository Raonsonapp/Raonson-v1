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
		// Дар назди тугмаи «паҳн кардан» ҳеҷ рақам набуд.
		"reel_shares",
	} {
		if !strings.Contains(body, field) {
			t.Errorf("reels %s-ро намегиранд", field)
		}
	}
}

// Паҳнкунӣ бояд ҲИСОБ шавад, вагарна рақам ҳамеша сифр мемонад.
func TestShareIsCounted(t *testing.T) {
	src, err := os.ReadFile("other.go")
	if err != nil {
		t.Fatalf("other.go хонда нашуд: %v", err)
	}
	s := string(src)
	if !strings.Contains(s, "func ShareReel(") {
		t.Fatal("reel роҳи паҳнкунӣ надорад — рақам ҳамеша сифр мемонад")
	}
	// Як корбар набояд рақамро бо такрор калон кунад.
	i := strings.Index(s, "func ShareReel(")
	body := s[i : i+strings.Index(s[i:], "\n}\n")]
	if !strings.Contains(body, "ON CONFLICT (user_id, reel_id) DO NOTHING") {
		t.Error("паҳнкунии такрории ҲАМОН корбар боз ҳисоб мешавад — " +
			"як нафар рақамро ба ҳар андоза калон карда метавонад")
	}

	// Роҳ бояд дар router низ васл шуда бошад.
	mainSrc, err := os.ReadFile("../main_optimized.go")
	if err != nil {
		t.Fatalf("main хонда нашуд: %v", err)
	}
	if !strings.Contains(string(mainSrc), "handlers.ShareReel") {
		t.Error("ShareReel навишта шуд, вале ба ягон роҳ васл нашуд")
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
