package store

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/domain"
	"raonson/marketplace/matching"
	"raonson/marketplace/money"
)

var (
	ErrCampaignNotPaid = errors.New("store: эҷодкор танҳо баъди пардохт даъват мешавад")
	ErrOfferExists     = errors.New("store: эҷодкор аллакай даъват шудааст")
	ErrBudgetExceeded  = errors.New("store: маблағи даъватҳо аз буҷет зиёд")
)

// Offer — сатри campaign_creators.
type Offer struct {
	ID         string             `json:"id"`
	CampaignID string             `json:"campaignId"`
	CreatorID  string             `json:"creatorId"`
	Status     domain.OfferStatus `json:"status"`
	MatchScore float64            `json:"matchScore"`
	Reasons    []string           `json:"reasons"`
	Agreed     money.Amount       `json:"agreed"`
}

// InviteCreator эҷодкорро ба кампания даъват мекунад.
//
// Шартҳо:
//   - кампания PAID ё дертар (даъват бе пардохт маъно надорад)
//   - ҷамъи маблағи даъватҳо аз буҷет зиёд нашавад — сервер ҳисоб мекунад
//   - UNIQUE(campaign_id, creator_id) даъвати такрориро мебандад
func InviteCreator(ctx context.Context, tx Tx, campaignID, creatorID, actorID string,
	agreedMinor int64, m matching.Match) (Offer, error) {

	var status, cur string
	var budget int64
	err := tx.QueryRow(ctx, `
		SELECT status, currency, budget_minor
		FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).Scan(&status, &cur, &budget)
	if errors.Is(err, pgx.ErrNoRows) {
		return Offer{}, domain.ErrNotFound
	}
	if err != nil {
		return Offer{}, err
	}
	st := domain.CampaignStatus(status)
	switch st {
	case domain.CampaignPaid, domain.CampaignMatching,
		domain.CampaignCreatorInvited, domain.CampaignCreatorAccepted:
		// иҷозат
	default:
		return Offer{}, ErrCampaignNotPaid
	}
	if agreedMinor <= 0 {
		return Offer{}, fmt.Errorf("store: маблағи мувофиқашуда бояд мусбат бошад")
	}

	// Ҷамъи даъватҳои қаблӣ + ин яке набояд аз буҷет гузарад.
	var already int64
	if err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(agreed_minor),0) FROM campaign_creators
		WHERE campaign_id=$1 AND status NOT IN ('REJECTED','EXPIRED','CANCELLED')`,
		campaignID).Scan(&already); err != nil {
		return Offer{}, err
	}
	if already+agreedMinor > budget {
		return Offer{}, ErrBudgetExceeded
	}

	c, err := money.ParseCurrency(cur)
	if err != nil {
		return Offer{}, err
	}

	var o Offer
	var amt int64
	var curOut, stOut string
	err = tx.QueryRow(ctx, `
		INSERT INTO campaign_creators
		  (campaign_id, creator_id, status, match_score, match_reasons, agreed_minor, currency)
		VALUES ($1,$2,'INVITED',$3,$4,$5,$6)
		ON CONFLICT (campaign_id, creator_id) DO NOTHING
		RETURNING id, campaign_id, creator_id, status, match_score, match_reasons,
		          agreed_minor, currency`,
		campaignID, creatorID, m.MatchScore, m.Reasons, agreedMinor, string(c)).
		Scan(&o.ID, &o.CampaignID, &o.CreatorID, &stOut, &o.MatchScore, &o.Reasons,
			&amt, &curOut)
	if errors.Is(err, pgx.ErrNoRows) {
		return Offer{}, ErrOfferExists
	}
	if err != nil {
		return Offer{}, fmt.Errorf("store: даъват: %w", err)
	}
	c2, _ := money.ParseCurrency(curOut)
	o.Agreed = money.Amount{Minor: money.Minor(amt), Currency: c2}
	o.Status = domain.OfferStatus(stOut)

	// Кампания ба CREATOR_INVITED мегузарад (агар ҳанӯз набошад).
	if st == domain.CampaignPaid || st == domain.CampaignMatching {
		_ = setCampaignStatus(ctx, tx, campaignID, st, domain.CampaignCreatorInvited,
			actorID, "creator_invited")
	}
	_ = CampaignEvent(ctx, tx, campaignID, creatorID, "creator.invited", "", "INVITED", actorID,
		map[string]any{"agreedMinor": agreedMinor, "matchScore": m.MatchScore})
	return o, nil
}

