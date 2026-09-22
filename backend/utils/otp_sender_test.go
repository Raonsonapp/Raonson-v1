package utils

import (
	"os"
	"testing"
)

// Рамз ба телефон: SMS аввал.
//
// Камбудии аслӣ — `SendPhoneOTP` ТАНҲО Telegram-ро истифода мебурд.
// Telegram Gateway ба сим-карта SMS намефиристад. `SendSMSOTP`
// (Twilio) навишта шуда буд, вале ҳеҷ гоҳ даъват намешуд.

func TestSendPhoneCodeFailsLoudlyWhenNothingConfigured(t *testing.T) {
	for _, k := range []string{
		"TWILIO_SID", "TWILIO_TOKEN", "TWILIO_FROM", "TWILIO_WA_FROM",
		"TELEGRAM_GATEWAY_TOKEN", "TELEGRAM_GATEWAY_PROXY_URL",
	} {
		t.Setenv(k, "")
	}
	ch, err := SendPhoneCode("+992900000000", "123456")
	if err == nil {
		t.Fatalf("бе ягон канал хато набуд — канал %q", ch)
	}
	if ch != "" {
		t.Errorf("канали бармегашта бояд холӣ бошад, на %q", ch)
	}
	// Хато бояд ҳар СЕ канал ва сабаби ҳар кадомро гӯяд, вагарна
	// «смс намеояд» ташхис намешавад.
	for _, want := range []string{"sms", "telegram", "whatsapp"} {
		if !contains(err.Error(), want) {
			t.Errorf("хато дар бораи %s чизе намегӯяд: %v", want, err)
		}
	}
}

func TestOTPChannelsReady(t *testing.T) {
	for _, k := range []string{
		"TWILIO_SID", "TWILIO_TOKEN", "TWILIO_FROM", "TWILIO_WA_FROM",
		"TELEGRAM_GATEWAY_TOKEN", "BREVO_API_KEY", "SMTP_USER", "SMTP_PASS",
	} {
		t.Setenv(k, "")
	}
	r := OTPChannelsReady()
	for k, v := range r {
		if v {
			t.Errorf("%s бе танзимот «тайёр» менамояд", k)
		}
	}
	if OTPMissingHint() == "" {
		t.Error("ҳангоми набудани ҳама канал маслиҳат бояд бошад")
	}

	// SMS танҳо вақте тайёр аст, ки ҲАР СЕ калид бошанд.
	t.Setenv("TWILIO_SID", "x")
	t.Setenv("TWILIO_TOKEN", "y")
	if OTPChannelsReady()["sms"] {
		t.Error("бе TWILIO_FROM sms набояд «тайёр» бошад")
	}
	t.Setenv("TWILIO_FROM", "+1555")
	if !OTPChannelsReady()["sms"] {
		t.Error("бо ҳар се калид sms бояд тайёр бошад")
	}
	if OTPMissingHint() != "" {
		t.Error("вақте канал ҳаст, маслиҳат набояд бошад")
	}
	_ = os.Getenv
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (func() bool {
		for i := 0; i+len(sub) <= len(s); i++ {
			if s[i:i+len(sub)] == sub {
				return true
			}
		}
		return false
	})()
}
