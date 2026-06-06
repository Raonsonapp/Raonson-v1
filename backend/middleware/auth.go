package middleware

import (
	"context"
	"net/http"
	"os"
	"strings"

	"raonson/db"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
)

func Auth() gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "No token"})
			c.Abort()
			return
		}
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || strings.ToLower(parts[0]) != "bearer" {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token format"})
			c.Abort()
			return
		}
		secret := jwtSecret()
		tok, err := jwt.Parse(parts[1], func(t *jwt.Token) (interface{}, error) {
			return []byte(secret), nil
		}, jwt.WithValidMethods([]string{"HS256"}))
		if err != nil || !tok.Valid {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "Invalid token"})
			c.Abort()
			return
		}
		claims := tok.Claims.(jwt.MapClaims)
		c.Set("userID", claims["id"].(string))
		if role, ok := claims["role"].(string); ok {
			c.Set("role", role)
		} else {
			c.Set("role", "user")
		}
		c.Next()
	}
}

// AdminOnly — нақшро аз DB мегирад (JWT нақшро надорад), то соҳиби
// барнома (@raonson) ва ҳар admin-и дигар ҳамеша дастрасӣ дошта бошад.
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		uid := UID(c)
		var role string
		if uid != "" {
			db.Pool.QueryRow(context.Background(),
				`SELECT COALESCE(role,'user') FROM users WHERE id=$1`, uid).Scan(&role)
		}
		if role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Insufficient permissions"})
			c.Abort()
			return
		}
		c.Set("role", role)
		c.Next()
	}
}

func UID(c *gin.Context) string {
	v, _ := c.Get("userID")
	s, _ := v.(string)
	return s
}

func jwtSecret() string {
	if s := os.Getenv("JWT_SECRET"); s != "" {
		return s
	}
	return "RAONSON_SECRET"
}

func RefreshSecret() string {
	if s := os.Getenv("JWT_REFRESH_SECRET"); s != "" {
		return s
	}
	return "RAONSON_REFRESH_SECRET"
}

func JWTSecret() string { return jwtSecret() }
