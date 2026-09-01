package store

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

var (
	ErrInvalidCampaign = errors.New("store: маълумоти кампания нодуруст")
	ErrBudgetLocked    = errors.New("store: буҷет баъди пардохт тағйир намеёбад")
)

// CampaignInput — вуруди сохтани кампания. Ҳама майдонҳо тафтиш мешаванд.
type CampaignInput struct {
	Title               string
	Description         string
	Category            string
	TargetCountry       string
	TargetCity          string
	TargetAgeMin        int
	TargetAgeMax        int
	TargetGender        string
	TargetInterests     []string
	BudgetMinor         int64
	Currency            string
	CampaignType        string
	StartAt             *time.Time
	EndAt               *time.Time
	RequiredImpressions int64
	RequiredClicks      int64
	CreatorCount        int
}

// Validate қоидаҳои сервериро татбиқ мекунад.
//
// Ҳамаи маҳдудиятҳо ин ҷо санҷида мешаванд, на дар client: client
// метавонад ҳар чиз фиристад.
func (in CampaignInput) Validate() error {
	if strings.TrimSpace(in.Title) == "" {
		return fmt.Errorf("%w: сарлавҳа лозим аст", ErrInvalidCampaign)
	}
	if len([]rune(in.Title)) > 200 {
		return fmt.Errorf("%w: сарлавҳа хеле дароз", ErrInvalidCampaign)
	}
	if in.BudgetMinor <= 0 {
		return fmt.Errorf("%w: буҷет бояд мусбат бошад", ErrInvalidCampaign)
	}
	if _, err := money.ParseCurrency(in.Currency); err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidCampaign, err)
	}
	if in.CreatorCount < 1 || in.CreatorCount > 100 {
		return fmt.Errorf("%w: шумораи эҷодкорон бояд 1..100 бошад", ErrInvalidCampaign)
	}
	if in.TargetAgeMin < 0 || in.TargetAgeMax < 0 || in.TargetAgeMin > 120 || in.TargetAgeMax > 120 {
		return fmt.Errorf("%w: синну сол нодуруст", ErrInvalidCampaign)
	}
	if in.TargetAgeMax > 0 && in.TargetAgeMin > in.TargetAgeMax {
		return fmt.Errorf("%w: синну соли ҳадди ақал аз ҳадди аксар зиёд", ErrInvalidCampaign)
	}
	if in.StartAt != nil && in.EndAt != nil && in.EndAt.Before(*in.StartAt) {
		return fmt.Errorf("%w: санаи анҷом пеш аз оғоз", ErrInvalidCampaign)
	}
	// Буҷет бояд ба ҳар эҷодкор ҳадди ақал 1 воҳиди хурд расад.
	if in.BudgetMinor < int64(in.CreatorCount) {
		return fmt.Errorf("%w: буҷет барои %d эҷодкор хеле кам", ErrInvalidCampaign, in.CreatorCount)
	}
	return nil
}

// Campaign — сатри campaigns.
type Campaign struct {
	ID            string                `json:"id"`
	AdvertiserID  string                `json:"advertiserId"`
	Title         string                `json:"title"`
	Description   string                `json:"description"`
	Category      string                `json:"category"`
	TargetCountry string                `json:"targetCountry"`
	Budget        money.Amount          `json:"budget"`
	Status        domain.CampaignStatus `json:"status"`
	CreatorCount  int                   `json:"creatorCount"`
	CommissionBPS int64                 `json:"commissionBps"`
	CreatedAt     time.Time             `json:"createdAt"`
}

