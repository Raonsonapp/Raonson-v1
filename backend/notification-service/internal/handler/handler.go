package handler

import (
	"net/http"

	"notification-service/internal/model"
	"notification-service/internal/service"

	"github.com/gin-gonic/gin"
)

type Handler struct{ svc *service.Service }

func New(svc *service.Service) *Handler { return &Handler{svc: svc} }

func uid(c *gin.Context) string {
	v, _ := c.Get("userID")
	s, _ := v.(string)
	return s
}

func fail(c *gin.Context, code int, msg string) {
	c.AbortWithStatusJSON(code, gin.H{
		"success": false,
		"error":   gin.H{"message": msg},
	})
}

// GET /health
func (h *Handler) Health(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"service": "notification-service", "status": "ok"})
}

// GET /notifications
func (h *Handler) GetNotifications(c *gin.Context) {
	myID := uid(c)
	cursor := c.Query("cursor")
	notifs, next, unread, err := h.svc.GetNotifications(c.Request.Context(), myID, cursor)
	if err != nil {
		fail(c, http.StatusInternalServerError, "failed to get notifications")
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"notifications": notifs,
		"unreadCount":   unread,
		"cursor":        next,
	})
}

// POST /notifications/read-all
func (h *Handler) MarkAllRead(c *gin.Context) {
	if err := h.svc.MarkAllRead(c.Request.Context(), uid(c)); err != nil {
		fail(c, http.StatusInternalServerError, "failed")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /notifications/:id/read
func (h *Handler) MarkOneRead(c *gin.Context) {
	if err := h.svc.MarkOneRead(c.Request.Context(), c.Param("id"), uid(c)); err != nil {
		fail(c, http.StatusInternalServerError, "failed")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// DELETE /notifications/:id
func (h *Handler) Delete(c *gin.Context) {
	if err := h.svc.Delete(c.Request.Context(), c.Param("id"), uid(c)); err != nil {
		fail(c, http.StatusInternalServerError, "failed")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /notifications/push-token
func (h *Handler) SavePushToken(c *gin.Context) {
	var req model.PushTokenReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, "token required")
		return
	}
	if err := h.svc.SavePushToken(c.Request.Context(), uid(c), &req); err != nil {
		fail(c, http.StatusInternalServerError, "failed to save token")
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /internal/notify — called by post-service, user-service
func (h *Handler) CreateNotification(c *gin.Context) {
	var req model.CreateNotifReq
	if err := c.ShouldBindJSON(&req); err != nil {
		fail(c, http.StatusBadRequest, err.Error())
		return
	}
	err := h.svc.Create(c.Request.Context(), &req)
	if err != nil {
		if err.Error() == "duplicate" {
			c.JSON(http.StatusOK, gin.H{"success": true, "skipped": "duplicate"})
			return
		}
		fail(c, http.StatusInternalServerError, "failed to create notification")
		return
	}
	c.JSON(http.StatusCreated, gin.H{"success": true})
}
