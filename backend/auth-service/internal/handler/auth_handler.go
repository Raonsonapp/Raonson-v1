package handler

import (
	"net/http"
	"os"
	"strings"

	"auth-service/internal/model"
	"auth-service/internal/service"

	"github.com/gin-gonic/gin"
)

type Handler struct{ svc *service.Service }

func New(svc *service.Service) *Handler { return &Handler{svc: svc} }

func ok(c *gin.Context, code int, data gin.H) { c.JSON(code, data) }
func fail(c *gin.Context, code int, msg string) {
	c.AbortWithStatusJSON(code, gin.H{"success": false, "error": gin.H{"message": msg}})
}

// GET /health
func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"service": "auth-service", "status": "ok"})
}

// POST /auth/register
func (h *Handler) Register(c *gin.Context) {
	var req model.RegisterReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	pair, err := h.svc.Register(c.Request.Context(), &req)
	if err != nil {
		status := http.StatusInternalServerError
		if strings.Contains(err.Error(), "taken") {
			status = http.StatusConflict
		}
		fail(c, status, err.Error())
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"success":      true,
		"accessToken":  pair.AccessToken,
		"refreshToken": pair.RefreshToken,
		"user":         pair.User,
	})
}

// POST /auth/login
func (h *Handler) Login(c *gin.Context) {
	var req model.LoginReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "email and password required")
		return
	}
	pair, err := h.svc.Login(c.Request.Context(), &req)
	if err != nil {
		status := http.StatusUnauthorized
		if strings.Contains(err.Error(), "suspended") {
			status = http.StatusForbidden
		}
		fail(c, status, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"accessToken":  pair.AccessToken,
		"refreshToken": pair.RefreshToken,
		"user":         pair.User,
	})
}

// POST /auth/refresh
func (h *Handler) Refresh(c *gin.Context) {
	var req model.RefreshReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "refreshToken required")
		return
	}
	pair, err := h.svc.Refresh(req.RefreshToken)
	if err != nil {
		fail(c, http.StatusUnauthorized, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"accessToken":  pair.AccessToken,
		"refreshToken": pair.RefreshToken,
	})
}

// POST /auth/logout
func (h *Handler) Logout(c *gin.Context) {
	uid, _ := c.Get("userID")
	auth := c.GetHeader("Authorization")
	access := ""
	if strings.HasPrefix(auth, "Bearer ") {
		access = auth[7:]
	}
	var b struct{ RefreshToken string `json:"refreshToken"` }
	c.ShouldBindJSON(&b)
	h.svc.Logout(uid.(string), access, b.RefreshToken)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /auth/forgot-password
func (h *Handler) ForgotPassword(c *gin.Context) {
	var req model.ForgotReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "email required")
		return
	}
	otp, _ := h.svc.ForgotPassword(c.Request.Context(), req.Email)
	resp := gin.H{"success": true, "message": "If email exists, reset code sent"}
	if os.Getenv("APP_ENV") != "production" && otp != "" {
		resp["otp"] = otp // Dev only
	}
	c.JSON(http.StatusOK, resp)
}

// POST /auth/reset-password
func (h *Handler) ResetPassword(c *gin.Context) {
	var req model.ResetReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	if err := h.svc.ResetPassword(c.Request.Context(), &req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Password updated"})
}

// GET /internal/validate — nginx auth_request calls this
func (h *Handler) ValidateToken(c *gin.Context) {
	token := c.GetHeader("X-Auth-Token")
	if token == "" {
		auth := c.GetHeader("Authorization")
		if strings.HasPrefix(auth, "Bearer ") {
			token = auth[7:]
		}
	}
	if token == "" {
		fail(c, http.StatusUnauthorized, "no token")
		return
	}
	uid, err := h.svc.ValidateToken(token)
	if err != nil {
		fail(c, http.StatusUnauthorized, "invalid token")
		return
	}
	c.Header("X-User-ID", uid)
	c.JSON(http.StatusOK, gin.H{"userID": uid})
}
