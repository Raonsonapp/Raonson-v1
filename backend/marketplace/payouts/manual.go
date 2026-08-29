package payouts

import (
	"context"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

// ManualProvider — ҳолати пешфарз, вақте provider-и воқеии payout
// ҳанӯз пайваст нашудааст.
//
// Он ҳеҷ пул интиқол намедиҳад ва ҳеҷ гоҳ SUCCEEDED барнамегардонад.
// Ҳар payout ба REQUIRES_ACTION меравад, то оператор онро дастӣ иҷро
// кунад ва баъд дар admin тасдиқ намояд. Ин қасдан аст: payout-и
// сохта хатари молиявист.
type ManualProvider struct{}

func NewManualProvider() *ManualProvider { return &ManualProvider{} }

func (m *ManualProvider) Name() string { return "manual" }

func (m *ManualProvider) CreatePayout(_ context.Context, _ CreateRequest) (CreateResult, error) {
	return CreateResult{Status: domain.PayoutRequiresAction}, ErrManualRequired
}

func (m *ManualProvider) GetPayout(_ context.Context, _ string) (domain.PayoutStatus, error) {
	return domain.PayoutRequiresAction, nil
}

func (m *ManualProvider) ParseWebhook(_ context.Context, _ map[string]string, _ []byte) (WebhookEvent, error) {
	// Provider-и дастӣ webhook надорад.
	return WebhookEvent{}, ErrInvalidSignature
}

func (m *ManualProvider) VerifyPayout(_ context.Context, _ string) (domain.PayoutStatus, money.Amount, error) {
	return domain.PayoutRequiresAction, money.Amount{}, nil
}

var _ Provider = (*ManualProvider)(nil)
