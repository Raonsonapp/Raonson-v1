package handlers

// ══════════════════════════════════════════════════════════════════
//  Барқарорсозии ҳисоб — «Рамзро фаромӯш кардед?» (мисли Instagram).
//
//  Қадамҳо:
//    1. POST /auth/recover/lookup  {identifier}
//         → «Ин шумоед?»: номи корбари пӯшида, акс ва роҳҳое, ки ҳисоб
//           ҲОЗИР рамз гирифта метавонад (почта; SMS/Telegram/WhatsApp
//           танҳо агар провайдер танзим бошад).
//    2. POST /auth/recover/send    {identifier, channel}
//         → рамзи 6-рақама (10 дақ, 5 кӯшиш, 60 с байни фиристодан,
//           то 3 бор дар 15 дақ).
//    3. POST /auth/recover/verify  {identifier, code}
//         → token-и якдафъаина (32 байт, 15 дақ). Дар база танҳо hash.
//    4. POST /auth/recover/reset   {token, newPassword}
//         → рамз иваз, ҲАМАИ сессияҳо бекор, token нест, огоҳинома ва
//           почта, ва token-ҳои нав — корбар фавран ворид мешавад.
//    5. POST /auth/recover/request — «Кӯмак лозим»: вақте ҳеҷ роҳ
//         дастрас нест. Admin тасдиқ мекунад → рамзи якдафъаина (24 соат)
//         ба почтаи тамос меравад. Admin паролро намебинад ва гузошта
//         наметавонад.
//
//  Чаро «ҳисоби дуруст» кафолат дорад:
//    • пеш `WHERE email=$1 OR phone=$1 OR username=$1` + QueryRow яке аз
//      чанд ҳисобро тасодуфан мегирифт — рамз ба каси дигар мерафт;
//    • акнун: номи корбари аниқ → почтаи тасдиқшуда → почта → телефон
//      (E.164). Агар дар як зина зиёда аз як ҳисоб бошад — номи корбар
//      пурсида мешавад, на тахмин.
// ══════════════════════════════════════════════════════════════════

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/utils"
)

const (
	recoverCodeTTL    = 10 * time.Minute
	recoverResendGap  = 60 * time.Second
	recoverMaxSends   = 3
	recoverSendWindow = 15 * time.Minute
	resetTokenTTL     = 15 * time.Minute
	helpTokenTTL      = 24 * time.Hour
	lookupMinDuration = 400 * time.Millisecond

	purposeOTP       = "otp"
	purposeAdminHelp = "admin_help"
)

// otpEcho — рамз дар ҷавоб ТАНҲО дар муҳити санҷиш (OTP_ECHO=1 ва на
// release). Дар продакшн ҳеҷ гоҳ.
func otpEcho() bool {
	return os.Getenv("OTP_ECHO") == "1" && gin.Mode() != gin.ReleaseMode
}

// rlMult — ҳадҳои аз рӯи IP дар сервери санҷишӣ васеъ мешаванд (мисли
// mw.RateLimit). Ҳадҳои аз рӯи ҲИСОБ ва идентификатор тағйир намеёбанд.
func rlMult() int {
	if m, err := strconv.Atoi(os.Getenv("RATE_LIMIT_MULTIPLIER")); err == nil && m > 1 {
		return m
	}
	return 1
}

func recoverOTPKey(uid string) string { return "otp:recover:" + uid }

// ── Ба як шакл овардан ──────────────────────────────────────────────

// normalizePhone рақамро ба E.164 меорад: «+992 90 011 22 33»,
// «992900112233», «00992900112233», «900112233» (маҳаллии Тоҷикистон)
// → «+992900112233». ok=false — агар ин рақами телефон набошад.
func normalizePhone(raw string) (string, bool) {
	s := strings.TrimSpace(raw)
	if s == "" {
		return "", false
	}
	plus := false
	var d strings.Builder
	for i, r := range s {
		switch {
		case r >= '0' && r <= '9':
			d.WriteRune(r)
		case r == '+' && i == 0:
			plus = true
		case r == ' ' || r == '-' || r == '(' || r == ')' || r == '.' || r == ' ':
			// ҷудокунанда
		default:
			return "", false
		}
	}
	digits := d.String()
	if !plus && strings.HasPrefix(digits, "00") {
		digits = digits[2:]
		plus = true
	}
	if !plus {
		switch {
		case len(digits) == 9: // 90 011 22 33 — рақами маҳаллии ТҶ
			digits = "992" + digits
		case len(digits) == 10 && digits[0] == '0': // 0 90 011 22 33
			digits = "992" + digits[1:]
		}
	}
	if len(digits) < 10 || len(digits) > 15 || digits[0] == '0' {
		return "", false
	}
	return "+" + digits, true
}

// phoneDigitVariants — шаклҳое, ки рақам дар база (бе аломатҳо) дошта
// метавонад. Дар база рақамҳо бо шаклҳои гуногун навишта шудаанд.
func phoneDigitVariants(e164 string) []string {
	d := strings.TrimPrefix(e164, "+")
	out := []string{d, "00" + d}
	if strings.HasPrefix(d, "992") && len(d) == 12 {
		out = append(out, d[3:], "0"+d[3:])
	}
	return out
}

type recoverIdent struct {
	Raw      string
	Username string
	Email    string
	Phones   []string
}

// parseRecoverIdent — вуруди корбар: номи корбар, почта ё телефон.
func parseRecoverIdent(raw string) recoverIdent {
	s := normalizeLoginID(raw)
	id := recoverIdent{Raw: s, Phones: []string{}}
	if s == "" || utf8.RuneCountInString(s) > 254 {
		id.Raw = ""
		return id
	}
	if usernameRe.MatchString(s) {
		id.Username = s
	}
	if strings.Contains(s, "@") && emailRe.MatchString(s) {
		id.Email = s
	}
	if e, ok := normalizePhone(s); ok {
		id.Phones = phoneDigitVariants(e)
	}
	return id
}

