package handler

import (
	"net/http"

	"user-service/internal/model"
	"user-service/internal/service"

	"github.com/gin-gonic/gin"
)

type UserHandler struct {
	svc *service.UserService
}

func NewUserHandler(svc *service.UserService) *UserHandler {
	return &UserHandler{svc: svc}
}

func uid(c *gin.Context) string {
	v, _ := c.Get("userID")
	s, _ := v.(string)
	return s
}

// GET /profile/me
func (h *UserHandler) GetMyProfile(c *gin.Context) {
	myID := uid(c)
	user, posts, err := h.svc.GetMyProfile(c.Request.Context(), myID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user, "posts": posts})
}

// GET /profile/:username
func (h *UserHandler) GetProfile(c *gin.Context) {
	username := c.Param("username")
	myID := uid(c)
	user, posts, err := h.svc.GetProfileByUsername(c.Request.Context(), username, myID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Profile not found"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"user": user, "posts": posts})
}

// GET /users/:id
func (h *UserHandler) GetUserByID(c *gin.Context) {
	targetID := c.Param("id")
	myID := uid(c)
	user, err := h.svc.GetUserByID(c.Request.Context(), targetID, myID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "User not found"})
		return
	}
	c.JSON(http.StatusOK, user)
}

// PUT /profile
func (h *UserHandler) UpdateProfile(c *gin.Context) {
	myID := uid(c)
	var req model.UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Bad request"})
		return
	}
	user, err := h.svc.UpdateProfile(c.Request.Context(), myID, &req)
	if err != nil {
		if err.Error() == "username already taken" {
			c.JSON(http.StatusConflict, gin.H{"message": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Update failed"})
		return
	}
	c.JSON(http.StatusOK, user)
}

// POST /profile/note
func (h *UserHandler) SetNote(c *gin.Context) {
	myID := uid(c)
	var req model.SetNoteRequest
	c.ShouldBindJSON(&req)
	if err := h.svc.SetNote(c.Request.Context(), myID, &req); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed to set note"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"note": req.Note})
}

// GET /profile/notes/friends
func (h *UserHandler) GetFriendsNotes(c *gin.Context) {
	myID := uid(c)
	notes, err := h.svc.GetFriendsNotes(c.Request.Context(), myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get notes failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"notes": notes})
}

// POST /follow/:id
func (h *UserHandler) Follow(c *gin.Context) {
	myID := uid(c)
	targetID := c.Param("id")
	status, err := h.svc.Follow(c.Request.Context(), myID, targetID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": status})
}

// DELETE /follow/:id
func (h *UserHandler) Unfollow(c *gin.Context) {
	myID := uid(c)
	targetID := c.Param("id")
	if err := h.svc.Unfollow(c.Request.Context(), myID, targetID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Unfollow failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// GET /follow/:id/followers
func (h *UserHandler) GetFollowers(c *gin.Context) {
	targetID := c.Param("id")
	cursor := c.Query("cursor")
	users, nextCursor, err := h.svc.GetFollowers(c.Request.Context(), targetID, cursor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"users": users, "cursor": nextCursor})
}

// GET /follow/:id/following
func (h *UserHandler) GetFollowing(c *gin.Context) {
	targetID := c.Param("id")
	cursor := c.Query("cursor")
	users, nextCursor, err := h.svc.GetFollowing(c.Request.Context(), targetID, cursor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"users": users, "cursor": nextCursor})
}

// POST /follow/request/:id/accept
func (h *UserHandler) AcceptRequest(c *gin.Context) {
	myID := uid(c)
	requesterID := c.Param("id")
	if err := h.svc.AcceptRequest(c.Request.Context(), myID, requesterID); err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /follow/request/:id/reject
func (h *UserHandler) RejectRequest(c *gin.Context) {
	myID := uid(c)
	requesterID := c.Param("id")
	h.svc.RejectRequest(c.Request.Context(), myID, requesterID)
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// GET /search/users?q=...
func (h *UserHandler) SearchUsers(c *gin.Context) {
	q := c.Query("q")
	users, err := h.svc.SearchUsers(c.Request.Context(), q)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Search failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"users": users})
}

// DELETE /users
func (h *UserHandler) DeleteUser(c *gin.Context) {
	myID := uid(c)
	if err := h.svc.DeleteUser(c.Request.Context(), myID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Delete failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}
