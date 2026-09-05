package handlers

import (
	"context"
	"log"
	"fmt"
	"math/rand"
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
	t, _ := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"id":  userID,
		"exp": time.Now().Add(dur).Unix(),
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
	if len(b.Password) < 8 {
		c.JSON(http.StatusBadRequest,
			gin.H{"message": "Рамз ҳадди аққал 8 аломат бошад"})
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
	b.Email = strings.ToLower(strings.TrimSpace(b.Email))

	// Логин бо почта Ё номи корбар Ё рақами телефон
	var id, username, email, hash, avatar, fullName string
	var banned bool
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id,username,email,password,COALESCE(avatar,''),COALESCE(full_name,''),
		        COALESCE(banned,false)
		 FROM users WHERE email=$1 OR username=$1 OR phone=$1`,
		b.Email).Scan(&id, &username, &email, &hash, &avatar, &fullName, &banned)
	if err != nil {
		log.Printf("[Login] User not found")
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(b.Password)) != nil {
		log.Printf("[Login] Wrong password")
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}
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
	uid    := claims["id"].(string)
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
	if len(b.NewPassword) < 8 {
		c.JSON(http.StatusBadRequest,
			gin.H{"message": "Рамзи нав ҳадди аққал 8 аломат бошад"})
		return
	}
	var hash string
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT password FROM users WHERE id=$1`, myID).Scan(&hash); err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Корбар ёфт нашуд"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(b.OldPassword)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Рамзи кӯҳна нодуруст аст"})
		return
	}
	newHash, err := bcrypt.GenerateFromPassword([]byte(b.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "хатои дохилӣ"})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET password=$1 WHERE id=$2`, string(newHash), myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// POST /auth/forgot-password
func ForgotPassword(c *gin.Context) {
	var b struct {
		Identifier string `json:"identifier"` // email ё телефон ё username
		Email      string `json:"email"`      // мутобиқати қафо
		Channel    string `json:"channel"`    // email | sms | whatsapp
	}
	c.ShouldBindJSON(&b)
	ident := strings.ToLower(strings.TrimSpace(b.Identifier))
	if ident == "" {
		ident = strings.ToLower(strings.TrimSpace(b.Email))
	}
	if ident == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Email ё телефон лозим аст"})
		return
	}
	if b.Channel == "" {
		b.Channel = "email"
	}

	var id, email, phone string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id, COALESCE(email,''), COALESCE(phone,'')
		 FROM users WHERE LOWER(email)=$1 OR phone=$1 OR LOWER(username)=$1`,
		ident).Scan(&id, &email, &phone)
	if err != nil {
		// Маълумотро ошкор намекунем
		c.JSON(http.StatusOK, gin.H{"message": "Агар ҳисоб мавҷуд бошад, рамз фиристода шуд"})
		return
	}

	otp := fmt.Sprintf("%06d", rand.Intn(1000000))
	// Бо id нигоҳ медорем — то reset бо ҳар идентификатор кор кунад.
	mw.CacheSet("otp:reset:"+id, []byte(otp), 10*time.Minute)

	// Тавассути канали интихобшуда мефиристем.
	var sendErr error
	var dest string
	switch b.Channel {
	case "sms":
		if phone == "" { sendErr = fmt.Errorf("no phone") } else {
			sendErr = utils.SendSMSOTP(phone, otp); dest = utils.MaskPhone(phone)
		}
	case "whatsapp":
		if phone == "" { sendErr = fmt.Errorf("no phone") } else {
			sendErr = utils.SendWhatsAppOTP(phone, otp); dest = utils.MaskPhone(phone)
		}
	case "telegram":
		if phone == "" { sendErr = fmt.Errorf("no phone") } else {
			sendErr = utils.SendTelegramOTP(phone, otp); dest = utils.MaskPhone(phone)
		}
	default: // email
		if email == "" { sendErr = fmt.Errorf("no email") } else {
			sendErr = utils.SendEmailOTP(email, otp); dest = utils.MaskEmail(email)
		}
	}

	resp := gin.H{"message": "Рамз ба почтаи шумо фиристода шуд", "to": dest, "channel": b.Channel}
	if sendErr != nil {
		// Хатогиро сабт мекунем, вале ба корбар ошкор намекунем (бехатарӣ).
		log.Printf("[ForgotPassword] send via %s failed: %v", b.Channel, sendErr)
	}
	// Рамз ТАНҲО ба email/SMS меравад. Дар экран нишон дода НАМЕШАВАД.
	// Барои санҷиш (бе провайдер) — env OTP_ECHO=1 гузоред.
	if os.Getenv("OTP_ECHO") == "1" && gin.Mode() != gin.ReleaseMode {
		resp["otp"] = otp
	}
	c.JSON(http.StatusOK, resp)
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
	cfg := os.Getenv("SMTP_USER") != "" && os.Getenv("SMTP_PASS") != ""
	if err := utils.SendEmailOTP(email, "123456"); err != nil {
		c.JSON(http.StatusOK, gin.H{
			"sent": false, "to": email, "configured": cfg,
			"error": err.Error(),
		})
		return
	}
	c.JSON(http.StatusOK, gin.H{"sent": true, "to": email, "configured": cfg})
}

