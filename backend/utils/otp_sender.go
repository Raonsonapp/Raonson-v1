package utils

// OTP-расонӣ: Email (SMTP/Gmail), SMS ва WhatsApp (Twilio).
// Ҳар канал танҳо вақте кор мекунад, ки env-и дахлдор танзим шуда бошад;
// вагарна хато бармегардонад (то ҳолати dev OTP-ро дар response нишон диҳад).

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/smtp"
	"net/url"
	"os"
	"strings"
	"time"
)

// SendEmailOTP — рамзро тавассути email мефиристад.
// Афзалият бо Brevo (HTTP, порти 443) — чун хостингҳои ройгон (Hugging Face)
// порти SMTP-ро мебанданд. Агар Brevo танзим нашуда бошад, ба SMTP мегузарад.
func SendEmailOTP(to, otp string) error {
	subject := "Раонсон — рамзи барқарорсозӣ"
	body := fmt.Sprintf(
		"Рамзи тасдиқи шумо: %s\n\nИн рамз 10 дақиқа эътибор дорад.\n"+
			"Агар шумо дархост накарда бошед, ин паёмро нодида гиред.\n\n— Раонсон",
		otp)

	// 1) Brevo HTTP API (тавсияшаванда барои Hugging Face)
	if key := os.Getenv("BREVO_API_KEY"); key != "" {
		return sendBrevo(key, to, subject, body)
	}
	// 2) Fallback: SMTP (берун аз HF кор мекунад)
	return sendSMTP(to, subject, body)
}

// Brevo — transactional email тавассути HTTPS.
// env: BREVO_API_KEY, BREVO_SENDER (почтаи тасдиқшудаи фиристанда)
func sendBrevo(apiKey, to, subject, text string) error {
	sender := os.Getenv("BREVO_SENDER")
	if sender == "" {
		sender = os.Getenv("SMTP_USER")
	}
	if sender == "" {
		return fmt.Errorf("BREVO_SENDER not set")
	}
	payload := map[string]interface{}{
		"sender":      map[string]string{"email": sender, "name": "Raonson"},
		"to":          []map[string]string{{"email": to}},
		"subject":     subject,
		"textContent": text,
	}
	jb, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST",
		"https://api.brevo.com/v3/smtp/email", bytes.NewReader(jb))
	if err != nil {
		return err
	}
	req.Header.Set("api-key", apiKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("accept", "application/json")
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("brevo %d: %s", resp.StatusCode, string(b))
	}
	return nil
}

// SMTP бо timeout — портҳои гуногунро меозмоем (587 STARTTLS, баъд 465 SSL).
// Баъзе хостингҳо 587-ро мебанданд вале 465-ро мекушоянд (ё баръакс).
func sendSMTP(to, subject, bodyText string) error {
	host := os.Getenv("SMTP_HOST")
	user := os.Getenv("SMTP_USER")
	pass := strings.ReplaceAll(os.Getenv("SMTP_PASS"), " ", "")
	if host == "" {
		host = "smtp.gmail.com"
	}
	from := os.Getenv("SMTP_FROM")
	if from == "" {
		from = user
	}
	if user == "" || pass == "" {
		return fmt.Errorf("SMTP not configured (ва BREVO_API_KEY ҳам нест)")
	}

	msg := "From: Raonson <" + from + ">\r\n" +
		"To: " + to + "\r\n" +
		"Subject: " + subject + "\r\n" +
		"MIME-Version: 1.0\r\n" +
		"Content-Type: text/plain; charset=UTF-8\r\n\r\n" +
		bodyText

	// Тартиби озмоиш: агар SMTP_PORT танзим шуда бошад, аввал ҳамон.
	ports := []string{"587", "465"}
	if p := os.Getenv("SMTP_PORT"); p != "" && p != "587" && p != "465" {
		ports = append([]string{p}, ports...)
	} else if p == "465" {
		ports = []string{"465", "587"}
	}

	auth := smtp.PlainAuth("", user, pass, host)
	var lastErr error
	for _, port := range ports {
		err := smtpDeliver(host, port, from, to, msg, auth)
		if err == nil {
			return nil
		}
		lastErr = fmt.Errorf("порти %s: %w", port, err)
	}
	return fmt.Errorf("SMTP нашуд (%v) — хостинг шояд портҳоро баста бошад", lastErr)
}

