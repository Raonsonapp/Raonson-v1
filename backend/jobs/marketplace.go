package jobs

// Корҳои пасзаминаи Creator Marketplace.
//
// Се кор:
//   - метрикаи эҷодкорон аз маълумоти воқеӣ ҳисоб мешавад
//   - натиҷаи кампанияҳои фаъол ҷамъ карда мешавад
//   - payout-ҳои нокоммонда бо таъхири экспоненсиалӣ такрор мешаванд
//
// Ҳар кор дар транзаксияи худ иҷро мешавад ва хатои як эҷодкор
// коркарди дигаронро қатъ намекунад.

import (
	"context"
	"errors"
	"log"
	"time"

	"raonson/db"
	"raonson/marketplace"
	"raonson/marketplace/domain"
	"raonson/marketplace/payouts"
	"raonson/marketplace/store"
)

const (
	// Метрика ҳар 6 соат нав мешавад — маълумоти иҷтимоӣ зудтар
	// тағйир намеёбад ва ҳисоби зуд-зуд танҳо DB-ро бор мекунад.
	metricsStaleMinutes = 360
	metricsBatchSize    = 50
)

// StartMarketplaceJobs корҳои marketplace-ро оғоз мекунад.
func StartMarketplaceJobs() {
	go func() {
		// Оғози таъхирӣ: сервер бояд аввал пурра боло ояд.
		time.Sleep(45 * time.Second)
		runMarketplaceCycle()
		ticker := time.NewTicker(15 * time.Minute)
		for range ticker.C {
			runMarketplaceCycle()
		}
	}()
}

func runMarketplaceCycle() {
	defer func() {
		// Кори пасзамина набояд тамоми серверро афтонад.
		if r := recover(); r != nil {
			log.Printf("marketplace jobs: panic: %v", r)
		}
	}()
	refreshCreatorMetricsBatch()
	aggregateActiveCampaigns()
	retryDuePayouts()
}

// mpJobTx як транзаксияи кӯтоҳ месозад.
func mpJobTx(fn func(ctx context.Context, tx store.Tx) error) error {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	tx, err := db.Pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)
	if err := fn(ctx, tx); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// refreshCreatorMetricsBatch метрика ва аломатҳои фиребро нав мекунад.
func refreshCreatorMetricsBatch() {
	var ids []string
	if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
		var err error
		ids, err = store.CreatorsNeedingMetrics(ctx, tx, metricsStaleMinutes, metricsBatchSize)
		return err
	}); err != nil {
		log.Printf("marketplace jobs: интихоби эҷодкорон: %v", err)
		return
	}
	if len(ids) == 0 {
		return
	}

	ok := 0
	for _, id := range ids {
		// Ҳар эҷодкор дар транзаксияи ҷудогона: хатои яке набояд
		// ҳисоби дигаронро бекор кунад.
		if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
			if _, err := store.RefreshCreatorMetrics(ctx, tx, id); err != nil {
				return err
			}
			signals, err := store.DetectCreatorFraud(ctx, tx, id)
			if err != nil {
				return err
			}
			if err := store.SaveFraudSignals(ctx, tx, id, signals); err != nil {
				return err
			}
			return store.ClearResolvedFraudSignals(ctx, tx, id, signals)
		}); err != nil {
			log.Printf("marketplace jobs: метрикаи %s: %v", id, err)
			continue
		}
		ok++
	}
	log.Printf("marketplace jobs: метрикаи %d/%d эҷодкор нав шуд", ok, len(ids))
}

// aggregateActiveCampaigns натиҷаи кампанияҳои ҷориро ҷамъ мекунад.
func aggregateActiveCampaigns() {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	rows, err := db.Pool.Query(ctx, `
		SELECT id FROM campaigns
		WHERE status IN ('ACTIVE','REVIEW')
		ORDER BY updated_at ASC LIMIT 100`)
	if err != nil {
		log.Printf("marketplace jobs: кампанияҳои фаъол: %v", err)
		return
	}
	ids := []string{}
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()

	for _, id := range ids {
		if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
			return store.AggregateCampaignMetrics(ctx, tx, id)
		}); err != nil {
			log.Printf("marketplace jobs: ҷамъбасти кампанияи %s: %v", id, err)
		}
	}
}

// retryDuePayouts payout-ҳои интизорро ба provider мефиристад.
//
// Provider-и дастӣ ErrManualRequired бармегардонад — ин ХАТО нест:
// payout ба REQUIRES_ACTION мегузарад ва интизори оператор мемонад.
// Ҳеҷ payout бе тасдиқи воқеӣ SUCCEEDED намешавад.
func retryDuePayouts() {
	svc, err := marketplace.Get()
	if err != nil || svc == nil {
		return
	}

	var due []store.DuePayout
	if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
		var err error
		due, err = store.DuePayouts(ctx, tx, 20)
		return err
	}); err != nil {
		log.Printf("marketplace jobs: payout-ҳои интизор: %v", err)
		return
	}
	if len(due) == 0 {
		return
	}

	for _, p := range due {
		prov, err := svc.Payouts.Get(p.Provider)
		if err != nil {
			log.Printf("marketplace jobs: provider-и %q нест", p.Provider)
			continue
		}
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		res, err := prov.CreatePayout(ctx, payouts.CreateRequest{
			PayoutID:  p.ID,
			CreatorID: p.CreatorID,
			Amount:    p.Amount,
			// Калиди устувор: такрори кӯшиш дар тарафи provider
			// интиқоли дуюм намесозад.
			IdempotencyKey: "payout:" + p.ID,
			Description:    "Raonson campaign payout",
		})
		cancel()

		switch {
		case errors.Is(err, payouts.ErrManualRequired):
			// Интиқоли худкор нест — оператор иҷро мекунад.
			if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
				return store.MarkPayoutAttempt(ctx, tx, p.ID,
					domain.PayoutRequiresAction, "manual_transfer_required")
			}); err != nil {
				log.Printf("marketplace jobs: сабти payout-и %s: %v", p.ID, err)
			}
		case err != nil:
			if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
				return store.MarkPayoutAttempt(ctx, tx, p.ID,
					domain.PayoutFailed, err.Error())
			}); err != nil {
				log.Printf("marketplace jobs: сабти нокомии %s: %v", p.ID, err)
			}
		default:
			// Provider дархостро қабул кард. SUCCEEDED-ро ин ҷо
			// НАМЕГУЗОРЕМ: он танҳо аз webhook ё тасдиқи мустақим меояд.
			st := res.Status
			if st == domain.PayoutSucceeded {
				st = domain.PayoutProcessing
			}
			if err := mpJobTx(func(ctx context.Context, tx store.Tx) error {
				return store.SetPayoutReference(ctx, tx, p.ID, res.ProviderReference, st)
			}); err != nil {
				log.Printf("marketplace jobs: reference-и %s: %v", p.ID, err)
			}
		}
	}
}
