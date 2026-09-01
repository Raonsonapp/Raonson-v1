package store

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"

	"raonson/marketplace/domain"
	"raonson/marketplace/ledger"
	"raonson/marketplace/money"
)

var (
	ErrCampaignNotComplete = errors.New("store: payout танҳо баъди COMPLETED")
	ErrOfferNotApproved    = errors.New("store: мӯҳтавои эҷодкор тасдиқ нашудааст")
	ErrPayoutExists        = errors.New("store: payout аллакай мавҷуд аст")
)

// PayoutOrder — сатри payout_orders.
type PayoutOrder struct {
	ID         string              `json:"id"`
	CampaignID string              `json:"campaignId"`
	CreatorID  string              `json:"creatorId"`
	Amount     money.Amount        `json:"amount"`
	Status     domain.PayoutStatus `json:"status"`
	Provider   string              `json:"provider"`
}

// CreatePayoutOrder payout-и эҷодкорро месозад.
//
// Шартҳо (ҳама дар як транзаксия, бо қуфл):
//   - кампания дар ҳолати COMPLETED
//   - offer-и эҷодкор APPROVED
//   - маблағ аз ҷадвал гирифта мешавад ва комиссия аз commission_bps-и
//     ҚУФЛшудаи кампания ҳисоб мешавад — на аз конфигуратсияи ҷорӣ
//
// UNIQUE(campaign_id, creator_id) дар DB кафолат медиҳад, ки як эҷодкор
// барои як кампания ду бор пардохт нашавад — ҳатто агар ин код хато кунад.
func CreatePayoutOrder(ctx context.Context, tx Tx, campaignID, creatorID,
	provider, idempotencyKey string) (PayoutOrder, error) {

	// 1) Кампания бояд COMPLETED бошад.
	var campStatus, campCur string
	var commissionBPS int64
	err := tx.QueryRow(ctx, `
		SELECT status, currency, commission_bps
		FROM campaigns WHERE id=$1 FOR UPDATE`, campaignID).
		Scan(&campStatus, &campCur, &commissionBPS)
	if errors.Is(err, pgx.ErrNoRows) {
		return PayoutOrder{}, domain.ErrNotFound
	}
	if err != nil {
		return PayoutOrder{}, err
	}
	if domain.CampaignStatus(campStatus) != domain.CampaignCompleted {
		return PayoutOrder{}, ErrCampaignNotComplete
	}

	// 2) Offer бояд APPROVED бошад ва маблағи мувофиқашуда дошта бошад.
	var offerStatus string
	var agreedMinor int64
	var offerCur string
	err = tx.QueryRow(ctx, `
		SELECT status, agreed_minor, currency
		FROM campaign_creators
		WHERE campaign_id=$1 AND creator_id=$2 FOR UPDATE`, campaignID, creatorID).
		Scan(&offerStatus, &agreedMinor, &offerCur)
	if errors.Is(err, pgx.ErrNoRows) {
		return PayoutOrder{}, domain.ErrNotFound
	}
	if err != nil {
		return PayoutOrder{}, err
	}
	if domain.OfferStatus(offerStatus) != domain.OfferApproved {
		return PayoutOrder{}, ErrOfferNotApproved
	}
	if offerCur != campCur {
		return PayoutOrder{}, money.ErrCurrencyMismatch
	}
	cur, err := money.ParseCurrency(campCur)
	if err != nil {
		return PayoutOrder{}, err
	}
	gross, err := money.New(money.Minor(agreedMinor), cur)
	if err != nil {
		return PayoutOrder{}, err
	}
	if gross.Minor <= 0 {
		return PayoutOrder{}, errors.New("store: маблағи мувофиқашуда бояд мусбат бошад")
	}

	// 3) Комиссия аз rate-и ҚУФЛшудаи кампания — на аз конфигуратсияи имрӯза.
	fee, net, err := gross.SplitPercent(commissionBPS)
	if err != nil {
		return PayoutOrder{}, err
	}

	// 4) Фармоиши payout. UNIQUE(campaign_id, creator_id) такрорро мебандад.
	var o PayoutOrder
	var amtMinor int64
	var curOut, stOut string
	err = tx.QueryRow(ctx, `
		INSERT INTO payout_orders
		  (campaign_id, creator_id, amount_minor, currency, status, provider, idempotency_key)
		VALUES ($1,$2,$3,$4,'PENDING',$5,$6)
		ON CONFLICT (campaign_id, creator_id) DO NOTHING
		RETURNING id, campaign_id, creator_id, amount_minor, currency, status, provider`,
		campaignID, creatorID, int64(net.Minor), string(cur), provider, idempotencyKey).
		Scan(&o.ID, &o.CampaignID, &o.CreatorID, &amtMinor, &curOut, &stOut, &o.Provider)
	if errors.Is(err, pgx.ErrNoRows) {
		return PayoutOrder{}, ErrPayoutExists
	}
	if err != nil {
		return PayoutOrder{}, fmt.Errorf("store: payout: %w", err)
	}
	c2, _ := money.ParseCurrency(curOut)
	o.Amount = money.Amount{Minor: money.Minor(amtMinor), Currency: c2}
	o.Status = domain.PayoutStatus(stOut)

	// 5) Ledger: escrow → ҳамёни эҷодкор (net) ва даромади платформа (fee).
	//    Як транзаксия бо се сатр — ҷамъашон сифр.
	escrow, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, campaignID,
		ledger.PurposeEscrow, cur)
	if err != nil {
		return PayoutOrder{}, err
	}
	creatorWallet, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerUser, creatorID,
		ledger.PurposeWallet, cur)
	if err != nil {
		return PayoutOrder{}, err
	}
	revenue, err := ledger.EnsureAccount(ctx, tx, ledger.OwnerPlatform, "",
		ledger.PurposeRevenue, cur)
	if err != nil {
		return PayoutOrder{}, err
	}
	entries := []ledger.Entry{
		{AccountID: escrow, Amount: money.Amount{Minor: -gross.Minor, Currency: cur}},
		{AccountID: creatorWallet, Amount: net},
	}
	if fee.Minor > 0 {
		entries = append(entries, ledger.Entry{AccountID: revenue, Amount: fee})
	}
	if _, err := ledger.Post(ctx, tx, "PAYOUT_ACCRUED", campaignID,
		"payout:"+o.ID, "пардохт ба эҷодкор", entries); err != nil &&
		!errors.Is(err, ledger.ErrDuplicateRef) {
		return PayoutOrder{}, err
	}

	// 6) Комиссияи қуфлшударо сабт мекунем (барои ҳисобот).
	if _, err := tx.Exec(ctx, `
		INSERT INTO platform_fees(campaign_id, commission_bps, fee_minor, currency)
		VALUES ($1,$2,$3,$4)
		ON CONFLICT (campaign_id) DO NOTHING`,
		campaignID, commissionBPS, int64(fee.Minor), string(cur)); err != nil {
		return PayoutOrder{}, err
	}

	_ = Audit(ctx, tx, "", "system", "payout.created", "payout_order", o.ID,
		map[string]any{
			"campaignId": campaignID, "creatorId": creatorID,
			"grossMinor": int64(gross.Minor), "feeMinor": int64(fee.Minor),
			"netMinor": int64(net.Minor), "commissionBps": commissionBPS,
		})
	return o, nil
}

