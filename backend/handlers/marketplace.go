package handlers

// Creator Marketplace — тарафи рекламадиҳанда.
//
// Рекламадиҳанда кампания месозад, онро пардохт мекунад, эҷодкоронро
// интихоб ва даъват мекунад ва мӯҳтавои таҳвилшударо тасдиқ мекунад.
//
// Ҳама маблағ дар воҳиди хурд (диram) ҳисоб мешавад ва ҲАМЕША аз
// сервер меояд: client ҳеҷ гоҳ маблағи пардохтро таъин намекунад.

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"raonson/db"
	"raonson/marketplace"
	"raonson/marketplace/domain"
	"raonson/marketplace/matching"
	"raonson/marketplace/money"
	"raonson/marketplace/payments"
	"raonson/marketplace/store"
	mw "raonson/middleware"
)

// mpTx як транзаксия мекушояд ва онро ба fn медиҳад.
//
// Ҳама амалиёти молиявӣ дар ЯК транзаксия иҷро мешавад: ё ҳама сабт
// мешавад, ё ҳеҷ чиз. Rollback таъхирӣ аст, то ҳатто дар вазъи
// ғайричашмдошт пайваст кушода намонад.
func mpTx(ctx context.Context, fn func(tx store.Tx) error) error {
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// mpFail хатоҳои домениро ба коди HTTP табдил медиҳад.
//
// Матни хато ба корбар дода мешавад танҳо вақте он барои ӯ маъно
// дорад; хатоҳои дохилӣ пинҳон мемонанд.
func mpFail(c *gin.Context, err error) {
	switch {
	case errors.Is(err, domain.ErrNotFound), errors.Is(err, store.ErrCreatorProfileMissing):
		c.JSON(http.StatusNotFound, gin.H{"message": "Ёфт нашуд"})
	case errors.Is(err, domain.ErrForbidden):
		c.JSON(http.StatusForbidden, gin.H{"message": "Иҷозат нест"})
	case errors.Is(err, store.ErrInvalidCampaign),
		errors.Is(err, store.ErrInvalidCreatorProfile),
		errors.Is(err, money.ErrUnknownCurrency):
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
	case errors.Is(err, store.ErrBudgetExceeded):
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маблағи даъватҳо аз буҷети кампания зиёд аст"})
	case errors.Is(err, store.ErrCampaignNotReady),
		errors.Is(err, store.ErrNoApprovedCreators):
		c.JSON(http.StatusConflict, gin.H{"message": err.Error()})
	case errors.Is(err, store.ErrCampaignNotPaid):
		c.JSON(http.StatusConflict, gin.H{"message": "Аввал кампанияро пардохт кунед"})
	case errors.Is(err, store.ErrOfferExists):
		c.JSON(http.StatusConflict, gin.H{"message": "Ин эҷодкор аллакай даъват шудааст"})
	case errors.Is(err, payments.ErrUnknownProvider):
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "Хизмати пардохт танзим нашудааст"})
	default:
		c.JSON(http.StatusBadRequest, gin.H{"message": err.Error()})
	}
}

func mpService(c *gin.Context) (*marketplace.Service, bool) {
	s, err := marketplace.Get()
	if err != nil || s == nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "Marketplace танзим нашудааст"})
		return nil, false
	}
	return s, true
}

// currentAdvertiser id-и рекламадиҳандаи корбарро мегирад ва агар
// набошад, месозад. Як корбар — як рекламадиҳанда (UNIQUE user_id).
func currentAdvertiser(ctx context.Context, tx store.Tx, userID string) (string, error) {
	var id string
	err := tx.QueryRow(ctx, `
		INSERT INTO advertisers(user_id) VALUES ($1)
		ON CONFLICT (user_id) DO UPDATE SET updated_at = NOW()
		RETURNING id`, userID).Scan(&id)
	return id, err
}

// ── Профили рекламадиҳанда ──────────────────────────────────────

