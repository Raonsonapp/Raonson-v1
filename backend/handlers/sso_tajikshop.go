package handlers

// ═══════════════════════════════════════════════════════════════════
//  Як ҳисоб барои Raonson ва TajikShop (SSO).
//
//  TajikShop провайдери шахсият аст. Ду самт:
//
//  1. TajikShop → Raonson («Бо TajikShop ворид шавед»)
//       TajikShop raonson://sso?code=… -ро мекушояд →
//       барнома кодро ба МО мефиристад: POST /auth/sso/tajikshop {code}
//       → мо бо калиди шарик (танҳо дар сервер) /sso/exchange мекунем.
//
//     Пайвастан:
//       • аллакай пайваст → ҳамон корбари Raonson ворид мешавад;
//       • корбар ворид аст ва «Пайваст кардан»-ро интихоб кард (link:true)
//         → ба ҳисоби ҷорӣ пайваст мешавад; бе интихоб → «confirm_link»;
//       • почтаи TajikShop дар Raonson ҳаст → ХУДКОР ПАЙВАСТ НАМЕШАВАД.
//         TajikShop почтаро тасдиқ намекунад: касе метавонист бо почтаи
//         бегона дар TajikShop қайд шуда, ҳисоби Raonson-и ӯро гирад.
//         409 link_required + token-и якдафъаина (10 дақ) — корбар бо
//         рамзи Raonson ворид шуда, пайвандро тасдиқ мекунад;
//       • вагарна ҳисоби нав сохта мешавад (needsProfileSetup).
//
//  2. Raonson → TajikShop («TajikShop-ро кушоед»)
//       POST /sso/tajikshop/handoff → refresh-token-и захирашуда →
//       /auth/refresh → /sso/code {target_app:"tajikshop"} →
//       tajikshop://sso?code=…
//
//  Ҳеҷ код, token ё калид ба log намеравад.
// ═══════════════════════════════════════════════════════════════════

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"log"
	"math/big"
	"net/http"
	"regexp"
	"strings"
	"time"
	"unicode"

	"raonson/db"
	mw "raonson/middleware"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

const (
	ssoProvider   = "tajikshop"
	ssoPendingTTL = 10 * time.Minute
)

var (
	errSSOLinkedOther  = errors.New("sso: ҳисоби TajikShop ба корбари дигар пайваст аст")
	errSSOUserHasOther = errors.New("sso: корбар ба TajikShop-и дигар пайваст аст")
	errSSOPending      = errors.New("sso: token-и тасдиқ нодуруст")
)

var ssoPendingRe = regexp.MustCompile(`^[A-Za-z0-9_-]{43}$`)

func ssoConfigured() bool { return tajikshopPartnerKey() != "" }

func ssoFail(c *gin.Context, f ssoFailure) {
	c.JSON(f.HTTP, gin.H{"code": f.Code, "message": f.Message})
}

// ssoAudit — як сатри log бе ҳеҷ сир (на код, на token, на почта).
func ssoAudit(c *gin.Context, event, uid, extID, result string) {
	log.Printf("[sso] tajikshop event=%s uid=%s ts=%s ip=%s result=%s",
		event, uid, extID, c.ClientIP(), result)
}

// ── Пайвандҳо ──────────────────────────────────────────────────────

type ssoLink struct {
	UserID   string
	ExtID    string
	Name     string
	Email    string
	Sealed   string
	LinkedAt time.Time
}

