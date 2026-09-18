package handlers

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// Паёми чат ба телефон огоҳинома намефиристод.
//
// `SendMessageExt` танҳо `emitChat` даъват мекард — он ба WebSocket
// мефиристад, яъне танҳо ба барномаи КУШОДА. Агар корбар барномаро
// баста бошад — маҳз он вақте ки огоҳинома лозим аст — ҳеҷ чиз
// намеомад.
//
// Қабати огоҳинома навъи «message»-ро аллакай дастгирӣ мекард; танҳо
// ҳеҷ кас онро даъват намекард. Чунин камбудӣ дар ягон тести воҳидӣ
// дида намешавад, чунки он НАБУДАНИ код аст, на коди нодуруст.

func funcBody(t *testing.T, path, name string) string {
	t.Helper()
	src, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("%s хонда нашуд: %v", path, err)
	}
	s := string(src)
	i := strings.Index(s, "func "+name+"(")
	if i < 0 {
		t.Fatalf("%s дар %s ёфт нашуд — тест кӯҳна шудааст", name, path)
	}
	// То аввалин `\n}` — охири функсия дар сабки ин анбор.
	j := strings.Index(s[i:], "\n}\n")
	if j < 0 {
		t.Fatalf("охири %s ёфт нашуд", name)
	}
	return s[i : i+j]
}

func TestChatMessageSendsPush(t *testing.T) {
	body := funcBody(t, "chat_extended.go", "SendMessageExt")

	if !strings.Contains(body, "pushNotify(") {
		t.Error("SendMessageExt ҳеҷ огоҳинома намефиристад — " +
			"корбари барномаашро баста ҳеҷ чиз намебинад")
	}
	// Огоҳинома бояд ба ГИРАНДА равад, на ба фиристанда.
	if !regexp.MustCompile(`pushNotify\(\s*receiver\s*,`).MatchString(body) {
		t.Error("огоҳинома ба `receiver` фиристода намешавад")
	}
	if !strings.Contains(body, "ntf.Message") {
		t.Error("навъи огоҳинома бояд `ntf.Message` бошад — " +
			"вагарна танзимот ва соатҳои ором дуруст татбиқ намешаванд")
	}
}

// Ҳазфи мундариҷа бояд кэши ҲАМА тамошобинро бипартояд, на танҳо
// кэши соҳибро. Бе ин пости ҳазфшуда то 5 дақиқа дар explore мемонд.
func TestDeleteHandlersBumpContentEpoch(t *testing.T) {
	cases := []struct{ file, fn string }{
		{"post.go", "DeletePost"},
		{"other.go", "DeleteReel"},
		{"story_chat_notif_admin.go", "DeleteStory"},
	}
	for _, c := range cases {
		if !strings.Contains(funcBody(t, c.file, c.fn), "BumpContentEpoch") {
			t.Errorf("%s кэши тамошобинонро намепартояд — "+
				"мундариҷаи ҳазфшуда дар экрани дигарон мемонад", c.fn)
		}
	}
}