// GET /marketplace/advertiser
func GetAdvertiser(c *gin.Context) {
	ctx := c.Request.Context()
	var out gin.H
	err := mpTx(ctx, func(tx store.Tx) error {
		id, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		var company, email, phone, country string
		var verified bool
		if err := tx.QueryRow(ctx, `
			SELECT company_name, contact_email, contact_phone, country, verified
			FROM advertisers WHERE id=$1`, id).
			Scan(&company, &email, &phone, &country, &verified); err != nil {
			return err
		}
		out = gin.H{"id": id, "companyName": company, "contactEmail": email,
			"contactPhone": phone, "country": country, "verified": verified}
		return nil
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

// PUT /marketplace/advertiser
func UpdateAdvertiser(c *gin.Context) {
	var b struct {
		CompanyName  string `json:"companyName"`
		ContactEmail string `json:"contactEmail"`
		ContactPhone string `json:"contactPhone"`
		Country      string `json:"country"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	if len([]rune(b.CompanyName)) > 120 || len([]rune(b.ContactEmail)) > 190 {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Матн хеле дароз"})
		return
	}
	ctx := c.Request.Context()
	err := mpTx(ctx, func(tx store.Tx) error {
		id, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		// verified ин ҷо НЕСТ: рекламадиҳанда худро тасдиқшуда карда наметавонад.
		_, err = tx.Exec(ctx, `
			UPDATE advertisers SET company_name=$2, contact_email=$3,
			       contact_phone=$4, country=$5, updated_at=NOW()
			WHERE id=$1`, id, b.CompanyName, b.ContactEmail, b.ContactPhone, b.Country)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Сабт шуд"})
}

// ── Кампанияҳо ───────────────────────────────────────────────────

// POST /marketplace/campaigns
func CreateCampaign(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	var b struct {
		Title               string   `json:"title"`
		Description         string   `json:"description"`
		Category            string   `json:"category"`
		TargetCountry       string   `json:"targetCountry"`
		TargetCity          string   `json:"targetCity"`
		TargetAgeMin        int      `json:"targetAgeMin"`
		TargetAgeMax        int      `json:"targetAgeMax"`
		TargetGender        string   `json:"targetGender"`
		TargetLanguage      string   `json:"targetLanguage"`
		TargetInterests     []string `json:"targetInterests"`
		BudgetMinor         int64    `json:"budgetMinor"`
		Currency            string   `json:"currency"`
		CampaignType        string   `json:"campaignType"`
		StartAt             string   `json:"startAt"`
		EndAt               string   `json:"endAt"`
		RequiredImpressions int64    `json:"requiredImpressions"`
		RequiredClicks      int64    `json:"requiredClicks"`
		CreatorCount        int      `json:"creatorCount"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	if b.Currency == "" {
		b.Currency = svc.Cfg.DefaultCurrency
	}
	in := store.CampaignInput{
		Title: b.Title, Description: b.Description, Category: b.Category,
		TargetCountry: b.TargetCountry, TargetCity: b.TargetCity,
		TargetAgeMin: b.TargetAgeMin, TargetAgeMax: b.TargetAgeMax,
		TargetGender: b.TargetGender, TargetLanguage: b.TargetLanguage,
		TargetInterests: b.TargetInterests,
		BudgetMinor:     b.BudgetMinor, Currency: b.Currency,
		CampaignType: b.CampaignType, RequiredImpressions: b.RequiredImpressions,
		RequiredClicks: b.RequiredClicks, CreatorCount: b.CreatorCount,
	}
	if t, ok := parseTime(b.StartAt); ok {
		in.StartAt = &t
	}
	if t, ok := parseTime(b.EndAt); ok {
		in.EndAt = &t
	}

	ctx := c.Request.Context()
	var out store.Campaign
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		// Комиссия аз конфигуратсия меояд ва дар кампания қуфл мешавад.
		out, err = store.CreateCampaign(ctx, tx, advID, in, svc.Cfg.CommissionBPS)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusCreated, out)
}

// GET /marketplace/campaigns
func ListCampaigns(c *gin.Context) {
	ctx := c.Request.Context()
	limit := atoiDefault(c.Query("limit"), 30, 1, 100)
	offset := atoiDefault(c.Query("offset"), 0, 0, 100000)

	var out []store.Campaign
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		out, err = store.ListCampaigns(ctx, tx, advID, limit, offset)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"campaigns": out})
}

// GET /marketplace/campaigns/:id
func GetCampaignDetail(c *gin.Context) {
	ctx := c.Request.Context()
	id := c.Param("id")

	var camp store.Campaign
	offers := []store.Offer{}
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		camp, err = store.GetCampaign(ctx, tx, id, advID)
		if err != nil {
			return err
		}
		offers, err = store.ListOffersForCampaign(ctx, tx, id)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"campaign": camp, "creators": offers})
}