// smtpDeliver — як кӯшиши расонидан тавассути порти мушаххас.
// Порти 465 = implicit TLS; дигарон = plain + STARTTLS.
func smtpDeliver(host, port, from, to, msg string, auth smtp.Auth) error {
	addr := host + ":" + port
	var conn net.Conn
	var err error
	if port == "465" {
		d := &net.Dialer{Timeout: 8 * time.Second}
		conn, err = tls.DialWithDialer(d, "tcp", addr, &tls.Config{ServerName: host})
	} else {
		conn, err = net.DialTimeout("tcp", addr, 8*time.Second)
	}
	if err != nil {
		return fmt.Errorf("dial: %w", err)
	}
	defer conn.Close()

	c, err := smtp.NewClient(conn, host)
	if err != nil {
		return err
	}
	defer c.Close()

	// Барои портҳои ғайри-465 STARTTLS лозим аст.
	if port != "465" {
		if ok, _ := c.Extension("STARTTLS"); ok {
			if err := c.StartTLS(&tls.Config{ServerName: host}); err != nil {
				return err
			}
		}
	}
	if err := c.Auth(auth); err != nil {
		return err
	}
	if err := c.Mail(from); err != nil {
		return err
	}
	if err := c.Rcpt(to); err != nil {
		return err
	}
	w, err := c.Data()
	if err != nil {
		return err
	}
	if _, err := w.Write([]byte(msg)); err != nil {
		return err
	}
	if err := w.Close(); err != nil {
		return err
	}
	return c.Quit()
}

// SendSMSOTP — рамзро тавассути Twilio SMS мефиристад.
// env: TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM (рақами фиристанда)
func SendSMSOTP(phone, otp string) error {
	return twilioSend(os.Getenv("TWILIO_FROM"), phone, otp)
}

// SendWhatsAppOTP — рамзро тавассути Twilio WhatsApp мефиристад.
// env: TWILIO_SID, TWILIO_TOKEN, TWILIO_WA_FROM (масалан "whatsapp:+14155238886")
func SendWhatsAppOTP(phone, otp string) error {
	from := os.Getenv("TWILIO_WA_FROM")
	if from == "" {
		return fmt.Errorf("WhatsApp not configured")
	}
	to := phone
	if !strings.HasPrefix(to, "whatsapp:") {
		to = "whatsapp:" + to
	}
	return twilioSend(from, to, otp)
}

func twilioSend(from, to, otp string) error {
	sid := os.Getenv("TWILIO_SID")
	token := os.Getenv("TWILIO_TOKEN")
	if sid == "" || token == "" || from == "" {
		return fmt.Errorf("Twilio not configured")
	}
	endpoint := "https://api.twilio.com/2010-04-01/Accounts/" + sid + "/Messages.json"
	form := url.Values{}
	form.Set("From", from)
	form.Set("To", to)
	form.Set("Body", fmt.Sprintf("Раонсон: рамзи тасдиқи шумо %s (10 дақиқа эътибор дорад).", otp))

	req, err := http.NewRequest("POST", endpoint, strings.NewReader(form.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(sid, token)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("twilio status %d", resp.StatusCode)
	}
	return nil
}

// SendTelegramOTP — рамзро тавассути Telegram Gateway API мефиристад (ройгон).
// env: TELEGRAM_GATEWAY_TOKEN (аз gateway.telegram.org)
// Агар сервер мустақим ба Telegram пайваст нашавад (TLS timeout) —
// тавассути Google Apps Script proxy мефиристад:
// env: TELEGRAM_GATEWAY_PROXY_URL, TELEGRAM_GATEWAY_PROXY_SECRET
func SendTelegramOTP(phone, otp string) error {
	token := os.Getenv("TELEGRAM_GATEWAY_TOKEN")
	if token == "" {
		return fmt.Errorf("TELEGRAM_GATEWAY_TOKEN not configured")
	}

	// Аввал мустақим кӯшиш мекунем
	err := telegramGatewaySend(token, phone, otp)
	if err == nil {
		return nil
	}

	// Агар хато дод — тавассути proxy кӯшиш мекунем
	proxyURL := os.Getenv("TELEGRAM_GATEWAY_PROXY_URL")
	proxySecret := os.Getenv("TELEGRAM_GATEWAY_PROXY_SECRET")
	if proxyURL != "" && proxySecret != "" {
		return telegramProxySend(proxyURL, proxySecret, phone, otp)
	}
	return fmt.Errorf("telegram direct failed: %w", err)
}

func telegramGatewaySend(token, phone, otp string) error {
	payload := map[string]interface{}{
		"phone_number": phone,
		"code":         otp,
		"ttl":          300,
	}
	jb, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST",
		"https://gatewayapi.telegram.org/sendVerificationMessage",
		bytes.NewReader(jb))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 15 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("telegram gateway: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("telegram gateway %d: %s", resp.StatusCode, string(b))
	}
	return nil
}

