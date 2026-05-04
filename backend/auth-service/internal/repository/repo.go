package repository

import (
	"context"
	"fmt"
	"math/rand"
	"strings"
	"time"

	"auth-service/internal/model"
	rdb "auth-service/pkg/redis"

	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type AuthRepository struct {
	db *pgxpool.Pool
}

func NewAuthRepository(db *pgxpool.Pool) *AuthRepository {
	return &AuthRepository{db: db}
}

func (r *AuthRepository) CreateUser(ctx context.Context, req *model.RegisterRequest) (*model.User, error) {
	req.Username = strings.ToLower(strings.TrimSpace(req.Username))
	req.Email = strings.ToLower(strings.TrimSpace(req.Email))

	// Check exists
	var exists bool
	r.db.QueryRow(ctx,
		`SELECT EXISTS(SELECT 1 FROM users WHERE email=$1 OR username=$2)`,
		req.Email, req.Username,
	).Scan(&exists)
	if exists {
		return nil, fmt.Errorf("username or email already taken")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), 10)
	if err != nil {
		return nil, err
	}

	var u model.User
	err = r.db.QueryRow(ctx,
		`INSERT INTO users(username,email,password)
		 VALUES($1,$2,$3)
		 RETURNING id, username, email, avatar, verified, banned, role, created_at`,
		req.Username, req.Email, string(hash),
	).Scan(&u.ID, &u.Username, &u.Email, &u.Avatar, &u.Verified, &u.Banned, &u.Role, &u.CreatedAt)
	if err != nil {
		if strings.Contains(err.Error(), "unique") {
			return nil, fmt.Errorf("username or email already taken")
		}
		return nil, err
	}
	return &u, nil
}

func (r *AuthRepository) GetUserByEmail(ctx context.Context, email string) (*model.User, string, error) {
	email = strings.ToLower(strings.TrimSpace(email))
	var u model.User
	var hash string
	err := r.db.QueryRow(ctx,
		`SELECT id, username, email, password, avatar, verified, banned, role, created_at
		 FROM users WHERE email=$1`, email,
	).Scan(&u.ID, &u.Username, &u.Email, &hash, &u.Avatar, &u.Verified, &u.Banned, &u.Role, &u.CreatedAt)
	if err != nil {
		return nil, "", err
	}
	return &u, hash, nil
}

func (r *AuthRepository) UpdateLastSeen(ctx context.Context, userID string) {
	r.db.Exec(ctx, `UPDATE users SET last_seen=NOW() WHERE id=$1`, userID)
}

func (r *AuthRepository) UpdatePassword(ctx context.Context, email, newPassword string) error {
	hash, err := bcrypt.GenerateFromPassword([]byte(newPassword), 10)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(ctx,
		`UPDATE users SET password=$1, updated_at=NOW() WHERE email=$2`,
		string(hash), strings.ToLower(email),
	)
	return err
}

// OTP stored in Redis TTL 10 min
func (r *AuthRepository) SaveOTP(email, otp string) error {
	return rdb.Set("otp:"+strings.ToLower(email), otp, 10*time.Minute)
}

func (r *AuthRepository) ValidateOTP(email, otp string) bool {
	stored, err := rdb.Get("otp:" + strings.ToLower(email))
	if err != nil {
		return false
	}
	return stored == otp
}

func (r *AuthRepository) DeleteOTP(email string) {
	rdb.Del("otp:" + strings.ToLower(email))
}

func GenerateOTP() string {
	return fmt.Sprintf("%06d", rand.New(rand.NewSource(time.Now().UnixNano())).Intn(1000000))
}
