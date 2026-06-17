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

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
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
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id,username,email,password,COALESCE(avatar,''),COALESCE(full_name,'')
		 FROM users WHERE email=$1 OR username=$1 OR phone=$1`,
		b.Email).Scan(&id, &username, &email, &hash, &avatar, &fullName)
	if err != nil {
		log.Printf("[Login] User not found: email=%s err=%v", b.Email, err)
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(b.Password)) != nil {
		log.Printf("[Login] Wrong password for: email=%s", b.Email)
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}

	secret        := mw.JWTSecret()
	refreshSecret := mw.RefreshSecret()

	c.JSON(http.StatusOK, gin.H{
		"accessToken":  makeJWT(id, secret, 7*24*time.Hour),
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
		"accessToken": makeJWT(uid, mw.JWTSecret(), 7*24*time.Hour),
	})
}

// POST /auth/logout
func Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"success": true})
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
	if os.Getenv("OTP_ECHO") == "1" {
		resp["otp"] = otp
	}
	c.JSON(http.StatusOK, resp)
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
	if ident == "" || b.OTP == "" || len(b.NewPassword) < 6 {
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

var _ = os.Getenv
