// Package marketplace конфигуратсияи Creator Marketplace-ро мехонад.
package marketplace

import (
	"errors"
	"os"
	"strconv"
	"strings"
)

// Config — танзимот аз environment. Ҳеҷ secret дар код нест.
type Config struct {
	// PaymentProvider — номи provider-и сабтшуда (масалан "mock").
	PaymentProvider string
	// PayoutProvider — "manual" вақте provider-и худкор нест.
	PayoutProvider string

	PaymentWebhookSecret string
	PayoutWebhookSecret  string

	// CommissionBPS — комиссияи платформа бо basis points (1000 = 10%).
	// Дар кампания ҳангоми сохтан қуфл мешавад.
	CommissionBPS int64

	// DefaultCurrency барои кампанияҳои нав.
	DefaultCurrency string
}

var ErrBadCommission = errors.New("marketplace: PLATFORM_COMMISSION_PERCENT бояд 0..100 бошад")

// LoadConfig танзимотро мехонад ва тафтиш мекунад.
//
// Пешфарзҳо бехатаранд: provider-и mock барои пардохт танҳо дар
// development маъно дорад, payout — "manual", яъне ҳеҷ интиқоли
// худкор бе provider-и воқеӣ рух намедиҳад.
func LoadConfig() (Config, error) {
	c := Config{
		PaymentProvider:      envOr("PAYMENT_PROVIDER", "mock"),
		PayoutProvider:       envOr("PAYOUT_PROVIDER", "manual"),
		PaymentWebhookSecret: os.Getenv("PAYMENT_WEBHOOK_SECRET"),
		PayoutWebhookSecret:  os.Getenv("PAYOUT_WEBHOOK_SECRET"),
		DefaultCurrency:      envOr("MARKETPLACE_CURRENCY", "TJS"),
		CommissionBPS:        1000, // 10%
	}

	if v := strings.TrimSpace(os.Getenv("PLATFORM_COMMISSION_PERCENT")); v != "" {
		pct, err := strconv.ParseFloat(v, 64)
		if err != nil || pct < 0 || pct > 100 {
			return Config{}, ErrBadCommission
		}
		// Фоиз → basis points, бо round-half-up.
		c.CommissionBPS = int64(pct*100 + 0.5)
	}
	return c, nil
}

func envOr(k, def string) string {
	if v := strings.TrimSpace(os.Getenv(k)); v != "" {
		return v
	}
	return def
}