func (i recoverIdent) empty() bool {
	return i.Username == "" && i.Email == "" && len(i.Phones) == 0
}

// ── Ёфтани ҳисоб ────────────────────────────────────────────────────

type recoverCandidate struct {
	ID, Username, Email, Phone, Avatar, FullName string
	EmailVerified, Banned                        bool
	ByUsername, ByEmail, ByPhone                 bool
}

// pickRecoverAccount — аз номзадҳо ДАҚИҚАН як ҳисоб.
//
// Тартиб: номи корбар → почтаи тасдиқшуда → почтаи тасдиқнашуда →
// телефон. Зинаи аввале, ки ягон мувофиқат дорад, ҳал мекунад: як —
// ҳамон ҳисоб; зиёда — номуайян (номи корбарро мепурсем).
func pickRecoverAccount(cands []recoverCandidate) (*recoverCandidate, bool) {
	var byUser, byVerified, byEmail, byPhone []int
	for i, c := range cands {
		if c.ByUsername {
			byUser = append(byUser, i)
		}
		if c.ByEmail && c.EmailVerified {
			byVerified = append(byVerified, i)
		}
		if c.ByEmail && !c.EmailVerified {
			byEmail = append(byEmail, i)
		}
		if c.ByPhone {
			byPhone = append(byPhone, i)
		}
	}
	for _, g := range [][]int{byUser, byVerified, byEmail, byPhone} {
		switch {
		case len(g) == 1:
			return &cands[g[0]], false
		case len(g) > 1:
			return nil, true
		}
	}
	return nil, false
}

// findRecoverAccount — ҳисобро ёфта, ҳисоби басташударо «нест» меҳисобад.
func findRecoverAccount(ctx context.Context, id recoverIdent) (*recoverCandidate, bool, error) {
	if id.empty() || db.Pool == nil {
		return nil, false, nil
	}
	rows, err := db.Pool.Query(ctx, `
		SELECT id, username, COALESCE(email,''), COALESCE(email_verified,false),
		       COALESCE(phone,''), COALESCE(avatar,''), COALESCE(full_name,''),
		       COALESCE(banned,false),
		       COALESCE($1 <> '' AND LOWER(username) = $1, false),
		       COALESCE($2 <> '' AND LOWER(email) = $2, false),
		       COALESCE(regexp_replace(phone, '\D', '', 'g') = ANY($3::text[]), false)
		  FROM users
		 WHERE ($1 <> '' AND LOWER(username) = $1)
		    OR ($2 <> '' AND LOWER(email) = $2)
		    OR regexp_replace(phone, '\D', '', 'g') = ANY($3::text[])
		 LIMIT 20`, id.Username, id.Email, id.Phones)
	if err != nil {
		return nil, false, err
	}
	defer rows.Close()
	var cands []recoverCandidate
	for rows.Next() {
		var c recoverCandidate
		if err := rows.Scan(&c.ID, &c.Username, &c.Email, &c.EmailVerified,
			&c.Phone, &c.Avatar, &c.FullName, &c.Banned,
			&c.ByUsername, &c.ByEmail, &c.ByPhone); err != nil {
			return nil, false, err
		}
		cands = append(cands, c)
	}
	if err := rows.Err(); err != nil {
		return nil, false, err
	}
	acc, amb := pickRecoverAccount(cands)
	if acc != nil && acc.Banned {
		return nil, false, nil
	}
	return acc, amb, nil
}

// ── Пӯшонидан ───────────────────────────────────────────────────────

func stars(n int) string {
	if n < 1 {
		n = 1
	}
	return strings.Repeat("*", n)
}

// maskUsername — «ehsonmurod» → «eh*******d».
func maskUsername(u string) string {
	r := []rune(u)
	switch n := len(r); {
	case n == 0:
		return ""
	case n <= 2:
		return string(r[0]) + "*"
	case n <= 4:
		return string(r[0]) + stars(n-2) + string(r[n-1])
	default:
		return string(r[:2]) + stars(n-3) + string(r[n-1])
	}
}

// maskEmailHint — «ehson@gmail.com» → «e***n@gmail.com».
func maskEmailHint(email string) string {
	at := strings.LastIndex(email, "@")
	if at < 1 {
		return "***"
	}
	local := []rune(email[:at])
	if len(local) <= 2 {
		return string(local[0]) + "***" + email[at:]
	}
	return string(local[0]) + "***" + string(local[len(local)-1]) + email[at:]
}

// maskPhoneHint — «+992900112233» → «+992 *** ** 33». Танҳо коди кишвар
// ва ду рақами охир — utils.MaskPhone қариб тамоми рақамро нишон медод.
func maskPhoneHint(e164 string) string {
	if len(e164) < 8 {
		return "***"
	}
	return e164[:4] + " *** ** " + e164[len(e164)-2:]
}

// ── Каналҳо ─────────────────────────────────────────────────────────

type recoverChannel struct {
	Type string `json:"type"` // email | sms | telegram | whatsapp
	To   string `json:"to"`
}

// availableChannels — роҳҳое, ки ҳисоб ҲОЗИР рамз гирифта метавонад.
func availableChannels(c *recoverCandidate, ready map[string]bool, echo bool) []recoverChannel {
	out := []recoverChannel{}
	if c == nil {
		return out
	}
	if c.Email != "" && (ready["email"] || echo) {
		out = append(out, recoverChannel{"email", maskEmailHint(c.Email)})
	}
	if e, ok := normalizePhone(c.Phone); ok {
		for _, ch := range []string{"sms", "telegram", "whatsapp"} {
			if ready[ch] {
				out = append(out, recoverChannel{ch, maskPhoneHint(e)})
			}
		}
	}
	return out
}

func deliverRecoverCode(c *recoverCandidate, channel, otp string) error {
	switch channel {
	case "email":
		return utils.SendEmailOTP(c.Email, otp)
	}
	e, ok := normalizePhone(c.Phone)
	if !ok {
		return fmt.Errorf("no phone")
	}
	switch channel {
	case "sms":
		return utils.SendSMSOTP(e, otp)
	case "telegram":
		return utils.SendTelegramOTP(e, otp)
	case "whatsapp":
		return utils.SendWhatsAppOTP(e, otp)
	}
	return fmt.Errorf("unknown channel %q", channel)
}

