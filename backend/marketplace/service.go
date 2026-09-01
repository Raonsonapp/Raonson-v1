package marketplace

import (
	"crypto/rand"
	"encoding/hex"
	"log"
	"sync"

	"raonson/marketplace/payments"
	"raonson/marketplace/payouts"
)

// Service — қисмҳои Creator Marketplace, ки дар боло сим карда мешаванд.
//
// Он ҳолати худро дар DB нигоҳ намедорад: танҳо конфигуратсия ва
// registry-и provider-ҳо. Ҳама мантиқи молиявӣ дар store/ledger аст.
type Service struct {
	Cfg      Config
	Payments *payments.Registry
	Payouts  *payouts.Registry
}

var (
	once   sync.Once
	svc    *Service
	initEr error
)

// Get сервисро як бор месозад ва ҳамонро бармегардонад.
//
// Агар конфигуратсия нодуруст бошад, хато бармегардад — ва handler-ҳо
// 503 медиҳанд. Ин боиси нашикастани боқимондаи Raonson мешавад:
// marketplace хомӯш мемонад, вале барнома кор мекунад.
func Get() (*Service, error) {
	once.Do(func() {
		cfg, err := LoadConfig()
		if err != nil {
			initEr = err
			return
		}
		svc, initEr = New(cfg)
	})
	return svc, initEr
}

// New registry-ҳоро аз рӯи конфигуратсия пур мекунад.
func New(cfg Config) (*Service, error) {
	s := &Service{
		Cfg:      cfg,
		Payments: payments.NewRegistry(),
		Payouts:  payouts.NewRegistry(),
	}

	// Payout-и дастӣ ҳамеша дастрас аст: он ҳеҷ пул интиқол намедиҳад
	// ва ҳар дархостро ба REQUIRES_ACTION мегузорад, то оператор
	// онро дастӣ иҷро кунад.
	s.Payouts.Register(payouts.NewManualProvider())

	switch cfg.PaymentProvider {
	case "mock":
		secret := cfg.PaymentWebhookSecret
		if secret == "" {
			// Ҳамон роҳи JWT_SECRET: калиди тасодуфии муваққатӣ.
			// Webhook-и берунӣ бо он имзо гузашта наметавонад — ва ин
			// дуруст аст: провайдери санҷишӣ бе secret набояд қабул кунад.
			secret = randomSecret()
			log.Println("⚠️  PAYMENT_WEBHOOK_SECRET unset — mock provider using ephemeral secret")
		}
		s.Payments.Register(payments.NewMockProvider(secret))
	default:
		// Provider-и воқеӣ ҳанӯз пайваст нашудааст. Ҳеҷ чиз ихтироъ
		// намекунем: registry холӣ мемонад ва CreatePayment 503 медиҳад.
		log.Printf("⚠️  PAYMENT_PROVIDER=%q сабт нашудааст — пардохти кампания хомӯш аст",
			cfg.PaymentProvider)
	}
	return s, nil
}

// PaymentProvider provider-и ҷориро мегирад.
func (s *Service) PaymentProvider() (payments.Provider, error) {
	return s.Payments.Get(s.Cfg.PaymentProvider)
}

// PayoutProvider provider-и интиқолро мегирад.
func (s *Service) PayoutProvider() (payouts.Provider, error) {
	return s.Payouts.Get(s.Cfg.PayoutProvider)
}

func randomSecret() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		// Дар амал рух намедиҳад; вале хомӯш нагузарем.
		log.Println("⚠️  crypto/rand дастнорас — mock provider бе secret")
		return ""
	}
	return hex.EncodeToString(b)
}