// MarkPayoutStatus ҳолати payout-ро бо тафтиши гузариш нав мекунад.
func MarkPayoutStatus(ctx context.Context, tx Tx, payoutID string,
	to domain.PayoutStatus, reason string) error {
	var cur string
	if err := tx.QueryRow(ctx, `
		SELECT status FROM payout_orders WHERE id=$1 FOR UPDATE`, payoutID).Scan(&cur); err != nil {
		return err
	}
	from := domain.PayoutStatus(cur)
	if err := from.Transition(to); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			return nil
		}
		return err
	}
	_, err := tx.Exec(ctx, `
		UPDATE payout_orders SET status=$2, failure_reason=$3, updated_at=NOW()
		WHERE id=$1`, payoutID, string(to), reason)
	return err
}

// PayoutWebhookInput — ҳодисаи нормализашудаи payout аз provider.
type PayoutWebhookInput struct {
	EventID           string
	EventType         string
	ProviderReference string
	Status            domain.PayoutStatus
	FailureReason     string
	RawJSON           string
}

// ApplyPayoutWebhook ҳолати payout-ро аз рӯи ҳодисаи provider нав мекунад.
//
// Мисли ApplyPaymentWebhook, се қабати идемпотентӣ:
//   - webhook_events UNIQUE(provider, event_id) — такрор бетаъсир
//   - қуфли сатр + мошинаи ҳолат — гузариши нодуруст рад мешавад
//   - такрори ҳамон ҳолат ErrAlreadyInState → DUPLICATE, бе хато
//
// МУҲИМ: ин ҷо ҳеҷ сабти нави дафтар сохта намешавад. Пул аллакай
// ҳангоми CreatePayoutOrder аз escrow ба ҳамёни эҷодкор гузашт;
// webhook танҳо тақдири интиқоли БЕРУНиро сабт мекунад. Агар интиқол
// ноком шавад, маблағ дар ҳамёни эҷодкор мемонад ва кӯшиши нав мумкин аст.
func ApplyPayoutWebhook(ctx context.Context, tx Tx, provider string,
	ev PayoutWebhookInput) (applied bool, err error) {

	var eventRow int64
	err = tx.QueryRow(ctx, `
		INSERT INTO webhook_events(provider, event_id, event_type, payload, status)
		VALUES ($1,$2,$3,$4,'RECEIVED')
		ON CONFLICT (provider, event_id) DO NOTHING
		RETURNING id`, provider, ev.EventID, ev.EventType, ev.RawJSON).Scan(&eventRow)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, fmt.Errorf("store: сабти webhook-и payout: %w", err)
	}

	var id, status string
	err = tx.QueryRow(ctx, `
		SELECT id, status FROM payout_orders
		WHERE provider=$1 AND provider_reference=$2
		FOR UPDATE`, provider, ev.ProviderReference).Scan(&id, &status)
	if errors.Is(err, pgx.ErrNoRows) {
		_ = markWebhook(ctx, tx, eventRow, "IGNORED", "фармоиши payout ёфт нашуд")
		return false, domain.ErrNotFound
	}
	if err != nil {
		return false, err
	}

	from := domain.PayoutStatus(status)
	if err := from.Transition(ev.Status); err != nil {
		if errors.Is(err, domain.ErrAlreadyInState) {
			_ = markWebhook(ctx, tx, eventRow, "DUPLICATE", "")
			return false, nil
		}
		_ = markWebhook(ctx, tx, eventRow, "REJECTED", err.Error())
		return false, err
	}
	if _, err := tx.Exec(ctx, `
		UPDATE payout_orders SET status=$2, failure_reason=$3, updated_at=NOW()
		WHERE id=$1`, id, string(ev.Status), ev.FailureReason); err != nil {
		return false, err
	}

	_ = markWebhook(ctx, tx, eventRow, "PROCESSED", "")
	_ = Audit(ctx, tx, "", "provider", "payout.webhook", "payout_order", id,
		map[string]any{"status": ev.Status, "eventId": ev.EventID})
	return true, nil
}

