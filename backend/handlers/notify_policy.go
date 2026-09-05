package handlers

// Сиёсати огоҳиномаҳо.
//
// Мушкил: як пости маъруф метавонад дар як соат садҳо push диҳад ва
// телефон бе таваққуф ларзад. Одам баъд ҲАМА огоҳиномаро хомӯш
// мекунад — ва он вақт хабари муҳимро ҳам намебинад.
//
// Аз ин рӯ:
//   • Ҳисоби огоҳинома ҲАМЕША сабт мешавад (notify) — чизе гум
//     намешавад; танҳо ЛАРЗИШ (push) маҳдуд мешавад.
//   • Соатҳои ором ТАНҲО бо хости корбар кор мекунанд: барнома
//     худсарона хомӯш намекунад.
//   • Ҳангоми ҳар шубҳа push ФИРИСТОДА мешавад: хомӯшии нодуруст аз
//     ларзиши зиёдатӣ бадтар аст.

import (
	"context"
	"encoding/json"
	"strconv"
	"time"

	"raonson/db"
	mw "raonson/middleware"
)

// maxPushPerHour — ҳадди техникӣ, на танзими корбар.
//
// Аз ин зиёд аллакай на хабар, балки садо аст.
const maxPushPerHour = 10

// urgentTypes — намудҳое, ки маҳдуд НАМЕШАВАНД.
//
// Ин ҷо танҳо хабарҳое ҳастанд, ки одам онҳоро фавран интизор аст ё
// пул ба он вобаста аст.
var urgentTypes = map[string]bool{
	"message":                 true,
	"campaign_invite":         true,
	"campaign_offer_response": true,
	"campaign_payout":         true,
	"order":                   true,
	"effect_sale":             true,
}

// notifPrefs — танзимоти корбар аз notif_prefs (JSONB).
type notifPrefs struct {
	QuietHours struct {
		Enabled bool `json:"enabled"`
		// Соатҳо аз рӯи вақти МАҲАЛЛИИ корбар (0–23).
		StartHour *int `json:"startHour"`
		EndHour   *int `json:"endHour"`
		// Фарқи вақт аз UTB бо дақиқа. Бе он вақти маҳаллӣ маълум
		// нест ва соатҳои ором татбиқ намешаванд.
		TZOffsetMinutes *int `json:"tzOffsetMinutes"`
	} `json:"quietHours"`
}

// loadNotifPrefs танзимотро мехонад.
//
// Ҳар хато «танзимот нест»-ро маънидод мекунад: набояд аз сабаби
// хатои хондан огоҳинома хомӯш шавад.
func loadNotifPrefs(userID string) notifPrefs {
	var p notifPrefs
	var raw string
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	if err := db.Pool.QueryRow(ctx,
		`SELECT COALESCE(notif_prefs::text,'{}') FROM users WHERE id=$1`,
		userID).Scan(&raw); err != nil || raw == "" {
		return p
	}
	json.Unmarshal([]byte(raw), &p)
	return p
}

// inQuietHours мегӯяд, ки оё ҳозир вақти оромии корбар аст.
//
// Давра метавонад аз нимишаб гузарад (23:00–08:00) — ин ҳолати
// маъмул аст ва алоҳида ҳисоб мешавад.
func inQuietHours(p notifPrefs, now time.Time) bool {
	q := p.QuietHours
	if !q.Enabled || q.StartHour == nil || q.EndHour == nil ||
		q.TZOffsetMinutes == nil {
		return false
	}
	start, end, off := *q.StartHour, *q.EndHour, *q.TZOffsetMinutes
	if start < 0 || start > 23 || end < 0 || end > 23 || start == end {
		return false
	}
	if off < -14*60 || off > 14*60 {
		return false
	}
	h := now.UTC().Add(time.Duration(off) * time.Minute).Hour()
	if start < end {
		return h >= start && h < end
	}
	// Давраи шабона: 23 → 8.
	return h >= start || h < end
}

// pushBudgetLeft мегӯяд, ки оё корбар дар ин соат ҷои push дорад.
//
// Ҳисоб дар кэши раванд аст: агар кэш гум шавад, натиҷа «ҳаст» аст —
// яъне хатогӣ ба фиристодан меафтад, на ба хомӯшӣ.
func pushBudgetLeft(userID string, now time.Time) bool {
	key := "pushcount:" + userID + ":" + now.UTC().Format("2006010215")
	n := 0
	if b, ok := mw.CacheGet(key); ok {
		n, _ = strconv.Atoi(string(b))
	}
	if n >= maxPushPerHour {
		return false
	}
	mw.CacheSet(key, []byte(strconv.Itoa(n+1)), time.Hour)
	return true
}

// allowPush қарор мегирад, ки push фиристода шавад ё не.
func allowPush(userID, ntype string, now time.Time) bool {
	if urgentTypes[ntype] {
		return true
	}
	if inQuietHours(loadNotifPrefs(userID), now) {
		return false
	}
	return pushBudgetLeft(userID, now)
}