// RespondToOffer — эҷодкор даъватро қабул ё рад мекунад.
//
// Танҳо худи эҷодкор метавонад ҷавоб диҳад: creatorID аз токен меояд ва
// дар WHERE истифода мешавад, бинобар ин offer-и каси дигар дида намешавад.
func RespondToOffer(ctx context.Context, tx Tx, offerID, creatorID string, accept bool) (Offer, error) {
	var o Offer
	var stOut, curOut, campaignID string
	var amt int64
	err := tx.QueryRow(ctx, `
		SELECT id, campaign_id, creator_id, status, agreed_minor, currency
		FROM campaign_creators
		WHERE id=$1 AND creator_id=$2 FOR UPDATE`, offerID, creatorID).
		Scan(&o.ID, &campaignID, &o.CreatorID, &stOut, &amt, &curOut)
	if errors.Is(err, pgx.ErrNoRows) {
		return Offer{}, domain.ErrNotFound
	}
	if err != nil {
		return Offer{}, err
	}
	o.CampaignID = campaignID
	from := domain.OfferStatus(stOut)
	to := domain.OfferRejected
	if accept {
		to = domain.OfferAccepted
	}
	if err := from.Transition(to); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			o.Status = from
			return o, nil
		}
		return Offer{}, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE campaign_creators SET status=$2, responded_at=NOW(), updated_at=NOW()
		WHERE id=$1`, offerID, string(to)); err != nil {
		return Offer{}, err
	}
	o.Status = to
	c2, _ := money.ParseCurrency(curOut)
	o.Agreed = money.Amount{Minor: money.Minor(amt), Currency: c2}

	_ = CampaignEvent(ctx, tx, campaignID, creatorID, "creator.responded",
		string(from), string(to), creatorID, nil)

	// Агар қабул шуд ва кампания ҳанӯз ACTIVE нашуда бошад — мегузарад.
	if accept {
		var cs string
		if err := tx.QueryRow(ctx, `
			SELECT status FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).Scan(&cs); err == nil {
			cur := domain.CampaignStatus(cs)
			if cur == domain.CampaignCreatorInvited {
				_ = setCampaignStatus(ctx, tx, campaignID, cur, domain.CampaignCreatorAccepted,
					creatorID, "creator_accepted")
			}
		}
	}
	return o, nil
}

// SubmitContent — эҷодкор мӯҳтавои нашркардаашро мепайвандад.
func SubmitContent(ctx context.Context, tx Tx, offerID, creatorID, contentID, contentType string) error {
	var stOut, campaignID string
	err := tx.QueryRow(ctx, `
		SELECT status, campaign_id FROM campaign_creators
		WHERE id=$1 AND creator_id=$2 FOR UPDATE`, offerID, creatorID).Scan(&stOut, &campaignID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.ErrNotFound
	}
	if err != nil {
		return err
	}
	from := domain.OfferStatus(stOut)
	if err := from.Transition(domain.OfferDelivered); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			return nil
		}
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE campaign_creators
		SET status='DELIVERED', content_id=$2, content_type=$3,
		    delivered_at=NOW(), updated_at=NOW()
		WHERE id=$1`, offerID, contentID, contentType); err != nil {
		return err
	}
	_ = CampaignEvent(ctx, tx, campaignID, creatorID, "content.delivered",
		string(from), "DELIVERED", creatorID,
		map[string]any{"contentId": contentID, "contentType": contentType})
	return nil
}

// ApproveContent — рекламадиҳанда мӯҳтаворо тасдиқ мекунад.
// Танҳо соҳиби кампания метавонад — тафтиши соҳибӣ дар query.
func ApproveContent(ctx context.Context, tx Tx, offerID, advertiserID string) error {
	var stOut, campaignID, creatorID string
	err := tx.QueryRow(ctx, `
		SELECT cc.status, cc.campaign_id, cc.creator_id
		FROM campaign_creators cc
		JOIN campaigns c ON c.id = cc.campaign_id
		WHERE cc.id=$1 AND c.advertiser_id=$2
		FOR UPDATE OF cc`, offerID, advertiserID).Scan(&stOut, &campaignID, &creatorID)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.ErrForbidden
	}
	if err != nil {
		return err
	}
	from := domain.OfferStatus(stOut)
	if err := from.Transition(domain.OfferApproved); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			return nil
		}
		return err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE campaign_creators SET status='APPROVED', updated_at=NOW()
		WHERE id=$1`, offerID); err != nil {
		return err
	}
	_ = CampaignEvent(ctx, tx, campaignID, creatorID, "content.approved",
		string(from), "APPROVED", advertiserID, nil)
	return nil
}

// ListOffersForCreator — даъватҳои эҷодкор.
func ListOffersForCreator(ctx context.Context, tx Tx, creatorID, statusFilter string,
	limit, offset int) ([]Offer, error) {
	rows, err := tx.Query(ctx, `
		SELECT id, campaign_id, creator_id, status, match_score,
		       COALESCE(match_reasons,'{}'), agreed_minor, currency
		FROM campaign_creators
		WHERE creator_id=$1 AND ($2::text='' OR status=$2::text)
		ORDER BY created_at DESC LIMIT $3 OFFSET $4`,
		creatorID, statusFilter, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []Offer{}
	for rows.Next() {
		var o Offer
		var st, cur string
		var amt int64
		if err := rows.Scan(&o.ID, &o.CampaignID, &o.CreatorID, &st,
			&o.MatchScore, &o.Reasons, &amt, &cur); err != nil {
			continue
		}
		c, _ := money.ParseCurrency(cur)
		o.Agreed = money.Amount{Minor: money.Minor(amt), Currency: c}
		o.Status = domain.OfferStatus(st)
		out = append(out, o)
	}
	return out, nil
}
