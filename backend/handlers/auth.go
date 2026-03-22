package handlers

import (
	"context"
	"fmt"
	"math/rand"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"

	"raonson/db"
	mw "raonson/middleware"

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
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing fields"})
		return
	}
	b.Username = strings.ToLower(strings.TrimSpace(b.Username))
	b.Email    = strings.ToLower(strings.TrimSpace(b.Email))

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
		`INSERT INTO users(username,email,password) VALUES($1,$2,$3) RETURNING id,username,email`,
		b.Username, b.Email, string(hash)).Scan(&id, &username, &email)
	if err != nil {
		c.JSON(http.StatusConflict, gin.H{"message": "Username or email already taken"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"user":    gin.H{"id": id, "username": username, "email": email},
	})
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

	var id, username, email, hash string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id,username,email,password FROM users WHERE email=$1 AND banned=FALSE`,
		b.Email).Scan(&id, &username, &email, &hash)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(b.Password)) != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid email or password"})
		return
	}

	secret        := mw.JWTSecret()
	refreshSecret := mw.RefreshSecret()

	c.JSON(http.StatusOK, gin.H{
		"accessToken":  makeJWT(id, secret, 7*24*time.Hour),
		"refreshToken": makeJWT(id, refreshSecret, 30*24*time.Hour),
		"user":         gin.H{"id": id, "username": username, "email": email},
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
	var b struct{ Email string `json:"email"` }
	if err := c.ShouldBindJSON(&b); err != nil || b.Email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Email required"})
		return
	}
	email := strings.ToLower(strings.TrimSpace(b.Email))

	var id string
	err := db.Pool.QueryRow(context.Background(),
		`SELECT id FROM users WHERE email=$1`, email).Scan(&id)
	if err != nil {
		// Do not reveal if email exists
		c.JSON(http.StatusOK, gin.H{"message": "If email exists, reset code sent"})
		return
	}

	// Generate 6-digit OTP
	otp := fmt.Sprintf("%06d", rand.Intn(1000000))

	// Store in Redis (10 min TTL)
	mw.CacheSet("otp:"+email, []byte(otp), 10*time.Minute)

	// TODO production: send via SendGrid/AWS SES
	// Development: return OTP in response
	resp := gin.H{"message": "Reset code sent"}
	if os.Getenv("GIN_MODE") != "release" {
		resp["otp"] = otp // Only in dev mode
	}
	c.JSON(http.StatusOK, resp)
}

// POST /auth/reset-password
func ResetPassword(c *gin.Context) {
	var b struct {
		Email       string `json:"email"`
		OTP         string `json:"otp"`
		NewPassword string `json:"newPassword"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.Email == "" || b.OTP == "" || b.NewPassword == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing fields"})
		return
	}
	email := strings.ToLower(strings.TrimSpace(b.Email))

	stored, ok := mw.CacheGet("otp:" + email)
	if !ok || string(stored) != b.OTP {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Invalid or expired OTP"})
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(b.NewPassword), 10)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Reset failed"})
		return
	}

	db.Pool.Exec(context.Background(),
		`UPDATE users SET password=$1, updated_at=NOW() WHERE email=$2`,
		string(hash), email)

	mw.CacheDel("otp:" + email)
	c.JSON(http.StatusOK, gin.H{"message": "Password reset successful"})
}

var _ = os.Getenv
