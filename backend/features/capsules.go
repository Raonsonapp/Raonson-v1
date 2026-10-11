package features

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"
)

// ── «Мактуб ба оянда» ────────────────────────────────────────────────

// Барои кӣ.
const (
	CapsuleSelf      = "self"
	CapsuleFriend    = "friend"
	CapsuleFollowers = "followers"
)

// Ҳадҳо.
const (
	CapsuleTextMax  = 5000
	CapsuleNoteMax  = 80
	CapsuleMaxMedia = 4
	CapsuleMaxAhead = 10 * 365 * 24 * time.Hour
	CapsulesPerDay  = 10
)

// Хатоҳо.
var (
	ErrCapsuleAudience = errors.New("Барои кӣ: худам, дӯст ё обуначиён")
	ErrCapsuleEmpty    = errors.New("Мактуб холӣ аст")
	ErrCapsuleText     = errors.New("Мактуб то 5000 аломат")
	ErrCapsuleNote     = errors.New("Сатри рӯи лифофа то 80 аломат")
	ErrCapsuleMedia    = errors.New("То 4 акс ё видео")
	ErrCapsuleSoon     = errors.New("Санаи кушодан бояд дар оянда бошад")
	ErrCapsuleFar      = errors.New("Санаи кушодан то 10 сол")
)

// NormalizeAudience — false — нодуруст.
func NormalizeAudience(s string) (string, bool) {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case CapsuleSelf, "":
		return CapsuleSelf, true
	case CapsuleFriend:
		return CapsuleFriend, true
	case CapsuleFollowers:
		return CapsuleFollowers, true
	}
	return "", false
}

// ValidateCapsule — матн, медиа ва сана. minLead — ақаллан чӣ қадар
// пеш (дар продакшн 1 соат).
func ValidateCapsule(now time.Time, text, note string, media int, unlock time.Time, minLead time.Duration) error {
	if strings.TrimSpace(text) == "" && media == 0 {
		return ErrCapsuleEmpty
	}
	if utf8.RuneCountInString(text) > CapsuleTextMax {
		return ErrCapsuleText
	}
	if utf8.RuneCountInString(strings.TrimSpace(note)) > CapsuleNoteMax {
		return ErrCapsuleNote
	}
	if media > CapsuleMaxMedia {
		return ErrCapsuleMedia
	}
	if unlock.Before(now.Add(minLead)) {
		return ErrCapsuleSoon
	}
	if unlock.After(now.Add(CapsuleMaxAhead)) {
		return ErrCapsuleFar
	}
	return nil
}

// CapsuleOpen — мактуб кушода шуд?
func CapsuleOpen(now, unlock time.Time) bool {
	return !now.Before(unlock)
}

// CapsuleAudienceAllows — ин тамошобин ҚАТОРИ гирандагон аст?
// (бастан ва ҳисоби пӯшида ҷудогона санҷида мешаванд).
func CapsuleAudienceAllows(viewer, author, audience, recipient string, viewerFollowsAuthor bool) bool {
	if viewer == "" {
		return false
	}
	if viewer == author {
		return true
	}
	switch audience {
	case CapsuleFriend:
		return viewer == recipient
	case CapsuleFollowers:
		return viewerFollowsAuthor
	}
	return false
}

// CapsuleContentVisible — матн ва медиа ТАНҲО пас аз кушодан нишон дода
// мешаванд — ҳатто ба муаллиф: мактуб мӯҳр шудааст.
func CapsuleContentVisible(now, unlock time.Time, allowed bool) bool {
	return allowed && CapsuleOpen(now, unlock)
}