func telegramProxySend(proxyURL, secret, phone, otp string) error {
	payload := map[string]interface{}{
		"phone_number":  phone,
		"code":          otp,
		"ttl":           300,
		"relay_secret":  secret,
	}
	jb, _ := json.Marshal(payload)
	req, err := http.NewRequest("POST", proxyURL, bytes.NewReader(jb))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("telegram proxy: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		b, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("telegram proxy %d: %s", resp.StatusCode, string(b))
	}
	return nil
}

// MaskEmail — "ehson@gmail.com" → "ehs***@gmail.com"
func MaskEmail(email string) string {
	at := strings.Index(email, "@")
	if at <= 1 {
		return email
	}
	keep := 3
	if at < keep {
		keep = at
	}
	return email[:keep] + "***" + email[at:]
}

// MaskPhone — "+992900112233" → "+992 *** ** 33"
func MaskPhone(phone string) string {
	if len(phone) < 4 {
		return phone
	}
	return phone[:len(phone)-2] + "**"
}

// ══════════════════════════════════════════════════════════════════
//  Фиристодани рамз ба ТЕЛЕФОН — бо якчанд канал
//
//  Камбудии аслӣ: `SendPhoneOTP` ТАНҲО Telegram-ро истифода мебурд.
//  Telegram Gateway SMS ба сим-карта НАМЕФИРИСТАД — он паёмро дар
//  барномаи Telegram мерасонад ва танҳо баъди тасдиқи ҳисоб дар
//  gateway.telegram.org кор мекунад.
//
//  `SendSMSOTP` (Twilio — SMS-и ҳақиқӣ) навишта шуда буд, вале
//  ҳеҷ гоҳ даъват намешуд. Барои ҳамин корбар мегуфт: «смс
//  намеояд».
//
//  Акнун каналҳо бо навбат кӯшиш мешаванд ва маълум мешавад, ки
//  рамз аз кадом роҳ рафт — ё чаро ҳеҷ кадом нарафт.
// ══════════════════════════════════════════════════════════════════

// OTPChannel — кадом роҳ кор кард.
type OTPChannel string

const (
	ChannelSMS      OTPChannel = "sms"
	ChannelTelegram OTPChannel = "telegram"
	ChannelWhatsApp OTPChannel = "whatsapp"
)

// SendPhoneCode рамзро ба телефон мефиристад.
//
// Тартиб: SMS → Telegram → WhatsApp. SMS аввал аст, чунки он ба
// ҲАР телефон мерасад — барномаи иловагӣ лозим нест.
//
// Бармегардонад: кадом канал кор кард ва хатоҳои ҳамаи каналҳо
// (барои log; ба корбар нишон дода намешавад).
func SendPhoneCode(phone, otp string) (OTPChannel, error) {
	type attempt struct {
		name OTPChannel
		fn   func() error
	}
	attempts := []attempt{
		{ChannelSMS, func() error { return SendSMSOTP(phone, otp) }},
		{ChannelTelegram, func() error { return SendTelegramOTP(phone, otp) }},
		{ChannelWhatsApp, func() error { return SendWhatsAppOTP(phone, otp) }},
	}

	var errs []string
	for _, a := range attempts {
		if err := a.fn(); err == nil {
			return a.name, nil
		} else {
			errs = append(errs, string(a.name)+": "+err.Error())
		}
	}
	return "", fmt.Errorf("ҳеҷ канал кор накард — %s", strings.Join(errs, "; "))
}

// OTPChannelsReady — кадом каналҳо ТАНЗИМ шудаанд.
//
// Ин ба `/health` меравад, то соҳиби барнома бидуни фиристодани
// ягон калид бубинад, ки чаро SMS намеояд. Худи калидҳо ҳеҷ гоҳ
// бармегарданд — танҳо «ҳаст ё нест».
func OTPChannelsReady() map[string]bool {
	twilio := os.Getenv("TWILIO_SID") != "" && os.Getenv("TWILIO_TOKEN") != ""
	return map[string]bool{
		"sms":      twilio && os.Getenv("TWILIO_FROM") != "",
		"whatsapp": twilio && os.Getenv("TWILIO_WA_FROM") != "",
		"telegram": os.Getenv("TELEGRAM_GATEWAY_TOKEN") != "",
		"email": os.Getenv("BREVO_API_KEY") != "" ||
			(os.Getenv("SMTP_USER") != "" && os.Getenv("SMTP_PASS") != ""),
	}
}

// OTPMissingHint — матни кӯтоҳ барои соҳиби барнома: чиро танзим кардан.
func OTPMissingHint() string {
	r := OTPChannelsReady()
	if r["sms"] || r["telegram"] || r["whatsapp"] {
		return ""
	}
	return "барои SMS: TWILIO_SID, TWILIO_TOKEN, TWILIO_FROM; " +
		"барои Telegram: TELEGRAM_GATEWAY_TOKEN"
}
