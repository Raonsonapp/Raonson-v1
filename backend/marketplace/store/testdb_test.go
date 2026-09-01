package store

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
)

// testPool як пул ба DB-и санҷишӣ мекушояд.
//
// Агар MARKETPLACE_TEST_DB танзим нашуда бошад, тестҳо гузаранда
// мешаванд — то `go test ./...` дар муҳити бе Postgres нашиканад.
func testPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	dsn := os.Getenv("MARKETPLACE_TEST_DB")
	if dsn == "" {
		t.Skip("MARKETPLACE_TEST_DB танзим нашудааст — тести интегратсионӣ гузаронда шуд")
	}
	pool, err := pgxpool.New(context.Background(), dsn)
	if err != nil {
		t.Fatalf("пайвастшавӣ ба DB-и санҷишӣ: %v", err)
	}
	t.Cleanup(pool.Close)
	if err := pool.Ping(context.Background()); err != nil {
		t.Fatalf("ping: %v", err)
	}
	return pool
}

// schemaSQL — ҳамон схемаи marketplace. Дар тест онро мустақиман
// татбиқ мекунем, то ба db.Init() (ки DATABASE_URL-и воқеӣ мехоҳад)
// вобаста набошем.
func applySchema(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	ctx := context.Background()
	if _, err := pool.Exec(ctx, `CREATE EXTENSION IF NOT EXISTS "pgcrypto";`); err != nil {
		t.Fatalf("pgcrypto: %v", err)
	}
	if _, err := pool.Exec(ctx, marketplaceTestSchema); err != nil {
		t.Fatalf("схема: %v", err)
	}
}

// resetTables ҷадвалҳоро байни тестҳо тоза мекунад.
func resetTables(t *testing.T, pool *pgxpool.Pool) {
	t.Helper()
	_, err := pool.Exec(context.Background(), `
		TRUNCATE ledger_entries, ledger_transactions, ledger_accounts,
		         payment_orders, payout_orders, platform_fees,
		         webhook_events, idempotency_keys, marketplace_audit_logs,
		         campaign_events, campaign_metrics, campaign_creators,
		         campaigns, advertisers, creator_profiles, creator_metrics,
		         fraud_flags RESTART IDENTITY CASCADE;`)
	if err != nil {
		t.Fatalf("truncate: %v", err)
	}
}