func ssoFindLink(ctx context.Context, where string, arg string) (*ssoLink, error) {
	var l ssoLink
	err := db.Pool.QueryRow(ctx, `
		SELECT user_id, external_id, ext_name, ext_email, ts_refresh_token, linked_at
		  FROM external_accounts WHERE provider=$1 AND `+where+`=$2`, ssoProvider, arg).
		Scan(&l.UserID, &l.ExtID, &l.Name, &l.Email, &l.Sealed, &l.LinkedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &l, nil
}

func ssoLinkByExt(ctx context.Context, extID string) (*ssoLink, error) {
	return ssoFindLink(ctx, "external_id", extID)
}

func ssoLinkByUser(ctx context.Context, uid string) (*ssoLink, error) {
	return ssoFindLink(ctx, "user_id", uid)
}

// ssoLinkAccount — ҳисоби TajikShop-ро ба uid мебандад. Идемпотентӣ:
// ҳамон ҷуфт — танҳо token ва ном нав мешаванд.
func ssoLinkAccount(ctx context.Context, uid, extID, name, email, sealed string) error {
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var owner string
	err = tx.QueryRow(ctx, `SELECT user_id FROM external_accounts
		WHERE provider=$1 AND external_id=$2 FOR UPDATE`, ssoProvider, extID).Scan(&owner)
	switch {
	case err == nil && owner != uid:
		return errSSOLinkedOther
	case err == nil:
		if _, err := tx.Exec(ctx, `UPDATE external_accounts
			SET ext_name=$3, ext_email=$4,
			    ts_refresh_token=CASE WHEN $5='' THEN ts_refresh_token ELSE $5 END,
			    updated_at=NOW()
			WHERE provider=$1 AND external_id=$2`, ssoProvider, extID, name, email, sealed); err != nil {
			return err
		}
		return tx.Commit(ctx)
	case !errors.Is(err, pgx.ErrNoRows):
		return err
	}

	var other string
	err = tx.QueryRow(ctx, `SELECT external_id FROM external_accounts
		WHERE provider=$1 AND user_id=$2`, ssoProvider, uid).Scan(&other)
	if err == nil {
		return errSSOUserHasOther
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return err
	}
	if _, err := tx.Exec(ctx, `INSERT INTO external_accounts
		(provider, external_id, user_id, ext_name, ext_email, ts_refresh_token)
		VALUES ($1,$2,$3,$4,$5,$6)`, ssoProvider, extID, uid, name, email, sealed); err != nil {
		if isUnique(err) {
			return errSSOLinkedOther // пойга: дигаре ҳамин лаҳза пайваст кард
		}
		return err
	}
	return tx.Commit(ctx)
}

func ssoLinkErr(c *gin.Context, err error) {
	switch {
	case errors.Is(err, errSSOLinkedOther):
		c.JSON(http.StatusConflict, gin.H{"code": "linked_other",
			"message": "Ин ҳисоби TajikShop ба ҳисоби дигари Raonson пайваст аст"})
	case errors.Is(err, errSSOUserHasOther):
		c.JSON(http.StatusConflict, gin.H{"code": "already_linked",
			"message": "Ҳисоби шумо аллакай ба ҳисоби дигари TajikShop пайваст аст. Аввал онро ҷудо кунед"})
	default:
		c.JSON(http.StatusInternalServerError, gin.H{"code": "server_error",
			"message": "Пайваст нашуд. Баъдтар боз кӯшиш кунед"})
	}
}

// ── Token-и «тасдиқи пайванд» (10 дақ, якдафъаина) ────────────────

func ssoHash(tok string) string {
	s := sha256.Sum256([]byte(tok))
	return hex.EncodeToString(s[:])
}

func ssoCreatePending(ctx context.Context, extID, name, email, sealed string) (string, error) {
	buf := make([]byte, 32)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	tok := base64.RawURLEncoding.EncodeToString(buf)
	// Як token-и зинда барои як ҳисоби TajikShop; кӯҳнаҳо пок мешаванд.
	db.Pool.Exec(ctx, `DELETE FROM sso_pending_links
		WHERE (provider=$1 AND external_id=$2) OR expires_at < NOW() - INTERVAL '1 day'`,
		ssoProvider, extID)
	_, err := db.Pool.Exec(ctx, `INSERT INTO sso_pending_links
		(token_hash, provider, external_id, ext_name, ext_email, ts_refresh_token, expires_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		ssoHash(tok), ssoProvider, extID, name, email, sealed, time.Now().Add(ssoPendingTTL))
	if err != nil {
		return "", err
	}
	return tok, nil
}

// ssoConsumePending — як бор: шарт дар худи UPDATE аст.
func ssoConsumePending(ctx context.Context, tok string) (extID, name, email, sealed string, err error) {
	if !ssoPendingRe.MatchString(tok) {
		return "", "", "", "", errSSOPending
	}
	err = db.Pool.QueryRow(ctx, `UPDATE sso_pending_links SET used_at=NOW()
		WHERE token_hash=$1 AND provider=$2 AND used_at IS NULL AND expires_at > NOW()
		RETURNING external_id, ext_name, ext_email, ts_refresh_token`,
		ssoHash(tok), ssoProvider).Scan(&extID, &name, &email, &sealed)
	if err != nil {
		return "", "", "", "", errSSOPending
	}
	return extID, name, email, sealed, nil
}

// ── Ҷавобҳо ────────────────────────────────────────────────────────

// maskPersonName — «Ehson Mahmadmurodov» → «Ehson M.»
func maskPersonName(name string) string {
	parts := strings.Fields(name)
	if len(parts) == 0 {
		return ""
	}
	out := []string{string([]rune(parts[0])[:min(len([]rune(parts[0])), 20)])}
	for _, p := range parts[1:] {
		r := []rune(p)
		out = append(out, string(r[0])+".")
		if len(out) == 3 {
			break
		}
	}
	return strings.Join(out, " ")
}

func ssoPublic(name, email string, linkedAt time.Time) gin.H {
	m := ""
	if email != "" {
		m = maskEmailHint(email)
	}
	h := gin.H{"name": maskPersonName(name), "email": m}
	if !linkedAt.IsZero() {
		h["linkedAt"] = linkedAt.UTC().Format(time.RFC3339)
	}
	return h
}

// ssoIssueLogin — ҳамон token-ҳо ва сабти сессия, ки /auth/login медиҳад
// (token_version дар JWT). Ҳисоби баста ворид намешавад; маҳдудкунии
// муваққатии модератсия вурудро манъ намекунад (танҳо нашрро).
func ssoIssueLogin(c *gin.Context, uid string, extra gin.H) bool {
	ctx := c.Request.Context()
	var banned bool
	if err := db.Pool.QueryRow(ctx,
		`SELECT COALESCE(banned,false) FROM users WHERE id=$1`, uid).Scan(&banned); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"code": "user_not_found", "message": "Корбар ёфт нашуд"})
		return false
	}
	if banned {
		c.JSON(http.StatusForbidden, gin.H{"code": "banned", "message": "Ҳисоби шумо баста шудааст"})
		return false
	}
	resp, _, _ := loginResponse(c, uid)
	if t := suspendedUntil(ctx, uid); t != nil {
		resp["suspendedUntil"] = t.UTC().Format(time.RFC3339)
	}
	for k, v := range extra {
		resp[k] = v
	}
	c.JSON(http.StatusOK, resp)
	return true
}

// ── Ҳисоби нав ─────────────────────────────────────────────────────

var tjTranslit = map[rune]string{
	'а': "a", 'б': "b", 'в': "v", 'г': "g", 'ғ': "gh", 'д': "d", 'е': "e", 'ё': "yo",
	'ж': "zh", 'з': "z", 'и': "i", 'ӣ': "i", 'й': "y", 'к': "k", 'қ': "q", 'л': "l",
	'м': "m", 'н': "n", 'о': "o", 'п': "p", 'р': "r", 'с': "s", 'т': "t", 'у': "u",
	'ӯ': "u", 'ф': "f", 'х': "kh", 'ҳ': "h", 'ц': "ts", 'ч': "ch", 'ҷ': "j", 'ш': "sh",
	'щ': "sh", 'ъ': "", 'ы': "y", 'ь': "", 'э': "e", 'ю': "yu", 'я': "ya",
}

// usernameBase — «Эҳсон Маҳмадмуродов» → «ehson_mahmadmurodov».
func usernameBase(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		switch {
		case r >= 'a' && r <= 'z', r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '_' || r == '.':
			b.WriteRune(r)
		case unicode.IsSpace(r) || r == '-' || r == '+':
			b.WriteRune('_')
		default:
			if t, ok := tjTranslit[r]; ok {
				b.WriteString(t)
			}
		}
	}
	out := regexp.MustCompile(`[_.]{2,}`).ReplaceAllString(b.String(), "_")
	out = strings.Trim(out, "_.")
	if len(out) > 20 {
		out = strings.Trim(out[:20], "_.")
	}
	return out
}

func randDigits(n int) string {
	var b strings.Builder
	for i := 0; i < n; i++ {
		d, _ := rand.Int(rand.Reader, big.NewInt(10))
		b.WriteByte(byte('0' + d.Int64()))
	}
	return b.String()
}

func usernameTaken(ctx context.Context, u string) bool {
	var exists bool
	db.Pool.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(username)=$1)`, u).Scan(&exists)
	return exists
}

// ssoPickUsername — номи озод аз ном ё почта; корбар онро дар қадами
// «Номи корбарро интихоб кунед» иваз карда метавонад.
func ssoPickUsername(ctx context.Context, name, email string) string {
	base := usernameBase(name)
	if len(base) < 3 {
		if at := strings.Index(email, "@"); at > 0 {
			base = usernameBase(email[:at])
		}
	}
	if len(base) < 3 {
		base = "user"
	}
	if !usernameRe.MatchString(base) || reservedUsername(base) || usernameTaken(ctx, base) {
		for i := 0; i < 8; i++ {
			cand := base + "_" + randDigits(4+i/3)
			if usernameRe.MatchString(cand) && !usernameTaken(ctx, cand) {
				return cand
			}
		}
		return "user_" + randDigits(10)
	}
	return base
}

// ssoCreateUser — ҳисоби нав аз маълумоти TajikShop. Рамз холӣ аст
// (бо рамз ворид шудан мумкин нест, то корбар худаш рамз нагузорад).
// Аватар холӣ мемонад: расми сервери бегонаро дар профил намегузорем.
func ssoCreateUser(ctx context.Context, u tsUser, email string) (string, error) {
	verified := u.EmailVerified != nil && *u.EmailVerified
	var emailArg any
	if email != "" && emailRe.MatchString(email) {
		emailArg = email
	} else {
		verified = false
	}
	fullName := clampRunes(strings.TrimSpace(u.Name), 100)
	var lastErr error
	for i := 0; i < 3; i++ {
		uname := ssoPickUsername(ctx, u.Name, email)
		var id string
		err := db.Pool.QueryRow(ctx, `
			INSERT INTO users(username, email, password, full_name, email_verified)
			VALUES ($1,$2,'',$3,$4) RETURNING id`,
			uname, emailArg, fullName, verified).Scan(&id)
		if err == nil {
			return id, nil
		}
		lastErr = err
		if !isUnique(err) {
			break
		}
	}
	return "", lastErr
}

func normEmail(e string) string { return strings.ToLower(strings.TrimSpace(e)) }

// ── POST /auth/sso/tajikshop {code, link?} ─────────────────────────

func TajikshopSSOLogin(c *gin.Context) {
	var b struct {
		Code string `json:"code"`
		Link bool   `json:"link"`
	}
	c.ShouldBindJSON(&b)
	code := strings.TrimSpace(b.Code)
	if !ssoConfigured() {
		ssoAudit(c, "login", mw.UID(c), "", "not_configured")
		ssoFail(c, ssoFailure{http.StatusServiceUnavailable, "sso_not_configured", msgSSONotConfigured})
		return
	}
	if !validSSOCode(code) {
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_code", "message": msgSSOInvalidCode})
		return
	}
	ctx := c.Request.Context()
	ex, err := tsExchangeCode(ctx, code)
	if err != nil {
		f := mapExchangeError(err)
		ssoAudit(c, "login", mw.UID(c), "", f.Code)
		ssoFail(c, f)
		return
	}
	extID := string(ex.User.ID)
	email := normEmail(ex.User.Email)
	name := clampRunes(strings.TrimSpace(ex.User.Name), 100)
	sealed, err := sealSSOToken(ex.RefreshToken)
	if err != nil {
		sealed = "" // бе token: гузариш ба TajikShop танҳо бе ворид
	}
	cur := mw.UID(c)

	link, err := ssoLinkByExt(ctx, extID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"code": "server_error", "message": "Хатои сервер"})
		return
	}

	// 1. Аллакай пайваст.
	if link != nil {
		if cur != "" && cur != link.UserID {
			ssoAudit(c, "login", cur, extID, "linked_other")
			ssoLinkErr(c, errSSOLinkedOther)
			return
		}
		db.Pool.Exec(ctx, `UPDATE external_accounts
			SET ext_name=$3, ext_email=$4,
			    ts_refresh_token=CASE WHEN $5='' THEN ts_refresh_token ELSE $5 END,
			    updated_at=NOW()
			WHERE provider=$1 AND external_id=$2`, ssoProvider, extID, name, email, sealed)
		if ssoIssueLogin(c, link.UserID, gin.H{"status": "logged_in", "needsProfileSetup": false,
			"tajikshop": ssoPublic(name, email, link.LinkedAt)}) {
			ssoAudit(c, "login", link.UserID, extID, "ok")
		} else {
			ssoAudit(c, "login", link.UserID, extID, "denied")
		}
		return
	}

	// 2. Корбар дар Raonson ворид аст.
	if cur != "" {
		if b.Link {
			if err := ssoLinkAccount(ctx, cur, extID, name, email, sealed); err != nil {
				ssoAudit(c, "link", cur, extID, "error")
				ssoLinkErr(c, err)
				return
			}
			ssoAudit(c, "link", cur, extID, "ok")
			c.JSON(http.StatusOK, gin.H{"status": "linked", "linked": true,
				"tajikshop": ssoPublic(name, email, time.Now())})
			return
		}
		tok, err := ssoCreatePending(ctx, extID, name, email, sealed)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"code": "server_error", "message": "Хатои сервер"})
			return
		}
		ssoAudit(c, "login", cur, extID, "confirm_link")
		c.JSON(http.StatusOK, gin.H{"status": "confirm_link", "pendingToken": tok,
			"expiresIn": int(ssoPendingTTL.Seconds()),
			"tajikshop": ssoPublic(name, email, time.Time{})})
		return
	}

	// 3. Почта аллакай дар Raonson — худкор пайваст НАМЕКУНЕМ.
	if email != "" {
		var exists bool
		db.Pool.QueryRow(ctx,
			`SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(email)=$1)`, email).Scan(&exists)
		if exists {
			tok, err := ssoCreatePending(ctx, extID, name, email, sealed)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"code": "server_error", "message": "Хатои сервер"})
				return
			}
			ssoAudit(c, "login", "", extID, "link_required")
			c.JSON(http.StatusConflict, gin.H{
				"code": "link_required",
				"message": "Ҳисоби Raonson бо ҳамин почта аллакай ҳаст. Барои пайваст кардан " +
					"як бор бо рамзи Raonson ворид шавед",
				"email":        maskEmailHint(email),
				"pendingToken": tok,
				"expiresIn":    int(ssoPendingTTL.Seconds()),
			})
			return
		}
	}

	// 4. Ҳисоби нав.
	uid, err := ssoCreateUser(ctx, ex.User, email)
	if err != nil {
		ssoAudit(c, "signup", "", extID, "error")
		c.JSON(http.StatusConflict, gin.H{"code": "signup_failed",
			"message": "Ҳисоб сохта нашуд. Баъдтар боз кӯшиш кунед"})
		return
	}
	if err := ssoLinkAccount(ctx, uid, extID, name, email, sealed); err != nil {
		// Пойга: ҳамин лаҳза дигар дархост пайваст кард — ҳисоби нави
		// холиро нест мекунем, то ҳисоби «ятим» намонад.
		db.Pool.Exec(ctx, `DELETE FROM users WHERE id=$1`, uid)
		ssoAudit(c, "signup", "", extID, "race")
		ssoLinkErr(c, err)
		return
	}
	if ssoIssueLogin(c, uid, gin.H{"status": "created", "needsProfileSetup": true,
		"tajikshop": ssoPublic(name, email, time.Now())}) {
		ssoAudit(c, "signup", uid, extID, "ok")
	}
}

