// Package payouts abstraction-и provider-и пардохт ба эҷодкорро муайян мекунад.
//
// Мисли payments: ҳеҷ API-и воқеӣ ин ҷо ихтироъ намешавад.
//
// МУҲИМ: агар provider API-и payout надошта бошад, система payout-и
// СОХТА намесозад ва онро SUCCEEDED эълон намекунад. Ба ҷои он ҳолат
// REQUIRES_ACTION мешавад ва оператор онро дастӣ иҷро мекунад.
package payouts

import (
	"context"
	"errors"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

var (
	ErrUnknownProvider  = errors.New("payouts: provider номаълум")
	ErrInvalidSignature = errors.New("payouts: имзои webhook нодуруст")
	// ErrManualRequired — provider интиқоли худкор надорад.
	// Ин ХАТО нест: payout ба REQUIRES_ACTION мегузарад.
	ErrManualRequired = errors.New("payouts: provider интиқоли худкор надорад — амали дастӣ лозим")
)

type CreateRequest struct {
	PayoutID       string
	CreatorID      string
	Amount         money.Amount
	Description    string
	IdempotencyKey string
}

type CreateResult struct {
	ProviderReference string
	Status            domain.PayoutStatus
}

type WebhookEvent struct {
	EventID           string
	EventType         string
	ProviderReference string
	Status            domain.PayoutStatus
	Amount            money.Amount
	FailureReason     string
	Raw               []byte
}

type Provider interface {
	Name() string

	// CreatePayout интиқолро оғоз мекунад.
	// Агар provider интиқоли худкор надошта бошад, ErrManualRequired
	// бармегардонад — ва система payout-ро REQUIRES_ACTION мекунад.
	CreatePayout(ctx context.Context, req CreateRequest) (CreateResult, error)

	GetPayout(ctx context.Context, providerReference string) (domain.PayoutStatus, error)

	ParseWebhook(ctx context.Context, headers map[string]string, body []byte) (WebhookEvent, error)

	VerifyPayout(ctx context.Context, providerReference string) (domain.PayoutStatus, money.Amount, error)
}

type Registry struct{ providers map[string]Provider }

func NewRegistry() *Registry { return &Registry{providers: map[string]Provider{}} }

func (r *Registry) Register(p Provider) { r.providers[p.Name()] = p }

func (r *Registry) Get(name string) (Provider, error) {
	p, ok := r.providers[name]
	if !ok {
		return nil, ErrUnknownProvider
	}
	return p, nil
}
