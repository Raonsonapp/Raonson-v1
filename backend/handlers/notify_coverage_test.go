package handlers

import (
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"

	ntf "raonson/notify"
)

// Ҳодисаҳое, ки сатри огоҳинома месозанд, вале ба ТЕЛЕФОН чизе
// намефиристанд.
//
// `notify(...)` сатрро дар рӯйхат менависад. `pushNotify(...)` ба
// телефон мефиристад. Инҳо ДУ чизи ҷудогонаанд ва фаромӯш кардани
// дуюмӣ осон аст — маҳз ҳамин буд:
//
//   • қабули дархости обуна — на сатр, на push;
//   • қабули ҳамкорӣ — на сатр, на push;
//   • овоз дар пурсиши стори — сатр буд, push не.
//
// Ҳеҷ тести воҳидӣ инро намедид, чунки ин НАБУДАНИ код аст.

var (
	notifyCall = regexp.MustCompile(`(?m)^\s*notify\(\s*[^,]+,\s*[^,]+,\s*"([a-z_]+)"`)
	pushCall   = regexp.MustCompile(`(?m)pushNotify\(\s*[^,]+,\s*[^,]+,\s*(?:"([a-z_]+)"|string\(ntf\.(\w+)\))`)
)

func handlerSources(t *testing.T) map[string]string {
	t.Helper()
	out := map[string]string{}
	files, err := filepath.Glob("*.go")
	if err != nil {
		t.Fatalf("феҳрист хонда нашуд: %v", err)
	}
	for _, f := range files {
		if strings.HasSuffix(f, "_test.go") {
			continue
		}
		b, err := os.ReadFile(f)
		if err != nil {
			continue
		}
		out[f] = string(b)
	}
	return out
}

// kindValueOf номи Go-ро («IncomingCall») ба қимати воқеии намуд
// («incoming_call») табдил медиҳад.
//
// Муқоиса бо ҷадвали ҲАҚИҚИИ намудҳо мешавад, на бо тахмин: агар
// касе номи нав илова кунад, тест худаш онро мефаҳмад.
func kindValueOf(goName string) string {
	norm := func(s string) string {
		return strings.ToLower(strings.ReplaceAll(s, "_", ""))
	}
	target := norm(goName)
	for _, k := range ntf.AllKinds() {
		if norm(string(k)) == target {
			return string(k)
		}
	}
	// Номаълум — ҳамон тавр бармегардонем, то тест хато диҳад.
	return strings.ToLower(goName)
}

func TestEveryNotificationAlsoReachesThePhone(t *testing.T) {
	srcs := handlerSources(t)

	rows := map[string]string{} // намуд → файл
	pushed := map[string]bool{}

	for name, src := range srcs {
		for _, m := range notifyCall.FindAllStringSubmatch(src, -1) {
			rows[m[1]] = name
		}
		for _, m := range pushCall.FindAllStringSubmatch(src, -1) {
			if m[1] != "" {
				pushed[m[1]] = true
			}
			// `string(ntf.Message)` → "message"
			//
			// ⚠️ Хурд кардани ҳарфҳо КОФӢ НЕСТ: `IncomingCall` ба
			// «incomingcall» табдил мешавад, вале қимати воқеӣ
			// «incoming_call» аст. Барои ҳамин ном ба қимати
			// ҲАҚИҚӢ мутобиқ карда мешавад.
			if m[2] != "" {
				pushed[kindValueOf(m[2])] = true
			}
		}
	}

	if len(rows) == 0 {
		t.Fatal("ягон даъвати notify ёфт нашуд — тест кӯҳна шудааст")
	}

	for kind, file := range rows {
		if !pushed[kind] {
			t.Errorf("«%s» (%s) сатр месозад, вале ба телефон чизе "+
				"намефиристад — корбари барномаашро баста ҳеҷ чиз намебинад",
				kind, file)
		}
	}
}

// Ҳар намуди фиристодашаванда бояд матни тарҷумашуда дошта бошад,
// вагарна корбар огоҳиномаи БЕ МАТН мегирад.
func TestEveryPushedKindHasText(t *testing.T) {
	srcs := handlerSources(t)

	seen := map[string]bool{}
	for _, src := range srcs {
		for _, m := range pushCall.FindAllStringSubmatch(src, -1) {
			if m[1] != "" {
				seen[m[1]] = true
			}
			if m[2] != "" {
				seen[kindValueOf(m[2])] = true
			}
		}
	}

	for kind := range seen {
		k := ntf.Kind(kind)
		if !ntf.Known(k) {
			t.Errorf("«%s» дар ҷадвали қоидаҳо нест — он ба қоидаи "+
				"захиравии Low меафтад ва матн надорад", kind)
			continue
		}
		for _, lang := range []string{"tg", "ru", "en"} {
			_, body := ntf.Text(k, ntf.NormalizeLang(lang), "kasse", 0)
			if strings.TrimSpace(body) == "" {
				t.Errorf("«%s» матни %s надорад — огоҳиномаи холӣ мешавад",
					kind, lang)
			}
		}
	}
}