// ── POST /auth/sso/tajikshop/link {pendingToken | code} (бо ворид) ─

func TajikshopSSOLink(c *gin.Context) {
	uid := mw.UID(c)
	var b struct {
		Code         string `json:"code"`
		PendingToken string `json:"pendingToken"`
	}
	c.ShouldBindJSON(&b)
	ctx := c.Request.Context()

	var extID, name, email, sealed string
	switch {
	case strings.TrimSpace(b.PendingToken) != "":
		var err error
		extID, name, email, sealed, err = ssoConsumePending(ctx, strings.TrimSpace(b.PendingToken))
		if err != nil {
			ssoAudit(c, "link", uid, "", "pending_invalid")
			c.JSON(http.StatusUnauthorized, gin.H{"code": "link_expired",
				"message": "Мӯҳлати тасдиқ гузашт. Аз TajikShop боз ба Raonson гузаред"})
			return
		}
	case strings.TrimSpace(b.Code) != "":
		if !ssoConfigured() {
			ssoFail(c, ssoFailure{http.StatusServiceUnavailable, "sso_not_configured", msgSSONotConfigured})
			return
		}
		code := strings.TrimSpace(b.Code)
		if !validSSOCode(code) {
			c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_code", "message": msgSSOInvalidCode})
			return
		}
		ex, err := tsExchangeCode(ctx, code)
		if err != nil {
			f := mapExchangeError(err)
			ssoAudit(c, "link", uid, "", f.Code)
			ssoFail(c, f)
			return
		}
		extID = string(ex.User.ID)
		name = clampRunes(strings.TrimSpace(ex.User.Name), 100)
		email = normEmail(ex.User.Email)
		sealed, _ = sealSSOToken(ex.RefreshToken)
	default:
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_code", "message": msgSSOInvalidCode})
		return
	}

	if err := ssoLinkAccount(ctx, uid, extID, name, email, sealed); err != nil {
		ssoAudit(c, "link", uid, extID, "error")
		ssoLinkErr(c, err)
		return
	}
	ssoAudit(c, "link", uid, extID, "ok")
	c.JSON(http.StatusOK, gin.H{"status": "linked", "linked": true,
		"tajikshop": ssoPublic(name, email, time.Now())})
}

