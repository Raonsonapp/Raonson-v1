// Package money ҳисоби маблағро бо воҳидҳои хурди БУТУН анҷом медиҳад.
//
// Float ҳеҷ гоҳ барои пул истифода намешавад: 0.1+0.2 != 0.3 ва хатоҳо
// ҷамъ мешаванд. 1500.00 TJS ҳамчун 150000 дирам нигоҳ дошта мешавад.
package money

import (
	"errors"
	"fmt"
	"strings"
)

// Minor — маблағ бо воҳиди хурд (дирам барои TJS, копейка барои RUB, cent барои USD).
type Minor int64

// Currency — коди ISO-4217.
type Currency string

const (
	TJS Currency = "TJS"
	RUB Currency = "RUB"
	USD Currency = "USD"
)

// exponent — чанд рақами баъд аз вергул барои ҳар асъор.
var exponent = map[Currency]int{
	TJS: 2,
	RUB: 2,
	USD: 2,
}

var (
	ErrUnknownCurrency  = errors.New("money: асъори номаълум")
	ErrNegative         = errors.New("money: маблағ манфӣ буда наметавонад")
	ErrCurrencyMismatch = errors.New("money: асъорҳо мувофиқат намекунанд")
	ErrOverflow         = errors.New("money: маблағ аз ҳад калон")
)

// ParseCurrency асъорро тафтиш мекунад.
func ParseCurrency(s string) (Currency, error) {
	c := Currency(strings.ToUpper(strings.TrimSpace(s)))
	if _, ok := exponent[c]; !ok {
		return "", ErrUnknownCurrency
	}
	return c, nil
}

// Exponent шумораи рақамҳои касрро бармегардонад.
func (c Currency) Exponent() (int, error) {
	e, ok := exponent[c]
	if !ok {
		return 0, ErrUnknownCurrency
	}
	return e, nil
}

// Amount — маблағ ҳамроҳи асъораш. Ҳамеша якҷоя интиқол дода мешавад,
// то ҷамъи ду асъори гуногун ғайриимкон бошад.
type Amount struct {
	Minor    Minor    `json:"minor"`
	Currency Currency `json:"currency"`
}

func New(m Minor, c Currency) (Amount, error) {
	if _, ok := exponent[c]; !ok {
		return Amount{}, ErrUnknownCurrency
	}
	if m < 0 {
		return Amount{}, ErrNegative
	}
	return Amount{Minor: m, Currency: c}, nil
}

// MustNew танҳо дар тест ва константаҳо истифода мешавад.
func MustNew(m Minor, c Currency) Amount {
	a, err := New(m, c)
	if err != nil {
		panic(err)
	}
	return a
}

func (a Amount) IsZero() bool { return a.Minor == 0 }

// Add ду маблағи ҳамасъорро ҷамъ мекунад.
func (a Amount) Add(b Amount) (Amount, error) {
	if a.Currency != b.Currency {
		return Amount{}, ErrCurrencyMismatch
	}
	s := a.Minor + b.Minor
	// Сарҳадро тафтиш мекунем — ҷамъи ду мусбат бояд мусбат монад.
	if (a.Minor > 0 && b.Minor > 0 && s < 0) || (a.Minor < 0 && b.Minor < 0 && s > 0) {
		return Amount{}, ErrOverflow
	}
	return Amount{Minor: s, Currency: a.Currency}, nil
}

// Sub тарҳ мекунад; натиҷа метавонад манфӣ бошад (барои ledger лозим аст).
func (a Amount) Sub(b Amount) (Amount, error) {
	if a.Currency != b.Currency {
		return Amount{}, ErrCurrencyMismatch
	}
	return Amount{Minor: a.Minor - b.Minor, Currency: a.Currency}, nil
}

// SplitPercent маблағро ба ду ҳисса тақсим мекунад: fee (bps) ва боқимонда.
//
// bps = basis points (1% = 100 bps). Ҳисоб бо round-half-up анҷом дода
// мешавад ва боқимонда ҲАМЕША аз тарҳи fee гирифта мешавад, то ҷамъи
// ду ҳисса дақиқан ба маблағи аслӣ баробар бошад — ягон дирам гум намешавад.
func (a Amount) SplitPercent(bps int64) (fee Amount, rest Amount, err error) {
	if bps < 0 || bps > 10000 {
		return Amount{}, Amount{}, fmt.Errorf("money: bps бояд 0..10000 бошад, %d дода шуд", bps)
	}
	if a.Minor < 0 {
		return Amount{}, Amount{}, ErrNegative
	}
	// round-half-up: (x*bps + 5000) / 10000
	f := (int64(a.Minor)*bps + 5000) / 10000
	fee = Amount{Minor: Minor(f), Currency: a.Currency}
	rest = Amount{Minor: a.Minor - Minor(f), Currency: a.Currency}
	return fee, rest, nil
}

// String намуди хондашаванда: "1500.00 TJS".
func (a Amount) String() string {
	e, ok := exponent[a.Currency]
	if !ok {
		return fmt.Sprintf("%d ???", a.Minor)
	}
	neg := ""
	v := int64(a.Minor)
	if v < 0 {
		neg = "-"
		v = -v
	}
	div := int64(1)
	for i := 0; i < e; i++ {
		div *= 10
	}
	return fmt.Sprintf("%s%d.%0*d %s", neg, v/div, e, v%div, a.Currency)
}
