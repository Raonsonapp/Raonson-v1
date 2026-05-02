package jwt

import (
	"errors"
	"os"
	"time"

	gojwt "github.com/golang-jwt/jwt/v5"
)

func secret() []byte {
	s := os.Getenv("JWT_SECRET")
	if s == "" {
		s = "raonson-secret-change-in-prod"
	}
	return []byte(s)
}

func refreshSecret() []byte {
	s := os.Getenv("JWT_REFRESH_SECRET")
	if s == "" {
		s = "raonson-refresh-secret-change-in-prod"
	}
	return []byte(s)
}

func MakeAccess(userID string) (string, error) {
	t := gojwt.NewWithClaims(gojwt.SigningMethodHS256, gojwt.MapClaims{
		"id":  userID,
		"exp": time.Now().Add(7 * 24 * time.Hour).Unix(),
		"iat": time.Now().Unix(),
	})
	return t.SignedString(secret())
}

func MakeRefresh(userID string) (string, error) {
	t := gojwt.NewWithClaims(gojwt.SigningMethodHS256, gojwt.MapClaims{
		"id":   userID,
		"type": "refresh",
		"exp":  time.Now().Add(30 * 24 * time.Hour).Unix(),
		"iat":  time.Now().Unix(),
	})
	return t.SignedString(refreshSecret())
}

func ParseAccess(tokenStr string) (string, error) {
	tok, err := gojwt.Parse(tokenStr,
		func(t *gojwt.Token) (interface{}, error) { return secret(), nil },
		gojwt.WithValidMethods([]string{"HS256"}),
	)
	if err != nil || !tok.Valid {
		return "", errors.New("invalid token")
	}
	claims := tok.Claims.(gojwt.MapClaims)
	id, ok := claims["id"].(string)
	if !ok {
		return "", errors.New("invalid claims")
	}
	return id, nil
}

func ParseRefresh(tokenStr string) (string, error) {
	tok, err := gojwt.Parse(tokenStr,
		func(t *gojwt.Token) (interface{}, error) { return refreshSecret(), nil },
		gojwt.WithValidMethods([]string{"HS256"}),
	)
	if err != nil || !tok.Valid {
		return "", errors.New("invalid refresh token")
	}
	claims := tok.Claims.(gojwt.MapClaims)
	id, ok := claims["id"].(string)
	if !ok {
		return "", errors.New("invalid claims")
	}
	return id, nil
}
