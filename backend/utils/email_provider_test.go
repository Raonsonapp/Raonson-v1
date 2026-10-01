package utils

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

// Hugging Face Spaces портҳои SMTP-ро мебандад. Brevo (HTTPS) бояд
// ҳамеша аввал озмуда шавад, вақте калидаш ҳаст — ҳатто агар SMTP ҳам
// танзим бошад. Ҳамаи тестҳо бе шабакаи воқеӣ (httptest).

func clearEmailEnv(t *testing.T) {
	for _, k := range []string{"BREVO_API_KEY", "BREVO_SENDER", "RESEND_API_KEY",
		"RESEND_FROM", "SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "SMTP_FROM"} {
		t.Setenv(k, "")
	}
}

func withURL(t *testing.T, target *string, v string) {
	old := *target
	*target = v
	t.Cleanup(func() { *target = old })
}

func TestBrevoPreferredOverSMTP(t *testing.T) {
	clearEmailEnv(t)
	var gotKey string
	var got map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.Header.Get("api-key")
		json.NewDecoder(r.Body).Decode(&got)
		w.WriteHeader(201)
		w.Write([]byte(`{"messageId":"x"}`))
	}))
	defer srv.Close()
	withURL(t, &brevoAPIURL, srv.URL)

	t.Setenv("BREVO_API_KEY", "xkeysib-test-secret")
	t.Setenv("BREVO_SENDER", "noreply@example.com")
	// SMTP ҳам танзим аст, вале ба хости мурда — набояд озмуда шавад.
	t.Setenv("SMTP_HOST", "127.0.0.1")
	t.Setenv("SMTP_PORT", "1")
	t.Setenv("SMTP_USER", "u@example.com")
	t.Setenv("SMTP_PASS", "pw")

	if p := EmailProvidersConfigured(); len(p) != 2 || p[0] != EmailProviderBrevo || p[1] != EmailProviderSMTP {
		t.Fatalf("тартиби провайдерҳо нодуруст: %v", p)
	}
	res, err := SendEmailDetailed(context.Background(), "to@example.com", "s", "b")
	if err != nil {
		t.Fatalf("Brevo бояд кор кунад: %v", err)
	}
	if res.Provider != EmailProviderBrevo || len(res.Attempts) != 1 || !res.Attempts[0].OK {
		t.Fatalf("натиҷа: %+v", res)
	}
	if gotKey != "xkeysib-test-secret" {
		t.Errorf("сарлавҳаи api-key нарасид")
	}
	if got["subject"] != "s" {
		t.Errorf("payload: %v", got)
	}
	sender, _ := got["sender"].(map[string]any)
	if sender["email"] != "noreply@example.com" {
		t.Errorf("sender: %v", got["sender"])
	}
}

func TestBrevoErrorFallsBackAndNeverLeaksKey(t *testing.T) {
	clearEmailEnv(t)
	const key = "xkeysib-very-secret-value"
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Ҳатто агар сервер калидро дар ҷавоб баргардонад.
		w.WriteHeader(401)
		w.Write([]byte(`{"code":"unauthorized","message":"Key not found: ` + key + `"}`))
	}))
	defer srv.Close()
	withURL(t, &brevoAPIURL, srv.URL)

	// Resend ҳамчун захира кор мекунад.
	var auth string
	rs := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		auth = r.Header.Get("Authorization")
		w.WriteHeader(200)
		w.Write([]byte(`{"id":"1"}`))
	}))
	defer rs.Close()
	withURL(t, &resendAPIURL, rs.URL)

	t.Setenv("BREVO_API_KEY", key)
	t.Setenv("BREVO_SENDER", "noreply@example.com")
	t.Setenv("RESEND_API_KEY", "re_secret")

	res, err := SendEmailDetailed(context.Background(), "to@example.com", "s", "b")
	if err != nil {
		t.Fatalf("Resend бояд захира бошад: %v", err)
	}
	if res.Provider != EmailProviderResend || len(res.Attempts) != 2 {
		t.Fatalf("натиҷа: %+v", res)
	}
	if auth != "Bearer re_secret" {
		t.Errorf("Authorization нарасид")
	}
	if strings.Contains(res.Attempts[0].Error, key) {
		t.Fatalf("калид дар хато фош шуд: %s", res.Attempts[0].Error)
	}
	if !strings.Contains(res.Attempts[0].Error, "401") {
		t.Errorf("хатои Brevo фаҳмо нест: %s", res.Attempts[0].Error)
	}
}

