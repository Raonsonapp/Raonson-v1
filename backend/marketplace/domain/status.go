// Package domain ҳолатҳо ва қоидаҳои гузариши Creator Marketplace-ро
// муайян мекунад. Ҳар гузариш возеҳан иҷозат дода мешавад — ҳеҷ ҳолат
// «худ ба худ» тағйир намеёбад.
package domain

import "fmt"

// ── Campaign ─────────────────────────────────────────────────────

type CampaignStatus string

const (
	CampaignDraft           CampaignStatus = "DRAFT"
	CampaignPendingPayment  CampaignStatus = "PENDING_PAYMENT"
	CampaignPaid            CampaignStatus = "PAID"
	CampaignMatching        CampaignStatus = "MATCHING"
	CampaignCreatorInvited  CampaignStatus = "CREATOR_INVITED"
	CampaignCreatorAccepted CampaignStatus = "CREATOR_ACCEPTED"
	CampaignActive          CampaignStatus = "ACTIVE"
	CampaignReview          CampaignStatus = "REVIEW"
	CampaignCompleted       CampaignStatus = "COMPLETED"
	CampaignCancelled       CampaignStatus = "CANCELLED"
	CampaignRefunded        CampaignStatus = "REFUNDED"
)

var campaignTransitions = map[CampaignStatus][]CampaignStatus{
	CampaignDraft:           {CampaignPendingPayment, CampaignCancelled},
	CampaignPendingPayment:  {CampaignPaid, CampaignCancelled},
	CampaignPaid:            {CampaignMatching, CampaignRefunded, CampaignCancelled},
	CampaignMatching:        {CampaignCreatorInvited, CampaignRefunded, CampaignCancelled},
	CampaignCreatorInvited:  {CampaignCreatorAccepted, CampaignMatching, CampaignRefunded, CampaignCancelled},
	CampaignCreatorAccepted: {CampaignActive, CampaignRefunded, CampaignCancelled},
	CampaignActive:          {CampaignReview, CampaignCancelled},
	CampaignReview:          {CampaignCompleted, CampaignActive, CampaignRefunded},
	// Ҳолатҳои ниҳоӣ — аз онҳо роҳи баромад нест.
	CampaignCompleted: {},
	CampaignCancelled: {},
	CampaignRefunded:  {},
}

func (s CampaignStatus) Valid() bool {
	_, ok := campaignTransitions[s]
	return ok
}

// IsTerminal — ҳолати ниҳоӣ, ки дигар тағйир намеёбад.
func (s CampaignStatus) IsTerminal() bool {
	next, ok := campaignTransitions[s]
	return ok && len(next) == 0
}

// CanTransition — оё гузариш аз s ба to иҷозат аст?
func (s CampaignStatus) CanTransition(to CampaignStatus) bool {
	for _, n := range campaignTransitions[s] {
		if n == to {
			return true
		}
	}
	return false
}

// Transition гузаришро тафтиш мекунад ва хатои возеҳ бармегардонад.
func (s CampaignStatus) Transition(to CampaignStatus) error {
	if !s.Valid() {
		return fmt.Errorf("campaign: ҳолати номаълум %q", s)
	}
	if !to.Valid() {
		return fmt.Errorf("campaign: ҳолати мақсади номаълум %q", to)
	}
	// Такрори ҳамон ҳолат хато нест: як webhook ё retry метавонад
	// дубора ҳамон гузаришро талаб кунад — он бояд no-op шавад.
	if s == to {
		return ErrAlreadyInState
	}
	if !s.CanTransition(to) {
		return fmt.Errorf("campaign: гузариш аз %s ба %s иҷозат нест", s, to)
	}
	return nil
}

// ── Payment ──────────────────────────────────────────────────────

type PaymentStatus string

const (
	PaymentCreated   PaymentStatus = "CREATED"
	PaymentPending   PaymentStatus = "PENDING"
	PaymentSucceeded PaymentStatus = "SUCCEEDED"
	PaymentFailed    PaymentStatus = "FAILED"
	PaymentCancelled PaymentStatus = "CANCELLED"
	PaymentRefunded  PaymentStatus = "REFUNDED"
)

var paymentTransitions = map[PaymentStatus][]PaymentStatus{
	PaymentCreated:   {PaymentPending, PaymentSucceeded, PaymentFailed, PaymentCancelled},
	PaymentPending:   {PaymentSucceeded, PaymentFailed, PaymentCancelled},
	PaymentSucceeded: {PaymentRefunded},
	PaymentFailed:    {},
	PaymentCancelled: {},
	PaymentRefunded:  {},
}

func (s PaymentStatus) Valid() bool {
	_, ok := paymentTransitions[s]
	return ok
}

func (s PaymentStatus) IsTerminal() bool {
	next, ok := paymentTransitions[s]
	return ok && len(next) == 0
}

