package features

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"
)

// ── Пурсиш ва викторина дар пост ─────────────────────────────────────

// Ҳадҳо.
const (
	PollMinOptions  = 2
	PollMaxOptions  = 4
	PollOptionMax   = 80
	PollQuestionMax = 140
	PollMinDuration = 5 * time.Minute
	PollMaxDuration = 30 * 24 * time.Hour
)

// PollInput — он чи муаллиф ҳангоми сохтани пост мефиристад.
type PollInput struct {
	Question string     `json:"question"`
	Options  []string   `json:"options"`
	Correct  *int       `json:"correctIndex"`
	EndsAt   *time.Time `json:"endsAt"`
}

// Хатоҳои пурсиш.
var (
	ErrPollOptions  = errors.New("Пурсиш бояд 2 то 4 ҷавоб дошта бошад")
	ErrPollOption   = errors.New("Ҳар ҷавоб бояд аз 1 то 80 аломат бошад")
	ErrPollDup      = errors.New("Ҷавобҳо набояд такрор шаванд")
	ErrPollQuestion = errors.New("Савол то 140 аломат")
	ErrPollCorrect  = errors.New("Ҷавоби дурусти викторина нодуруст аст")
	ErrPollEnds     = errors.New("Анҷоми пурсиш бояд аз 5 дақиқа то 30 рӯз бошад")
)

// NormalizePoll — тоза ва санҷидани пурсиш.
func NormalizePoll(in PollInput, now time.Time) (PollInput, error) {
	out := PollInput{Question: strings.TrimSpace(in.Question)}
	if utf8.RuneCountInString(out.Question) > PollQuestionMax {
		return out, ErrPollQuestion
	}
	if len(in.Options) < PollMinOptions || len(in.Options) > PollMaxOptions {
		return out, ErrPollOptions
	}
	seen := map[string]bool{}
	for _, o := range in.Options {
		o = strings.TrimSpace(o)
		n := utf8.RuneCountInString(o)
		if n < 1 || n > PollOptionMax {
			return out, ErrPollOption
		}
		k := strings.ToLower(o)
		if seen[k] {
			return out, ErrPollDup
		}
		seen[k] = true
		out.Options = append(out.Options, o)
	}
	if in.Correct != nil {
		if *in.Correct < 0 || *in.Correct >= len(out.Options) {
			return out, ErrPollCorrect
		}
		c := *in.Correct
		out.Correct = &c
	}
	if in.EndsAt != nil {
		d := in.EndsAt.Sub(now)
		if d < PollMinDuration-time.Second || d > PollMaxDuration {
			return out, ErrPollEnds
		}
		e := in.EndsAt.UTC()
		out.EndsAt = &e
	}
	return out, nil
}

// PollEnded — пурсиш тамом шуд?
func PollEnded(now time.Time, endsAt *time.Time) bool {
	return endsAt != nil && !now.Before(*endsAt)
}

// PollResultsVisible — натиҷа танҳо баъди овоз, барои муаллиф ё
// баъди анҷом (мисли Instagram: аввал интихоб, баъд натиҷа).
func PollResultsVisible(isAuthor, voted, ended bool) bool {
	return isAuthor || voted || ended
}

// PollPercents — фоизҳо бо усули «боқимондаи калонтарин»: ҳамеша
// ҷамъашон 100 (агар ягон овоз бошад), на 99 ё 101.
func PollPercents(counts []int) []int {
	out := make([]int, len(counts))
	total := 0
	for _, c := range counts {
		if c > 0 {
			total += c
		}
	}
	if total == 0 {
		return out
	}
	type rem struct {
		i int
		r int
	}
	sum := 0
	rems := make([]rem, 0, len(counts))
	for i, c := range counts {
		if c < 0 {
			c = 0
		}
		out[i] = c * 100 / total
		sum += out[i]
		rems = append(rems, rem{i, c * 100 % total})
	}
	// Боқимондаи калонтарин аввал; баробар — тартиби ҷавобҳо.
	for k := 0; k < 100-sum; k++ {
		best := -1
		for j, r := range rems {
			if r.r < 0 {
				continue
			}
			if best < 0 || r.r > rems[best].r {
				best = j
			}
		}
		if best < 0 {
			break
		}
		out[rems[best].i]++
		rems[best].r = -1
	}
	return out
}