// POST /auth/reset-password
func ResetPassword(c *gin.Context) {
	var b struct {
		Identifier  string `json:"identifier"`
		Email       string `json:"email"`
		OTP         string `json:"otp"`
		NewPassword string `json:"newPassword"`
	}
	c.ShouldBindJSON(&b)
	ident := strings.ToLower(strings.TrimSpace(b.Identifier))
	if ident == "" {
		ident = strings.ToLower(strings.TrimSpace(b.Email))
	}
	if ident == "" || b.OTP == "" || len(b.NewPassword) < 8 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Майдонҳо нопурра (парол ≥6)"})
		return
	}

	var id string
	if err := db.Pool.QueryRow(context.Background(),
		`SELECT id FROM users WHERE LOWER(email)=$1 OR phone=$1 OR LOWER(username)=$1`,
		ident).Scan(&id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ҳисоб ёфт нашуд"})
		return
	}

	stored, ok := mw.CacheGet("otp:reset:" + id)
	if !ok || string(stored) != strings.TrimSpace(b.OTP) {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Рамз нодуруст ё кӯҳна"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(b.NewPassword), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Барқарорсозӣ ноком шуд"})
		return
	}
	db.Pool.Exec(context.Background(),
		`UPDATE users SET password=$1, updated_at=NOW() WHERE id=$2`, string(hash), id)
	mw.CacheDel("otp:reset:" + id)
	c.JSON(http.StatusOK, gin.H{"message": "Парол бо муваффақият иваз шуд"})
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

	otp := fmt.Sprintf("%06d", rand.Intn(1000000))
	mw.CacheSet("otp:phone:"+phone, []byte(otp), 5*time.Minute)

	sendErr := utils.SendTelegramOTP(phone, otp)

	resp := gin.H{"message": "Рамз фиристода шуд", "to": utils.MaskPhone(phone)}
	if sendErr != nil {
		log.Printf("[SendPhoneOTP] telegram send failed: %v", sendErr)
		resp["message"] = "Рамз фиристода нашуд. Telegram дар телефонатон бошад."
		resp["error"] = true
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
	stored, ok := mw.CacheGet("otp:phone:" + phone)
	if !ok || string(stored) != strings.TrimSpace(b.OTP) {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Рамз нодуруст ё кӯҳна"})
		return
	}
	mw.CacheDel("otp:phone:" + phone)
	// Агар корбар login карда бошад — телефони ӯро verified мекунем
	if uid := mw.UID(c); uid != "" {
		db.Pool.Exec(context.Background(),
			`UPDATE users SET phone=$1, updated_at=NOW() WHERE id=$2`, phone, uid)
	}
	c.JSON(http.StatusOK, gin.H{"verified": true})
}

var _ = os.Getenv