// sendRecoverCode — рамзро бо ҳамаи ҳадҳо мефиристад. fallback=true:
// агар канали дархостшуда набошад, аввалин канали дастрас (барои
// версияҳои кӯҳнаи барнома).
func sendRecoverCode(c *recoverCandidate, channel string, fallback bool) (int, gin.H) {
	chans := availableChannels(c, utils.OTPChannelsReady(), otpEcho())
	if len(chans) == 0 {
		return http.StatusUnprocessableEntity, gin.H{"code": "no_channel",
			"message": "Барои ин ҳисоб роҳи фиристодани рамз нест. «Кӯмак лозим»-ро интихоб кунед."}
	}
	var picked *recoverChannel
	for i := range chans {
		if chans[i].Type == channel {
			picked = &chans[i]
			break
		}
	}
	if picked == nil {
		if !fallback && channel != "" {
			return http.StatusBadRequest, gin.H{"code": "channel_unavailable",
				"message": "Ин роҳ барои ҳисоби шумо дастрас нест"}
		}
		picked = &chans[0]
	}

	lastKey := "recover:last:" + c.ID
	if v, ok := mw.CacheGet(lastKey); ok {
		if ts, err := strconv.ParseInt(string(v), 10, 64); err == nil {
			left := recoverResendGap - time.Since(time.Unix(0, ts))
			if left > 0 {
				secs := int(left.Seconds()) + 1
				return http.StatusTooManyRequests, gin.H{"code": "cooldown",
					"retryAfter": secs,
					"message":    fmt.Sprintf("Рамзи навро баъди %d сония фиристодан мумкин аст", secs)}
			}
		}
	}
	if !otpSendAllowed("recover:"+c.ID, recoverMaxSends, recoverSendWindow) {
		return http.StatusTooManyRequests, gin.H{"code": "too_many",
			"retryAfter": int(recoverSendWindow.Seconds()),
			"message":    "Рамз чанд бор фиристода шуд. 15 дақиқа интизор шавед."}
	}

	otp := secureOTP()
	key := recoverOTPKey(c.ID)
	storeOTP(key, otp, recoverCodeTTL)
	mw.CacheSet(lastKey, []byte(strconv.FormatInt(time.Now().UnixNano(), 10)), recoverResendGap)

	if err := deliverRecoverCode(c, picked.Type, otp); err != nil {
		// Рамз ҳеҷ гоҳ ба log намеравад — танҳо хатои провайдер.
		log.Printf("[recover] send via %s failed: %v", picked.Type, err)
		if !otpEcho() {
			mw.CacheDel(key, lastKey)
			return http.StatusBadGateway, gin.H{"code": "send_failed",
				"message": "Рамз фиристода нашуд. Дертар кӯшиш кунед ё роҳи дигарро интихоб кунед."}
		}
	}
	resp := gin.H{
		"sent": true, "channel": picked.Type, "to": picked.To,
		"resendIn":  int(recoverResendGap.Seconds()),
		"expiresIn": int(recoverCodeTTL.Seconds()),
		"message":   "Рамз фиристода шуд",
	}
	if otpEcho() {
		resp["otp"] = otp
	}
	return http.StatusOK, resp
}

// ── Token-и барқарорсозӣ ────────────────────────────────────────────

var (
	errResetTokenInvalid = errors.New("reset token invalid")
	errResetBanned       = errors.New("account banned")
)

const helpCodeAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" // бе 0/O, 1/I/L

// genHelpCode — рамзи 12-аломата барои дархости тасдиқшуда (≈59 бит):
// корбар онро аз почта нусха мекунад, бинобар ин кӯтоҳ аст.
func genHelpCode() (string, error) {
	var b strings.Builder
	max := big.NewInt(int64(len(helpCodeAlphabet)))
	for i := 0; i < 12; i++ {
		n, err := rand.Int(rand.Reader, max)
		if err != nil {
			return "", err
		}
		b.WriteByte(helpCodeAlphabet[n.Int64()])
	}
	return b.String(), nil
}

func formatHelpCode(code string) string {
	if len(code) != 12 {
		return code
	}
	return code[:4] + "-" + code[4:8] + "-" + code[8:]
}

// canonicalResetToken — «abcd-efgh-jkmn» ва «ABCDEFGHJKMN» як рамзанд.
// Token-и дарози base64 бетағйир мемонад.
func canonicalResetToken(t string) string {
	t = strings.TrimSpace(t)
	c := strings.ToUpper(strings.NewReplacer("-", "", " ", "").Replace(t))
	if len(c) == 12 {
		ok := true
		for _, r := range c {
			if !strings.ContainsRune(helpCodeAlphabet, r) {
				ok = false
				break
			}
		}
		if ok {
			return c
		}
	}
	return t
}

func hashResetToken(t string) string {
	sum := sha256.Sum256([]byte(canonicalResetToken(t)))
	return hex.EncodeToString(sum[:])
}

// issueResetToken — token-и нав; token-ҳои истифоданашудаи ҳамин мақсад
// бекор мешаванд (танҳо охиринаш кор мекунад).
func issueResetToken(ctx context.Context, uid, purpose string, ttl time.Duration, createdBy string) (string, error) {
	var token string
	if purpose == purposeAdminHelp {
		c, err := genHelpCode()
		if err != nil {
			return "", err
		}
		token = c
	} else {
		b := make([]byte, 32)
		if _, err := rand.Read(b); err != nil {
			return "", err
		}
		token = base64.RawURLEncoding.EncodeToString(b)
	}
	db.Pool.Exec(ctx, `DELETE FROM password_reset_tokens
		WHERE expires_at < NOW() - INTERVAL '1 day'`)
	if _, err := db.Pool.Exec(ctx, `DELETE FROM password_reset_tokens
		WHERE user_id=$1 AND purpose=$2 AND used_at IS NULL`, uid, purpose); err != nil {
		return "", err
	}
	if _, err := db.Pool.Exec(ctx, `
		INSERT INTO password_reset_tokens(token_hash, user_id, purpose, expires_at, created_by)
		VALUES($1,$2,$3, NOW() + make_interval(secs => $4), $5)`,
		hashResetToken(token), uid, purpose, int(ttl.Seconds()), createdBy); err != nil {
		return "", err
	}
	return token, nil
}

