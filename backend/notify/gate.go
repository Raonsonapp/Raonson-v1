package notify

// Дарвоза: се санҷиш пеш аз ларзонидани телефон.
//
//   1. танзимоти корбар (ӯ ин намудро мехоҳад?)
//   2. соатҳои ором (ҳозир вақти хоб нест?)
//   3. маҳдудияти шумора (аллакай хеле зиёд нашуд?)
//
// Ҳар се танҳо ба PUSH дахл доранд. Сатри огоҳинома аллакай навишта
// шудааст ва одам онро дар барнома мебинад.
//
// Ҳангоми ҳар шубҳа — ИҶОЗАТ. Хомӯшии нодуруст аз ларзиши зиёдатӣ
// бадтар аст: одам хабари муҳимро аз даст медиҳад ва сабабашро
// намедонад.

import (
	"context"
	"encoding/json"
	"strconv"
	"time"

	"raonson/push"
)

// Prefs — танзимоти огоҳиномаи корбар.
//
// Ҳар майдон *bool аст: nil маънои «корбар ин чизро танзим накард»
// дорад ва пешфарз ФАЪОЛ мебошад.
type Prefs struct {
	Likes           *bool `json:"likes"`
	Comments        *bool `json:"comments"`
	Followers       *bool `json:"followers"`
	Messages        *bool `json:"messages"`
	Mentions        *bool `json:"mentions"`
	Recommendations *bool `json:"recommendations"`
	Creator         *bool `json:"creator"`
	Achievements    *bool `json:"achievements"`
	// Push — калиди умумӣ. Хомӯш = ҳеҷ push.
	Push *bool `json:"push"`

	QuietHours struct {
		Enabled   bool `json:"enabled"`
		StartHour *int `json:"startHour"`
		EndHour   *int `json:"endHour"`
		// Бе ин рақам вақти маҳаллӣ маълум нест ва соатҳои ором
		// ТАТБИҚ НАМЕШАВАНД — тахмин задан хатари хомӯшии нодуруст
		// дорад.
		TZOffsetMinutes *int `json:"tzOffsetMinutes"`
	} `json:"quietHours"`
}

// enabled арзиши танзимро бо пешфарзи «фаъол» мехонад.
func enabled(v *bool) bool { return v == nil || *v }

// Allows мегӯяд, ки оё корбар ин намудро мехоҳад.
func (p Prefs) Allows(k Kind) bool {
	if !enabled(p.Push) {
		return false
	}
	switch RuleFor(k).PrefKey {
	case "":
		// Хомӯш карда намешавад (пул, ӯҳдадорӣ, амният).
		return true
	case "likes":
		return enabled(p.Likes)
	case "comments":
		return enabled(p.Comments)
	case "followers":
		return enabled(p.Followers)
	case "messages":
		return enabled(p.Messages)
	case "mentions":
		return enabled(p.Mentions)
	case "recommendations":
		return enabled(p.Recommendations)
	case "creator":
		return enabled(p.Creator)
	case "achievements":
		return enabled(p.Achievements)
	default:
		return true
	}
}

// InQuietHours мегӯяд, ки оё ҳозир вақти оромии корбар аст.
//
// Давра метавонад аз нимишаб гузарад (23:00–08:00).
func (p Prefs) InQuietHours(now time.Time) bool {
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
	return h >= start || h < end
}

// LoadPrefs танзимотро аз users.notif_prefs мехонад.
//
// Ҳар хато «танзимот нест»-ро маънидод мекунад: хатои хондан набояд
// огоҳиномаро хомӯш кунад.
func LoadPrefs(ctx context.Context, db push.DB, userID string) Prefs {
	var p Prefs
	var raw string
	if err := db.QueryRow(ctx,
		`SELECT COALESCE(notif_prefs::text,'{}') FROM users WHERE id=$1`,
		userID).Scan(&raw); err != nil || raw == "" {
		return p
	}
	json.Unmarshal([]byte(raw), &p)
	return p
}

// MaxPushPerHour — ҳадди техникӣ, на танзими корбар.
//
// Аз ин зиёд аллакай на хабар, балки садо аст.
const MaxPushPerHour = 10

// Counter — ҳисоби огоҳиномаҳои соат.
//
// Дар кэши раванд нигоҳ дошта мешавад. Агар кэш гум шавад, натиҷа
// «ҳаст» аст: хато ба фиристодан меафтад, на ба хомӯшӣ.
type Counter interface {
	Get(key string) ([]byte, bool)
	Set(key string, value []byte, ttl time.Duration)
}

// budgetLeft мегӯяд, ки оё корбар дар ин соат ҷои push дорад.
func budgetLeft(c Counter, userID string, now time.Time) bool {
	if c == nil {
		return true
	}
	key := "pushcount:" + userID + ":" + now.UTC().Format("2006010215")
	n := 0
	if b, ok := c.Get(key); ok {
		n, _ = strconv.Atoi(string(b))
	}
	if n >= MaxPushPerHour {
		return false
	}
	c.Set(key, []byte(strconv.Itoa(n+1)), time.Hour)
	return true
}

// Gate дарвозаи пурраро месозад.
//
// Ҷавоб: иҷозат ва сабаби рад (барои ташхис дар
// notification_delivery.reason).
func Gate(db push.DB, c Counter, now func() time.Time) func(
	context.Context, string, Kind) (bool, string) {

	if now == nil {
		now = time.Now
	}
	return func(ctx context.Context, userID string, k Kind) (bool, string) {
		rule := RuleFor(k)
		p := LoadPrefs(ctx, db, userID)

		if !p.Allows(k) {
			return false, "preference"
		}
		// Хабари фаврӣ (паём, пул, амали зарурӣ) на аз соатҳои ором
		// ва на аз маҳдудият таъсир намебинад.
		if rule.Priority == High {
			return true, ""
		}
		if p.InQuietHours(now()) {
			return false, "quiet_hours"
		}
		if !budgetLeft(c, userID, now()) {
			return false, "rate_limit"
		}
		return true, ""
	}
}
