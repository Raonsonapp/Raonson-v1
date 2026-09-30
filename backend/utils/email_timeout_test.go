package utils

import (
	"net"
	"strings"
	"testing"
	"time"
)

// Сервери SMTP, ки пайвастро қабул мекунад, вале ҳеҷ гоҳ ҷавоб намедиҳад.
//
// Пеш net/smtp баъди dial deadline надошт — дархости /admin/test-email
// то абад овезон мемонд ва клиент бо «TimeoutException after 0:00:08»
// меафтод. Акнун бояд дар буҷети EmailTimeout бо хатои фаҳмо баргардад.
func TestSendEmailOTPTimesOutOnSilentSMTP(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()
	var conns []net.Conn
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			conns = append(conns, c) // хомӯш: greeting намефиристем
		}
	}()
	_, port, _ := net.SplitHostPort(ln.Addr().String())

	t.Setenv("BREVO_API_KEY", "")
	t.Setenv("SMTP_HOST", "127.0.0.1")
	t.Setenv("SMTP_PORT", port)
	t.Setenv("SMTP_USER", "u@example.com")
	t.Setenv("SMTP_PASS", "p")
	old := EmailTimeout
	EmailTimeout = 700 * time.Millisecond
	defer func() { EmailTimeout = old }()

	start := time.Now()
	err = SendEmailOTP("to@example.com", "123456")
	took := time.Since(start)
	if err == nil {
		t.Fatal("сервери хомӯш хато надод")
	}
	if took > 3*time.Second {
		t.Fatalf("timeout кор накард: %s", took)
	}
	if !strings.Contains(err.Error(), "timeout") {
		t.Errorf("хато фаҳмо нест: %v", err)
	}
}