// completeReset — token-ро як бор истифода мебарад ва рамзро иваз мекунад.
// Ҳама дар як транзаксия: token сӯхт ⇔ рамз иваз шуд ⇔ ҳамаи сессияҳо
// (token_version) бекор шуданд ⇔ дигар token-ҳои ҳисоб нест шуданд.
func completeReset(ctx context.Context, token, newPassword string) (string, error) {
	if strings.TrimSpace(token) == "" {
		return "", errResetTokenInvalid
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 10)
	if err != nil {
		return "", err
	}
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	var uid string
	var banned bool
	err = tx.QueryRow(ctx, `
		UPDATE password_reset_tokens t SET used_at = NOW()
		  FROM users u
		 WHERE t.token_hash = $1 AND t.used_at IS NULL AND t.expires_at > NOW()
		   AND u.id = t.user_id
		RETURNING t.user_id, COALESCE(u.banned,false)`, hashResetToken(token)).Scan(&uid, &banned)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", errResetTokenInvalid
	}
	if err != nil {
		return "", err
	}
	if banned {
		return "", errResetBanned // rollback: token намесӯзад
	}
	if _, err := tx.Exec(ctx, `
		UPDATE users SET password=$1, token_version = COALESCE(token_version,0) + 1,
		       updated_at = NOW()
		 WHERE id=$2`, string(hash), uid); err != nil {
		return "", err
	}
	if _, err := tx.Exec(ctx,
		`DELETE FROM password_reset_tokens WHERE user_id=$1`, uid); err != nil {
		return "", err
	}
	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	mw.ForgetTokenState(uid)
	mw.CacheDel(recoverOTPKey(uid), "recover:last:"+uid)
	return uid, nil
}

// passwordProblem — қоидаҳои рамз (ҳамон барои сабти ном, ивазкунӣ ва
// барқарорсозӣ). "" — рамз мувофиқ аст.
func passwordProblem(pw string) string {
	switch {
	case utf8.RuneCountInString(pw) < 8:
		return "Рамз ҳадди аққал 8 аломат бошад"
	case len(pw) > 72:
		return "Рамз хеле дароз аст (то 72 аломат)"
	case strings.TrimSpace(pw) == "":
		return "Рамз холӣ буда наметавонад"
	}
	return ""
}

// notifyPasswordChanged — огоҳинома дар барнома + мактуб ба почта.
func notifyPasswordChanged(uid, username, email string) {
	go func() {
		db.Pool.Exec(context.Background(), `
			INSERT INTO notifications(user_id, from_user_id, type, target_id)
			VALUES($1,$1,'password_changed','')`, uid)
		if email == "" {
			return
		}
		ctx, cancel := context.WithTimeout(context.Background(), utils.EmailTimeout)
		defer cancel()
		body := fmt.Sprintf("Салом, @%s!\n\n"+
			"Рамзи ҳисоби Раонсони шумо %s (UTC) иваз карда шуд. "+
			"Ҳамаи дастгоҳҳои дигар аз ҳисоб хориҷ карда шуданд.\n\n"+
			"Агар ин шумо набудед, фавран дар барнома «Рамзро фаромӯш кардед?»-ро "+
			"интихоб кунед ва рамзро иваз кунед.\n\n— Раонсон",
			username, time.Now().UTC().Format("2006-01-02 15:04"))
		if _, err := utils.SendEmailDetailed(ctx, email,
			"Рамзи Раонсони шумо иваз шуд", body); err != nil {
			log.Printf("[recover] password-changed email failed: %v", err)
		}
	}()
}

func sendEmailAsync(to, subject, body string) {
	if to == "" {
		return
	}
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), utils.EmailTimeout)
		defer cancel()
		if _, err := utils.SendEmailDetailed(ctx, to, subject, body); err != nil {
			log.Printf("[recover] email failed: %v", err)
		}
	}()
}

// loginResponse — token-ҳои нав ва маълумоти корбар (мисли /auth/login).
func loginResponse(c *gin.Context, uid string) (gin.H, string, string) {
	var username, email, avatar, fullName string
	db.Pool.QueryRow(context.Background(), `
		SELECT username, COALESCE(email,''), COALESCE(avatar,''), COALESCE(full_name,'')
		  FROM users WHERE id=$1`, uid).Scan(&username, &email, &avatar, &fullName)
	recordLogin(uid, c)
	return gin.H{
		"accessToken":  makeJWT(uid, mw.JWTSecret(), 1*time.Hour),
		"refreshToken": makeJWT(uid, mw.RefreshSecret(), 30*24*time.Hour),
		"user": gin.H{
			"id": uid, "username": username, "email": email,
			"avatar": avatar, "fullName": fullName,
		},
	}, username, email
}

func tooMany(c *gin.Context, msg string) {
	if msg == "" {
		msg = "Кӯшишҳо зиёд шуданд. Баъдтар боз кӯшиш кунед."
	}
	c.JSON(http.StatusTooManyRequests, gin.H{"code": "rate_limited", "message": msg})
}

func needUsername(c *gin.Context) {
	c.JSON(http.StatusConflict, gin.H{"code": "need_username",
		"message": "Бо ин маълумот якчанд ҳисоб ҳаст. Номи корбарро ворид кунед."})
}

// randomDelay — то ҷавоби «ҳисоб нест» аз рӯи вақт фарқ накунад.
func randomDelay(minMs, spanMs int64) {
	n, _ := rand.Int(rand.Reader, big.NewInt(spanMs))
	time.Sleep(time.Duration(minMs+n.Int64()) * time.Millisecond)
}

