// Package payments abstraction-и provider-и пардохтро муайян мекунад.
//
// ҲЕҶ API, secret ё рафтори provider-и мушаххас ин ҷо ихтироъ карда
// намешавад. То гирифтани ҳуҷҷатҳои provider-и воқеӣ, танҳо adapter-и
// mock (барои тест) мавҷуд аст. Илова кардани provider-и воқеӣ = сохтани
// файли нав, ки Provider-ро қонеъ мекунад, ва сабти он дар Registry.
package payments

import (
	"context"
	"errors"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

var (
	ErrUnknownProvider  = errors.New("payments: provider номаълум")
	ErrInvalidSignature = errors.New("payments: имзои webhook нодуруст")
	ErrUnsupported      = errors.New("payments: provider ин амалро дастгирӣ намекунад")
)

// CreateRequest — дархости сохтани пардохт.
// Маблағ ҳамеша аз сервер меояд; client ҳеҷ гоҳ онро таъин намекунад.
type CreateRequest struct {
	OrderID     string       // id-и payment_orders — reference-и мо
	Amount      money.Amount // аз сервер ҳисоб шудааст
	Description string
	ReturnURL   string
	// IdempotencyKey ба provider дода мешавад, агар онро дастгирӣ кунад.
	IdempotencyKey string
}

// CreateResult — он чи provider баъди сохтани пардохт бармегардонад.
type CreateResult struct {
	ProviderReference string               // id-и пардохт дар тарафи provider
	Status            domain.PaymentStatus // одатан CREATED ё PENDING
	// RedirectURL — агар provider саҳифаи пардохт дошта бошад.
	RedirectURL string
}

// WebhookEvent — ҳодисаи нормализашуда аз webhook.
type WebhookEvent struct {
	// EventID барои идемпотентӣ ҳатмист: як event_id танҳо як бор.
	EventID           string
	EventType         string
	ProviderReference string
	Status            domain.PaymentStatus
	Amount            money.Amount
	FailureReason     string
	Raw               []byte
}

// Provider — интерфейсе, ки ҳар provider-и пардохт бояд қонеъ кунад.
type Provider interface {
	// Name — номи кӯтоҳ, ки дар DB ва дар URL-и webhook меистад.
	Name() string

	// CreatePayment пардохтро дар тарафи provider месозад.
	CreatePayment(ctx context.Context, req CreateRequest) (CreateResult, error)

	// GetPayment ҳолати ҷориро аз provider мегирад (барои муқоиса).
	GetPayment(ctx context.Context, providerReference string) (domain.PaymentStatus, error)

	// ParseWebhook имзоро тафтиш ва ҳодисаро нормализа мекунад.
	// Агар имзо нодуруст бошад — ErrInvalidSignature.
	ParseWebhook(ctx context.Context, headers map[string]string, body []byte) (WebhookEvent, error)

	// VerifyPayment ҳолатро мустақиман аз provider тасдиқ мекунад.
	// Пеш аз ҳисоб кардани пардохт ҳамчун муваффақ истифода мешавад —
	// то ба webhook-и танҳо бовар накунем.
	VerifyPayment(ctx context.Context, providerReference string) (domain.PaymentStatus, money.Amount, error)
}

// Registry — provider-ҳои сабтшуда. Интихоб аз рӯи конфигуратсия.
type Registry struct {
	providers map[string]Provider
}

func NewRegistry() *Registry {
	return &Registry{providers: map[string]Provider{}}
}

func (r *Registry) Register(p Provider) {
	r.providers[p.Name()] = p
}

func (r *Registry) Get(name string) (Provider, error) {
	p, ok := r.providers[name]
	if !ok {
		return nil, ErrUnknownProvider
	}
	return p, nil
}

func (r *Registry) Names() []string {
	out := make([]string, 0, len(r.providers))
	for n := range r.providers {
		out = append(out, n)
	}
	return out
}
