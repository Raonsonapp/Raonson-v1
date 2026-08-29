// Package ledger ҳаракати пулро ҳамчун сабтҳои дутарафа нигоҳ медорад.
//
// Ҳеҷ ҷо "balance = balance + amount" истифода намешавад. Ҳар ҳаракат
// як транзаксия бо ду ё зиёда сатр аст, ки ҷамъашон ҲАМЕША сифр аст.
// Тавозун аз сатрҳо ҳисоб мешавад, на дар сутуни алоҳида нигоҳ дошта.
package ledger

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"

	"raonson/marketplace/money"
)

// Owner types.
const (
	OwnerUser     = "USER"
	OwnerPlatform = "PLATFORM"
	OwnerProvider = "PROVIDER"
)

// Account purposes.
const (
	PurposeWallet     = "WALLET"     // пули дастраси корбар
	PurposeEscrow     = "ESCROW"     // буҷети кампания то анҷом
	PurposeRevenue    = "REVENUE"    // даромади платформа
	PurposeSettlement = "SETTLEMENT" // ҳисоби provider (пули берунӣ)
)

var (
	ErrUnbalanced    = errors.New("ledger: ҷамъи сатрҳо сифр нест")
	ErrNoEntries     = errors.New("ledger: транзаксия бе сатр")
	ErrCurrencyMixed = errors.New("ledger: як транзаксия — як асъор")
	ErrDuplicateRef  = errors.New("ledger: reference аллакай сабт шудааст")
)

// Entry — як сатри дафтар. Мусбат = дебет, манфӣ = кредит.
type Entry struct {
	AccountID string
	Amount    money.Amount
}

// Tx — интерфейси минималии транзаксия. Ҳам pgx.Tx ва ҳам pgxpool.Pool
// онро қонеъ мекунанд, бинобар ин ledger дар ҳарду ҳолат кор мекунад.
// Ҳамаи навиштанҳои пул БОЯД дар як DB transaction бошанд.
type Tx interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// EnsureAccount ҳисобро меёбад ё месозад ва id-ашро бармегардонад.
//
// UNIQUE(owner_type, owner_id, purpose, currency) кафолат медиҳад, ки
// ду ҳисоби якхела сохта намешавад ҳатто ҳангоми дархостҳои ҳамзамон.
func EnsureAccount(ctx context.Context, tx Tx, ownerType, ownerID, purpose string, cur money.Currency) (string, error) {
	var id string
	err := tx.QueryRow(ctx, `
		INSERT INTO ledger_accounts(owner_type, owner_id, purpose, currency)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (owner_type, owner_id, purpose, currency) DO UPDATE
		  SET owner_type = EXCLUDED.owner_type
		RETURNING id`,
		ownerType, ownerID, purpose, string(cur)).Scan(&id)
	if err != nil {
		return "", fmt.Errorf("ledger: ensure account: %w", err)
	}
	return id, nil
}

// Post як транзаксияи дутарафа менависад.
//
// reference калиди идемпотентӣ аст: агар ҳамон reference аллакай бошад,
// ErrDuplicateRef бармегардад ва ҲЕҶ сатри нав навишта намешавад.
// Даъваткунанда метавонад онро ҳамчун "аллакай иҷро шуд" шуморад.
func Post(ctx context.Context, tx Tx, kind, campaignID, reference, memo string, entries []Entry) (string, error) {
	if len(entries) == 0 {
		return "", ErrNoEntries
	}
	// Ҳамаи сатрҳо як асъор ва ҷамъашон сифр бошад.
	cur := entries[0].Amount.Currency
	var sum money.Minor
	for _, e := range entries {
		if e.Amount.Currency != cur {
			return "", ErrCurrencyMixed
		}
		if e.AccountID == "" {
			return "", fmt.Errorf("ledger: сатр бе account_id")
		}
		sum += e.Amount.Minor
	}
	if sum != 0 {
		return "", fmt.Errorf("%w: ҷамъ = %d", ErrUnbalanced, sum)
	}

	var txID string
	err := tx.QueryRow(ctx, `
		INSERT INTO ledger_transactions(kind, campaign_id, reference, memo)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (reference) DO NOTHING
		RETURNING id`, kind, campaignID, reference, memo).Scan(&txID)
	if err != nil {
		// ON CONFLICT DO NOTHING сатр барнамегардонад → ErrNoRows.
		if errors.Is(err, pgx.ErrNoRows) {
			return "", ErrDuplicateRef
		}
		return "", fmt.Errorf("ledger: транзаксия: %w", err)
	}

	for _, e := range entries {
		if _, err := tx.Exec(ctx, `
			INSERT INTO ledger_entries(transaction_id, account_id, amount_minor, currency)
			VALUES ($1,$2,$3,$4)`,
			txID, e.AccountID, int64(e.Amount.Minor), string(e.Amount.Currency)); err != nil {
			return "", fmt.Errorf("ledger: сатр: %w", err)
		}
	}
	return txID, nil
}

// Balance тавозуни ҳисобро аз сатрҳо ҳисоб мекунад.
//
// Ҳеҷ сутуни "balance" нигоҳ дошта намешавад — сарчашмаи ягонаи ҳақиқат
// худи сатрҳоянд, бинобар ин тавозун ҳеҷ гоҳ аз ҳаракатҳо дур намешавад.
func Balance(ctx context.Context, tx Tx, accountID string) (money.Amount, error) {
	var sum int64
	var cur string
	err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount_minor),0),
		       COALESCE(MAX(currency),'')
		FROM ledger_entries WHERE account_id=$1`, accountID).Scan(&sum, &cur)
	if err != nil {
		return money.Amount{}, fmt.Errorf("ledger: тавозун: %w", err)
	}
	if cur == "" {
		return money.Amount{}, nil // ҳисоб ҳанӯз ҳаракат надорад
	}
	c, err := money.ParseCurrency(cur)
	if err != nil {
		return money.Amount{}, err
	}
	return money.Amount{Minor: money.Minor(sum), Currency: c}, nil
}

// Transfer як ҳаракати оддии ду-сатра месозад: аз "from" ба "to".
func Transfer(ctx context.Context, tx Tx, kind, campaignID, reference, memo,
	fromAccount, toAccount string, amt money.Amount) (string, error) {
	if amt.Minor <= 0 {
		return "", fmt.Errorf("ledger: маблағ бояд мусбат бошад, %d дода шуд", amt.Minor)
	}
	return Post(ctx, tx, kind, campaignID, reference, memo, []Entry{
		{AccountID: fromAccount, Amount: money.Amount{Minor: -amt.Minor, Currency: amt.Currency}},
		{AccountID: toAccount, Amount: amt},
	})
}
