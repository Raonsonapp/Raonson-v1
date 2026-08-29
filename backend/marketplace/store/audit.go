// Package store қабати дастрасӣ ба DB барои Creator Marketplace аст.
//
// Ҳар амали молиявӣ дар як DB transaction иҷро мешавад ва пеш аз
// тағйир сатрро бо FOR UPDATE қуфл мекунад — то ду дархости ҳамзамон
// ҳолатро вайрон накунанд.
package store

import (
	"context"
	"encoding/json"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
)

// Tx — интерфейси муштарак барои pgx.Tx ва pgxpool.Pool.
type Tx interface {
	Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
	Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// Audit як сатри audit log менависад.
//
// Хатои сабт амали асосиро қатъ намекунад — вале он дар transaction
// аст, бинобар ин rollback ҳам audit-ро бармегардонад: log ҳеҷ гоҳ
// амалеро нишон намедиҳад, ки воқеан рух надод.
func Audit(ctx context.Context, tx Tx, actorID, actorRole, action,
	entityType, entityID string, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		b = []byte(`{}`)
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO marketplace_audit_logs
		  (actor_id, actor_role, action, entity_type, entity_id, payload)
		VALUES ($1,$2,$3,$4,$5,$6)`,
		actorID, actorRole, action, entityType, entityID, string(b))
	return err
}

// CampaignEvent ҳодисаи кампанияро сабт мекунад (таърихи ҳаёти кампания).
func CampaignEvent(ctx context.Context, tx Tx, campaignID, creatorID,
	eventType, fromStatus, toStatus, actorID string, payload any) error {
	b, err := json.Marshal(payload)
	if err != nil {
		b = []byte(`{}`)
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO campaign_events
		  (campaign_id, creator_id, event_type, from_status, to_status, actor_id, payload)
		VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		campaignID, creatorID, eventType, fromStatus, toStatus, actorID, string(b))
	return err
}
