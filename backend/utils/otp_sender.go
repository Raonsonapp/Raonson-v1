package utils

// OTP-расонӣ: Email (SMTP/Gmail), SMS ва WhatsApp (Twilio).
// Ҳар канал танҳо вақте кор мекунад, ки env-и дахлдор танзим шуда бошад;
// вагарна хато бармегардонад (то ҳолати dev OTP-ро дар response нишон диҳад).

import (
	"fmt"
	"net/http"
	"net/smtp"
	"net/url"
	"os"
	"strings"
)

// SendEmailOTP — рамзро тавассути Gmail/SMTP мефиристад.
// env: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
func SendEmailOTP(to, otp string) error {
	host := os.Getenv("SMTP_HOST")
	user := os.Getenv("SMTP_USER")
	pass := os.Getenv("SMTP_PASS")
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
	// Gmail app-password-ро бо фосила нишон медиҳад ("xxxx xxxx ...") —
	// фосиларо тоза мекунем, то корбар хато накунад.
	pass = strings.ReplaceAll(pass, " ", "")
	if user == "" || pass == "" {
		return fmt.Errorf("SMTP not configured")
	}

	subject := "Раонсон — рамзи барқарорсозӣ"
	body := fmt.Sprintf(
		"Рамзи тасдиқи шумо: %s\n\nИн рамз 10 дақиқа эътибор дорад.\n"+
			"Агар шумо дархост накарда бошед, ин паёмро нодида гиред.\n\n— Раонсон",
		otp)
	msg := "From: Raonson <" + from + ">\r\n" +
		"To: " + to + "\r\n" +
		"Subject: " + subject + "\r\n" +
		"MIME-Version: 1.0\r\n" +
		"Content-Type: text/plain; charset=UTF-8\r\n\r\n" +
		body

	auth := smtp.PlainAuth("", user, pass, host)
	return smtp.SendMail(host+":"+port, auth, from, []string{to}, []byte(msg))
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