// CreatorPayout — як сатри таърихи пардохт барои эҷодкор.
type CreatorPayout struct {
	ID         string              `json:"id"`
	CampaignID string              `json:"campaignId"`
	Title      string              `json:"campaignTitle"`
	Amount     money.Amount        `json:"amount"`
	Status     domain.PayoutStatus `json:"status"`
	Provider   string              `json:"provider"`
	Reason     string              `json:"failureReason,omitempty"`
	CreatedAt  time.Time           `json:"createdAt"`
}

// ListPayoutsForCreator таърихи пардохтҳои эҷодкорро бармегардонад.
//
// creator_id аз токен меояд ва дар WHERE аст — эҷодкор пардохти каси
// дигарро дида наметавонад.
func ListPayoutsForCreator(ctx context.Context, tx Tx, creatorID string,
	limit, offset int) ([]CreatorPayout, error) {
	rows, err := tx.Query(ctx, `
		SELECT p.id, p.campaign_id, COALESCE(c.title,''), p.amount_minor,
		       p.currency, p.status, p.provider, COALESCE(p.failure_reason,''),
		       p.created_at
		FROM payout_orders p
		LEFT JOIN campaigns c ON c.id = p.campaign_id
		WHERE p.creator_id=$1
		ORDER BY p.created_at DESC LIMIT $2 OFFSET $3`, creatorID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CreatorPayout{}
	for rows.Next() {
		var p CreatorPayout
		var amt int64
		var cur, st string
		if err := rows.Scan(&p.ID, &p.CampaignID, &p.Title, &amt, &cur,
			&st, &p.Provider, &p.Reason, &p.CreatedAt); err != nil {
			continue
		}
		c, _ := money.ParseCurrency(cur)
		p.Amount = money.Amount{Minor: money.Minor(amt), Currency: c}
		p.Status = domain.PayoutStatus(st)
		out = append(out, p)
	}
	return out, rows.Err()
}

// CreatorEarnings — ҷамъбасти даромади эҷодкор.
//
// Ҳар рақам аз ҷадвалҳо ҳисоб мешавад, на аз сутуни ҷамъшуда.
type CreatorEarnings struct {
	Wallet    CreatorWallet `json:"wallet"`
	PaidOut   money.Amount  `json:"paidOut"`
	Upcoming  money.Amount  `json:"upcoming"`
	Campaigns int64         `json:"completedCampaigns"`
}

// GetCreatorEarnings даромади эҷодкорро ҷамъбаст мекунад.
//
// Upcoming — маблағи offer-ҳои тасдиқшуда, ки кампанияашон ҳанӯз
// пӯшида нашудааст: пул ваъда шудааст, вале ҳанӯз ҳисоб нашудааст.
// Комиссия аз он тарҳ мешавад, то рақам ваъдаи аз ҳад набошад.
func GetCreatorEarnings(ctx context.Context, tx Tx, creatorID string,
	cur money.Currency) (CreatorEarnings, error) {
	var e CreatorEarnings
	w, err := GetCreatorWallet(ctx, tx, creatorID, cur)
	if err != nil {
		return CreatorEarnings{}, err
	}
	e.Wallet = w

	var paid int64
	if err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(amount_minor),0) FROM payout_orders
		WHERE creator_id=$1 AND currency=$2 AND status='SUCCEEDED'`,
		creatorID, string(cur)).Scan(&paid); err != nil {
		return CreatorEarnings{}, err
	}
	e.PaidOut = money.Amount{Minor: money.Minor(paid), Currency: cur}

	// Маблағи интизорӣ: offer-и APPROVED дар кампанияи ҳанӯз накушода,
	// бо тарҳи комиссияи ҚУФЛшудаи ҳамон кампания.
	var upcoming int64
	if err := tx.QueryRow(ctx, `
		SELECT COALESCE(SUM(
		         cc.agreed_minor - ((cc.agreed_minor * c.commission_bps + 5000) / 10000)
		       ),0)
		FROM campaign_creators cc
		JOIN campaigns c ON c.id = cc.campaign_id
		WHERE cc.creator_id=$1 AND cc.currency=$2
		  AND cc.status='APPROVED'
		  AND c.status NOT IN ('COMPLETED','CANCELLED','REFUNDED')`,
		creatorID, string(cur)).Scan(&upcoming); err != nil {
		return CreatorEarnings{}, err
	}
	e.Upcoming = money.Amount{Minor: money.Minor(upcoming), Currency: cur}

	if err := tx.QueryRow(ctx, `
		SELECT COUNT(*) FROM campaign_creators cc
		JOIN campaigns c ON c.id = cc.campaign_id
		WHERE cc.creator_id=$1 AND cc.status='APPROVED' AND c.status='COMPLETED'`,
		creatorID).Scan(&e.Campaigns); err != nil {
		return CreatorEarnings{}, err
	}
	return e, nil
}

// CreatorCampaign — кампанияе, ки эҷодкор дар он иштирок дорад.
type CreatorCampaign struct {
	CampaignID string             `json:"campaignId"`
	Title      string             `json:"title"`
	Status     string             `json:"campaignStatus"`
	OfferID    string             `json:"offerId"`
	Offer      domain.OfferStatus `json:"offerStatus"`
	Agreed     money.Amount       `json:"agreed"`
	ContentID  string             `json:"contentId,omitempty"`
}

// ListCampaignsForCreator кампанияҳои эҷодкорро бармегардонад.
func ListCampaignsForCreator(ctx context.Context, tx Tx, creatorID string,
	limit, offset int) ([]CreatorCampaign, error) {
	rows, err := tx.Query(ctx, `
		SELECT cc.campaign_id, COALESCE(c.title,''), COALESCE(c.status,''),
		       cc.id, cc.status, cc.agreed_minor, cc.currency,
		       COALESCE(cc.content_id,'')
		FROM campaign_creators cc
		JOIN campaigns c ON c.id = cc.campaign_id
		WHERE cc.creator_id=$1 AND cc.status IN ('ACCEPTED','DELIVERED','APPROVED')
		ORDER BY cc.created_at DESC LIMIT $2 OFFSET $3`, creatorID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []CreatorCampaign{}
	for rows.Next() {
		var r CreatorCampaign
		var amt int64
		var cur, st string
		if err := rows.Scan(&r.CampaignID, &r.Title, &r.Status, &r.OfferID,
			&st, &amt, &cur, &r.ContentID); err != nil {
			continue
		}
		c, _ := money.ParseCurrency(cur)
		r.Agreed = money.Amount{Minor: money.Minor(amt), Currency: c}
		r.Offer = domain.OfferStatus(st)
		out = append(out, r)
	}
	return out, rows.Err()
}
