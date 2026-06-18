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

// SMTP бо timeout-и пайвастшавӣ (то дар HF беохир шах нашавад).
func sendSMTP(to, subject, bodyText string) error {
	host := os.Getenv("SMTP_HOST")
	user := os.Getenv("SMTP_USER")
	pass := strings.ReplaceAll(os.Getenv("SMTP_PASS"), " ", "")
	if host == "" {
		host = "smtp.gmail.com"
	}
	port := os.Getenv("SMTP_PORT")
	if port == "" {
		port = "587"
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

	addr := host + ":" + port
	conn, err := net.DialTimeout("tcp", addr, 8*time.Second)
	if err != nil {
		return fmt.Errorf("SMTP dial: %w (хостинг шояд портро баста бошад)", err)
	}
	defer conn.Close()
	c, err := smtp.NewClient(conn, host)
	if err != nil {
		return err
	}
	defer c.Close()
	if err := c.StartTLS(&tls.Config{ServerName: host}); err != nil {
		return err
	}
	if err := c.Auth(smtp.PlainAuth("", user, pass, host)); err != nil {
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
