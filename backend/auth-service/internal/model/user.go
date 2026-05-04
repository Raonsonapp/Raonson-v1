package model

import "time"

type User struct {
	ID        string    `json:"_id"`
	Username  string    `json:"username"`
	Email     string    `json:"email,omitempty"`
	Avatar    string    `json:"avatar"`
	Bio       string    `json:"bio"`
	Verified  bool      `json:"verified"`
	Banned    bool      `json:"banned,omitempty"`
	Role      string    `json:"role"`
	CreatedAt time.Time `json:"createdAt"`
}

type RegisterReq struct {
	Username string `json:"username" binding:"required,min=3,max=30"`
	Email    string `json:"email"    binding:"required,email"`
	Password string `json:"password" binding:"required,min=6"`
}

type LoginReq struct {
	Email    string `json:"email"    binding:"required"`
	Password string `json:"password" binding:"required"`
}

type RefreshReq struct {
	RefreshToken string `json:"refreshToken" binding:"required"`
}

type ForgotReq struct {
	Email string `json:"email" binding:"required,email"`
}

type ResetReq struct {
	Email    string `json:"email"       binding:"required"`
	OTP      string `json:"otp"         binding:"required"`
	Password string `json:"newPassword" binding:"required,min=6"`
}

type TokenPair struct {
	AccessToken  string `json:"accessToken"`
	RefreshToken string `json:"refreshToken"`
	User         *User  `json:"user,omitempty"`
}