// ══════════════════════════════════════════════════════════════════
//  Handlers
// ══════════════════════════════════════════════════════════════════

// POST /auth/recover/lookup {identifier}
func RecoverLookup(c *gin.Context) {
	start := time.Now()
	var b struct {
		Identifier string `json:"identifier"`
	}
	c.ShouldBindJSON(&b)
	id := parseRecoverIdent(b.Identifier)
	if id.Raw == "" {
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_identifier",
			"message": "Номи корбар, почта ё рақами телефонро ворид кунед"})
		return
	}
	if bump("rl:rlookup:ip:"+c.ClientIP(), 15*time.Minute) > 40*rlMult() ||
		bump("rl:rlookup:id:"+id.Raw, 15*time.Minute) > 10 {
		tooMany(c, "Кӯшишҳо зиёд шуданд. 15 дақиқа интизор шавед.")
		return
	}

	acc, amb, err := findRecoverAccount(c.Request.Context(), id)
	if err != nil {
		log.Printf("[recover] lookup: %v", err)
	}
	if acc != nil && bump("rl:rlookup:acct:"+acc.ID, 15*time.Minute) > 15 {
		tooMany(c, "Кӯшишҳо зиёд шуданд. 15 дақиқа интизор шавед.")
		return
	}

	// Шакли ҷавоб ҳамеша як хел.
	resp := gin.H{
		"found": false, "needUsername": false, "account": nil,
		"channels": []recoverChannel{}, "canRequestHelp": true,
		"message": "Ҳисоб ёфт нашуд. Маълумотро санҷед.",
	}
	switch {
	case amb:
		resp["needUsername"] = true
		resp["message"] = "Бо ин маълумот якчанд ҳисоб ҳаст. Номи корбарро ворид кунед."
	case acc != nil:
		chans := availableChannels(acc, utils.OTPChannelsReady(), otpEcho())
		resp["found"] = true
		resp["account"] = gin.H{"username": maskUsername(acc.Username), "avatar": acc.Avatar}
		resp["channels"] = chans
		resp["message"] = "Ин шумоед?"
		if len(chans) == 0 {
			resp["message"] = "Барои ин ҳисоб роҳи фиристодани рамз нест. «Кӯмак лозим»-ро интихоб кунед."
		}
	}
	// Вақти ҷавоб аз натиҷа вобаста нест.
	if wait := lookupMinDuration - time.Since(start); wait > 0 {
		time.Sleep(wait)
	}
	randomDelay(0, 100)
	c.JSON(http.StatusOK, resp)
}

// POST /auth/recover/send {identifier, channel}
func RecoverSend(c *gin.Context) {
	var b struct {
		Identifier string `json:"identifier"`
		Channel    string `json:"channel"`
	}
	c.ShouldBindJSON(&b)
	id := parseRecoverIdent(b.Identifier)
	if id.Raw == "" {
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_identifier",
			"message": "Номи корбар, почта ё рақами телефонро ворид кунед"})
		return
	}
	if bump("rl:rsend:ip:"+c.ClientIP(), 15*time.Minute) > 20*rlMult() {
		tooMany(c, "")
		return
	}
	acc, amb, err := findRecoverAccount(c.Request.Context(), id)
	if err != nil {
		log.Printf("[recover] send lookup: %v", err)
	}
	if amb {
		needUsername(c)
		return
	}
	if acc == nil {
		randomDelay(300, 400)
		c.JSON(http.StatusOK, gin.H{"sent": true, "channel": b.Channel, "to": "",
			"resendIn":  int(recoverResendGap.Seconds()),
			"expiresIn": int(recoverCodeTTL.Seconds()), "message": "Рамз фиристода шуд"})
		return
	}
	st, resp := sendRecoverCode(acc, strings.ToLower(strings.TrimSpace(b.Channel)), false)
	c.JSON(st, resp)
}

// POST /auth/recover/verify {identifier, code} → {resetToken}
func RecoverVerify(c *gin.Context) {
	var b struct {
		Identifier string `json:"identifier"`
		Code       string `json:"code"`
		OTP        string `json:"otp"`
	}
	c.ShouldBindJSON(&b)
	if b.Code == "" {
		b.Code = b.OTP
	}
	id := parseRecoverIdent(b.Identifier)
	code := strings.TrimSpace(b.Code)
	if id.Raw == "" || code == "" {
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_code", "message": "Рамзро ворид кунед"})
		return
	}
	if bump("rl:rverify:ip:"+c.ClientIP(), 15*time.Minute) > 30*rlMult() {
		tooMany(c, "")
		return
	}
	acc, amb, err := findRecoverAccount(c.Request.Context(), id)
	if err != nil {
		log.Printf("[recover] verify lookup: %v", err)
	}
	if amb {
		needUsername(c)
		return
	}
	expired := gin.H{"code": "expired", "message": "Рамз гузашт, нав фиристед"}
	if acc == nil {
		c.JSON(http.StatusGone, expired)
		return
	}
	status, left := checkOTPDetailed(recoverOTPKey(acc.ID), code)
	switch status {
	case otpMissing:
		c.JSON(http.StatusGone, expired)
		return
	case otpLocked:
		c.JSON(http.StatusTooManyRequests, gin.H{"code": "locked",
			"message": "Кӯшишҳо зиёд шуданд. Рамзи нав фиристед."})
		return
	case otpWrong:
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_code",
			"message": "Рамз нодуруст", "attemptsLeft": left})
		return
	}
	token, err := issueResetToken(c.Request.Context(), acc.ID, purposeOTP, resetTokenTTL, "")
	if err != nil {
		log.Printf("[recover] issue token: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои дохилӣ. Боз кӯшиш кунед."})
		return
	}
	c.JSON(http.StatusOK, gin.H{"resetToken": token,
		"expiresIn": int(resetTokenTTL.Seconds())})
}

