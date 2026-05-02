package service

import (
	"context"
	"fmt"
	"time"

	"auth-service/internal/model"
	"auth-service/internal/repository"
	rdb "auth-service/pkg/redis"
	"auth-service/pkg/jwt"

	"golang.org/x/crypto/bcrypt"
)

type AuthService struct {
	repo *repository.AuthRepository
}

func NewAuthService(repo *repository.AuthRepository) *AuthService {
	return &AuthService{repo: repo}
}

func (s *AuthService) Register(ctx context.Context, req *model.RegisterRequest) (*model.TokenPair, error) {
	user, err := s.repo.CreateUser(ctx, req)
	if err != nil {
		return nil, err
	}
	return s.makeTokenPair(user)
}

func (s *AuthService) Login(ctx context.Context, req *model.LoginRequest) (*model.TokenPair, error) {
	user, hash, err := s.repo.GetUserByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("invalid email or password")
	}
	if user.Banned {
		return nil, fmt.Errorf("account banned")
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
		return nil, fmt.Errorf("invalid email or password")
	}
	go s.repo.UpdateLastSeen(context.Background(), user.ID)
	return s.makeTokenPair(user)
}

func (s *AuthService) RefreshTokens(ctx context.Context, refreshToken string) (*model.TokenPair, error) {
	// Check blacklist
	if rdb.Exists("blacklist:refresh:" + refreshToken) {
		return nil, fmt.Errorf("token revoked")
	}
	userID, err := jwt.ParseRefresh(refreshToken)
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}
	// Verify stored refresh token
	stored, err := rdb.Get("refresh:" + userID)
	if err != nil || stored != refreshToken {
		return nil, fmt.Errorf("refresh token expired or invalid")
	}
	// Rotate tokens
	access, err := jwt.MakeAccess(userID)
	if err != nil {
		return nil, err
	}
	refresh, err := jwt.MakeRefresh(userID)
	if err != nil {
		return nil, err
	}
	// Store new refresh, invalidate old
	rdb.Set("refresh:"+userID, refresh, 30*24*time.Hour)
	rdb.Set("blacklist:refresh:"+refreshToken, "1", 30*24*time.Hour)

	return &model.TokenPair{AccessToken: access, RefreshToken: refresh}, nil
}

func (s *AuthService) Logout(ctx context.Context, userID, accessToken, refreshToken string) error {
	rdb.Del("refresh:" + userID)
	if accessToken != "" {
		rdb.Set("blacklist:"+accessToken, "1", 7*24*time.Hour)
	}
	if refreshToken != "" {
		rdb.Set("blacklist:refresh:"+refreshToken, "1", 30*24*time.Hour)
	}
	return nil
}

func (s *AuthService) ForgotPassword(ctx context.Context, email string) (string, error) {
	// Check user exists
	_, _, err := s.repo.GetUserByEmail(ctx, email)
	if err != nil {
		// Don't reveal if email exists
		return "", nil
	}
	otp := repository.GenerateOTP()
	if err := s.repo.SaveOTP(email, otp); err != nil {
		return "", err
	}
	return otp, nil
}

func (s *AuthService) ResetPassword(ctx context.Context, req *model.ResetPasswordRequest) error {
	if !s.repo.ValidateOTP(req.Email, req.OTP) {
		return fmt.Errorf("invalid or expired OTP")
	}
	if err := s.repo.UpdatePassword(ctx, req.Email, req.NewPassword); err != nil {
		return err
	}
	s.repo.DeleteOTP(req.Email)
	return nil
}

func (s *AuthService) ValidateToken(ctx context.Context, tokenStr string) (string, error) {
	// Check blacklist
	if rdb.Exists("blacklist:" + tokenStr) {
		return "", fmt.Errorf("token revoked")
	}
	return jwt.ParseAccess(tokenStr)
}

// ── private ───────────────────────────────────────────────────────
func (s *AuthService) makeTokenPair(user *model.User) (*model.TokenPair, error) {
	access, err := jwt.MakeAccess(user.ID)
	if err != nil {
		return nil, err
	}
	refresh, err := jwt.MakeRefresh(user.ID)
	if err != nil {
		return nil, err
	}
	// Store refresh token in Redis TTL 30 days
	rdb.Set("refresh:"+user.ID, refresh, 30*24*time.Hour)
	return &model.TokenPair{
		AccessToken:  access,
		RefreshToken: refresh,
		User:         user,
	}, nil
}
