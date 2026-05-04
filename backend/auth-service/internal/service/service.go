package service

import (
	"context"
	"fmt"
	"os"
	"time"

	"auth-service/internal/model"
	"auth-service/internal/repository"
	rdb "auth-service/pkg/redis"

	gojwt "github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

type Service struct{ repo *repository.Repo }

func New(repo *repository.Repo) *Service { return &Service{repo: repo} }

// ── Register ──────────────────────────────────────────────────────
func (s *Service) Register(ctx context.Context, req *model.RegisterReq) (*model.TokenPair, error) {
	u, err := s.repo.Create(ctx, req)
	if err != nil {
		return nil, err
	}
	return s.pair(u)
}

// ── Login ─────────────────────────────────────────────────────────
func (s *Service) Login(ctx context.Context, req *model.LoginReq) (*model.TokenPair, error) {
	u, hash, err := s.repo.GetByEmail(ctx, req.Email)
	if err != nil {
		return nil, fmt.Errorf("invalid credentials")
	}
	if u.Banned {
		return nil, fmt.Errorf("account suspended")
	}
	if bcrypt.CompareHashAndPassword([]byte(hash), []byte(req.Password)) != nil {
		return nil, fmt.Errorf("invalid credentials")
	}
	go s.repo.TouchLastSeen(context.Background(), u.ID)
	return s.pair(u)
}

// ── Refresh ───────────────────────────────────────────────────────
func (s *Service) Refresh(refreshToken string) (*model.TokenPair, error) {
	if rdb.Exists("blacklist:refresh:" + refreshToken) {
		return nil, fmt.Errorf("token revoked")
	}
	uid, err := parseToken(refreshToken, refreshSecret())
	if err != nil {
		return nil, fmt.Errorf("invalid refresh token")
	}
	stored, err := rdb.Get("refresh:" + uid)
	if err != nil || stored != refreshToken {
		return nil, fmt.Errorf("refresh token expired")
	}
	access, _ := makeToken(uid, jwtSecret(), 7*24*time.Hour)
	refresh, _ := makeToken(uid, refreshSecret(), 30*24*time.Hour)
	rdb.Set("refresh:"+uid, refresh, 30*24*time.Hour)
	rdb.Set("blacklist:refresh:"+refreshToken, "1", 30*24*time.Hour)
	return &model.TokenPair{AccessToken: access, RefreshToken: refresh}, nil
}

// ── Logout ────────────────────────────────────────────────────────
func (s *Service) Logout(uid, accessToken, refreshToken string) {
	rdb.Del("refresh:" + uid)
	if accessToken != "" {
		rdb.Set("blacklist:"+accessToken, "1", 7*24*time.Hour)
	}
	if refreshToken != "" {
		rdb.Set("blacklist:refresh:"+refreshToken, "1", 30*24*time.Hour)
	}
}

// ── ForgotPassword ────────────────────────────────────────────────
func (s *Service) ForgotPassword(ctx context.Context, email string) (string, error) {
	_, _, err := s.repo.GetByEmail(ctx, email)
	if err != nil {
		return "", nil // don't reveal
	}
	otp := repository.OTP()
	s.repo.SaveOTP(email, otp)
	return otp, nil
}

// ── ResetPassword ─────────────────────────────────────────────────
func (s *Service) ResetPassword(ctx context.Context, req *model.ResetReq) error {
	if !s.repo.VerifyOTP(req.Email, req.OTP) {
		return fmt.Errorf("invalid or expired OTP")
	}
	if err := s.repo.UpdatePassword(ctx, req.Email, req.Password); err != nil {
		return err
	}
	s.repo.DeleteOTP(req.Email)
	return nil
}

// ── ValidateToken — for Nginx auth_request ───────────────────────
func (s *Service) ValidateToken(token string) (string, error) {
	if rdb.Exists("blacklist:" + token) {
		return "", fmt.Errorf("revoked")
	}
	return parseToken(token, jwtSecret())
}

// ── private ───────────────────────────────────────────────────────
func (s *Service) pair(u *model.User) (*model.TokenPair, error) {
	access, err := makeToken(u.ID, jwtSecret(), 7*24*time.Hour)
	if err != nil {
		return nil, err
	}
	refresh, err := makeToken(u.ID, refreshSecret(), 30*24*time.Hour)
	if err != nil {
		return nil, err
	}
	rdb.Set("refresh:"+u.ID, refresh, 30*24*time.Hour)
	return &model.TokenPair{AccessToken: access, RefreshToken: refresh, User: u}, nil
}

func makeToken(uid, secret string, ttl time.Duration) (string, error) {
	t := gojwt.NewWithClaims(gojwt.SigningMethodHS256, gojwt.MapClaims{
		"id": uid, "exp": time.Now().Add(ttl).Unix(), "iat": time.Now().Unix(),
	})
	return t.SignedString([]byte(secret))
}

func parseToken(token, secret string) (string, error) {
	t, err := gojwt.Parse(token,
		func(t *gojwt.Token) (interface{}, error) { return []byte(secret), nil },
		gojwt.WithValidMethods([]string{"HS256"}))
	if err != nil || !t.Valid {
		return "", fmt.Errorf("invalid token")
	}
	claims := t.Claims.(gojwt.MapClaims)
	uid, _ := claims["id"].(string)
	return uid, nil
}

func jwtSecret() string     { return getenv("JWT_SECRET", "change_me") }
func refreshSecret() string { return getenv("JWT_REFRESH_SECRET", "refresh_change_me") }
func getenv(k, fb string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return fb
}