// ── GET /sso/tajikshop/status ──────────────────────────────────────

func TajikshopSSOStatus(c *gin.Context) {
	uid := mw.UID(c)
	ctx := c.Request.Context()
	var hasPassword bool
	db.Pool.QueryRow(ctx, `SELECT COALESCE(password,'') <> '' FROM users WHERE id=$1`, uid).Scan(&hasPassword)
	link, err := ssoLinkByUser(ctx, uid)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои сервер"})
		return
	}
	out := gin.H{"configured": ssoConfigured(), "linked": link != nil,
		"hasPassword": hasPassword, "fallback": tajikshopFallback(), "tajikshop": nil}
	if link != nil {
		out["tajikshop"] = ssoPublic(link.Name, link.Email, link.LinkedAt)
		out["canOpenSignedIn"] = link.Sealed != ""
	}
	c.JSON(http.StatusOK, out)
}

// ── DELETE /sso/tajikshop/link ─────────────────────────────────────

func TajikshopSSOUnlink(c *gin.Context) {
	uid := mw.UID(c)
	ctx := c.Request.Context()
	var hasPassword bool
	db.Pool.QueryRow(ctx, `SELECT COALESCE(password,'') <> '' FROM users WHERE id=$1`, uid).Scan(&hasPassword)
	link, _ := ssoLinkByUser(ctx, uid)
	if link == nil {
		c.JSON(http.StatusOK, gin.H{"linked": false})
		return
	}
	// Ҳисоби аз TajikShop сохташуда рамз надорад: бе пайванд корбар ба он
	// ворид шуда наметавонад.
	if !hasPassword {
		c.JSON(http.StatusConflict, gin.H{"code": "password_required",
			"message": "Аввал рамз гузоред — вагарна баъди ҷудо кардан ба ҳисоб ворид шуда наметавонед"})
		return
	}
	if _, err := db.Pool.Exec(ctx, `DELETE FROM external_accounts WHERE provider=$1 AND user_id=$2`,
		ssoProvider, uid); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Ҷудо нашуд"})
		return
	}
	ssoAudit(c, "unlink", uid, link.ExtID, "ok")
	c.JSON(http.StatusOK, gin.H{"linked": false})
}

