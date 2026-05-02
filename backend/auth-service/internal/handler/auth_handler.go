package handler

import (
	"net/http"
	"os"
	"strings"

	"auth-service/internal/model"
	"auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	svc *service.AuthService
}

func NewAuthHandler(svc *service.AuthService) *AuthHandler {
	return &AuthHandler{svc: svc}
}

func (h *AuthHandler) Register(c *gin.Context) {
	var req model.RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing or invalid fields", "error": err.Error()})
		return
	}
	pair, err := h.svc.Register(c.Request.Context(), &req)
	if err != nil {
		status := http.StatusInternalServerError
		if strings.Contains(err.Error(), "already taken") {
			status = http.StatusConflict
		}
		c.JSON(status, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"success":      true,
		"accessToken":  pair.AccessToken,
		"refreshToken": pair.RefreshToken,
		"user":         pair.User,
	})
}

func (h *AuthHandler) Login(c *gin.Context) {
	var req model.LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing fields"})
		return
	}
	pair, err := h.svc.Login(c.Request.Context(), &req)
	if err != nil {
		status := http.StatusUnauthorized
		if strings.Contains(err.Error(), "banned") {
			status = http.StatusForbidden
		}
		c.JSON(status, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"accessToken":  pair.AccessToken,
		"refreshToken": pair.RefreshToken,
		"user":         pair.User,
	})
}

func (h *AuthHandler) RefreshToken(c *gin.Context) {
	var req model.RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "refreshToken required"})
		return
	}
	pair, err := h.svc.RefreshTokens(c.Request.Context(), req.RefreshToken)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"accessToken":  pair.AccessToken,
		"refreshToken": pair.RefreshToken,
	})
}

func (h *AuthHandler) Logout(c *gin.Context) {
	userID, _ := c.Get("userID")
	uid, _ := userID.(string)

	// Get tokens for blacklisting
	authHeader := c.GetHeader("Authorization")
	accessToken := ""
	if strings.HasPrefix(authHeader, "Bearer ") {
		accessToken = authHeader[7:]
	}
	var body struct{ RefreshToken string `json:"refreshToken"` }
	c.ShouldBindJSON(&body)

	h.svc.Logout(c.Request.Context(), uid, accessToken, body.RefreshToken)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req model.ForgotPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Email required"})
		return
	}
	otp, err := h.svc.ForgotPassword(c.Request.Context(), req.Email)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to send reset code"})
		return
	}
	resp := gin.H{"message": "If email exists, reset code sent"}
	// Dev mode: return OTP directly
	if os.Getenv("APP_ENV") != "production" && otp != "" {
		resp["otp"] = otp
	}
	c.JSON(http.StatusOK, resp)
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req model.ResetPasswordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Missing fields"})
		return
	}
	if err := h.svc.ResetPassword(c.Request.Context(), &req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Password reset successful"})
}

// ValidateToken — Nginx auth_request-и дохилӣ ин endpoint-ро меноманд
func (h *AuthHandler) ValidateToken(c *gin.Context) {
	tokenStr := c.GetHeader("X-Auth-Token")
	if tokenStr == "" {
		// Also try Authorization header
		auth := c.GetHeader("Authorization")
		if strings.HasPrefix(auth, "Bearer ") {
			tokenStr = auth[7:]
		}
	}
	if tokenStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "no token"})
		return
	}
	userID, err := h.svc.ValidateToken(c.Request.Context(), tokenStr)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}
	// Nginx auth_request passes these headers to upstream
	c.Header("X-User-ID", userID)
	c.JSON(http.StatusOK, gin.H{"userID": userID})
}
