package features

import (
	"errors"
	"sort"
	"strings"
	"time"
	"unicode/utf8"
)

// ── «Чаленҷ» ─────────────────────────────────────────────────────────

// Ҳадҳо.
const (
	ChallengeTitleMax  = 80
	ChallengeRulesMax  = 1500
	ChallengeMaxLength = 60 * 24 * time.Hour
	ChallengeMaxAhead  = 90 * 24 * time.Hour
	ChallengeWinners   = 3
	ChallengesPerDay   = 3
	// Вазни ҳар шарҳ. Ҳар ҳисоб ба як иштирок ҳадди аксар 1 лайк +
	// 1 шарҳ (яъне 1 + CommentWeight хол) медиҳад — ҳазор лайк аз як
	// ҳисоб ё сад шарҳи як нафар холро баланд намекунанд.
	CommentWeight = 2
)

// Хатоҳо.
var (
	ErrChallengeTitle  = errors.New("Ном бояд аз 3 то 80 аломат бошад")
	ErrChallengeRules  = errors.New("Қоидаҳо то 1500 аломат")
	ErrChallengeWindow = errors.New("Санаҳо: оғоз аз имрӯз то 90 рӯз, давомнокӣ то 60 рӯз")
)

// ValidateChallenge — ном, қоида ва санаҳо.
func ValidateChallenge(now time.Time, title, rules string, start, end time.Time) error {
	if n := utf8.RuneCountInString(strings.TrimSpace(title)); n < 3 || n > ChallengeTitleMax {
		return ErrChallengeTitle
	}
	if utf8.RuneCountInString(rules) > ChallengeRulesMax {
		return ErrChallengeRules
	}
	if start.Before(now.Add(-time.Hour)) || start.After(now.Add(ChallengeMaxAhead)) ||
		!end.After(start) || end.Sub(start) > ChallengeMaxLength {
		return ErrChallengeWindow
	}
	return nil
}

// ChallengeStatus — upcoming | active | ended.
func ChallengeStatus(now, start, end time.Time) string {
	switch {
	case now.Before(start):
		return "upcoming"
	case now.Before(end):
		return "active"
	}
	return "ended"
}

// Entry — як пост/Reel-и иштирок бо ҳисоби тозаи (бе худ, бе
// такрор) лайкдиҳандагон ва шарҳнависон дар давраи чаленҷ.
type Entry struct {
	UserID     string
	Kind       string
	ID         string
	CreatedAt  time.Time
	Likers     int
	Commenters int
}

// Score — хол.
func (e Entry) Score() int {
	l, c := e.Likers, e.Commenters
	if l < 0 {
		l = 0
	}
	if c < 0 {
		c = 0
	}
	return l + CommentWeight*c
}

// Ranked — як сатри ҷадвал.
type Ranked struct {
	Rank int
	Entry
	Score int
}

// Leaderboard — ҷадвал: аз ҳар корбар ТАНҲО беҳтарин иштирок ҳисоб
// мешавад (даҳ пост аз як нафар ҷадвалро пур намекунад). Баробарӣ:
// иштироки барвақттар боло; баъд id (тартиби устувор).
func Leaderboard(entries []Entry, limit int) []Ranked {
	best := map[string]Entry{}
	for _, e := range entries {
		if e.UserID == "" {
			continue
		}
		cur, ok := best[e.UserID]
		if !ok || better(e, cur) {
			best[e.UserID] = e
		}
	}
	list := make([]Entry, 0, len(best))
	for _, e := range best {
		list = append(list, e)
	}
	sort.Slice(list, func(i, j int) bool { return better(list[i], list[j]) })
	if limit > 0 && len(list) > limit {
		list = list[:limit]
	}
	out := make([]Ranked, len(list))
	for i, e := range list {
		out[i] = Ranked{Rank: i + 1, Entry: e, Score: e.Score()}
	}
	return out
}

func better(a, b Entry) bool {
	if a.Score() != b.Score() {
		return a.Score() > b.Score()
	}
	if !a.CreatedAt.Equal(b.CreatedAt) {
		return a.CreatedAt.Before(b.CreatedAt)
	}
	return a.Kind+a.ID < b.Kind+b.ID
}
