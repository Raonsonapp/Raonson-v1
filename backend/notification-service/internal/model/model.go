package model

import "time"

type Notification struct {
	ID        string     `json:"_id"`
	Type      string     `json:"type"`
	TargetID  string     `json:"targetID"`
	Read      bool       `json:"read"`
	CreatedAt time.Time  `json:"createdAt"`
	FromUser  *NotifUser `json:"fromUser"`
}

type NotifUser struct {
	ID       string `json:"_id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
}

// CreateNotifReq is used internally (post→notif, user→notif)
type CreateNotifReq struct {
	UserID     string `json:"userID"     binding:"required"`
	FromUserID string `json:"fromUserID" binding:"required"`
	Type       string `json:"type"       binding:"required"`
	TargetID   string `json:"targetID"`
}

type PushTokenReq struct {
	Token    string `json:"token"    binding:"required"`
	Platform string `json:"platform"`
}