// POST /marketplace/campaigns/:id/checkout — сохтани фармоиши пардохт.
//
// Маблағ аз сатри кампания хонда мешавад, на аз client.
func CheckoutCampaign(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	prov, err := svc.PaymentProvider()
	if err != nil {
		mpFail(c, err)
		return
	}
	var b struct {
		IdempotencyKey string `json:"idempotencyKey"`
		ReturnURL      string `json:"returnUrl"`
	}
	_ = c.ShouldBindJSON(&b)
	if b.IdempotencyKey == "" {
		// Бе калиди идемпотентӣ ду зеркунӣ = ду фармоиш. Калиди
		// устувор аз кампания сохта мешавад.
		b.IdempotencyKey = "campaign:" + c.Param("id")
	}

	ctx := c.Request.Context()
	var order store.PaymentOrder
	err = mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		order, err = store.CreatePaymentOrder(ctx, tx, c.Param("id"), advID,
			prov.Name(), b.IdempotencyKey)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}

	// Даъват ба provider БЕРУН аз транзаксия: дархости шабакавӣ набояд
	// транзаксияи DB-ро нигоҳ дорад.
	res, err := prov.CreatePayment(ctx, payments.CreateRequest{
		OrderID:        order.ID,
		Amount:         order.Amount,
		Description:    "Raonson campaign " + order.CampaignID,
		ReturnURL:      b.ReturnURL,
		IdempotencyKey: b.IdempotencyKey,
	})
	if err != nil {
		// Фармоиш дар CREATED мемонад; корбар метавонад такрор кунад
		// ва ҳамон калиди идемпотентӣ ҳамон фармоишро бармегардонад.
		c.JSON(http.StatusBadGateway, gin.H{"message": "Хизмати пардохт ҷавоб надод"})
		return
	}
	if err := mpTx(ctx, func(tx store.Tx) error {
		return store.SetProviderReference(ctx, tx, order.ID, res.ProviderReference, res.Status)
	}); err != nil {
		mpFail(c, err)
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"orderId":     order.ID,
		"amountMinor": int64(order.Amount.Minor),
		"currency":    string(order.Amount.Currency),
		"status":      string(res.Status),
		"redirectUrl": res.RedirectURL,
		"provider":    prov.Name(),
	})
}

// POST /marketplace/campaigns/:id/cancel
func CancelCampaign(c *gin.Context) {
	ctx := c.Request.Context()
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		// Тафтиши соҳибӣ пеш аз гузариш.
		if _, err := store.GetCampaign(ctx, tx, c.Param("id"), advID); err != nil {
			return err
		}
		return store.TransitionCampaign(ctx, tx, c.Param("id"),
			domain.CampaignCancelled, mw.UID(c), "advertiser_cancelled")
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Кампания бекор карда шуд"})
}

// GET /marketplace/campaigns/:id/candidates — эҷодкорони мувофиқ.
//
// Тартиб аз matching.Engine меояд ва детерминистӣ аст: ҳамон вуруд —
// ҳамон натиҷа. Ҳеҷ тасодуфӣ.
func GetCampaignCandidates(c *gin.Context) {
	ctx := c.Request.Context()
	limit := atoiDefault(c.Query("limit"), 20, 1, 100)

	var matches []matching.Match
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		camp, err := store.GetCampaign(ctx, tx, c.Param("id"), advID)
		if err != nil {
			return err
		}
		crit, err := store.CampaignCriteria(ctx, tx, camp)
		if err != nil {
			return err
		}
		cands, err := store.FindCandidates(ctx, tx, camp.Budget.Currency,
			int64(crit.PerCreatorBudget.Minor), 300)
		if err != nil {
			return err
		}
		all := matching.NewEngine().Rank(cands, crit)
		if len(all) > limit {
			all = all[:limit]
		}
		matches = all
		return nil
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	if matches == nil {
		matches = []matching.Match{}
	}
	c.JSON(http.StatusOK, gin.H{"candidates": matches})
}

