package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/domain"
)

var (
	// ErrCampaignNotReady — кампания ҳанӯз ба анҷом омода нест.
	ErrCampaignNotReady = errors.New("store: кампания ҳанӯз ба анҷом омода нест")
	// ErrNoApprovedCreators — чизе барои пардохт нест.
	ErrNoApprovedCreators = errors.New("store: ҳеҷ эҷодкори тасдиқшуда нест")
)

// offerCounts — ҳисоби ҳолати эҷодкорони кампания.
type offerCounts struct {
	Total     int
	Active    int // рад/бекор нашуда
	Delivered int
	Approved  int
}

func countOffers(ctx context.Context, tx Tx, campaignID string) (offerCounts, error) {
	var c offerCounts
	err := tx.QueryRow(ctx, `
		SELECT COUNT(*),
		       COUNT(*) FILTER (WHERE status NOT IN ('REJECTED','EXPIRED','CANCELLED')),
		       COUNT(*) FILTER (WHERE status IN ('DELIVERED','APPROVED')),
		       COUNT(*) FILTER (WHERE status = 'APPROVED')
		FROM campaign_creators WHERE campaign_id=$1`, campaignID).
		Scan(&c.Total, &c.Active, &c.Delivered, &c.Approved)
	return c, err
}

// AdvanceCampaignOnDelivery кампанияро ҳангоми пайдо шудани мӯҳтавои
// зинда ба ACTIVE мебарад.
//
// Ин аз ҳодисаи ВОҚЕӢ бармеояд: эҷодкор мӯҳтаво нашр кард, пас кампания
// воқеан фаъол аст. Ҳеҷ таймер ва ҳеҷ тахмин.
func AdvanceCampaignOnDelivery(ctx context.Context, tx Tx, campaignID, actorID string) error {
	var st string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).Scan(&st); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return err
	}
	from := domain.CampaignStatus(st)
	if from != domain.CampaignCreatorAccepted {
		return nil // аллакай ACTIVE ё дертар — коре нест
	}
	return setCampaignStatus(ctx, tx, campaignID, from, domain.CampaignActive,
		actorID, "content_delivered")
}

// AdvanceCampaignOnApproval кампанияро ба REVIEW мебарад, вақте ҲАМА
// эҷодкорони фаъол мӯҳтавои худро тасдиқ кардаанд.
//
// То он даме ки ҳатто як эҷодкор боқӣ монда бошад, кампания ACTIVE
// мемонад — REVIEW маънои «ҳама кор супорида шуд» дорад.
func AdvanceCampaignOnApproval(ctx context.Context, tx Tx, campaignID, actorID string) error {
	var st string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).Scan(&st); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return err
	}
	from := domain.CampaignStatus(st)
	if from != domain.CampaignActive {
		return nil
	}
	counts, err := countOffers(ctx, tx, campaignID)
	if err != nil {
		return err
	}
	if counts.Active == 0 || counts.Approved < counts.Active {
		return nil // ҳанӯз ҳама тасдиқ нашудаанд
	}
	return setCampaignStatus(ctx, tx, campaignID, from, domain.CampaignReview,
		actorID, "all_content_approved")
}

// CompleteCampaign кампанияро мебандад ва барои ҳар эҷодкори тасдиқшуда
// фармоиши пардохт месозад.
//
// Шартҳо:
//   - кампания дар REVIEW бошад (яъне ҳама мӯҳтаво тасдиқ шудааст)
//   - ҳадди ақал як эҷодкори APPROVED бошад
//
// Пардохтҳо дар ҲАМОН транзаксия сохта мешаванд, ки кампания баста
// мешавад: ё ҳама, ё ҳеҷ. UNIQUE(campaign_id, creator_id) дар
// payout_orders такрори пардохтро ғайриимкон мекунад, бинобар ин
// даъвати такрории ин функсия пули дукарата намедиҳад.
func CompleteCampaign(ctx context.Context, tx Tx, campaignID, provider, actorID string) ([]PayoutOrder, error) {
	var st string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).Scan(&st); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrNotFound
		}
		return nil, err
	}
	from := domain.CampaignStatus(st)
	if from != domain.CampaignReview {
		return nil, fmt.Errorf("%w: ҳолати ҷорӣ %s", ErrCampaignNotReady, from)
	}

	rows, err := tx.Query(ctx, `
		SELECT creator_id FROM campaign_creators
		WHERE campaign_id=$1 AND status='APPROVED'
		ORDER BY creator_id`, campaignID)
	if err != nil {
		return nil, err
	}
	creators := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			rows.Close()
			return nil, err
		}
		creators = append(creators, id)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if len(creators) == 0 {
		return nil, ErrNoApprovedCreators
	}

	// Аввал кампания баста мешавад: CreatePayoutOrder талаб мекунад,
	// ки кампания COMPLETED бошад.
	if err := setCampaignStatus(ctx, tx, campaignID, from, domain.CampaignCompleted,
		actorID, "campaign_completed"); err != nil {
		return nil, err
	}

	out := make([]PayoutOrder, 0, len(creators))
	for _, creatorID := range creators {
		// Калиди идемпотентӣ устувор аст: такрори даъват ҳамон
		// фармоишро мебинад, на фармоиши нав.
		key := "payout:" + campaignID + ":" + creatorID
		o, err := CreatePayoutOrder(ctx, tx, campaignID, creatorID, provider, key)
		if err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, nil
}
