package middleware

import (
	"context"
	"sync"
	"time"

	"raonson/db"
)

// ══════════════════════════════════════════════════════════════════
//  Бекор кардани token-ҳо.
//
//  Пеш «Ҳамаи дастгоҳҳоро бандед», иваз кардани рамз ва бастани
//  ҳисоб (ban) ҳеҷ token-ро бекор намекарданд: token-и дастрасӣ то
//  охир ва refresh-token 30 рӯз кор мекард. Касе, ки рамзро дуздида
//  буд, баъди ивази рамз ҳам дар ҳисоб мемонд.
//
//  Акнун дар ҳар token рақами `tv` (token_version) ҳаст. Ин амалҳо
//  рақамро дар база зиёд мекунанд — ҳамаи token-ҳои кӯҳна фавран
//  (то 20 сония — кэш) эътибор надоранд. Token-ҳои бе `tv` (то ин
//  нашр дода шуда) ҳамчун 0 ҳисоб мешаванд — касе маҷбуран намебарояд.
// ══════════════════════════════════════════════════════════════════

type tokenState struct {
	version int
	banned  bool
	at      time.Time
}

var (
	stateMu    sync.RWMutex
	stateCache = map[string]tokenState{}
)

const stateTTL = 20 * time.Second

// TokenState — версияи ҷорӣ ва ҳолати бани корбар.
func TokenState(uid string) (version int, banned bool) {
	stateMu.RLock()
	st, ok := stateCache[uid]
	stateMu.RUnlock()
	if ok && time.Since(st.at) < stateTTL {
		return st.version, st.banned
	}
	if db.Pool == nil {
		return 0, false
	}
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(token_version,0), COALESCE(banned,false) FROM users WHERE id=$1`,
		uid).Scan(&version, &banned)
	stateMu.Lock()
	if len(stateCache) > 100000 {
		stateCache = map[string]tokenState{}
	}
	stateCache[uid] = tokenState{version, banned, time.Now()}
	stateMu.Unlock()
	return version, banned
}

// RevokeTokens — ҳамаи token-ҳои корбарро бекор мекунад.
func RevokeTokens(uid string) {
	if db.Pool != nil {
		db.Pool.Exec(context.Background(),
			`UPDATE users SET token_version = COALESCE(token_version,0) + 1 WHERE id=$1`, uid)
	}
	stateMu.Lock()
	delete(stateCache, uid)
	stateMu.Unlock()
}

// ForgetTokenState — кэшро пок мекунад (масалан баъди ban/unban).
func ForgetTokenState(uid string) {
	stateMu.Lock()
	delete(stateCache, uid)
	stateMu.Unlock()
}

// TokenAllowed — claims-и token ҳанӯз эътибор дорад?
func TokenAllowed(uid string, claimTV interface{}) bool {
	tv := 0
	if f, ok := claimTV.(float64); ok {
		tv = int(f)
	}
	cur, banned := TokenState(uid)
	return !banned && tv == cur
}
