package features

import (
	"errors"
	"strings"
	"unicode/utf8"
)

// ── «Савол ба ман» ───────────────────────────────────────────────────

// Кӣ савол дода метавонад.
const (
	QAEveryone  = "everyone"
	QAFollowers = "followers"
	QAOff       = "off"
)

// Ҳадҳо.
const (
	QuestionMin = 3
	QuestionMax = 300
	AnswerMax   = 1000
	// Ба як нафар дар як соат; аз як нафар дар як рӯз.
	QuestionsPerOwnerHour = 5
	QuestionsPerDay       = 30
)

// Хатоҳо.
var (
	ErrQuestionLen = errors.New("Савол бояд аз 3 то 300 аломат бошад")
	ErrAnswerLen   = errors.New("Ҷавоб бояд аз 1 то 1000 аломат бошад")
)

// NormalizeQAMode — қимати танзим. false — нодуруст.
func NormalizeQAMode(s string) (string, bool) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case QAEveryone:
		return QAEveryone, true
	case QAFollowers, "":
		return QAFollowers, true
	case QAOff:
		return QAOff, true
	}
	return "", false
}

// CanAsk — танзими соҳиб иҷозат медиҳад? (бастан ва ҳисоби пӯшида
// ҷудогона санҷида мешаванд).
func CanAsk(mode string, askerFollowsOwner bool) bool {
	switch mode {
	case QAEveryone:
		return true
	case QAOff:
		return false
	default:
		return askerFollowsOwner
	}
}

// AskerVisible — номи савoлдиҳанда ба ин тамошобин нишон дода шавад?
// Саволи беном номро ба ҳеҷ кас нишон намедиҳад — на ба соҳиб, на ба
// тамошобинон; танҳо модератор/admin (ва худи савoлдиҳанда) медонад.
func AskerVisible(anonymous, viewerIsAsker, viewerIsAdmin bool) bool {
	return !anonymous || viewerIsAsker || viewerIsAdmin
}

// ValidateQuestion — дарозии савол.
func ValidateQuestion(text string) (string, error) {
	t := strings.TrimSpace(text)
	if n := utf8.RuneCountInString(t); n < QuestionMin || n > QuestionMax {
		return t, ErrQuestionLen
	}
	return t, nil
}

// ValidateAnswer — дарозии ҷавоб.
func ValidateAnswer(text string) (string, error) {
	t := strings.TrimSpace(text)
	if n := utf8.RuneCountInString(t); n < 1 || n > AnswerMax {
		return t, ErrAnswerLen
	}
	return t, nil
}