// POST /auth/recover/reset {token, newPassword} → token-ҳои нав
func RecoverReset(c *gin.Context) {
	var b struct {
		Token       string `json:"token"`
		NewPassword string `json:"newPassword"`
	}
	c.ShouldBindJSON(&b)
	if bump("rl:rreset:ip:"+c.ClientIP(), 15*time.Minute) > 20*rlMult() {
		tooMany(c, "")
		return
	}
	if msg := passwordProblem(b.NewPassword); msg != "" {
		c.JSON(http.StatusBadRequest, gin.H{"code": "weak_password", "message": msg})
		return
	}
	uid, err := completeReset(c.Request.Context(), b.Token, b.NewPassword)
	switch {
	case errors.Is(err, errResetTokenInvalid):
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_token",
			"message": "Рамз ё линк нодуруст ё мӯҳлаташ гузаштааст. Аз нав оғоз кунед."})
		return
	case errors.Is(err, errResetBanned):
		c.JSON(http.StatusForbidden, gin.H{"message": "Ҳисоби шумо баста шудааст"})
		return
	case err != nil:
		log.Printf("[recover] reset: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Рамз иваз нашуд. Боз кӯшиш кунед."})
		return
	}
	resp, username, email := loginResponse(c, uid)
	notifyPasswordChanged(uid, username, email)
	resp["success"] = true
	resp["message"] = "Рамз иваз шуд"
	c.JSON(http.StatusOK, resp)
}

// POST /auth/recover/request {identifier, contactEmail, fullName, message}
func RecoverRequestHelp(c *gin.Context) {
	var b struct {
		Identifier   string `json:"identifier"`
		ContactEmail string `json:"contactEmail"`
		FullName     string `json:"fullName"`
		Message      string `json:"message"`
	}
	c.ShouldBindJSON(&b)
	id := parseRecoverIdent(b.Identifier)
	contact := strings.ToLower(strings.TrimSpace(b.ContactEmail))
	fullName := strings.TrimSpace(b.FullName)
	msg := clampRunes(strings.TrimSpace(b.Message), 1000)
	switch {
	case id.Raw == "":
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_identifier",
			"message": "Номи корбар, почта ё рақами телефонро ворид кунед"})
		return
	case !emailRe.MatchString(contact) || len(contact) > 254:
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_email",
			"message": "Почтаи тамос нодуруст аст"})
		return
	case utf8.RuneCountInString(fullName) < 2 || utf8.RuneCountInString(fullName) > 100:
		c.JSON(http.StatusBadRequest, gin.H{"code": "invalid_name",
			"message": "Ному насабро ворид кунед"})
		return
	}
	if bump("rl:rhelp:ip:"+c.ClientIP(), time.Hour) > 5*rlMult() ||
		bump("rl:rhelp:mail:"+contact, 24*time.Hour) > 3 {
		tooMany(c, "Дархостҳо зиёд шуданд. Баъдтар боз кӯшиш кунед.")
		return
	}
	acc, amb, err := findRecoverAccount(c.Request.Context(), id)
	if err != nil {
		log.Printf("[recover] help lookup: %v", err)
	}
	if amb {
		needUsername(c)
		return
	}
	done := gin.H{"submitted": true, "alreadyPending": false,
		"message": "Дархост қабул шуд. Ҷавоб ба почтаи тамоси шумо меояд."}
	if acc == nil {
		// Ҳисоб нест — ҳамон ҷавоб, вале чизе сабт намешавад.
		randomDelay(100, 200)
		c.JSON(http.StatusOK, done)
		return
	}
	var reqID string
	err = db.Pool.QueryRow(c.Request.Context(), `
		INSERT INTO account_recovery_requests(user_id, identifier, contact_email, full_name, message, ip)
		VALUES($1,$2,$3,$4,$5,$6)
		ON CONFLICT (user_id) WHERE status = 'pending' DO NOTHING
		RETURNING id`, acc.ID, clampRunes(id.Raw, 254), contact, fullName, msg, c.ClientIP()).Scan(&reqID)
	if errors.Is(err, pgx.ErrNoRows) {
		done["alreadyPending"] = true
		done["message"] = "Дархости шумо аллакай баррасӣ мешавад. Ҷавоб ба почтаи тамос меояд."
		c.JSON(http.StatusOK, done)
		return
	}
	if err != nil {
		log.Printf("[recover] help insert: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Дархост сабт нашуд. Боз кӯшиш кунед."})
		return
	}
	// Соҳиби ҳисоб (агар ба почтааш дастрасӣ дошта бошад) огоҳ мешавад.
	if acc.Email != "" && !strings.EqualFold(acc.Email, contact) {
		sendEmailAsync(acc.Email, "Раонсон — дархости барқарорсозии ҳисоб",
			fmt.Sprintf("Салом, @%s!\n\nБарои ҳисоби шумо дархости барқарорсозӣ "+
				"фиристода шуд. Агар ин шумо набудед, ин мактубро нодида гиред — "+
				"бе тасдиқи маъмурият ҳеҷ чиз тағйир намеёбад.\n\n— Раонсон", acc.Username))
	}
	c.JSON(http.StatusOK, done)
}

// GET /auth/recovery-status — Танзимот → Амният: почта ва телефон.
func RecoveryStatus(c *gin.Context) {
	uid := mw.UID(c)
	var email, phone string
	var verified bool
	if err := db.Pool.QueryRow(c.Request.Context(), `
		SELECT COALESCE(email,''), COALESCE(email_verified,false), COALESCE(phone,'')
		  FROM users WHERE id=$1`, uid).Scan(&email, &verified, &phone); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	ready := utils.OTPChannelsReady()
	phoneChannels := []string{}
	for _, ch := range []string{"sms", "telegram", "whatsapp"} {
		if ready[ch] {
			phoneChannels = append(phoneChannels, ch)
		}
	}
	_, phoneOK := normalizePhone(phone)
	c.JSON(http.StatusOK, gin.H{
		"email": email, "emailVerified": email != "" && verified,
		"phone": phone, "hasPhone": phoneOK,
		"emailReady": ready["email"], "phoneChannels": phoneChannels,
		"needsEmail": !(email != "" && verified),
	})
}