func TestBrevoOnlyFailureReportsProvider(t *testing.T) {
	clearEmailEnv(t)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(400)
		w.Write([]byte(`{"code":"invalid_parameter","message":"sender not valid"}`))
	}))
	defer srv.Close()
	withURL(t, &brevoAPIURL, srv.URL)
	t.Setenv("BREVO_API_KEY", "xkeysib-abc")
	t.Setenv("BREVO_SENDER", "noreply@example.com")
	res, err := SendEmailDetailed(context.Background(), "to@example.com", "s", "b")
	if err == nil || res.Provider != EmailProviderBrevo {
		t.Fatalf("бояд хато бо провайдери brevo бошад: %+v %v", res, err)
	}
	if !strings.Contains(err.Error(), "sender not valid") {
		t.Errorf("сабаби Brevo гум шуд: %v", err)
	}
}

func TestBrevoSMTPKeyDetected(t *testing.T) {
	clearEmailEnv(t)
	called := false
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(201)
	}))
	defer srv.Close()
	withURL(t, &brevoAPIURL, srv.URL)
	t.Setenv("BREVO_API_KEY", "xsmtpsib-wrong-kind")
	t.Setenv("BREVO_SENDER", "noreply@example.com")
	_, err := SendEmailDetailed(context.Background(), "to@example.com", "s", "b")
	if err == nil || called {
		t.Fatalf("калиди SMTP бояд пеш аз дархост рад шавад (called=%v err=%v)", called, err)
	}
	if strings.Contains(err.Error(), "xsmtpsib-wrong-kind") || !strings.Contains(err.Error(), "API Keys") {
		t.Errorf("хато: %v", err)
	}
}

func TestBrevoAPIKeyInSMTPPassUsesHTTPS(t *testing.T) {
	clearEmailEnv(t)
	var gotKey string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotKey = r.Header.Get("api-key")
		w.WriteHeader(201)
	}))
	defer srv.Close()
	withURL(t, &brevoAPIURL, srv.URL)
	t.Setenv("SMTP_HOST", "smtp-relay.brevo.com")
	t.Setenv("SMTP_USER", "me@example.com")
	t.Setenv("SMTP_PASS", "xkeysib-in-smtp-pass")
	res, err := SendEmailDetailed(context.Background(), "to@example.com", "s", "b")
	if err != nil || res.Provider != EmailProviderBrevo || gotKey != "xkeysib-in-smtp-pass" {
		t.Fatalf("калиди API дар SMTP_PASS бояд бо HTTPS равад: %+v %v", res, err)
	}
}

// Танҳо SMTP ва порт баста (хости хомӯш) → хато ба BREVO_API_KEY ишора кунад.
func TestSMTPOnlyBlockedGivesBrevoHint(t *testing.T) {
	clearEmailEnv(t)
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			defer c.Close() // хомӯш
		}
	}()
	_, port, _ := net.SplitHostPort(ln.Addr().String())
	t.Setenv("SMTP_HOST", "127.0.0.1")
	t.Setenv("SMTP_PORT", port)
	t.Setenv("SMTP_USER", "u@example.com")
	t.Setenv("SMTP_PASS", "plain-smtp-password")
	old := EmailTimeout
	EmailTimeout = 600 * time.Millisecond
	defer func() { EmailTimeout = old }()

	ctx, cancel := context.WithTimeout(context.Background(), EmailTimeout)
	defer cancel()
	res, err := SendEmailDetailed(ctx, "to@example.com", "s", "b")
	if err == nil || res.Provider != EmailProviderSMTP {
		t.Fatalf("бояд хатои SMTP бошад: %+v %v", res, err)
	}
	msg := err.Error()
	for _, want := range []string{"BREVO_API_KEY", "API Keys", "Hugging Face"} {
		if !strings.Contains(msg, want) {
			t.Errorf("маслиҳат %q нест: %s", want, msg)
		}
	}
	if strings.Contains(msg, "plain-smtp-password") {
		t.Fatal("пароли SMTP фош шуд")
	}
}

func TestNoEmailProviderConfigured(t *testing.T) {
	clearEmailEnv(t)
	if len(EmailProvidersConfigured()) != 0 {
		t.Fatal("набояд провайдер бошад")
	}
	_, err := SendEmailDetailed(context.Background(), "to@example.com", "s", "b")
	if err == nil || !strings.Contains(err.Error(), "BREVO_API_KEY") {
		t.Fatalf("хато: %v", err)
	}
}