// CreateCampaign кампанияи навро дар ҳолати DRAFT месозад.
//
// commissionBPS ҳангоми сохтан ҚУФЛ мешавад: тағйири баъдии rate-и
// платформа ба ин кампания таъсир намерасонад.
func CreateCampaign(ctx context.Context, tx Tx, advertiserID string,
	in CampaignInput, commissionBPS int64) (Campaign, error) {
	if err := in.Validate(); err != nil {
		return Campaign{}, err
	}
	if commissionBPS < 0 || commissionBPS > 10000 {
		return Campaign{}, fmt.Errorf("%w: комиссия нодуруст", ErrInvalidCampaign)
	}
	cur, _ := money.ParseCurrency(in.Currency)

	var c Campaign
	var budget int64
	var curOut, status string
	err := tx.QueryRow(ctx, `
		INSERT INTO campaigns
		  (advertiser_id,title,description,category,target_country,target_city,
		   target_age_min,target_age_max,target_gender,target_interests,
		   budget_minor,currency,campaign_type,start_at,end_at,
		   required_impressions,required_clicks,creator_count,status,commission_bps)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,'DRAFT',$19)
		RETURNING id, advertiser_id, title, description, category, target_country,
		          budget_minor, currency, status, creator_count, commission_bps, created_at`,
		advertiserID, strings.TrimSpace(in.Title), in.Description, in.Category,
		in.TargetCountry, in.TargetCity, in.TargetAgeMin, in.TargetAgeMax,
		in.TargetGender, in.TargetInterests, in.BudgetMinor, string(cur),
		in.CampaignType, in.StartAt, in.EndAt, in.RequiredImpressions,
		in.RequiredClicks, in.CreatorCount, commissionBPS).
		Scan(&c.ID, &c.AdvertiserID, &c.Title, &c.Description, &c.Category,
			&c.TargetCountry, &budget, &curOut, &status, &c.CreatorCount,
			&c.CommissionBPS, &c.CreatedAt)
	if err != nil {
		return Campaign{}, fmt.Errorf("store: сохтани кампания: %w", err)
	}
	c2, _ := money.ParseCurrency(curOut)
	c.Budget = money.Amount{Minor: money.Minor(budget), Currency: c2}
	c.Status = domain.CampaignStatus(status)

	_ = CampaignEvent(ctx, tx, c.ID, "", "campaign.created", "", string(c.Status), advertiserID, nil)
	_ = Audit(ctx, tx, advertiserID, "advertiser", "campaign.created", "campaign", c.ID,
		map[string]any{"budgetMinor": budget, "currency": curOut, "commissionBps": commissionBPS})
	return c, nil
}

// GetCampaign кампанияро бо тафтиши соҳибӣ мегирад.
//
// Агар advertiserID холӣ набошад, кампанияи каси дигар ErrForbidden медиҳад —
// рекламадиҳанда кампанияи дигарро дида наметавонад.
func GetCampaign(ctx context.Context, tx Tx, campaignID, advertiserID string) (Campaign, error) {
	var c Campaign
	var budget int64
	var cur, status string
	err := tx.QueryRow(ctx, `
		SELECT id, advertiser_id, title, description, category, target_country,
		       budget_minor, currency, status, creator_count, commission_bps, created_at
		FROM campaigns WHERE id=$1`, campaignID).
		Scan(&c.ID, &c.AdvertiserID, &c.Title, &c.Description, &c.Category,
			&c.TargetCountry, &budget, &cur, &status, &c.CreatorCount,
			&c.CommissionBPS, &c.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return Campaign{}, domain.ErrNotFound
	}
	if err != nil {
		return Campaign{}, err
	}
	if advertiserID != "" && c.AdvertiserID != advertiserID {
		return Campaign{}, domain.ErrForbidden
	}
	c2, _ := money.ParseCurrency(cur)
	c.Budget = money.Amount{Minor: money.Minor(budget), Currency: c2}
	c.Status = domain.CampaignStatus(status)
	return c, nil
}

// ListCampaigns кампанияҳои рекламадиҳандаро бармегардонад.
func ListCampaigns(ctx context.Context, tx Tx, advertiserID string, limit, offset int) ([]Campaign, error) {
	rows, err := tx.Query(ctx, `
		SELECT id, advertiser_id, title, description, category, target_country,
		       budget_minor, currency, status, creator_count, commission_bps, created_at
		FROM campaigns WHERE advertiser_id=$1
		ORDER BY created_at DESC LIMIT $2 OFFSET $3`, advertiserID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Campaign{}
	for rows.Next() {
		var c Campaign
		var budget int64
		var cur, status string
		if err := rows.Scan(&c.ID, &c.AdvertiserID, &c.Title, &c.Description,
			&c.Category, &c.TargetCountry, &budget, &cur, &status,
			&c.CreatorCount, &c.CommissionBPS, &c.CreatedAt); err != nil {
			continue
		}
		c2, _ := money.ParseCurrency(cur)
		c.Budget = money.Amount{Minor: money.Minor(budget), Currency: c2}
		c.Status = domain.CampaignStatus(status)
		out = append(out, c)
	}
	return out, nil
}

// TransitionCampaign гузариши ҳолатро бо тафтиш иҷро мекунад.
func TransitionCampaign(ctx context.Context, tx Tx, campaignID string,
	to domain.CampaignStatus, actorID, reason string) error {
	var cur string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).Scan(&cur); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return domain.ErrNotFound
		}
		return err
	}
	from := domain.CampaignStatus(cur)
	if err := from.Transition(to); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			return nil
		}
		return err
	}
	return setCampaignStatus(ctx, tx, campaignID, from, to, actorID, reason)
}
