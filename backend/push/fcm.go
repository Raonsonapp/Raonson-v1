// Package push огоҳиномаро ба дастгоҳ мефиристад.
//
// ⚠️ Чаро ин пакет пайдо шуд:
//
// Код қаблӣ FCM Legacy API-ро истифода мебурд
// (fcm.googleapis.com/fcm/send + «Authorization: key=...»).
// Google онро хомӯш кард — ин суроға ҳоло 404 бармегардонад.
// Яъне ҳеҷ push намерасид, ҳатто бо калиди дуруст.
//
// Ин ҷо FCM HTTP v1 истифода мешавад: ба ҷои калиди статикӣ
// service account ва токени OAuth2 лозим аст.
package push

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// Result — натиҷаи як кӯшиши фиристодан.
type Result int

const (
	// Sent — провайдер қабул кард. Ин КАФОЛАТИ расидан НЕСТ:
	// расиданро танҳо худи Android/iOS медонад.
	Sent Result = iota
	// TokenDead — дастгоҳ дигар вуҷуд надорад; токен хомӯш шавад.
	TokenDead
	// Retry — хатои муваққатӣ (шабака, 429, 5xx).
	Retry
	// ConfigError — мушкили калид ё танзимот. Токен АЙБДОР НЕСТ ва
	// хомӯш карда НАМЕШАВАД.
	ConfigError
)

func (r Result) String() string {
	switch r {
	case Sent:
		return "sent"
	case TokenDead:
		return "token_dead"
	case Retry:
		return "retry"
	default:
		return "config_error"
	}
}

// Message — огоҳиномаи омода барои як дастгоҳ.
type Message struct {
	Token string
	Title string
	Body  string
	// Data ба барнома мерасад; deep link ҳам ин ҷост.
	Data map[string]string
	// ChannelID — канали Android (садо ва аҳамият аз он вобаста аст).
	ChannelID string
	// HighPriority — танҳо барои чизи воқеан фаврӣ (паём, амали
	// зарурӣ). Сӯиистифода аз он боиси маҳдудкунии FCM мешавад.
	HighPriority bool
	// Badge — рақами рӯи нишонаи барнома (iOS).
	Badge int
	// CollapseKey — огоҳиномаи кӯҳна бо нав иваз мешавад.
	CollapseKey string
}

// ── Аслнома ──────────────────────────────────────────────────────

type serviceAccount struct {
	ProjectID   string `json:"project_id"`
	ClientEmail string `json:"client_email"`
	PrivateKey  string `json:"private_key"`
	TokenURI    string `json:"token_uri"`
}

var (
	mu       sync.Mutex
	cachedSA *serviceAccount
	saLoaded bool

	tokenMu     sync.Mutex
	accessToken string
	tokenExp    time.Time
)

// loadServiceAccount аслномаро аз env мехонад.
//
// Ду роҳ: худи JSON дар FCM_SERVICE_ACCOUNT_JSON, ё роҳи файл дар
// FCM_SERVICE_ACCOUNT_FILE. Ҳеҷ гоҳ дар код нигоҳ дошта намешавад.
func loadServiceAccount() (*serviceAccount, error) {
	mu.Lock()
	defer mu.Unlock()
	if saLoaded {
		if cachedSA == nil {
			return nil, fmt.Errorf("push: service account танзим нашудааст")
		}
		return cachedSA, nil
	}
	saLoaded = true

	raw := os.Getenv("FCM_SERVICE_ACCOUNT_JSON")
	if raw == "" {
		if p := os.Getenv("FCM_SERVICE_ACCOUNT_FILE"); p != "" {
			b, err := os.ReadFile(p)
			if err != nil {
				return nil, fmt.Errorf("push: файли аслнома хонда нашуд")
			}
			raw = string(b)
		}
	}
	if strings.TrimSpace(raw) == "" {
		return nil, fmt.Errorf("push: service account танзим нашудааст")
	}

	var sa serviceAccount
	if err := json.Unmarshal([]byte(raw), &sa); err != nil {
		// Матни хато сирро ошкор накунад.
		return nil, fmt.Errorf("push: аслнома шакли нодуруст дорад")
	}
	if sa.ProjectID == "" || sa.ClientEmail == "" || sa.PrivateKey == "" {
		return nil, fmt.Errorf("push: аслнома нопурра аст")
	}
	if sa.TokenURI == "" {
		sa.TokenURI = "https://oauth2.googleapis.com/token"
	}
	cachedSA = &sa
	return cachedSA, nil
}

