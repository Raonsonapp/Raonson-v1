package handlers

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

// Музика дар як ҷо буд, дар ҷои дигар не.
//
// Корбар ҳангоми нашр суруд мегузошт. Дар ЛЕНТА он намоён мешуд,
// вале ҳамин ки пост кушода мешуд — нопадид. Сабаб: `GetPost`
// сутунҳои музикаро умуман намепурсид.
//
// Ин намуди камбудӣ ҳар бор бармегардад, вақте касе дархости нави
// постро менависад ва майдонҳоро нусхабардорӣ намекунад. Пас ин ҷо
// ҳар ФАЙЛЕ санҷида мешавад, ки ҷавоби пост месозад.

// Файле, ки `"likesCount"` бармегардонад, пости пурраро ба телефон
// медиҳад — пас он бояд музикаро низ диҳад.
var postResponseMarker = regexp.MustCompile(`"likesCount"\s*:`)

func TestEveryPostResponseCarriesMusic(t *testing.T) {
	files, err := os.ReadDir(".")
	if err != nil {
		t.Fatalf("феҳрист хонда нашуд: %v", err)
	}

	checked := 0
	for _, f := range files {
		name := f.Name()
		if !strings.HasSuffix(name, ".go") || strings.HasSuffix(name, "_test.go") {
			continue
		}
		b, err := os.ReadFile(name)
		if err != nil {
			continue
		}
		src := string(b)
		if !postResponseMarker.MatchString(src) {
			continue
		}
		// Reels ва стори ҷавоби худро доранд — ин ҷо танҳо пост.
		if !strings.Contains(src, "FROM posts p") {
			continue
		}
		checked++

		if !strings.Contains(src, "music_title") {
			t.Errorf("%s ҷавоби пост месозад, вале сутунҳои музикаро "+
				"намепурсад — суруд дар ин экран нопадид мешавад", name)
			continue
		}
		// Ном бе суроға кофӣ нест: он навишта мешавад, вале
		// намехонад — маҳз ҳамин дар пост буд.
		if !strings.Contains(src, "music_url") {
			t.Errorf("%s суроғаи сурудро намепурсад — ном навишта "+
				"мешавад, вале музика намехонад", name)
		}
		// Ҷои оғоз: бе он суруд аз САРИ худ мехонад, новобаста аз
		// он ки муаллиф чиро интихоб кард.
		if !strings.Contains(src, "music_start_ms") {
			t.Errorf("%s ҷои оғози порчаро намепурсад — суруд аз сари "+
				"худ мехонад", name)
		}
		if !strings.Contains(src, "songJSON(") {
			t.Errorf("%s объекти `song`-ро барнамегардонад", name)
		}
	}

	if checked == 0 {
		t.Fatal("ягон ҷавоби пост ёфт нашуд — тест кӯҳна шудааст")
	}
	t.Logf("санҷида шуд: %d файл", checked)
}
