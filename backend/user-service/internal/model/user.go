package model

import "time"

type User struct {
	ID             string      `json:"_id"`
	Username       string      `json:"username"`
	Email          string      `json:"email,omitempty"`
	Avatar         string      `json:"avatar"`
	Bio            string      `json:"bio"`
	Website        string      `json:"website"`
	Location       string      `json:"location"`
	Verified       bool        `json:"verified"`
	IsPrivate      bool        `json:"isPrivate"`
	Banned         bool        `json:"banned,omitempty"`
	Role           string      `json:"role,omitempty"`
	PostsCount     int         `json:"postsCount"`
	FollowersCount int         `json:"followersCount"`
	FollowingCount int         `json:"followingCount"`
	IsFollowing    bool        `json:"isFollowing"`
	LastSeen       *time.Time  `json:"lastSeen"`
	Note           string      `json:"note"`
	NoteExpiresAt  *time.Time  `json:"noteExpiresAt"`
	NoteSong       *NoteSong   `json:"noteSong"`
	CreatedAt      time.Time   `json:"createdAt"`
}

type NoteSong struct {
	Title      string `json:"title"`
	Artist     string `json:"artist"`
	ArtURL     string `json:"artUrl"`
	PreviewURL string `json:"previewUrl"`
	TrackMs    int    `json:"trackMs"`
	StartMs    int    `json:"startMs"`
	EndMs      int    `json:"endMs"`
}

type UpdateProfileRequest struct {
	Bio       *string `json:"bio"`
	Avatar    *string `json:"avatar"`
	IsPrivate *bool   `json:"isPrivate"`
	Username  *string `json:"username"`
	Website   *string `json:"website"`
	Location  *string `json:"location"`
}

type SetNoteRequest struct {
	Note string                 `json:"note"`
	Song map[string]interface{} `json:"song"`
}

type MiniUser struct {
	ID       string `json:"_id"`
	Username string `json:"username"`
	Avatar   string `json:"avatar"`
	Verified bool   `json:"verified"`
	Bio      string `json:"bio"`
}