// ── Admin ───────────────────────────────────────────────────────────

// GET /admin/recovery-requests?status=pending|approved|rejected|all
func AdminListRecoveryRequests(c *gin.Context) {
	status := c.DefaultQuery("status", "pending")
	if status != "approved" && status != "rejected" && status != "all" {
		status = "pending"
	}
	rows, err := db.Pool.Query(c.Request.Context(), `
		SELECT r.id, r.status, r.created_at, r.contact_email, r.full_name, r.message,
		       r.identifier, r.reviewed_at, COALESCE(rv.username,''), r.review_note,
		       u.id, u.username, COALESCE(u.full_name,''), COALESCE(u.avatar,''),
		       COALESCE(u.email,''), COALESCE(u.email_verified,false), COALESCE(u.phone,''),
		       u.created_at, COALESCE(u.posts_count,0), COALESCE(u.followers_count,0)
		  FROM account_recovery_requests r
		  JOIN users u ON u.id = r.user_id
		  LEFT JOIN users rv ON rv.id = r.reviewed_by
		 WHERE ($1 = 'all' OR r.status = $1)
		 ORDER BY r.created_at DESC LIMIT 100`, status)
	if err != nil {
		log.Printf("[recover] admin list: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои дохилӣ"})
		return
	}
	defer rows.Close()
	out := []gin.H{}
	for rows.Next() {
		var id, st, contact, fullName, message, ident, reviewer, note string
		var uid, uname, ufull, avatar, uemail, uphone string
		var created, ucreated time.Time
		var reviewed *time.Time
		var verified bool
		var posts, followers int
		if err := rows.Scan(&id, &st, &created, &contact, &fullName, &message,
			&ident, &reviewed, &reviewer, &note,
			&uid, &uname, &ufull, &avatar, &uemail, &verified, &uphone,
			&ucreated, &posts, &followers); err != nil {
			continue
		}
		item := gin.H{
			"id": id, "status": st, "createdAt": created,
			"contactEmail": contact, "fullName": fullName, "message": message,
			"identifier": ident, "reviewedBy": reviewer, "reviewNote": note,
			// Барои қарор: оё маълумоти дархост бо ҳисоб мувофиқ аст.
			"contactMatchesAccountEmail": uemail != "" && strings.EqualFold(uemail, contact),
			"nameMatches":                ufull != "" && strings.EqualFold(strings.TrimSpace(ufull), fullName),
			"account": gin.H{
				"id": uid, "username": uname, "fullName": ufull, "avatar": avatar,
				"email": func() string {
					if uemail == "" {
						return ""
					}
					return maskEmailHint(uemail)
				}(),
				"emailVerified": verified, "hasPhone": uphone != "",
				"createdAt": ucreated, "postsCount": posts, "followersCount": followers,
			},
		}
		if reviewed != nil {
			item["reviewedAt"] = *reviewed
		}
		out = append(out, item)
	}
	c.JSON(http.StatusOK, gin.H{"requests": out})
}

// POST /admin/recovery-requests/:id/approve — рамзи якдафъаина (24 соат)
// ба почтаи тамос. Admin рамзро намебинад (ғайр аз муҳити санҷиш).
func AdminApproveRecovery(c *gin.Context) {
	adminID := mw.UID(c)
	reqID := c.Param("id")
	ctx := c.Request.Context()
	var uid, contact, username, accEmail string
	err := db.Pool.QueryRow(ctx, `
		UPDATE account_recovery_requests r
		   SET status='approved', reviewed_by=$2, reviewed_at=NOW()
		  FROM users u
		 WHERE r.id=$1 AND r.status='pending' AND u.id = r.user_id
		RETURNING r.user_id, r.contact_email, u.username, COALESCE(u.email,'')`,
		reqID, adminID).Scan(&uid, &contact, &username, &accEmail)
	if errors.Is(err, pgx.ErrNoRows) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Дархост ёфт нашуд ё аллакай баррасӣ шудааст"})
		return
	}
	if err != nil {
		log.Printf("[recover] approve: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои дохилӣ"})
		return
	}
	revert := func() {
		db.Pool.Exec(context.Background(), `
			UPDATE account_recovery_requests SET status='pending', reviewed_by='', reviewed_at=NULL
			 WHERE id=$1`, reqID)
	}
	code, err := issueResetToken(ctx, uid, purposeAdminHelp, helpTokenTTL, adminID)
	if err != nil {
		revert()
		log.Printf("[recover] approve token: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои дохилӣ"})
		return
	}
	body := fmt.Sprintf("Салом!\n\nДархости барқарорсозии ҳисоби @%s тасдиқ шуд.\n\n"+
		"Рамзи барқарорсозӣ: %s\n\n"+
		"Барнома → Воридшавӣ → «Рамзро фаромӯш кардед?» → «Рамзи барқарорсозӣ дорам» "+
		"-ро кушоед, ин рамз ва рамзи навро ворид кунед.\n"+
		"Рамз 24 соат ва танҳо як бор эътибор дорад. Онро ба касе нагӯед.\n\n— Раонсон",
		username, formatHelpCode(code))
	sendCtx, cancel := context.WithTimeout(context.Background(), utils.EmailTimeout)
	_, sendErr := utils.SendEmailDetailed(sendCtx, contact, "Раонсон — рамзи барқарорсозии ҳисоб", body)
	cancel()
	if sendErr != nil {
		log.Printf("[recover] approve email failed: %v", sendErr)
		if !otpEcho() {
			db.Pool.Exec(context.Background(),
				`DELETE FROM password_reset_tokens WHERE user_id=$1 AND purpose=$2`, uid, purposeAdminHelp)
			revert()
			resp := gin.H{"message": "Мактуб ба почтаи тамос фиристода нашуд. Дархост дар интизорӣ монд."}
			if !utils.OTPChannelsReady()["email"] {
				resp["setup"] = "BREVO_API_KEY ё SMTP_USER + SMTP_PASS"
			}
			c.JSON(http.StatusBadGateway, resp)
			return
		}
	}
	log.Printf("[recover] request %s for user %s approved by admin %s", reqID, uid, adminID)
	if accEmail != "" && !strings.EqualFold(accEmail, contact) {
		sendEmailAsync(accEmail, "Раонсон — барқарорсозии ҳисоб тасдиқ шуд",
			fmt.Sprintf("Салом, @%s!\n\nДархости барқарорсозии ҳисоби шумо тасдиқ шуд ва рамз ба "+
				"почтаи тамос (%s) фиристода шуд. Агар ин шумо набудед, фавран ба дастгирӣ нависед.\n\n— Раонсон",
				username, maskEmailHint(contact)))
	}
	resp := gin.H{"ok": true, "status": "approved", "sentTo": maskEmailHint(contact)}
	if otpEcho() {
		resp["code"] = formatHelpCode(code)
	}
	c.JSON(http.StatusOK, resp)
}