// Configured мегӯяд, ки оё push фиристода метавонад.
func Configured() bool {
	_, err := loadServiceAccount()
	return err == nil
}

// ProjectID барои ташхис (бе сир).
func ProjectID() string {
	sa, err := loadServiceAccount()
	if err != nil {
		return ""
	}
	return sa.ProjectID
}

// getAccessToken токени OAuth2-ро мегирад ва кэш мекунад.
//
// Токен тақрибан як соат эътибор дорад; барои ҳар огоҳинома аз нав
// гирифтани он ҳам суст аст ва ҳам маҳдудияти Google-ро мезанад.
func getAccessToken(ctx context.Context) (string, error) {
	sa, err := loadServiceAccount()
	if err != nil {
		return "", err
	}

	tokenMu.Lock()
	defer tokenMu.Unlock()
	// Як дақиқа захира: токен набояд дар роҳ кӯҳна шавад.
	if accessToken != "" && time.Now().Before(tokenExp.Add(-time.Minute)) {
		return accessToken, nil
	}

	key, err := jwt.ParseRSAPrivateKeyFromPEM([]byte(sa.PrivateKey))
	if err != nil {
		return "", fmt.Errorf("push: калиди хусусӣ хонда нашуд")
	}
	now := time.Now()
	claims := jwt.MapClaims{
		"iss":   sa.ClientEmail,
		"scope": "https://www.googleapis.com/auth/firebase.messaging",
		"aud":   sa.TokenURI,
		"iat":   now.Unix(),
		"exp":   now.Add(time.Hour).Unix(),
	}
	signed, err := jwt.NewWithClaims(jwt.SigningMethodRS256, claims).
		SignedString(key)
	if err != nil {
		return "", fmt.Errorf("push: JWT имзо нашуд")
	}

	form := strings.NewReader(
		"grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=" +
			signed)
	req, err := http.NewRequestWithContext(ctx, "POST", sa.TokenURI, form)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))
	if resp.StatusCode >= 400 {
		// Ҷавоби Google метавонад маълумоти аслнома дошта бошад —
		// он ба log намеравад.
		return "", fmt.Errorf("push: токен гирифта нашуд (HTTP %d)",
			resp.StatusCode)
	}

	var out struct {
		AccessToken string `json:"access_token"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.Unmarshal(body, &out); err != nil || out.AccessToken == "" {
		return "", fmt.Errorf("push: ҷавоби токен хонда нашуд")
	}
	accessToken = out.AccessToken
	if out.ExpiresIn <= 0 {
		out.ExpiresIn = 3600
	}
	tokenExp = now.Add(time.Duration(out.ExpiresIn) * time.Second)
	return accessToken, nil
}

var httpClient = &http.Client{Timeout: 15 * time.Second}

// ResetForTest кэши аслнома ва токенро тоза мекунад.
func ResetForTest() {
	mu.Lock()
	cachedSA, saLoaded = nil, false
	mu.Unlock()
	tokenMu.Lock()
	accessToken, tokenExp = "", time.Time{}
	tokenMu.Unlock()
}

// ── Фиристодан ───────────────────────────────────────────────────

// buildPayload бадани дархости FCM v1-ро месозад.
//
// Ҷудо аз Send нигоҳ дошта мешавад, то шакли он бе шабака санҷида
// шавад: хатои сохтани payload хомӯшона огоҳиномаро нобуд мекунад.
func buildPayload(m Message) map[string]any {
	prio := "NORMAL"
	apnsPrio := "5"
	if m.HighPriority {
		prio = "HIGH"
		apnsPrio = "10"
	}

	android := map[string]any{
		"priority": prio,
		"notification": map[string]any{
			"channel_id": m.ChannelID,
			// default_sound-ро худи канал ҳал мекунад.
			"default_sound": true,
		},
	}
	if m.CollapseKey != "" {
		android["collapse_key"] = m.CollapseKey
	}

	aps := map[string]any{
		"sound": "default",
	}
	if m.Badge > 0 {
		aps["badge"] = m.Badge
	}

	msg := map[string]any{
		"token": m.Token,
		"notification": map[string]any{
			"title": m.Title,
			"body":  m.Body,
		},
		"android": android,
		"apns": map[string]any{
			"headers": map[string]any{"apns-priority": apnsPrio},
			"payload": map[string]any{"aps": aps},
		},
	}
	if len(m.Data) > 0 {
		// FCM танҳо сатр қабул мекунад.
		data := make(map[string]string, len(m.Data))
		for k, v := range m.Data {
			data[k] = v
		}
		msg["data"] = data
	}
	return map[string]any{"message": msg}
}

// classify ҷавоби FCM-ро ба қарори амалӣ табдил медиҳад.
//
// Фарқи муҳим: токени мурда хомӯш мешавад, вале хатои АСЛНОМА
// набояд токенҳои солимро нобуд кунад.
func classify(status int, body []byte) Result {
	switch {
	case status >= 200 && status < 300:
		return Sent
	case status == 404:
		// UNREGISTERED — барнома аз дастгоҳ нест шуд.
		return TokenDead
	case status == 400:
		// INVALID_ARGUMENT метавонад ҳам токен бошад, ҳам payload.
		// Танҳо вақте токенро айбдор мекунем, ки FCM худаш гуфт.
		if bytes.Contains(body, []byte("registration token")) ||
			bytes.Contains(body, []byte("Invalid registration")) ||
			(bytes.Contains(body, []byte("INVALID_ARGUMENT")) &&
				bytes.Contains(body, []byte("token"))) {
			return TokenDead
		}
		return ConfigError
	case status == 401 || status == 403:
		// Мушкили мо, на дастгоҳ.
		return ConfigError
	case status == 429 || status >= 500:
		return Retry
	default:
		return ConfigError
	}
}

// Send як огоҳиномаро мефиристад.
//
// Хато барои log аст; қарори амалӣ дар Result мебошад.
func Send(ctx context.Context, m Message) (Result, error) {
	if m.Token == "" {
		return TokenDead, fmt.Errorf("push: токен холӣ")
	}
	sa, err := loadServiceAccount()
	if err != nil {
		return ConfigError, err
	}
	tok, err := getAccessToken(ctx)
	if err != nil {
		return ConfigError, err
	}

	payload, err := json.Marshal(buildPayload(m))
	if err != nil {
		return ConfigError, err
	}

	url := "https://fcm.googleapis.com/v1/projects/" + sa.ProjectID +
		"/messages:send"
	req, err := http.NewRequestWithContext(ctx, "POST", url,
		bytes.NewReader(payload))
	if err != nil {
		return Retry, err
	}
	req.Header.Set("Authorization", "Bearer "+tok)
	req.Header.Set("Content-Type", "application/json")

	resp, err := httpClient.Do(req)
	if err != nil {
		// Шабака афтод — ин айби токен нест.
		return Retry, err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<16))

	res := classify(resp.StatusCode, body)
	if res == Sent {
		return Sent, nil
	}
	// Матни FCM метавонад маълумоти лоиҳаро дошта бошад; танҳо
	// рамзи ҳолат сабт мешавад.
	return res, fmt.Errorf("push: FCM HTTP %d (%s)", resp.StatusCode, res)
}
