package domain

import "testing"

func TestCampaignHappyPath(t *testing.T) {
	// Роҳи пурраи campaign — ҳар қадам бояд иҷозат бошад.
	path := []CampaignStatus{
		CampaignDraft, CampaignPendingPayment, CampaignPaid, CampaignMatching,
		CampaignCreatorInvited, CampaignCreatorAccepted, CampaignActive,
		CampaignReview, CampaignCompleted,
	}
	for i := 0; i+1 < len(path); i++ {
		if err := path[i].Transition(path[i+1]); err != nil {
			t.Fatalf("%s → %s бояд иҷозат бошад: %v", path[i], path[i+1], err)
		}
	}
}

func TestCampaignCannotSkipPayment(t *testing.T) {
	// Муҳимтарин қоида: campaign бе пардохт ACTIVE намешавад.
	if err := CampaignDraft.Transition(CampaignActive); err == nil {
		t.Error("DRAFT → ACTIVE бояд рад шавад")
	}
	if err := CampaignPendingPayment.Transition(CampaignActive); err == nil {
		t.Error("PENDING_PAYMENT → ACTIVE бояд рад шавад")
	}
	if err := CampaignDraft.Transition(CampaignPaid); err == nil {
		t.Error("DRAFT → PAID бояд рад шавад (танҳо баъди пардохт)")
	}
}

func TestCampaignTerminalStatesAreFinal(t *testing.T) {
	for _, s := range []CampaignStatus{CampaignCompleted, CampaignCancelled, CampaignRefunded} {
		if !s.IsTerminal() {
			t.Errorf("%s бояд ниҳоӣ бошад", s)
		}
		if err := s.Transition(CampaignActive); err == nil {
			t.Errorf("%s → ACTIVE бояд рад шавад", s)
		}
	}
}

func TestPaymentCannotUnsucceed(t *testing.T) {
	if err := PaymentSucceeded.Transition(PaymentFailed); err == nil {
		t.Error("SUCCEEDED → FAILED бояд рад шавад")
	}
	if err := PaymentFailed.Transition(PaymentSucceeded); err == nil {
		t.Error("FAILED → SUCCEEDED бояд рад шавад")
	}
	if err := PaymentSucceeded.Transition(PaymentRefunded); err != nil {
		t.Errorf("SUCCEEDED → REFUNDED бояд иҷозат бошад: %v", err)
	}
}

func TestRepeatedStateIsIdempotentNotError(t *testing.T) {
	// Webhook метавонад ду бор ояд — ин бояд ErrAlreadyInState диҳад,
	// на хатои «гузариш иҷозат нест».
	if err := PaymentSucceeded.Transition(PaymentSucceeded); err != ErrAlreadyInState {
		t.Errorf("такрори SUCCEEDED: интизор ErrAlreadyInState, гирифтем %v", err)
	}
	if err := PayoutSucceeded.Transition(PayoutSucceeded); err != ErrAlreadyInState {
		t.Errorf("такрори payout SUCCEEDED: интизор ErrAlreadyInState, гирифтем %v", err)
	}
}

func TestPayoutRequiresActionWhenNoProviderAPI(t *testing.T) {
	// Агар provider payout API надошта бошад, payout ба REQUIRES_ACTION
	// меравад — на ба SUCCEEDED-и сохта.
	if err := PayoutPending.Transition(PayoutRequiresAction); err != nil {
		t.Errorf("PENDING → REQUIRES_ACTION бояд иҷозат бошад: %v", err)
	}
	if err := PayoutRequiresAction.Transition(PayoutSucceeded); err != nil {
		t.Errorf("REQUIRES_ACTION → SUCCEEDED бояд иҷозат бошад: %v", err)
	}
}

func TestPayoutCannotJumpToSucceeded(t *testing.T) {
	if err := PayoutPending.Transition(PayoutSucceeded); err == nil {
		t.Error("PENDING → SUCCEEDED бояд рад шавад (аввал PROCESSING)")
	}
}

func TestOfferFlow(t *testing.T) {
	if err := OfferInvited.Transition(OfferAccepted); err != nil {
		t.Errorf("INVITED → ACCEPTED: %v", err)
	}
	if err := OfferRejected.Transition(OfferAccepted); err == nil {
		t.Error("REJECTED → ACCEPTED бояд рад шавад")
	}
	if err := OfferInvited.Transition(OfferDelivered); err == nil {
		t.Error("INVITED → DELIVERED бояд рад шавад (аввал ACCEPTED)")
	}
}

func TestUnknownStatusRejected(t *testing.T) {
	if err := CampaignStatus("НАДОРАД").Transition(CampaignPaid); err == nil {
		t.Error("ҳолати номаълум бояд рад шавад")
	}
}
