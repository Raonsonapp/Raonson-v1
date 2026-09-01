package handlers

// Webhook-ҳои Creator Marketplace.
//
// Ин endpoint-ҳо БЕ токени корбар кор мекунанд — онҳоро provider даъват
// мекунад, на барнома. Бинобар ин ҳимоя аз имзои криптографӣ меояд:
//
//   1. Имзо тафтиш мешавад (ParseWebhook → ErrInvalidSignature).
//   2. Ҳолат МУСТАҚИМАН аз provider тасдиқ мешавад (VerifyPayment) —
//      ба матни webhook танҳо бовар карда намешавад.
//   3. event_id дар webhook_events UNIQUE аст — такрор бетаъсир аст.
//
// Ҳар се қабат лозим аст: имзо метавонад дуруст бошад, вале паём
// такрорӣ; ё паём нав бошад, вале ҳолат аллакай тағйир ёфта.

import (
	"errors"
	"io"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"raonson/marketplace/domain"
	"raonson/marketplace/payments"
	"raonson/marketplace/payouts"
	"raonson/marketplace/store"
)

// maxWebhookBody — ҳадди андозаи бадан. Бе он як дархости бузург
// хотираро пур мекунад.
const maxWebhookBody = 1 << 20 // 1 MiB

// POST /payments/webhook/:provider
func PaymentWebhook(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	prov, err := svc.Payments.Get(c.Param("provider"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "provider номаълум"})
		return
	}
	body, err := io.ReadAll(io.LimitReader(c.Request.Body, maxWebhookBody))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "бадан хонда нашуд"})
		return
	}

	ctx := c.Request.Context()
	ev, err := prov.ParseWebhook(ctx, flatHeaders(c), body)
	if err != nil {
		if errors.Is(err, payments.ErrInvalidSignature) {
			log.Printf("marketplace: имзои webhook-и %s нодуруст", prov.Name())
			c.JSON(http.StatusUnauthorized, gin.H{"message": "имзо нодуруст"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"message": "webhook хонда нашуд"})
		return
	}
	if ev.EventID == "" || ev.ProviderReference == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "webhook нопурра"})
		return
	}

	// Ҳолатро аз худи provider мепурсем. Агар webhook «муваффақ» гӯяд,
	// вале provider не — ба webhook бовар намекунем.
	if ev.Status == domain.PaymentSucceeded {
		st, amt, err := prov.VerifyPayment(ctx, ev.ProviderReference)
		if err != nil {
			// Тасдиқ нашуд — 502, то provider такрор фиристад.
			log.Printf("marketplace: тасдиқи пардохт нашуд (%s): %v", ev.ProviderReference, err)
			c.JSON(http.StatusBadGateway, gin.H{"message": "тасдиқ нашуд"})
			return
		}
		if st != domain.PaymentSucceeded {
			log.Printf("marketplace: webhook SUCCEEDED мегӯяд, provider %s — рад шуд", st)
			c.JSON(http.StatusConflict, gin.H{"message": "ҳолат мувофиқат намекунад"})
			return
		}
		// Маблағи тасдиқшуда бартарӣ дорад.
		if amt.Minor > 0 {
			ev.Amount = amt
		}
	}

	var applied bool
	err = mpTx(ctx, func(tx store.Tx) error {
		var err error
		applied, err = store.ApplyPaymentWebhook(ctx, tx, prov.Name(),
			store.PaymentWebhookInput{
				EventID:           ev.EventID,
				EventType:         ev.EventType,
				ProviderReference: ev.ProviderReference,
				Status:            ev.Status,
				Amount:            ev.Amount,
				FailureReason:     ev.FailureReason,
				RawJSON:           string(body),
			})
		return err
	})
	if err != nil {
		log.Printf("marketplace: коркарди webhook-и пардохт: %v", err)
		// 500 медиҳем, то provider такрор фиристад — ҳодиса гум нашавад.
		c.JSON(http.StatusInternalServerError, gin.H{"message": "коркард нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "applied": applied})
}

// POST /payouts/webhook/:provider
func PayoutWebhook(c *gin.Context) {
	svc, ok := mpService(c)
	if !ok {
		return
	}
	prov, err := svc.Payouts.Get(c.Param("provider"))
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"message": "provider номаълум"})
		return
	}
	body, err := io.ReadAll(io.LimitReader(c.Request.Body, maxWebhookBody))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "бадан хонда нашуд"})
		return
	}

	ctx := c.Request.Context()
	ev, err := prov.ParseWebhook(ctx, flatHeaders(c), body)
	if err != nil {
		if errors.Is(err, payouts.ErrInvalidSignature) {
			c.JSON(http.StatusUnauthorized, gin.H{"message": "имзо нодуруст"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"message": "webhook хонда нашуд"})
		return
	}
	if ev.EventID == "" || ev.ProviderReference == "" {
		c.JSON(http.StatusBadRequest, gin.H{"message": "webhook нопурра"})
		return
	}

	// Мисли пардохт: SUCCEEDED бе тасдиқи provider қабул намешавад.
	if ev.Status == domain.PayoutSucceeded {
		st, _, err := prov.VerifyPayout(ctx, ev.ProviderReference)
		if err != nil {
			c.JSON(http.StatusBadGateway, gin.H{"message": "тасдиқ нашуд"})
			return
		}
		if st != domain.PayoutSucceeded {
			c.JSON(http.StatusConflict, gin.H{"message": "ҳолат мувофиқат намекунад"})
			return
		}
	}

	var applied bool
	err = mpTx(ctx, func(tx store.Tx) error {
		var err error
		applied, err = store.ApplyPayoutWebhook(ctx, tx, prov.Name(),
			store.PayoutWebhookInput{
				EventID:           ev.EventID,
				EventType:         ev.EventType,
				ProviderReference: ev.ProviderReference,
				Status:            ev.Status,
				FailureReason:     ev.FailureReason,
				RawJSON:           string(body),
			})
		return err
	})
	if err != nil {
		log.Printf("marketplace: коркарди webhook-и payout: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"message": "коркард нашуд"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true, "applied": applied})
}

// flatHeaders header-ҳоро ба map-и содда табдил медиҳад — provider
// худаш медонад, ки кадомашро барои имзо истифода барад.
func flatHeaders(c *gin.Context) map[string]string {
	out := make(map[string]string, len(c.Request.Header))
	for k, v := range c.Request.Header {
		if len(v) > 0 {
			out[k] = v[0]
		}
	}
	return out
}
