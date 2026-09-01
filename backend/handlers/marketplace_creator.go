package handlers

// Creator Marketplace — тарафи эҷодкор.
//
// Эҷодкор профили тиҷоратии худро танзим мекунад, даъватҳоро мебинад,
// қабул ё рад мекунад, мӯҳтаворо мепайвандад ва тавозуни худро мебинад.

import (
	"context"
	"errors"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"raonson/db"
	"raonson/marketplace/money"
	"raonson/marketplace/store"
	mw "raonson/middleware"
)

// GET /marketplace/creator/me — профил + метрика + хол.
func GetCreatorMarketplaceProfile(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	cur, err := money.ParseCurrency(svc.Cfg.DefaultCurrency)
	if err != nil {
		mpFail(c, err)
		return
	}
	ctx := c.Request.Context()
	me := mw.UID(c)

	var out gin.H
	err = mpTx(ctx, func(tx store.Tx) error {
		metrics, err := store.GetCreatorMetrics(ctx, tx, me)
		if err != nil {
			return err
		}
		wallet, err := store.GetCreatorWallet(ctx, tx, me, cur)
		if err != nil {
			return err
		}
		profile, err := store.GetCreatorProfile(ctx, tx, me)
		joined := true
		if err != nil {
			// Эҷодкор ҳанӯз ба marketplace ворид нашудааст — ин хато нест.
			if !errors.Is(err, store.ErrCreatorProfileMissing) {
				return err
			}
			joined = false
			profile = store.CreatorProfile{
				CreatorID: me,
				Price:     money.Amount{Currency: cur},
			}
		}
		out = gin.H{
			"joined":  joined,
			"profile": profile,
			"metrics": metrics,
			"wallet":  wallet,
		}
		return nil
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

// PUT /marketplace/creator/me — эҷодкор профили худро танзим мекунад.
func UpdateCreatorMarketplaceProfile(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	var in store.CreatorProfileInput
	if err := c.ShouldBindJSON(&in); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	if in.Currency == "" {
		in.Currency = svc.Cfg.DefaultCurrency
	}

	ctx := c.Request.Context()
	var out store.CreatorProfile
	err := mpTx(ctx, func(tx store.Tx) error {
		var err error
		out, err = store.UpsertCreatorProfile(ctx, tx, mw.UID(c), in)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}

// GET /marketplace/offers — даъватҳои эҷодкор.
func ListMyOffers(c *gin.Context) {
	ctx := c.Request.Context()
	limit := atoiDefault(c.Query("limit"), 30, 1, 100)
	offset := atoiDefault(c.Query("offset"), 0, 0, 100000)

	var offers []store.Offer
	err := mpTx(ctx, func(tx store.Tx) error {
		var err error
		offers, err = store.ListOffersForCreator(ctx, tx, mw.UID(c),
			c.Query("status"), limit, offset)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"offers": offers})
}

// POST /marketplace/offers/:id/respond — қабул ё рад.
func RespondToOffer(c *gin.Context) {
	var b struct {
		Accept bool `json:"accept"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	ctx := c.Request.Context()
	var offer store.Offer
	err := mpTx(ctx, func(tx store.Tx) error {
		var err error
		offer, err = store.RespondToOffer(ctx, tx, c.Param("id"), mw.UID(c), b.Accept)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	notifyOfferResponse(offer)
	c.JSON(http.StatusOK, offer)
}

// POST /marketplace/offers/:id/content — пайванди мӯҳтавои нашршуда.
func SubmitOfferContent(c *gin.Context) {
	var b struct {
		ContentID   string `json:"contentId"`
		ContentType string `json:"contentType"`
	}
	if err := c.ShouldBindJSON(&b); err != nil || b.ContentID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "contentId лозим аст"})
		return
	}
	if b.ContentType == "" {
		b.ContentType = "post"
	}
	switch b.ContentType {
	case "post", "reel", "story":
	default:
		c.JSON(http.StatusBadRequest, gin.H{"message": "Навъи мӯҳтаво нодуруст"})
		return
	}

	ctx := c.Request.Context()
	me := mw.UID(c)
	err := mpTx(ctx, func(tx store.Tx) error {
		// Мӯҳтаво бояд ВОҚЕАН аз они ҳамин эҷодкор бошад: вагарна
		// касе метавонад пости бегонаро ҳамчун кори худ супорад.
		owned, err := creatorOwnsContent(ctx, tx, me, b.ContentID, b.ContentType)
		if err != nil {
			return err
		}
		if !owned {
			return errContentNotOwned
		}
		return store.SubmitContent(ctx, tx, c.Param("id"), me, b.ContentID, b.ContentType)
	})
	if err != nil {
		if errors.Is(err, errContentNotOwned) {
			c.JSON(http.StatusForbidden, gin.H{"message": "Ин мӯҳтаво аз они шумо нест"})
			return
		}
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Мӯҳтаво супорида шуд"})
}

// errContentNotOwned — эҷодкор мӯҳтавои бегонаро ҳамчун кори худ супорид.
var errContentNotOwned = errors.New("marketplace: мӯҳтаво аз они эҷодкор нест")

// creatorOwnsContent тафтиш мекунад, ки пост/рилс/стори аз они корбар аст.
func creatorOwnsContent(ctx context.Context, tx store.Tx, userID, contentID, contentType string) (bool, error) {
	var table string
	switch contentType {
	case "post":
		table = "posts"
	case "reel":
		table = "reels"
	case "story":
		table = "stories"
	default:
		return false, nil
	}
	var owner string
	err := tx.QueryRow(ctx,
		`SELECT user_id FROM `+table+` WHERE id=$1`, contentID).Scan(&owner)
	if err != nil {
		// Мӯҳтаво нест — соҳибӣ тасдиқ нашуд.
		return false, nil
	}
	return owner == userID, nil
}

// GET /marketplace/wallet — тавозуни эҷодкор.
func GetMarketplaceWallet(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	cur, err := money.ParseCurrency(svc.Cfg.DefaultCurrency)
	if err != nil {
		mpFail(c, err)
		return
	}
	ctx := c.Request.Context()
	var w store.CreatorWallet
	err = mpTx(ctx, func(tx store.Tx) error {
		var err error
		w, err = store.GetCreatorWallet(ctx, tx, mw.UID(c), cur)
		return err
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, w)
}

// ── Огоҳиномаҳо ──────────────────────────────────────────────────

// notifyCampaignInvite ба эҷодкор хабар медиҳад, ки даъват шудааст.
//
// Огоҳинома баъди commit фиристода мешавад: агар транзаксия бекор
// шавад, эҷодкор хабари дурӯғ намегирад.
func notifyCampaignInvite(o store.Offer) {
	if o.CreatorID == "" {
		return
	}
	advUser := advertiserUserOfCampaign(o.CampaignID)
	if advUser == "" {
		return
	}
	notify(o.CreatorID, advUser, "campaign_invite", o.ID)
	pushNotify(o.CreatorID, advUser, "campaign_invite", o.ID,
		"Шуморо ба кампанияи рекламавӣ даъват кард")
}

// notifyOfferResponse ба рекламадиҳанда хабар медиҳад.
func notifyOfferResponse(o store.Offer) {
	if o.CampaignID == "" {
		return
	}
	advUser := advertiserUserOfCampaign(o.CampaignID)
	if advUser == "" {
		return
	}
	body := "Даъвати кампанияро қабул кард"
	if o.Status != "ACCEPTED" {
		body = "Даъвати кампанияро рад кард"
	}
	notify(advUser, o.CreatorID, "campaign_offer_response", o.ID)
	pushNotify(advUser, o.CreatorID, "campaign_offer_response", o.ID, body)
}

// advertiserUserOfCampaign id-и КОРБАРи рекламадиҳандаро мегирад
// (advertisers.id ба огоҳинома намеравад — он корбар нест).
func advertiserUserOfCampaign(campaignID string) string {
	var userID string
	err := db.Pool.QueryRow(context.Background(), `
		SELECT a.user_id FROM campaigns c
		JOIN advertisers a ON a.id = c.advertiser_id
		WHERE c.id=$1`, campaignID).Scan(&userID)
	if err != nil {
		log.Printf("marketplace: корбари рекламадиҳанда ёфт нашуд (%s): %v", campaignID, err)
		return ""
	}
	return userID
}

// notifyPayoutsCreated ба ҳар эҷодкор хабар медиҳад, ки пардохт сохта шуд.
//
// Матн эҳтиёткор аст: «омода шуд», на «фиристода шуд» — то даме ки
// интиқол воқеан тасдиқ нашудааст, ба эҷодкор ваъдаи иҷрошуда дода
// намешавад.
func notifyPayoutsCreated(orders []store.PayoutOrder) {
	for _, o := range orders {
		if o.CreatorID == "" {
			continue
		}
		advUser := advertiserUserOfCampaign(o.CampaignID)
		if advUser == "" {
			continue
		}
		notify(o.CreatorID, advUser, "campaign_payout", o.ID)
		pushNotify(o.CreatorID, advUser, "campaign_payout", o.ID,
			"Пардохти кампания омода шуд")
	}
}
