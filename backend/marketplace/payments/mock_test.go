package payments

import (
	"context"
	"encoding/json"
	"testing"

	"raonson/marketplace/domain"
	"raonson/marketplace/money"
)

func TestWebhookRejectsBadSignature(t *testing.T) {
	p := NewMockProvider("secret-A")
	body, _ := json.Marshal(mockWebhookBody{
		EventID: "e1", Reference: "mock_o1", Status: "SUCCEEDED",
		Minor: 50000, Currency: "TJS",
	})
	// Имзо бо калиди дигар — бояд рад шавад.
	other := NewMockProvider("secret-B")
	_, err := p.ParseWebhook(context.Background(),
		map[string]string{"X-Signature": other.Sign(body)}, body)
	if err != ErrInvalidSignature {
		t.Fatalf("интизор ErrInvalidSignature, гирифтем %v", err)
	}
}

func TestWebhookRejectsMissingSignature(t *testing.T) {
	p := NewMockProvider("s")
	body := []byte(`{"event_id":"e1","reference":"r","status":"SUCCEEDED","amount_minor":1,"currency":"TJS"}`)
	if _, err := p.ParseWebhook(context.Background(), map[string]string{}, body); err != ErrInvalidSignature {
		t.Fatalf("бе имзо бояд рад шавад, гирифтем %v", err)
	}
}

func TestWebhookRejectsTamperedBody(t *testing.T) {
	p := NewMockProvider("s")
	body, _ := json.Marshal(mockWebhookBody{
		EventID: "e1", Reference: "mock_o1", Status: "SUCCEEDED",
		Minor: 50000, Currency: "TJS",
	})
	sig := p.Sign(body)
	// Маблағро баъд аз имзо иваз мекунем — имзо бояд мувофиқ набошад.
	tampered, _ := json.Marshal(mockWebhookBody{
		EventID: "e1", Reference: "mock_o1", Status: "SUCCEEDED",
		Minor: 999999, Currency: "TJS",
	})
	if _, err := p.ParseWebhook(context.Background(),
		map[string]string{"X-Signature": sig}, tampered); err != ErrInvalidSignature {
		t.Fatalf("body-и тағйирёфта бояд рад шавад, гирифтем %v", err)
	}
}

func TestWebhookAcceptsValidSignature(t *testing.T) {
	p := NewMockProvider("s")
	body, _ := json.Marshal(mockWebhookBody{
		EventID: "e1", EventType: "payment.succeeded", Reference: "mock_o1",
		Status: "SUCCEEDED", Minor: 50000, Currency: "TJS",
	})
	ev, err := p.ParseWebhook(context.Background(),
		map[string]string{"X-Signature": p.Sign(body)}, body)
	if err != nil {
		t.Fatal(err)
	}
	if ev.EventID != "e1" || ev.Status != domain.PaymentSucceeded {
		t.Errorf("ҳодиса нодуруст: %+v", ev)
	}
	if ev.Amount.Minor != 50000 || ev.Amount.Currency != money.TJS {
		t.Errorf("маблағ нодуруст: %v", ev.Amount)
	}
}

func TestWebhookRejectsUnknownStatus(t *testing.T) {
	p := NewMockProvider("s")
	body, _ := json.Marshal(mockWebhookBody{
		EventID: "e1", Reference: "r", Status: "НАДОРАД",
		Minor: 1, Currency: "TJS",
	})
	if _, err := p.ParseWebhook(context.Background(),
		map[string]string{"X-Signature": p.Sign(body)}, body); err == nil {
		t.Fatal("ҳолати номаълум бояд рад шавад")
	}
}

func TestCreatePaymentIsIdempotent(t *testing.T) {
	p := NewMockProvider("s")
	req := CreateRequest{OrderID: "o1", Amount: money.MustNew(50000, money.TJS)}
	a, err := p.CreatePayment(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	b, err := p.CreatePayment(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if a.ProviderReference != b.ProviderReference {
		t.Errorf("такрори CreatePayment reference-и дигар дод: %s != %s",
			a.ProviderReference, b.ProviderReference)
	}
}

func TestCreatePaymentRejectsNonPositive(t *testing.T) {
	p := NewMockProvider("s")
	_, err := p.CreatePayment(context.Background(),
		CreateRequest{OrderID: "o1", Amount: money.Amount{Minor: 0, Currency: money.TJS}})
	if err == nil {
		t.Fatal("маблағи сифр бояд рад шавад")
	}
}

func TestRegistry(t *testing.T) {
	r := NewRegistry()
	r.Register(NewMockProvider("s"))
	if _, err := r.Get("mock"); err != nil {
		t.Errorf("mock бояд ёфт шавад: %v", err)
	}
	if _, err := r.Get("надорад"); err != ErrUnknownProvider {
		t.Errorf("интизор ErrUnknownProvider, гирифтем %v", err)
	}
}