// ── POST /sso/tajikshop/handoff ────────────────────────────────────
//
// Ҳамеша deep_link медиҳад: бо код (корбар дар TajikShop фавран ворид)
// ё «tajikshop://» (TajikShop танҳо кушода мешавад).

func TajikshopSSOHandoff(c *gin.Context) {
	uid := mw.UID(c)
	ctx := c.Request.Context()
	fb := tajikshopFallback()
	plain := func(linked bool, reason string) {
		c.JSON(http.StatusOK, gin.H{"linked": linked, "handoff": false, "reason": reason,
			"deep_link": "tajikshop://", "fallback": fb})
	}
	link, err := ssoLinkByUser(ctx, uid)
	if err != nil || link == nil {
		plain(false, "not_linked")
		return
	}
	refresh, err := openSSOToken(link.Sealed)
	if err != nil || refresh == "" {
		plain(true, "session_expired")
		return
	}
	access, newRefresh, err := tsRefresh(ctx, refresh)
	if err != nil {
		st := tsErrStatus(err)
		if st == http.StatusUnauthorized || st == http.StatusForbidden {
			// Сессияи TajikShop бекор шуд (баромад, рамзро иваз кард).
			db.Pool.Exec(ctx, `UPDATE external_accounts SET ts_refresh_token='', updated_at=NOW()
				WHERE provider=$1 AND user_id=$2`, ssoProvider, uid)
			ssoAudit(c, "handoff", uid, link.ExtID, "session_expired")
			plain(true, "session_expired")
			return
		}
		ssoAudit(c, "handoff", uid, link.ExtID, "provider_unavailable")
		plain(true, "provider_unavailable")
		return
	}
	if newRefresh != "" && newRefresh != refresh {
		if s, err := sealSSOToken(newRefresh); err == nil {
			db.Pool.Exec(ctx, `UPDATE external_accounts SET ts_refresh_token=$3, updated_at=NOW()
				WHERE provider=$1 AND user_id=$2`, ssoProvider, uid, s)
		}
	}
	deepLink, fallback, err := tsIssueCode(ctx, access)
	if err != nil {
		ssoAudit(c, "handoff", uid, link.ExtID, "code_failed")
		plain(true, "provider_unavailable")
		return
	}
	ssoAudit(c, "handoff", uid, link.ExtID, "ok")
	c.JSON(http.StatusOK, gin.H{"linked": true, "handoff": true,
		"deep_link": deepLink, "fallback": fallback})
}
