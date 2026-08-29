package payments

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"sync"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

// MockProvider — provider-и санҷишӣ.
//
// Ин provider-и ВОҚЕӢ НЕСТ ва пул интиқол намедиҳад. Он барои тест ва
// муҳити development вуҷуд дорад, то ҷараёни пардохтро бе provider-и
// беруна санҷидан мумкин бошад. Дар production он бояд ба provider-и
// воқеӣ иваз шавад (PAYMENT_PROVIDER=<ном>).
//
// Имзои webhook ВОҚЕӢ HMAC-SHA256 аст — то мантиқи тафтиши имзо
// худаш санҷида шавад, на аз тафтиш гузашта шавад.
type MockProvider struct {
	secret []byte

	mu       sync.Mutex
	payments map[string]mockPayment
}

type mockPayment struct {
	status domain.PaymentStatus
	amount money.Amount
}

func NewMockProvider(secret string) *MockProvider {
	return &MockProvider{
		secret:   []byte(secret),
		payments: map[string]mockPayment{},
	}
}

func (m *MockProvider) Name() string { return "mock" }

func (m *MockProvider) CreatePayment(_ context.Context, req CreateRequest) (CreateResult, error) {
	if req.Amount.Minor <= 0 {
		return CreateResult{}, fmt.Errorf("payments/mock: маблағ бояд мусбат бошад")
	}
	ref := "mock_" + req.OrderID
	m.mu.Lock()
	// Идемпотентӣ: ҳамон OrderID → ҳамон reference, ҳолат тағйир намеёбад.
	if _, exists := m.payments[ref]; !exists {
		m.payments[ref] = mockPayment{status: domain.PaymentPending, amount: req.Amount}
	}
	m.mu.Unlock()
	return CreateResult{
		ProviderReference: ref,
		Status:            domain.PaymentPending,
		RedirectURL:       "",
	}, nil
}

func (m *MockProvider) GetPayment(_ context.Context, ref string) (domain.PaymentStatus, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.payments[ref]
	if !ok {
		return "", domain.ErrNotFound
	}
	return p.status, nil
}

func (m *MockProvider) VerifyPayment(_ context.Context, ref string) (domain.PaymentStatus, money.Amount, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.payments[ref]
	if !ok {
		return "", money.Amount{}, domain.ErrNotFound
	}
	return p.status, p.amount, nil
}

// mockWebhookBody — шакли ҳодисае, ки MockProvider интизор аст.
type mockWebhookBody struct {
	EventID   string `json:"event_id"`
	EventType string `json:"event_type"`
	Reference string `json:"reference"`
	Status    string `json:"status"`
	Minor     int64  `json:"amount_minor"`
	Currency  string `json:"currency"`
	Reason    string `json:"failure_reason"`
}

// Sign имзои дурустро барои body месозад — дар тестҳо истифода мешавад.
func (m *MockProvider) Sign(body []byte) string {
	mac := hmac.New(sha256.New, m.secret)
	mac.Write(body)
	return hex.EncodeToString(mac.Sum(nil))
}

func (m *MockProvider) ParseWebhook(_ context.Context, headers map[string]string, body []byte) (WebhookEvent, error) {
	got := headers["X-Signature"]
	if got == "" {
		got = headers["x-signature"]
	}
	if got == "" {
		return WebhookEvent{}, ErrInvalidSignature
	}
	// hmac.Equal — муқоисаи вақти собит, то имзоро бо brute-force
	// аз рӯи вақт наёбанд.
	if !hmac.Equal([]byte(got), []byte(m.Sign(body))) {
		return WebhookEvent{}, ErrInvalidSignature
	}

	var b mockWebhookBody
	if err := json.Unmarshal(body, &b); err != nil {
		return WebhookEvent{}, fmt.Errorf("payments/mock: body: %w", err)
	}
	if b.EventID == "" || b.Reference == "" {
		return WebhookEvent{}, errors.New("payments/mock: event_id ва reference ҳатмист")
	}
	st := domain.PaymentStatus(b.Status)
	if !st.Valid() {
		return WebhookEvent{}, fmt.Errorf("payments/mock: ҳолати номаълум %q", b.Status)
	}
	cur, err := money.ParseCurrency(b.Currency)
	if err != nil {
		return WebhookEvent{}, err
	}

	// Ҳолати дохилиро нав мекунем, то VerifyPayment ҳамон чизро тасдиқ кунад.
	m.mu.Lock()
	p := m.payments[b.Reference]
	p.status = st
	p.amount = money.Amount{Minor: money.Minor(b.Minor), Currency: cur}
	m.payments[b.Reference] = p
	m.mu.Unlock()

	return WebhookEvent{
		EventID:           b.EventID,
		EventType:         b.EventType,
		ProviderReference: b.Reference,
		Status:            st,
		Amount:            money.Amount{Minor: money.Minor(b.Minor), Currency: cur},
		FailureReason:     b.Reason,
		Raw:               body,
	}, nil
}

// Compile-time: MockProvider бояд Provider-ро қонеъ кунад.
var _ Provider = (*MockProvider)(nil)
