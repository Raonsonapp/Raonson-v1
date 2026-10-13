// Package features — қоидаҳои тозаи (бе база) панҷ имконияти нав:
// даъватнома, пурсиш дар пост, «Савол ба ман», «Мактуб ба оянда» ва
// «Чаленҷ». Handler-ҳо ва корҳои вақтӣ (jobs) ҳамин қоидаҳоро истифода
// мебаранд, то як қоида дар ду ҷо ду хел нашавад.
package features

import (
	"errors"
	"strings"
	"time"
	"unicode/utf8"
)

// ── «Даъватнома» ─────────────────────────────────────────────────────

// Ҷавобҳои даъват.
const (
	RSVPPending  = "pending"
	RSVPGoing    = "going"    // «Меоям»
	RSVPMaybe    = "maybe"    // «Шояд»
	RSVPDeclined = "declined" // «Намеоям»
)

// Намудҳои чорабинӣ.
var eventKinds = map[string]bool{
	"wedding": true, "birthday": true, "meetup": true, "other": true,
}

// Ҳадҳо.
const (
	EventTitleMax   = 100
	EventDescMax    = 2000
	EventMaxPlus    = 10  // ҳадди меҳмони иловагӣ бо як даъватшуда
	EventMaxGuests  = 500 // ҳадди даъватшудагон
	EventMaxCohosts = 3
	EventMaxAhead   = 2 * 365 * 24 * time.Hour
	EventMaxLength  = 14 * 24 * time.Hour
)

// NormalizeEventKind — намуди номаълум «other» мешавад.
func NormalizeEventKind(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	if eventKinds[s] {
		return s
	}
	return "other"
}

// ValidRSVP — танҳо се ҷавоби корбар (pending ҷавоб нест).
func ValidRSVP(s string) bool {
	return s == RSVPGoing || s == RSVPMaybe || s == RSVPDeclined
}

// ClampPlus — шумораи меҳмони иловагӣ: «Намеоям» — 0; дигар 0..max.
func ClampPlus(status string, plus, max int) int {
	if status == RSVPDeclined || plus < 0 {
		return 0
	}
	if max < 0 {
		max = 0
	}
	if max > EventMaxPlus {
		max = EventMaxPlus
	}
	if plus > max {
		return max
	}
	return plus
}

// Хатоҳои санҷиш — матн ба корбар нишон дода мешавад.
var (
	ErrTitle     = errors.New("Ном бояд аз 2 то 100 аломат бошад")
	ErrStartPast = errors.New("Вақти оғоз бояд дар оянда бошад")
	ErrStartFar  = errors.New("Вақти оғоз аз ҳад дур аст")
	ErrEnd       = errors.New("Вақти анҷом бояд пас аз оғоз ва то 14 рӯз бошад")
)

// ValidateEvent — ном ва вақт. end метавонад nil бошад.
func ValidateEvent(now time.Time, title string, start time.Time, end *time.Time) error {
	if n := utf8.RuneCountInString(strings.TrimSpace(title)); n < 2 || n > EventTitleMax {
		return ErrTitle
	}
	// 5 дақиқа фурсат: соати телефон каме пас мемонад.
	if start.Before(now.Add(-5 * time.Minute)) {
		return ErrStartPast
	}
	if start.After(now.Add(EventMaxAhead)) {
		return ErrStartFar
	}
	if end != nil && (!end.After(start) || end.Sub(start) > EventMaxLength) {
		return ErrEnd
	}
	return nil
}

// Марҳилаҳои ёдрасӣ.
const (
	ReminderDay = "1d"
	Reminder2h  = "2h"
)

// DueReminder — кадом ёдрасӣ ҲОЗИР фиристода шавад ("" — ҳеҷ).
//
// Қоидаҳо:
//   - пас аз оғоз ҳеҷ ёдрасӣ нест;
//   - «2 соат пеш» — вақте то оғоз ≤ 2 соат; агар он ҳам дер шуда бошад,
//     ёдрасии «1 рӯз» дигар фиристода намешавад (ду паём пайиҳам нест);
//   - «1 рӯз пеш» — вақте то оғоз ≤ 24 соат ва > 2 соат;
//   - чорабинии дар 24 соати охир сохташуда ёдрасии «1 рӯз» намегирад
//     (даъват худаш навакак омад), дар 2 соати охир — ҳеҷ ёдрасӣ.
func DueReminder(now, created, start time.Time, sentDay, sent2h bool) string {
	until := start.Sub(now)
	if until <= 0 {
		return ""
	}
	lead := start.Sub(created)
	if until <= 2*time.Hour {
		if sent2h || lead <= 2*time.Hour {
			return ""
		}
		return Reminder2h
	}
	if until <= 24*time.Hour && !sentDay && lead > 24*time.Hour {
		return ReminderDay
	}
	return ""
}

// AlbumOpen — албоми муштарак пас аз оғози чорабинӣ кушода мешавад.
func AlbumOpen(now, start time.Time) bool {
	return !now.Before(start)
}

// CanUploadToAlbum — мизбон ё меҳмоне, ки «Меоям» гуфт.
func CanUploadToAlbum(isHost bool, rsvp string) bool {
	return isHost || rsvp == RSVPGoing
}