// POST /marketplace/campaigns/:id/invite
func InviteCreator(c *gin.Context) {
	var b struct {
		CreatorID   string `json:"creatorId"`
		AgreedMinor int64  `json:"agreedMinor"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.CreatorID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "creatorId лозим аст"})
		return
	}

	ctx := c.Request.Context()
	var offer store.Offer
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		camp, err := store.GetCampaign(ctx, tx, c.Param("id"), advID)
		if err != nil {
			return err
		}
		// Агар маблағ нишон дода нашуда бошад, нархи эълоншудаи эҷодкор
		// гирифта мешавад — на маблағи ихтиёрии client.
		agreed := b.AgreedMinor
		if agreed <= 0 {
			p, err := store.GetCreatorProfile(ctx, tx, b.CreatorID)
			if err != nil {
				return err
			}
			agreed = int64(p.Price.Minor)
		}
		// Холи мувофиқат аз ҳамон engine, то сабти даъват шаффоф бошад.
		m, err := store.MatchForCreator(ctx, tx, camp, b.CreatorID)
		if err != nil {
			return err
		}
		offer, err = store.InviteCreator(ctx, tx, camp.ID, b.CreatorID, mw.UID(c), agreed, m)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	notifyCampaignInvite(offer)
	c.JSON(http.StatusCreated, offer)
}

// POST /marketplace/offers/:id/approve — тасдиқи мӯҳтаво.
func ApproveOfferContent(c *gin.Context) {
	ctx := c.Request.Context()
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		return store.ApproveContent(ctx, tx, c.Param("id"), advID)
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Мӯҳтаво тасдиқ шуд"})
}

// ── Ёридиҳандаҳо ─────────────────────────────────────────────────

func parseTime(s string) (time.Time, bool) {
	if s == "" {
		return time.Time{}, false
	}
	if t, err := time.Parse(time.RFC3339, s); err == nil {
		return t, true
	}
	if t, err := time.Parse("2006-01-02", s); err == nil {
		return t, true
	}
	return time.Time{}, false
}

func atoiDefault(s string, def, min, max int) int {
	v, err := strconv.Atoi(s)
	if err != nil {
		return def
	}
	if v < min {
		return min
	}
	if v > max {
		return max
	}
	return v
}

// POST /marketplace/campaigns/:id/complete — бастани кампания ва
// сохтани фармоишҳои пардохт ба эҷодкорон.
//
// Пардохт ба провайдер ин ҷо ФИРИСТОДА НАМЕШАВАД: фармоиш сохта
// мешавад ва провайдери воқеӣ (ё оператор, вақте provider дастӣ аст)
// онро иҷро мекунад. Ҳеҷ "муваффақият"-и сохта.
func CompleteCampaign(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	prov, err := svc.PayoutProvider()
	if err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"message": "Хизмати интиқол танзим нашудааст"})
		return
	}

	ctx := c.Request.Context()
	var payouts []store.PayoutOrder
	err = mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		if _, err := store.GetCampaign(ctx, tx, c.Param("id"), advID); err != nil {
			return err
		}
		payouts, err = store.CompleteCampaign(ctx, tx, c.Param("id"), prov.Name(), mw.UID(c))
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	notifyPayoutsCreated(payouts)
	c.JSON(http.StatusOK, gin.H{
		"message": "Кампания баста шуд",
		"payouts": payouts,
	})
}

// GET /marketplace/campaigns/:id/metrics — натиҷаи воқеии кампания.
//
// Рақамҳо аз мӯҳтавои воқеан нашршуда ҷамъ мешаванд (кори пасзамина).
// Агар эҷодкор ҳанӯз чизе насупорида бошад, ӯ дар рӯйхат нест —
// рақами тахминӣ нишон дода намешавад.
func GetCampaignMetrics(c *gin.Context) {
	ctx := c.Request.Context()
	var rows []store.CampaignMetricsRow
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		if _, err := store.GetCampaign(ctx, tx, c.Param("id"), advID); err != nil {
			return err
		}
		// Пеш аз нишон додан як бор нав мекунем, то рекламадиҳанда
		// маълумоти кӯҳнаи то давраи навбатии job-ро набинад.
		if err := store.AggregateCampaignMetrics(ctx, tx, c.Param("id")); err != nil {
			return err
		}
		rows, err = store.GetCampaignMetrics(ctx, tx, c.Param("id"))
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	var totals store.CampaignMetricsRow
	for _, r := range rows {
		totals.Impressions += r.Impressions
		totals.Views += r.Views
		totals.Likes += r.Likes
		totals.Comments += r.Comments
		totals.Saves += r.Saves
	}
	c.JSON(http.StatusOK, gin.H{"creators": rows, "totals": totals})
}

// POST /marketplace/campaigns/:id/match — матчинг + даъвати худкор.
//
// Сервер номзадҳоро тартиб медиҳад ва то creator_count-и кампания
// даъват мефиристад. Маблағи ҳар даъват аз нархи ЭЪЛОНШУДАи эҷодкор
// гирифта мешавад ва бо буҷет маҳдуд аст — client ҳеҷ рақам намедиҳад.
//
// Даъвате, ки ба буҷет намеғунҷад, партофта мешавад, на кам карда:
// нархи эҷодкор аз они ӯст, на чизе ки мо мувофиқ мекунем.
func MatchCampaign(c *gin.Context) {
	ctx := c.Request.Context()
	var invited []store.Offer
	var skipped int

	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		camp, err := store.GetCampaign(ctx, tx, c.Param("id"), advID)
		if err != nil {
			return err
		}
		crit, err := store.CampaignCriteria(ctx, tx, camp)
		if err != nil {
			return err
		}
		cands, err := store.FindCandidates(ctx, tx, camp.Budget.Currency,
			int64(crit.PerCreatorBudget.Minor), 300)
		if err != nil {
			return err
		}
		ranked := matching.NewEngine().Rank(cands, crit)

		// Нархи ҳар номзад — барои маблағи даъват.
		price := make(map[string]int64, len(cands))
		for _, cd := range cands {
			price[cd.CreatorID] = int64(cd.Price.Minor)
		}

		for _, m := range ranked {
			if len(invited) >= camp.CreatorCount {
				break
			}
			agreed := price[m.CreatorID]
			if agreed <= 0 {
				skipped++
				continue
			}
			o, err := store.InviteCreator(ctx, tx, camp.ID, m.CreatorID,
				mw.UID(c), agreed, m)
			switch {
			case err == nil:
				invited = append(invited, o)
			case errors.Is(err, store.ErrBudgetExceeded),
				errors.Is(err, store.ErrOfferExists):
				// Буҷет тамом шуд ё аллакай даъват шудааст — ин
				// хатои кампания нест, номзади навбатӣ.
				skipped++
			default:
				return err
			}
		}
		return nil
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	for _, o := range invited {
		notifyCampaignInvite(o)
	}
	if invited == nil {
		invited = []store.Offer{}
	}
	c.JSON(http.StatusOK, gin.H{
		"invited": invited,
		"skipped": skipped,
	})
}

// ApproveOfferContentByParam — ҳамон тасдиқи мӯҳтаво, вале offer id
// дар :offerId аст (роҳи /campaigns/:id/creators/:offerId/approve).
func ApproveOfferContentByParam(c *gin.Context) {
	ctx := c.Request.Context()
	err := mpTx(ctx, func(tx store.Tx) error {
		advID, err := currentAdvertiser(ctx, tx, mw.UID(c))
		if err != nil {
			return err
		}
		return store.ApproveContent(ctx, tx, c.Param("offerId"), advID)
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Мӯҳтаво тасдиқ шуд"})
}
