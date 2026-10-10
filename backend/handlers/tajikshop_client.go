package handlers

// Мизоҷи API-и TajikShop (провайдери шахсият).
//
// Шартнома: tajikshop/docs/SSO_RAONSON.md. Ҷавобҳо дар шакли
// {success, data} ё {success:false, error}. Калиди шарик танҳо дар
// сервер аст (SSO_PARTNER_KEY) — барнома онро ҳеҷ гоҳ намебинад.
//
// ⚠️ /sso/exchange ТАКРОР НАМЕШАВАД: код якдафъаина аст ва такрор
// танҳо «Код нодуруст» медиҳад, ҳатто агар дархости аввал ба TajikShop
// расида бошад.

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strings"
	"time"
)

const (
	defaultTajikshopAPI      = "https://mahmadmurodov-tajikshop.hf.space/api/v1"
	defaultTajikshopFallback = "https://play.google.com/store/apps/details?id=com.tajikshop.app"
	tajikshopTimeout         = 15 * time.Second
)

// Код: base64url, на дарозтар аз 64 аломат (TajikShop 43 медиҳад).
var ssoCodeRe = regexp.MustCompile(`^[A-Za-z0-9_-]{16,64}$`)

func validSSOCode(code string) bool { return ssoCodeRe.MatchString(code) }

// tajikshopBase — суроғаи API бе «/» дар охир.
func tajikshopBase() string {
	b := strings.TrimSpace(os.Getenv("TAJIKSHOP_API"))
	if b == "" {
		b = defaultTajikshopAPI
	}
	return strings.TrimRight(b, "/")
}

// tajikshopPartnerKey — SSO_PARTNER_KEY (номи асосӣ) ё TAJIKSHOP_PARTNER_KEY.
func tajikshopPartnerKey() string {
	if k := strings.TrimSpace(os.Getenv("SSO_PARTNER_KEY")); k != "" {
		return k
	}
	return strings.TrimSpace(os.Getenv("TAJIKSHOP_PARTNER_KEY"))
}

func tajikshopFallback() string {
	if f := strings.TrimSpace(os.Getenv("TAJIKSHOP_FALLBACK_URL")); f != "" {
		return f
	}
	return defaultTajikshopFallback
}

var tajikshopHTTP = &http.Client{Timeout: tajikshopTimeout}

// tsError — ҷавоби ғайри-2xx аз TajikShop (ё хатои шабака: Status=0).
type tsError struct {
	Status int
	Msg    string
}

func (e *tsError) Error() string { return fmt.Sprintf("tajikshop %d: %s", e.Status, e.Msg) }

// tsID — шиносаи корбар: TajikShop uuid медиҳад, вале рақамро ҳам мегирем.
type tsID string

func (t *tsID) UnmarshalJSON(b []byte) error {
	var s string
	if json.Unmarshal(b, &s) == nil {
		*t = tsID(strings.TrimSpace(s))
		return nil
	}
	var n json.Number
	if err := json.Unmarshal(b, &n); err != nil {
		return err
	}
	*t = tsID(n.String())
	return nil
}

type tsUser struct {
	ID         tsID   `json:"id"`
	Name       string `json:"name"`
	Email      string `json:"email"`
	AvatarURL  string `json:"avatar_url"`
	IsVerified bool   `json:"is_verified"`
	// Почта тасдиқ шудааст? TajikShop ҳоло инро намедиҳад (is_verified —
	// тасдиқи фурӯшанда/KYC, на почта). Агар илова шавад — истифода мешавад.
	EmailVerified *bool `json:"email_verified"`
}

type tsExchange struct {
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	User         tsUser `json:"user"`
}

