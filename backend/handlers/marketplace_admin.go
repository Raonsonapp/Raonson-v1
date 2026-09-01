package handlers

// Creator Marketplace — панели админ.
//
// Ду вазифаи асосӣ:
//   - дидани payout-ҳое, ки интизори амали дастӣ ҳастанд
//   - тасдиқи интиқоли дастӣ баъди иҷрои воқеӣ
//
// Тасдиқ ҳеҷ пул интиқол намедиҳад: он танҳо сабт мекунад, ки оператор
// интиқолро ВОҚЕАН иҷро кардааст. Бинобар ин reference-и берунӣ ҳатмист —
// бе он ҳеҷ payout SUCCEEDED намешавад.

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	"raonson/marketplace/domain"
	"raonson/marketplace/store"
	mw "raonson/middleware"
)

// GET /admin/marketplace/payouts?status=REQUIRES_ACTION
func AdminListPayouts(c *gin.Context) {
	status := strings.ToUpper(strings.TrimSpace(c.Query("status")))
	if status != "" && !domain.PayoutStatus(status).Valid() {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Ҳолати номаълум"})
		return
	}
	limit := atoiDefault(c.Query("limit"), 50, 1, 200)

	ctx := c.Request.Context()
	out := []gin.H{}
	err := mpTx(ctx, func(tx store.Tx) error {
		rows, err := tx.Query(ctx, `
			SELECT p.id, p.campaign_id, p.creator_id, p.amount_minor, p.currency,
			       p.status, p.provider, p.provider_reference, p.failure_reason,
			       p.attempts, p.created_at, COALESCE(u.username,'')
			FROM payout_orders p
			LEFT JOIN users u ON u.id = p.creator_id
			WHERE ($1='' OR p.status=$1)
			ORDER BY p.created_at DESC LIMIT $2`, status, limit)
		if err != nil {
			return err
		}
		defer rows.Close()
		for rows.Next() {
			var id, campID, creatorID, cur, st, prov, ref, reason, username string
			var amount int64
			var attempts int
			var createdAt any
			if err := rows.Scan(&id, &campID, &creatorID, &amount, &cur, &st,
				&prov, &ref, &reason, &attempts, &createdAt, &username); err != nil {
				continue
			}
			out = append(out, gin.H{
				"id": id, "campaignId": campID, "creatorId": creatorID,
				"username": username, "amountMinor": amount, "currency": cur,
				"status": st, "provider": prov, "providerReference": ref,
				"failureReason": reason, "attempts": attempts, "createdAt": createdAt,
			})
		}
		return rows.Err()
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"payouts": out})
}

// POST /admin/marketplace/payouts/:id/settle — тасдиқи интиқоли дастӣ.
//
// Оператор интиқолро дар бонк/ҳамён иҷро мекунад ва reference-и онро
// ин ҷо менависад. Бе reference тасдиқ қабул намешавад: вагарна
// payout-и «муваффақ» бе ҳеҷ далели интиқол пайдо мешавад.
func AdminSettlePayout(c *gin.Context) {
	var b struct {
		ProviderReference string `json:"providerReference"`
		Note              string `json:"note"`
	}
	if err := c.ShouldBindJSON(&b); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"message": "Маълумот нодуруст"})
		return
	}
	b.ProviderReference = strings.TrimSpace(b.ProviderReference)
	if b.ProviderReference == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"message": "Рақами интиқоли воқеӣ (providerReference) лозим аст"})
		return
	}

	ctx := c.Request.Context()
	id := c.Param("id")
	err := mpTx(ctx, func(tx store.Tx) error {
		if _, err := tx.Exec(ctx, `
			UPDATE payout_orders SET provider_reference=$2, updated_at=NOW()
			WHERE id=$1 AND provider_reference=''`, id, b.ProviderReference); err != nil {
			return err
		}
		// PROCESSING → SUCCEEDED: мошинаи ҳолат аз REQUIRES_ACTION
		// мустақиман ба SUCCEEDED низ иҷозат медиҳад.
		if err := store.MarkPayoutStatus(ctx, tx, id,
			domain.PayoutSucceeded, "manual_settlement"); err != nil {
			return err
		}
		return store.Audit(ctx, tx, mw.UID(c), "admin", "payout.settled_manually",
			"payout_order", id, map[string]any{
				"providerReference": b.ProviderReference,
				"note":              b.Note,
			})
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Интиқол тасдиқ шуд"})
}

// POST /admin/marketplace/payouts/:id/fail — интиқол иҷро нашуд.
func AdminFailPayout(c *gin.Context) {
	var b struct {
		Reason string `json:"reason"`
	}
	_ = c.ShouldBindJSON(&b)
	if strings.TrimSpace(b.Reason) == "" {
		b.Reason = "manual_failure"
	}

	ctx := c.Request.Context()
	id := c.Param("id")
	err := mpTx(ctx, func(tx store.Tx) error {
		if err := store.MarkPayoutStatus(ctx, tx, id, domain.PayoutFailed, b.Reason); err != nil {
			return err
		}
		return store.Audit(ctx, tx, mw.UID(c), "admin", "payout.failed_manually",
			"payout_order", id, map[string]any{"reason": b.Reason})
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"message": "Ҳамчун иҷронашуда сабт шуд"})
}

// GET /admin/marketplace/stats — ҳолати умумии marketplace.
//
// Ҳама рақам аз ҷадвалҳои воқеӣ ҳисоб мешавад.
func AdminMarketplaceStats(c *gin.Context) {
	ctx := c.Request.Context()
	var out gin.H
	err := mpTx(ctx, func(tx store.Tx) error {
		var campaigns, activeCampaigns, creators, pendingPayouts int64
		var escrowMinor, revenueMinor, paidOutMinor int64
		err := tx.QueryRow(ctx, `
			SELECT
			  (SELECT COUNT(*) FROM campaigns),
			  (SELECT COUNT(*) FROM campaigns
			     WHERE status IN ('PAID','MATCHING','CREATOR_INVITED',
			                      'CREATOR_ACCEPTED','ACTIVE','REVIEW')),
			  (SELECT COUNT(*) FROM creator_profiles WHERE available),
			  (SELECT COUNT(*) FROM payout_orders
			     WHERE status IN ('PENDING','PROCESSING','REQUIRES_ACTION')),
			  (SELECT COALESCE(SUM(e.amount_minor),0)
			     FROM ledger_entries e JOIN ledger_accounts a ON a.id = e.account_id
			     WHERE a.purpose='ESCROW'),
			  (SELECT COALESCE(SUM(e.amount_minor),0)
			     FROM ledger_entries e JOIN ledger_accounts a ON a.id = e.account_id
			     WHERE a.purpose='REVENUE'),
			  (SELECT COALESCE(SUM(amount_minor),0) FROM payout_orders
			     WHERE status='SUCCEEDED')`).
			Scan(&campaigns, &activeCampaigns, &creators, &pendingPayouts,
				&escrowMinor, &revenueMinor, &paidOutMinor)
		if err != nil {
			return err
		}
		out = gin.H{
			"campaigns":         campaigns,
			"activeCampaigns":   activeCampaigns,
			"availableCreators": creators,
			"pendingPayouts":    pendingPayouts,
			// Escrow ва даромад аз дафтар — на аз сутуни алоҳида.
			"escrowMinor":  escrowMinor,
			"revenueMinor": revenueMinor,
			"paidOutMinor": paidOutMinor,
		}
		return nil
	})
	if err != nil {
		mpFail(c, err)
		return
	}
	c.JSON(http.StatusOK, out)
}
