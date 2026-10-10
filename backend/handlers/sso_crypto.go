package handlers

// Рамзгузории token-и TajikShop дар база.
//
// Refresh-token-и TajikShop 30 рӯз сессияи пурра медиҳад. Агар он дар
// база кушода монад, ҳар кӣ нусхаи базаро бинад (backup, SQL-и бегона)
// ба ҳисоби TajikShop-и ҳамаи корбарон ворид мешавад. Барои ҳамин:
//
//   калид = HKDF-SHA256(SSO_TOKEN_KEY ё JWT_SECRET, salt, info)
//   сабт  = "v1:" + base64url(nonce ‖ AES-256-GCM(token))
//
// Калид дар база нест ва ҳеҷ гоҳ ба log намеравад. Агар SSO_TOKEN_KEY
// иваз шавад, token-ҳои кӯҳна кушода намешаванд — корбар танҳо як бор
// TajikShop-ро бе гузариши худкор мекушояд (ниг. TajikshopSSOHandoff).

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"io"
	"os"
	"strings"

	mw "raonson/middleware"

	"golang.org/x/crypto/hkdf"
)

const ssoSealPrefix = "v1:"

var errSSOSeal = errors.New("sso: token кушода нашуд")

// ssoTokenKey — 32 байт аз сирри сервер. SSO_TOKEN_KEY бартарӣ дорад: бо
// он ивази JWT_SECRET token-ҳои захирашударо намесӯзонад.
func ssoTokenKey() []byte {
	secret := strings.TrimSpace(os.Getenv("SSO_TOKEN_KEY"))
	if secret == "" {
		secret = mw.JWTSecret()
	}
	r := hkdf.New(sha256.New, []byte(secret),
		[]byte("raonson-sso-v1"), []byte("tajikshop-refresh-token"))
	key := make([]byte, 32)
	if _, err := io.ReadFull(r, key); err != nil {
		// HKDF барои 32 байт хато намедиҳад; агар шавад — калиди тасодуфӣ
		// (token кушода намешавад, вале ҳеҷ гоҳ бо калиди маълум).
		rand.Read(key)
	}
	return key
}

// sealSSOToken — token-ро рамзгузорӣ мекунад. Холӣ → холӣ.
func sealSSOToken(plain string) (string, error) {
	if plain == "" {
		return "", nil
	}
	block, err := aes.NewCipher(ssoTokenKey())
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return "", err
	}
	out := gcm.Seal(nonce, nonce, []byte(plain), []byte("tajikshop"))
	return ssoSealPrefix + base64.RawURLEncoding.EncodeToString(out), nil
}

// openSSOToken — баръакси sealSSOToken. Холӣ → холӣ.
func openSSOToken(sealed string) (string, error) {
	if sealed == "" {
		return "", nil
	}
	if !strings.HasPrefix(sealed, ssoSealPrefix) {
		return "", errSSOSeal
	}
	raw, err := base64.RawURLEncoding.DecodeString(sealed[len(ssoSealPrefix):])
	if err != nil {
		return "", errSSOSeal
	}
	block, err := aes.NewCipher(ssoTokenKey())
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(raw) < gcm.NonceSize()+gcm.Overhead() {
		return "", errSSOSeal
	}
	plain, err := gcm.Open(nil, raw[:gcm.NonceSize()], raw[gcm.NonceSize():], []byte("tajikshop"))
	if err != nil {
		return "", errSSOSeal
	}
	return string(plain), nil
}
