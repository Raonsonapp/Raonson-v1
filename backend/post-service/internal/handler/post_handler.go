package handler

import (
	"net/http"
	"strconv"

	"post-service/internal/model"
	"post-service/internal/service"

	"github.com/gin-gonic/gin"
)

type PostHandler struct {
	svc *service.PostService
}

func NewPostHandler(svc *service.PostService) *PostHandler {
	return &PostHandler{svc: svc}
}

func uid(c *gin.Context) string {
	v, _ := c.Get("userID")
	s, _ := v.(string)
	return s
}

func toInt(s string, def int) int {
	if n, err := strconv.Atoi(s); err == nil && n > 0 { return n }
	return def
}

// POST /posts
func (h *PostHandler) CreatePost(c *gin.Context) {
	myID := uid(c)
	var req model.CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil || len(req.Media) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "At least one media item required"})
		return
	}
	post, err := h.svc.CreatePost(c.Request.Context(), myID, &req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Create post failed"})
		return
	}
	c.JSON(http.StatusCreated, post)
}

// GET /posts/:id
func (h *PostHandler) GetPost(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	post, err := h.svc.GetPost(c.Request.Context(), postID, myID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "Post not found"})
		return
	}
	c.JSON(http.StatusOK, post)
}

// DELETE /posts/:id
func (h *PostHandler) DeletePost(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	if err := h.svc.DeletePost(c.Request.Context(), postID, myID); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// PUT /posts/:id/caption
func (h *PostHandler) UpdateCaption(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	var req model.UpdateCaptionRequest
	c.ShouldBindJSON(&req)
	if err := h.svc.UpdateCaption(c.Request.Context(), postID, myID, req.Caption); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /posts/:id/like
func (h *PostHandler) ToggleLike(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	liked, count, err := h.svc.ToggleLike(c.Request.Context(), postID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Like failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"liked": liked, "likesCount": count})
}

// POST /posts/:id/save
func (h *PostHandler) ToggleSave(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	saved, err := h.svc.ToggleSave(c.Request.Context(), postID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Save failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"saved": saved})
}

// POST /posts/:id/report
func (h *PostHandler) ReportPost(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	var b struct{ Reason string `json:"reason"` }
	c.ShouldBindJSON(&b)
	if b.Reason == "" { b.Reason = "spam" }
	h.svc.ReportPost(c.Request.Context(), postID, myID, b.Reason)
	c.JSON(http.StatusOK, gin.H{"reported": true})
}

// POST /posts/view/:id
func (h *PostHandler) TrackView(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	h.svc.TrackView(c.Request.Context(), postID, myID)
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /comments/:id
func (h *PostHandler) GetComments(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	cursor := c.Query("cursor")
	comments, nextCursor, err := h.svc.GetComments(c.Request.Context(), postID, myID, cursor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get comments failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"comments": comments, "cursor": nextCursor})
}

// POST /comments/:id
func (h *PostHandler) AddComment(c *gin.Context) {
	postID := c.Param("id")
	myID := uid(c)
	var req model.CreateCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
		return
	}
	comment, err := h.svc.AddComment(c.Request.Context(), postID, myID, req.Text)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Add comment failed"})
		return
	}
	c.JSON(http.StatusCreated, comment)
}

// DELETE /comments/:id
func (h *PostHandler) DeleteComment(c *gin.Context) {
	commentID := c.Param("id")
	myID := uid(c)
	if err := h.svc.DeleteComment(c.Request.Context(), commentID, myID); err != nil {
		c.JSON(http.StatusForbidden, gin.H{"message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true})
}

// POST /comments/:id/like
func (h *PostHandler) ToggleCommentLike(c *gin.Context) {
	commentID := c.Param("id")
	myID := uid(c)
	liked, err := h.svc.ToggleCommentLike(c.Request.Context(), commentID, myID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Like failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"liked": liked})
}

// GET /users/:id/posts
func (h *PostHandler) GetUserPosts(c *gin.Context) {
	userID := c.Param("id")
	cursor := c.Query("cursor")
	posts, nextCursor, err := h.svc.GetUserPosts(c.Request.Context(), userID, cursor)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"message": "Get posts failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"posts": posts, "cursor": nextCursor})
}
