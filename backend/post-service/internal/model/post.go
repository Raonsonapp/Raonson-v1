package model

import "time"

type Post struct {
	ID            string        `json:"_id"`
	UserID        string        `json:"userID,omitempty"`
	Caption       string        `json:"caption"`
	LikesCount    int           `json:"likesCount"`
	CommentsCount int           `json:"commentsCount"`
	Media         []MediaItem   `json:"media"`
	User          *PostUser     `json:"user,omitempty"`
	Liked         bool          `json:"liked"`
	Saved         bool          `json:"saved"`
	Hidden        bool          `json:"hidden,omitempty"`
	CreatedAt     time.Time     `json:"createdAt"`
}

type MediaItem struct {
	URL      string `json:"url"`
	Type     string `json:"type"`
	Position int    `json:"position,omitempty"`
}

type PostUser struct {
	ID       string `json:"_id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
	Verified bool   `json:"verified"`
}

type Comment struct {
	ID         string    `json:"_id"`
	PostID     string    `json:"postID,omitempty"`
	Text       string    `json:"text"`
	LikesCount int       `json:"likesCount"`
	Liked      bool      `json:"liked"`
	User       *PostUser `json:"user"`
	CreatedAt  time.Time `json:"createdAt"`
}

type CreatePostRequest struct {
	Caption string                   `json:"caption"`
	Media   []map[string]interface{} `json:"media" binding:"required,min=1"`
}

type CreateCommentRequest struct {
	Text string `json:"text" binding:"required,min=1,max=500"`
}

type UpdateCaptionRequest struct {
	Caption string `json:"caption"`
}
