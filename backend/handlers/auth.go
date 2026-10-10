package handlers

import (
	"context"
	"log"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"
	"raonson/referral"
	"raonson/utils"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

func makeJWT(userID, secret string, dur time.Duration) string {
	tv, _ := mw.TokenState(userID)
	t, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":  userID,
		"exp": time.Now().Add(dur).Unix(),
		// Версияи token — «Ҳамаро бандед», ивази рамз ва ban онро зиёд
		// мекунанд ва ҳамаи token-ҳои кӯҳна бекор мешаванд.
		"tv": tv,
	}).SignedString([]byte(secret))
	return t
}

// POST /auth/register
func Register(c *gin.Context) {
	var b struct {
		Username string `json:"username" binding:"required"`
		Email    string `json:"email"    binding:"required"`
		Password string `json:"password" binding:"required"`
		FullName string `json:"fullName"`
		Phone    string `json:"phone"`
		// Коди даъват аз линки чуқур. Коди нодуруст бақайдгириро
		// БАС НАМЕКУНАД — он ҷузъи ихтиёрист.
		ReferralCode string `json:"referralCode"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing fields"})
		return
	}
	b.Username = strings.ToLower(strings.TrimSpace(b.Username))
	b.Email    = strings.ToLower(strings.TrimSpace(b.Email))
	b.FullName = strings.TrimSpace(b.FullName)
	b.Phone    = strings.TrimSpace(b.Phone)

	// Validate username: only a-z, 0-9, _ and .
	validUsername := regexp.MustCompile(`^[a-z0-9_.]{3,30}$`)
	if !validUsername.MatchString(b.Username) {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Username can only contain letters, numbers, _ and .",
		})
		return
	}
	validEmail := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
	if !validEmail.MatchString(b.Email) {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Почтаи электронӣ нодуруст аст",
		})
		return
	}
	// Парол дар сервер ҳам санҷида мешавад (на танҳо дар клиент).
	// Ҳамон қоидаҳо барои ивазкунӣ ва барқарорсозӣ (passwordProblem).
	if msg := passwordProblem(b.Password); msg != "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": msg})
		return
	}

	var exists bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE email=$1 OR username=$2)`,
		b.Email, b.Username).Scan(&exists)
	if exists {
		c.JSON(http.StatusConflict, gin.H{"message": "Username or email already taken"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(b.Password), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Register failed"})
		return
	}

	var id, username, email string
	err = db.Pool.QueryRow(context.Background(),
		`INSERT INTO users(username,email,password,full_name,phone)
		 VALUES($1,$2,$3,$4,$5) RETURNING id,username,email`,
		b.Username, b.Email, string(hash), b.FullName, b.Phone).Scan(&id, &username, &email)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"message": "Username or email already taken"})
		return
	}

	secret        := mw.JWTSecret()
	refreshSecret := mw.RefreshSecret()

	recordLogin(id, c)
	if b.Phone != "" {
		// «… аз мухотибони шумо ҳамроҳ шуд» — танҳо ба онҳое, ки розигӣ
		// додаанд (ниг. contacts_join.go).
		announceContactJoined(id)
	}

	// Даъват: як бор ва танҳо дар сервер. Хато сабт мешавад, вале
	// бақайдгирии муваффақро вайрон намекунад.
	if b.ReferralCode != "" {
		if _, err := referral.Attribute(context.Background(), db.Pool,
			id, b.ReferralCode); err != nil {
			log.Printf("[Register] referral: %v", err)
		}
	}

	c.JSON(http.StatusCreated, gin.H{
		"success":      true,
		"accessToken":  makeJWT(id, secret, 1*time.Hour),
		"refreshToken": makeJWT(id, refreshSecret, 30*24*time.Hour),
		"user": gin.H{
			"id": id, "username": username, "email": email,
			"avatar": "", "fullName": b.FullName,
		},
	})
}

// GET /auth/check-username/:username — оё номи корбар озод аст
func CheckUsername(c *gin.Context) {
	uname := strings.ToLower(strings.TrimSpace(c.Param("username")))
	valid := regexp.MustCompile(`^[a-z0-9_.]{3,30}$`).MatchString(uname)
	if !valid {
		c.JSON(http.StatusOK, gin.H{"valid": false, "available": false})
		return
	}
	var exists bool
	db.Pool.QueryRow(context.Background(),
		`SELECT EXISTS(SELECT 1 FROM users WHERE username=$1)`, uname).Scan(&exists)
	c.JSON(http.StatusOK, gin.H{"valid": true, "available": !exists})
}

