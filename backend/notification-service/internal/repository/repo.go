package repository

import (
	"context"
	"time"

	"notification-service/internal/model"
	rdb "notification-service/pkg/redis"

	"github.com/jackc/pgx/v5/pgxpool"
)

type Repo struct{ db *pgxpool.Pool }

func New(db *pgxpool.Pool) *Repo { return &Repo{db: db} }

// ── Create ────────────────────────────────────────────────────────
func (r *Repo) Create(ctx context.Context, req *model.CreateNotifReq) (string, error) {
	var id string
	err := r.db.QueryRow(ctx,
		`INSERT INTO notifications(user_id,from_user_id,type,target_id)
		 VALUES($1,$2,$3,$4) RETURNING id`,
		req.UserID, req.FromUserID, req.Type, req.TargetID,
	).Scan(&id)
	return id, err
}

// ── List — cursor-based ───────────────────────────────────────────
func (r *Repo) List(ctx context.Context, userID, cursor string, limit int) ([]*model.Notification, string, error) {
	var rows interface{ Next() bool }
	var err error
	if cursor == "" {
		rows, err = r.db.Query(ctx, `
			SELECT n.id, n.type, COALESCE(n.target_id,''), n.read, n.created_at,
			  COALESCE(u.id,''), COALESCE(u.username,''), COALESCE(u.avatar,'')
			FROM notifications n
			LEFT JOIN users u ON u.id = n.from_user_id
			WHERE n.user_id = $1
			ORDER BY n.created_at DESC LIMIT $2`, userID, limit+1)
	} else {
		rows, err = r.db.Query(ctx, `
			SELECT n.id, n.type, COALESCE(n.target_id,''), n.read, n.created_at,
			  COALESCE(u.id,''), COALESCE(u.username,''), COALESCE(u.avatar,'')
			FROM notifications n
			LEFT JOIN users u ON u.id = n.from_user_id
			WHERE n.user_id = $1
			  AND n.created_at < (SELECT created_at FROM notifications WHERE id = $2)
			ORDER BY n.created_at DESC LIMIT $3`, userID, cursor, limit+1)
	}
	if err != nil {
		return nil, "", err
	}

	type pgxRows interface {
		Next() bool
		Scan(...any) error
		Close()
	}
	pgRows := rows.(pgxRows)
	defer pgRows.Close()

	notifs := []*model.Notification{}
	for pgRows.Next() {
		n := &model.Notification{FromUser: &model.NotifUser{}}
		pgRows.Scan(&n.ID, &n.Type, &n.TargetID, &n.Read, &n.CreatedAt,
			&n.FromUser.ID, &n.FromUser.Username, &n.FromUser.Avatar)
		notifs = append(notifs, n)
	}

	var nextCursor string
	if len(notifs) > limit {
		notifs = notifs[:limit]
		nextCursor = notifs[limit-1].ID
	}
	return notifs, nextCursor, nil
}

// ── MarkAllRead ───────────────────────────────────────────────────
func (r *Repo) MarkAllRead(ctx context.Context, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE notifications SET read=TRUE WHERE user_id=$1 AND read=FALSE`, userID)
	return err
}

// ── MarkOneRead ───────────────────────────────────────────────────
func (r *Repo) MarkOneRead(ctx context.Context, notifID, userID string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE notifications SET read=TRUE WHERE id=$1 AND user_id=$2`, notifID, userID)
	return err
}

// ── Delete ────────────────────────────────────────────────────────
func (r *Repo) Delete(ctx context.Context, notifID, userID string) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM notifications WHERE id=$1 AND user_id=$2`, notifID, userID)
	return err
}

// ── SavePushToken ─────────────────────────────────────────────────
func (r *Repo) SavePushToken(ctx context.Context, userID, token, platform string) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO push_tokens(user_id,token,platform,updated_at)
		VALUES($1,$2,$3,NOW())
		ON CONFLICT(user_id,platform) DO UPDATE SET token=$2, updated_at=NOW()`,
		userID, token, platform)
	if err == nil {
		rdb.C.Set(ctx, "fcm:"+userID+":"+platform, token, 30*24*time.Hour)
	}
	return err
}

// ── GetPushToken ──────────────────────────────────────────────────
func (r *Repo) GetPushToken(ctx context.Context, userID string) string {
	// Try Redis first
	if token, err := rdb.Get("fcm:" + userID + ":android"); err == nil && token != "" {
		return token
	}
	var token string
	r.db.QueryRow(ctx,
		`SELECT token FROM push_tokens WHERE user_id=$1 ORDER BY updated_at DESC LIMIT 1`,
		userID).Scan(&token)
	return token
}

// ── IsDuplicate — dedup via Redis TTL ────────────────────────────
func (r *Repo) IsDuplicate(userID, fromUserID, nType, targetID string) bool {
	key := "notif:dedup:" + userID + ":" + fromUserID + ":" + nType + ":" + targetID
	n, _ := rdb.C.Exists(context.Background(), key).Result()
	if n > 0 {
		return true
	}
	rdb.C.Set(context.Background(), key, "1", 5*time.Minute)
	return false
}
