// Package hashtags — ЯК қоидаи хештег барои сервер ва барнома.
//
// Ҳамин қоида дар lib/core/hashtags/hashtag_parser.dart такрор шудааст
// ва санҷишҳои якхела (hashtags_test.go ↔ test/hashtag_parser_test.dart)
// онҳоро ҳамоҳанг нигоҳ медоранд. Агар ин ҷо чизе иваз шавад, он ҷо ҳам
// иваз кунед.
//
// Қоида (мисли Instagram):
//   - «#» + ҳарфҳои Unicode (ҳамаи ҳарфҳои тоҷикӣ: ҳ ҷ қ ӯ ғ ӣ), рақамҳо,
//     аломатҳои диакритикӣ ва «_». Ҳар аломати дигар хештегро тамом мекунад.
//   - Ақаллан як ҳарф: «#2024» хештег нест, «#2024сол» ҳаст.
//   - Пеш аз «#» ҳарф/рақам/«_»/«#»/«&»/«/» набошад: «a#b», «&#39;»,
//     «/page#x» хештег нестанд.
//   - Дар дохили URL («https://…#bolo», «www.…#x») хештег нест.
//   - Дарозӣ то 50 аломат; дарозтар — хештег ҳисоб намешавад.
//   - Ҳарфи калон/хурд фарқ надорад: «#Душанбе» = «#душанбе».
//   - Аз як матн то 30 хештеги гуногун гирифта мешавад (мисли Instagram).
package hashtags

import (
	"context"
	"regexp"
	"strings"
	"unicode"
	"unicode/utf8"

	"github.com/jackc/pgx/v5/pgconn"
)

const (
	// MaxPerText — ҳадди хештегҳои як тавсиф.
	MaxPerText = 30
	// MaxLen — ҳадди дарозии як хештег (бе «#»), бо аломат.
	MaxLen = 50
)

// urlRe — URL-ҳо, ки «#»-и дохилашон хештег нест. Синфи фосила ошкоро
// навишта шудааст, то бо Dart (ки `\s`-аш Unicode аст) айнан якхела бошад.
var urlRe = regexp.MustCompile(`(?i)(?:https?://|www\.)[^ \t\n\r\f\v]+`)

// IsTagRune — аломати ҷоиз дар дохили хештег.
func IsTagRune(r rune) bool {
	return unicode.IsLetter(r) || unicode.IsMark(r) || unicode.Is(unicode.Nd, r) || r == '_'
}

// blocksStart — аломате, ки пеш аз «#» омада, онро хештег намекунад.
func blocksStart(r rune) bool {
	return IsTagRune(r) || r == '#' || r == '&' || r == '/'
}

// Match — як хештег дар матн. Start/End — мавқеи байтӣ (бо «#»).
type Match struct {
	Start, End int
	Raw        string // ҳамон тавре ки навишта шуд (бе «#»)
	Tag        string // шакли муқаррарӣ (ҳарфи хурд)
}

// validBody — ақаллан як ҳарф ва дарозӣ ≤ MaxLen.
func validBody(body string) bool {
	if body == "" || utf8.RuneCountInString(body) > MaxLen {
		return false
	}
	for _, r := range body {
		if unicode.IsLetter(r) {
			return true
		}
	}
	return false
}

// Find — ҳамаи хештегҳои ҷоиз бо тартиб (такрорҳо низ).
func Find(text string) []Match {
	if !strings.Contains(text, "#") {
		return nil
	}
	urls := urlRe.FindAllStringIndex(text, -1)
	inURL := func(i int) bool {
		for _, u := range urls {
			if i >= u[0] && i < u[1] {
				return true
			}
		}
		return false
	}
	var out []Match
	prev := rune(-1)
	for i := 0; i < len(text); {
		r, size := utf8.DecodeRuneInString(text[i:])
		if r != '#' || (prev != -1 && blocksStart(prev)) || inURL(i) {
			prev = r
			i += size
			continue
		}
		j := i + size
		for j < len(text) {
			r2, s2 := utf8.DecodeRuneInString(text[j:])
			if !IsTagRune(r2) {
				break
			}
			j += s2
		}
		body := text[i+size : j]
		if validBody(body) {
			out = append(out, Match{Start: i, End: j, Raw: body, Tag: strings.ToLower(body)})
		}
		if j == i+size {
			prev = r
			i += size
			continue
		}
		// Аломати охири бадан — «#a#b»: «#b» хештег намешавад.
		lr, _ := utf8.DecodeLastRuneInString(text[:j])
		prev = lr
		i = j
	}
	return out
}

// Extract — хештегҳои муқаррарии беназир, то MaxPerText, бо тартиби пайдоиш.
func Extract(text string) []string {
	out := []string{}
	seen := map[string]bool{}
	for _, m := range Find(text) {
		if seen[m.Tag] {
			continue
		}
		seen[m.Tag] = true
		out = append(out, m.Tag)
		if len(out) >= MaxPerText {
			break
		}
	}
	return out
}

// Normalize — «#Душанбе» / «Душанбе» → «душанбе». false — хештеги нодуруст.
func Normalize(tag string) (string, bool) {
	t := strings.TrimSpace(tag)
	t = strings.TrimPrefix(t, "#")
	for _, r := range t {
		if !IsTagRune(r) {
			return "", false
		}
	}
	if !validBody(t) {
		return "", false
	}
	return strings.ToLower(t), true
}

// NormalizePrefix — барои пешниҳод: «#Ду» → «ду». Ҳарф шарт нест
// («#20» → «20» то «#2024сол» ёфт шавад). false — холӣ ё аломати бегона.
func NormalizePrefix(q string) (string, bool) {
	t := strings.TrimPrefix(strings.TrimSpace(q), "#")
	if t == "" || utf8.RuneCountInString(t) > MaxLen {
		return "", false
	}
	for _, r := range t {
		if !IsTagRune(r) {
			return "", false
		}
	}
	return strings.ToLower(t), true
}

// Execer — pgxpool.Pool ва pgx.Tx ҳарду мувофиқанд.
type Execer interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
}

// Kind → ҷадвал.
func table(kind string) string {
	if kind == "reel" {
		return "reels"
	}
	return "posts"
}

// Sync — хештегҳои як пост/Reel-ро бо тавсифи ҳозира баробар мекунад.
// Хештегҳои мондагор вақти аслии худро нигоҳ медоранд (тренд вайрон
// намешавад); хориҷшудаҳо нест мешаванд.
func Sync(ctx context.Context, q Execer, kind, id, caption string) error {
	if id == "" {
		return nil
	}
	tags := Extract(caption)
	if _, err := q.Exec(ctx,
		`DELETE FROM content_hashtags
		  WHERE content_kind=$1 AND content_id=$2 AND NOT (tag = ANY($3::text[]))`,
		kind, id, tags); err != nil {
		return err
	}
	if len(tags) == 0 {
		return nil
	}
	_, err := q.Exec(ctx,
		`INSERT INTO content_hashtags(content_kind, content_id, tag, created_at)
		 SELECT $1, $2, t, COALESCE((SELECT created_at FROM `+table(kind)+` WHERE id=$2), NOW())
		   FROM unnest($3::text[]) AS t
		 ON CONFLICT DO NOTHING`,
		kind, id, tags)
	return err
}

// Remove — пост/Reel нест шуд.
func Remove(ctx context.Context, q Execer, kind, id string) {
	q.Exec(ctx, `DELETE FROM content_hashtags WHERE content_kind=$1 AND content_id=$2`, kind, id)
}