// POST /admin/recovery-requests/:id/reject {note}
func AdminRejectRecovery(c *gin.Context) {
	adminID := mw.UID(c)
	reqID := c.Param("id")
	var b struct {
		Note string `json:"note"`
	}
	c.ShouldBindJSON(&b)
	var contact string
	err := db.Pool.QueryRow(c.Request.Context(), `
		UPDATE account_recovery_requests
		   SET status='rejected', reviewed_by=$2, reviewed_at=NOW(), review_note=$3
		 WHERE id=$1 AND status='pending'
		RETURNING contact_email`, reqID, adminID, clampRunes(strings.TrimSpace(b.Note), 500)).Scan(&contact)
	if errors.Is(err, pgx.ErrNoRows) {
		c.JSON(http.StatusNotFound, gin.H{"message": "Дархост ёфт нашуд ё аллакай баррасӣ шудааст"})
		return
	}
	if err != nil {
		log.Printf("[recover] reject: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Хатои дохилӣ"})
		return
	}
	log.Printf("[recover] request %s rejected by admin %s", reqID, adminID)
	sendEmailAsync(contact, "Раонсон — дархости барқарорсозӣ",
		"Салом!\n\nМутаассифона, мо натавонистем тасдиқ кунем, ки ҳисоб ба шумо тааллуқ дорад. "+
			"Агар ба почта ё телефони ҳисоб дастрасӣ пайдо кунед, «Рамзро фаромӯш кардед?»-ро "+
			"истифода баред.\n\n— Раонсон")
	c.JSON(http.StatusOK, gin.H{"ok": true, "status": "rejected"})
}

// ── Роҳҳои кӯҳна (версияҳои пешинаи барнома) ────────────────────────

// POST /auth/forgot-password {identifier|email, channel}
func ForgotPassword(c *gin.Context) {
	var b struct {
		Identifier string `json:"identifier"`
		Email      string `json:"email"`
		Channel    string `json:"channel"`
	}
	c.ShouldBindJSON(&b)
	raw := b.Identifier
	if strings.TrimSpace(raw) == "" {
		raw = b.Email
	}
	id := parseRecoverIdent(raw)
	if id.Raw == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Email ё телефон лозим аст"})
		return
	}
	generic := gin.H{"message": "Агар ҳисоб мавҷуд бошад, рамз фиристода шуд"}
	if bump("rl:rsend:ip:"+c.ClientIP(), 15*time.Minute) > 20*rlMult() {
		c.JSON(http.StatusOK, generic)
		return
	}
	acc, amb, _ := findRecoverAccount(c.Request.Context(), id)
	if acc == nil || amb {
		c.JSON(http.StatusOK, generic)
		return
	}
	st, resp := sendRecoverCode(acc, strings.ToLower(strings.TrimSpace(b.Channel)), true)
	if st != http.StatusOK {
		// Ҷавоби кӯҳна ҳеҷ гоҳ хаторо ошкор намекард.
		c.JSON(http.StatusOK, generic)
		return
	}
	c.JSON(http.StatusOK, resp)
}

// POST /auth/reset-password {identifier|email, otp, newPassword}
func ResetPassword(c *gin.Context) {
	var b struct {
		Identifier  string `json:"identifier"`
		Email       string `json:"email"`
		OTP         string `json:"otp"`
		NewPassword string `json:"newPassword"`
	}
	c.ShouldBindJSON(&b)
	raw := b.Identifier
	if strings.TrimSpace(raw) == "" {
		raw = b.Email
	}
	id := parseRecoverIdent(raw)
	if id.Raw == "" || strings.TrimSpace(b.OTP) == "" || passwordProblem(b.NewPassword) != "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Майдонҳо нопурра (рамз ≥ 8 аломат)"})
		return
	}
	bad := gin.H{"message": "Рамз нодуруст ё кӯҳна"}
	acc, amb, _ := findRecoverAccount(c.Request.Context(), id)
	if acc == nil || amb {
		c.JSON(http.StatusBadRequest, bad)
		return
	}
	status, _ := checkOTPDetailed(recoverOTPKey(acc.ID), b.OTP)
	switch status {
	case otpLocked:
		c.JSON(http.StatusTooManyRequests, gin.H{
			"message": "Кӯшишҳо зиёд шуданд. Рамзи нав дархост кунед."})
		return
	case otpWrong, otpMissing:
		c.JSON(http.StatusBadRequest, bad)
		return
	}
	token, err := issueResetToken(c.Request.Context(), acc.ID, purposeOTP, resetTokenTTL, "")
	if err == nil {
		_, err = completeReset(c.Request.Context(), token, b.NewPassword)
	}
	if err != nil {
		log.Printf("[recover] legacy reset: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Барқарорсозӣ ноком шуд"})
		return
	}
	notifyPasswordChanged(acc.ID, acc.Username, acc.Email)
	c.JSON(http.StatusOK, gin.H{"message": "Парол бо муваффақият иваз шуд"})
}