// POST /auth/login
func Login(c *gin.Context) {
	var b struct {
		Email    string `json:"email"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing fields"})
		return
	}
	b.Email = normalizeLoginID(b.Email)

	// Логин бо почта Ё номи корбар Ё рақами телефон
	// ⚠️ Як идентификатор метавонад ба чанд ҳисоб мувофиқ ояд (масалан
	// ҳисоби дигар рақами телефони шуморо гузошта буд). Пеш аввалин сатр
	// гирифта мешуд — соҳиби аслӣ ворид шуда наметавонист. Акнун паролро
	// бо ҳар кадом месанҷем; почта ва номи корбар бартарӣ доранд.
	// Кӯшишҳои нодуруст ба як идентификатор маҳдуданд (на аз рӯи IP).
	if bump("login:"+b.Email, 15*time.Minute) > 20 {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"message": "Кӯшишҳо зиёд шуданд. 15 дақиқа интизор шавед."})
		return
	}
	var id, username, email, hash, avatar, fullName string
	var banned, found bool
	rows, err := db.Pool.Query(context.Background(),
		`SELECT id,username,COALESCE(email,''),password,COALESCE(avatar,''),COALESCE(full_name,''),
		        COALESCE(banned,false)
		 FROM users WHERE email=$1 OR username=$1 OR phone=$1
		 ORDER BY (email=$1 OR username=$1) DESC, created_at ASC LIMIT 5`, b.Email)
	if err == nil {
		for rows.Next() {
			var cid, cu, ce, ch, ca, cf string
			var cb bool
			if rows.Scan(&cid, &cu, &ce, &ch, &ca, &cf, &cb) != nil {
				continue
			}
			if bcrypt.CompareHashAndPassword([]byte(ch), []byte(b.Password)) == nil {
				id, username, email, hash, avatar, fullName, banned = cid, cu, ce, ch, ca, cf, cb
				found = true
				break
			}
		}
		rows.Close()
	}
	if !found {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}
	resetCounter("login:" + b.Email)
	_ = hash
	if banned {
		c.JSON(http.StatusForbidden,
			gin.H{"message": "Ҳисоби шумо баста шудааст"})
		return
	}

	secret        := mw.JWTSecret()
	refreshSecret := mw.RefreshSecret()

	recordLogin(id, c) // таърихи воридшавӣ (device + IP)

	c.JSON(http.StatusOK, gin.H{
		"accessToken":  makeJWT(id, secret, 1*time.Hour),
		"refreshToken": makeJWT(id, refreshSecret, 30*24*time.Hour),
		"user": gin.H{
			"id": id, "username": username, "email": email,
			"avatar": avatar, "fullName": fullName,
		},
	})
}

// POST /auth/refresh
func RefreshToken(c *gin.Context) {
	var b struct{ RefreshToken string `json:"refreshToken"` }
	if err := c.ShouldBindJSON(&b); err != nil || b.RefreshToken == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "No refresh token"})
		return
	}
	tok, err := jwt.Parse(b.RefreshToken, func(t *jwt.Token) (interface{}, error) {
		return []byte(mw.RefreshSecret()), nil
	}, jwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !tok.Valid {
		c.JSON(http.StatusForbidden, gin.H{"message": "Invalid refresh token"})
		return
	}
	claims := tok.Claims.(jwt.MapClaims)
	uid, _ := claims["id"].(string)
	// Refresh-token-и бекоршуда (ивази рамз, «Ҳамаро бандед», ban) нав
	// намекунад — пеш 30 рӯз кор мекард.
	if uid == "" || !mw.TokenAllowed(uid, claims["tv"]) {
		c.JSON(http.StatusForbidden, gin.H{"message": "Session revoked"})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"accessToken": makeJWT(uid, mw.JWTSecret(), 1*time.Hour),
	})
}

// POST /auth/logout
func Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /auth/change-password {oldPassword,newPassword} — корбари воридшуда.
func ChangePassword(c *gin.Context) {
	myID := mw.UID(c)
	var b struct {
		OldPassword string `json:"oldPassword"`
		NewPassword string `json:"newPassword"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "invalid body"})
		return
	}
	if msg := passwordProblem(b.NewPassword); msg != "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": msg})
		return
	}
	var hash string
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT password FROM users WHERE id=$1`, myID).Scan(&hash); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	// Ҳисоби аз TajikShop сохташуда (SSO) рамз надорад — рамзи аввалро
	// бе «рамзи кӯҳна» гузоштан мумкин аст (мисли «Create password»-и
	// Instagram барои ҳисоби Facebook).
	if hash != "" && bcrypt.CompareHashAndPassword([]byte(hash), []byte(b.OldPassword)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Рамзи кӯҳна нодуруст аст"})
		return
	}
	newHash, err := bcrypt.GenerateFromPassword([]byte(b.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "хатои дохилӣ"})
		return
	}
	if _, err := db.Pool.Exec(context.Background(),
		`UPDATE users SET password=$1 WHERE id=$2`, string(newHash), myID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Рамз иваз нашуд"})
		return
	}
	// Дигар дастгоҳҳо мебароянд (мисли Instagram); ин дастгоҳ token-и
	// нав мегирад, то корбар худаш набарояд.
	mw.RevokeTokens(myID)
	var uname, uemail string
	db.Pool.QueryRow(context.Background(),
		`SELECT username, COALESCE(email,'') FROM users WHERE id=$1`, myID).Scan(&uname, &uemail)
	notifyPasswordChanged(myID, uname, uemail)
	c.JSON(http.StatusOK, gin.H{"ok": true,
		"accessToken":  makeJWT(myID, mw.JWTSecret(), 1*time.Hour),
		"refreshToken": makeJWT(myID, mw.RefreshSecret(), 30*24*time.Hour),
	})
}

// POST /admin/test-email — ба почтаи худи admin тест мефиристад ва
// хатои аслии SMTP-ро бармегардонад (барои ташхиси «email намеояд»).
func AdminTestEmail(c *gin.Context) {
	myID := mw.UID(c)
	var email string
	db.Pool.QueryRow(context.Background(),
		`SELECT COALESCE(email,'') FROM users WHERE id=$1`, myID).Scan(&email)
	if email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Аккаунти шумо почта надорад"})
		return
	}
	// Танҳо НОМИ провайдерҳо бармегардад — калид/парол ҳеҷ гоҳ.
	providers := utils.EmailProvidersConfigured()
	if providers == nil {
		providers = []string{}
	}
	ctx, cancel := context.WithTimeout(c.Request.Context(), utils.EmailTimeout)
	defer cancel()
	res, err := utils.SendEmailDetailed(ctx, email,
		"Раонсон — санҷиши почта", "Ин паёми санҷишӣ аз панели admin аст.\n\n— Раонсон")
	attempts := res.Attempts
	if attempts == nil {
		attempts = []utils.EmailAttempt{}
	}
	out := gin.H{
		"sent": err == nil, "to": email, "configured": len(providers) > 0,
		"providers": providers, "provider": res.Provider, "attempts": attempts,
	}
	if err != nil {
		out["error"] = err.Error()
		// Танҳо SMTP ва он баста аст → маслиҳати аниқ (Brevo API).
		if res.Provider == utils.EmailProviderSMTP && len(providers) == 1 {
			out["hint"] = utils.SMTPBlockedHint
		}
		log.Printf("[AdminTestEmail] provider=%s failed", res.Provider)
	}
	c.JSON(http.StatusOK, out)
}

// POST /auth/send-phone-otp — рамзро ба телефон тавассути Telegram мефиристад.
// Барои тасдиқи телефон ҳангоми сабти ном ва барои барқарорсозии парол.
func SendPhoneOTP(c *gin.Context) {
	var b struct {
		Phone string `json:"phone" binding:"required"`
	}
	if c.ShouldBindJSON(&b) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Рақами телефон лозим аст"})
		return
	}
	phone := strings.TrimSpace(b.Phone)
	if len(phone) < 7 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Рақами телефон нодуруст аст"})
		return
	}

	// То 3 рамз дар соат ба як рақам — SMS пулакӣ аст ва бе ин ба
	// ҳар рақам беохир фиристода мешуд.
	if !otpSendAllowed("phone:"+phone, 3, time.Hour) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"message": "Рамз аллакай фиристода шуд. Баъди чанд дақиқа боз кӯшиш кунед."})
		return
	}
	otp := secureOTP()
	storeOTP("otp:phone:"+phone, otp, 5*time.Minute)

	// Пеш ин ҷо ТАНҲО Telegram буд. Telegram Gateway ба сим-карта
	// SMS НАМЕФИРИСТАД — барои ҳамин корбар мегуфт «смс намеояд».
	// Акнун аввал SMS (Twilio), баъд Telegram, баъд WhatsApp.
	channel, sendErr := utils.SendPhoneCode(phone, otp)

	if sendErr != nil {
		// Барои корбар: рамз НАРАФТ — ва ин бояд хатои ҳақиқӣ бошад,
		// вагарна барнома равзанаи «рамзро ворид кунед» мекушояд ва
		// корбар паёмеро интизор мешавад, ки ҳеҷ гоҳ намеояд.
		log.Printf("[SendPhoneOTP] %v", sendErr)
		mw.CacheDel("otp:phone:" + phone)

		body := gin.H{
			"error":   true,
			"message": "Рамз фиристода нашуд. Рақамро санҷед ё дертар кӯшиш кунед.",
			"ready":   utils.OTPChannelsReady(),
		}
		// Барои СОҲИБИ барнома: чиро танзим кардан. Ин калид нест —
		// танҳо номи танзимоти норасида.
		if hint := utils.OTPMissingHint(); hint != "" {
			body["setup"] = hint
		}
		c.JSON(http.StatusBadGateway, body)
		return
	}

	resp := gin.H{
		"message": "Рамз фиристода шуд",
		"to":      utils.MaskPhone(phone),
		"channel": string(channel), // sms | telegram | whatsapp
	}
	if os.Getenv("OTP_ECHO") == "1" && gin.Mode() != gin.ReleaseMode {
		resp["otp"] = otp
	}
	c.JSON(http.StatusOK, resp)
}

// POST /auth/verify-phone-otp — рамзро тасдиқ мекунад.
func VerifyPhoneOTP(c *gin.Context) {
	var b struct {
		Phone string `json:"phone" binding:"required"`
		OTP   string `json:"otp"   binding:"required"`
	}
	if c.ShouldBindJSON(&b) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Телефон ва рамз лозим аст"})
		return
	}
	phone := strings.TrimSpace(b.Phone)
	good, locked := checkOTP("otp:phone:"+phone, b.OTP)
	if locked {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"message": "Кӯшишҳо зиёд шуданд. Рамзи нав дархост кунед."})
		return
	}
	if !good {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Рамз нодуруст ё кӯҳна"})
		return
	}
	// Агар корбар login карда бошад — телефони ӯро verified мекунем
	if uid := mw.UID(c); uid != "" {
		if phoneTaken(phone, uid) {
			c.JSON(http.StatusConflict, gin.H{"message": "Ин рақам ба ҳисоби дигар тааллуқ дорад"})
			return
		}
		db.Pool.Exec(context.Background(),
			`UPDATE users SET phone=$1, updated_at=NOW() WHERE id=$2`, phone, uid)
		announceContactJoined(uid)
	}
	c.JSON(http.StatusOK, gin.H{"verified": true})
}

var _ = os.Getenv

// normalizeLoginID майдони «почта / номи корбар / телефон»-ро ба як
// шакл меорад.
//
// ⚠️ `@`-и аввал бардошта мешавад. Дар тамоми барнома ном ҳамчун
// «@tajikshop» нишон дода мешавад, пас корбарон маҳз ҳамин тавр
// менависанд. Сервер `@tajikshop`-ро ҳарфан меҷуст, ёфта наметавонист
// ва «Invalid email or password» мегуфт — гарчанде ки парол дуруст
// буд. Номи корбар `@` дошта наметавонад (`^[a-z0-9_.]{3,30}$`) ва
// почта бо `@` оғоз намешавад, пас ин бехатар аст.
func normalizeLoginID(raw string) string {
	s := strings.ToLower(strings.TrimSpace(raw))
	return strings.TrimSpace(strings.TrimPrefix(s, "@"))
}
