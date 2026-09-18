package main

// Роҳҳои боркунӣ набояд ба ҳади умумии API баста бошанд.
//
// Чаро ин тест ҳаст: боркунӣ ба `rl20` (20 дархост дар як дақиқа)
// баста буд. Як пости 10-акса 10 боркунӣ мефиристад ва ApiClient
// ҳангоми нокомӣ худаш такрор мекунад — пас корбари ОДДӢ 429
// мегирифт ва нашр намешуд. Дар log-и сервер чунин менамуд:
//
//	[429] POST /upload 288.198µs
//
// 288 микросония — дархост ҳатто ба коди R2 нарасида буд.
//
// Ин хатогӣ дар ягон тести воҳидӣ дида намешуд, чунки он на дар
// handler, балки дар САТРИ ПАЙВАСТИ router буд. Барои ҳамин ин
// тест худи сарчашмаро мехонад.

import (
	"os"
	"regexp"
	"strings"
	"testing"
)

func TestUploadRoutesDoNotShareTheGlobalLimiter(t *testing.T) {
	src, err := os.ReadFile("main_optimized.go")
	if err != nil {
		t.Fatalf("main_optimized.go хонда нашуд: %v", err)
	}

	// Ҳар сатре, ки роҳи боркуниро сабт мекунад.
	line := regexp.MustCompile(`(?m)^.*r\.POST\("(/upload[^"]*|/media/upload)".*$`)
	found := line.FindAllString(string(src), -1)
	if len(found) == 0 {
		t.Fatal("ягон роҳи боркунӣ ёфт нашуд — тест кӯҳна шудааст")
	}

	for _, l := range found {
		if strings.Contains(l, "rl20") {
			t.Errorf("роҳи боркунӣ ба ҳади умумии rl20 (20/дақиқа) "+
				"баста аст; он барои пости бисёракса кам аст:\n  %s",
				strings.TrimSpace(l))
		}
		if !strings.Contains(l, "upl") {
			t.Errorf("роҳи боркунӣ ҳади худро (`upl`) надорад:\n  %s",
				strings.TrimSpace(l))
		}
	}
}