// tsCall — POST ба TajikShop; data-и {success,data}-ро ба out мехонад.
func tsCall(ctx context.Context, path string, body any, headers map[string]string, out any) error {
	buf, _ := json.Marshal(body)
	ctx, cancel := context.WithTimeout(ctx, tajikshopTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, tajikshopBase()+path, bytes.NewReader(buf))
	if err != nil {
		return &tsError{Status: 0, Msg: "bad request"}
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	res, err := tajikshopHTTP.Do(req)
	if err != nil {
		// Матни хато суроғаро дорад, вале ҳеҷ код/token — бехатар барои log.
		return &tsError{Status: 0, Msg: "network"}
	}
	defer res.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	var env struct {
		Success bool            `json:"success"`
		Data    json.RawMessage `json:"data"`
		Error   string          `json:"error"`
		Message string          `json:"message"`
	}
	_ = json.Unmarshal(raw, &env)
	if res.StatusCode < 200 || res.StatusCode >= 300 {
		msg := env.Error
		if msg == "" {
			msg = env.Message
		}
		return &tsError{Status: res.StatusCode, Msg: msg}
	}
	data := env.Data
	if len(data) == 0 {
		data = raw // ҷавоби бе {data}
	}
	if out != nil {
		if err := json.Unmarshal(data, out); err != nil {
			return &tsError{Status: 502, Msg: "bad json"}
		}
	}
	return nil
}

// tsExchangeCode — POST /sso/exchange {code, app:"raonson"} + X-Partner-Key.
func tsExchangeCode(ctx context.Context, code string) (*tsExchange, error) {
	var out tsExchange
	err := tsCall(ctx, "/sso/exchange", map[string]string{"code": code, "app": "raonson"},
		map[string]string{"X-Partner-Key": tajikshopPartnerKey()}, &out)
	if err != nil {
		return nil, err
	}
	if out.User.ID == "" {
		return nil, &tsError{Status: 502, Msg: "no user"}
	}
	return &out, nil
}

// tsRefresh — POST /auth/refresh. TajikShop ҳоло refresh-token-ро
// иваз намекунад; агар нав диҳад (ротатсия) — онро бармегардонем.
func tsRefresh(ctx context.Context, refresh string) (access, newRefresh string, err error) {
	var out struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token"`
	}
	if err = tsCall(ctx, "/auth/refresh", map[string]string{"refresh_token": refresh}, nil, &out); err != nil {
		return "", "", err
	}
	if out.AccessToken == "" {
		return "", "", &tsError{Status: 502, Msg: "no access token"}
	}
	return out.AccessToken, out.RefreshToken, nil
}

// tsIssueCode — POST /sso/code {target_app:"tajikshop"} бо Bearer.
// deep_link-ро худамон месозем (аз коди санҷидашуда), на аз ҷавоб.
func tsIssueCode(ctx context.Context, access string) (deepLink, fallback string, err error) {
	var out struct {
		Code     string `json:"code"`
		Fallback string `json:"fallback"`
	}
	if err = tsCall(ctx, "/sso/code", map[string]string{"target_app": "tajikshop"},
		map[string]string{"Authorization": "Bearer " + access}, &out); err != nil {
		return "", "", err
	}
	if !validSSOCode(out.Code) {
		return "", "", &tsError{Status: 502, Msg: "bad code"}
	}
	fallback = tajikshopFallback()
	if strings.HasPrefix(out.Fallback, "https://") {
		fallback = out.Fallback
	}
	return "tajikshop://sso?code=" + out.Code, fallback, nil
}

// tsErrStatus — рамзи HTTP-и хатои TajikShop (0 — шабака).
func tsErrStatus(err error) int {
	var te *tsError
	if errors.As(err, &te) {
		return te.Status
	}
	return 0
}

// Сабаби хатои /sso/exchange барои корбар ва log.
type ssoFailure struct {
	HTTP    int
	Code    string
	Message string
}

// mapExchangeError — хатои TajikShop → ҷавоби мо (бо матни тоҷикӣ).
//
//	401 «Калиди шарик нодуруст» → 503: ин хатои танзими МО аст, на корбар.
//	400 «Барномаи номаълум»     → 503: TajikShop Raonson-ро намешиносад.
//	401 дигар (код)             → 401 invalid_code.
//	шабака / 5xx                → 502.
func mapExchangeError(err error) ssoFailure {
	var te *tsError
	if !errors.As(err, &te) {
		return ssoFailure{http.StatusBadGateway, "provider_unavailable", msgTSUnavailable}
	}
	low := strings.ToLower(te.Msg)
	switch {
	case te.Status == http.StatusUnauthorized && (strings.Contains(low, "шарик") || strings.Contains(low, "partner")):
		return ssoFailure{http.StatusServiceUnavailable, "sso_not_configured", msgSSONotConfigured}
	case te.Status == http.StatusBadRequest && (strings.Contains(low, "барнома") || strings.Contains(low, "app")):
		return ssoFailure{http.StatusServiceUnavailable, "sso_not_configured", msgSSONotConfigured}
	case te.Status == http.StatusUnauthorized || te.Status == http.StatusBadRequest ||
		te.Status == http.StatusNotFound || te.Status == http.StatusGone:
		return ssoFailure{http.StatusUnauthorized, "invalid_code", msgSSOInvalidCode}
	default:
		return ssoFailure{http.StatusBadGateway, "provider_unavailable", msgTSUnavailable}
	}
}

const (
	msgSSOInvalidCode   = "Код нодуруст ё мӯҳлаташ гузашт"
	msgSSONotConfigured = "Пайвасти TajikShop танзим нашудааст"
	msgTSUnavailable    = "TajikShop ҷавоб надод. Баъдтар боз кӯшиш кунед"
)