func (s PaymentStatus) CanTransition(to PaymentStatus) bool {
	for _, n := range paymentTransitions[s] {
		if n == to {
			return true
		}
	}
	return false
}

func (s PaymentStatus) Transition(to PaymentStatus) error {
	if !s.Valid() {
		return fmt.Errorf("payment: ҳолати номаълум %q", s)
	}
	if !to.Valid() {
		return fmt.Errorf("payment: ҳолати мақсади номаълум %q", to)
	}
	// Такрори ҳамон ҳолат хато нест — webhook метавонад ду бор ояд.
	if s == to {
		return ErrAlreadyInState
	}
	if !s.CanTransition(to) {
		return fmt.Errorf("payment: гузариш аз %s ба %s иҷозат нест", s, to)
	}
	return nil
}

// ── Payout ───────────────────────────────────────────────────────

type PayoutStatus string

const (
	PayoutPending    PayoutStatus = "PENDING"
	PayoutProcessing PayoutStatus = "PROCESSING"
	PayoutSucceeded  PayoutStatus = "SUCCEEDED"
	PayoutFailed     PayoutStatus = "FAILED"
	PayoutCancelled  PayoutStatus = "CANCELLED"
	PayoutReversed   PayoutStatus = "REVERSED"
	// Вақте provider API-и payout надорад — payout-и сохта СОХТА
	// НАМЕШАВАД, балки интизори амали дастӣ мемонад.
	PayoutRequiresAction PayoutStatus = "REQUIRES_ACTION"
)

var payoutTransitions = map[PayoutStatus][]PayoutStatus{
	PayoutPending:        {PayoutProcessing, PayoutRequiresAction, PayoutFailed, PayoutCancelled},
	PayoutRequiresAction: {PayoutProcessing, PayoutSucceeded, PayoutFailed, PayoutCancelled},
	PayoutProcessing:     {PayoutSucceeded, PayoutFailed},
	PayoutSucceeded:      {PayoutReversed},
	PayoutFailed:         {PayoutPending}, // такрори кӯшиш
	PayoutCancelled:      {},
	PayoutReversed:       {},
}

func (s PayoutStatus) Valid() bool {
	_, ok := payoutTransitions[s]
	return ok
}

func (s PayoutStatus) IsTerminal() bool {
	next, ok := payoutTransitions[s]
	return ok && len(next) == 0
}

func (s PayoutStatus) CanTransition(to PayoutStatus) bool {
	for _, n := range payoutTransitions[s] {
		if n == to {
			return true
		}
	}
	return false
}

func (s PayoutStatus) Transition(to PayoutStatus) error {
	if !s.Valid() {
		return fmt.Errorf("payout: ҳолати номаълум %q", s)
	}
	if !to.Valid() {
		return fmt.Errorf("payout: ҳолати мақсади номаълум %q", to)
	}
	if s == to {
		return ErrAlreadyInState
	}
	if !s.CanTransition(to) {
		return fmt.Errorf("payout: гузариш аз %s ба %s иҷозат нест", s, to)
	}
	return nil
}

// ── Campaign creator (offer) ─────────────────────────────────────

type OfferStatus string

const (
	OfferInvited   OfferStatus = "INVITED"
	OfferAccepted  OfferStatus = "ACCEPTED"
	OfferRejected  OfferStatus = "REJECTED"
	OfferExpired   OfferStatus = "EXPIRED"
	OfferDelivered OfferStatus = "DELIVERED"
	OfferApproved  OfferStatus = "APPROVED"
	OfferCancelled OfferStatus = "CANCELLED"
)

var offerTransitions = map[OfferStatus][]OfferStatus{
	OfferInvited:   {OfferAccepted, OfferRejected, OfferExpired, OfferCancelled},
	OfferAccepted:  {OfferDelivered, OfferCancelled},
	OfferDelivered: {OfferApproved, OfferCancelled},
	OfferApproved:  {},
	OfferRejected:  {},
	OfferExpired:   {},
	OfferCancelled: {},
}

func (s OfferStatus) Valid() bool {
	_, ok := offerTransitions[s]
	return ok
}

func (s OfferStatus) CanTransition(to OfferStatus) bool {
	for _, n := range offerTransitions[s] {
		if n == to {
			return true
		}
	}
	return false
}

func (s OfferStatus) Transition(to OfferStatus) error {
	if !s.Valid() {
		return fmt.Errorf("offer: ҳолати номаълум %q", s)
	}
	if !to.Valid() {
		return fmt.Errorf("offer: ҳолати мақсади номаълум %q", to)
	}
	if s == to {
		return ErrAlreadyInState
	}
	if !s.CanTransition(to) {
		return fmt.Errorf("offer: гузариш аз %s ба %s иҷозат нест", s, to)
	}
	return nil
}
