package handlers

import (
	"strings"
	"testing"

	at2 "github.com/AgoraIO/Tools/DynamicKey/AgoraDynamicKey/go/src/accesstoken2"
)

// Agora номи каналро то 64 байт қабул мекунад; "uuid_uuid" 73 буд.
func TestCallChannelShortAndSymmetric(t *testing.T) {
	a := "4f1c2b0e-8a7d-4c3e-9b1a-2d3e4f5a6b7c"
	b := "9e8d7c6b-5a4f-4e3d-8c2b-1a0f9e8d7c6b"
	ab, ba := callChannel(a, b), callChannel(b, a)
	if ab != ba {
		t.Fatalf("channel must be the same for both sides: %q vs %q", ab, ba)
	}
	if len(ab) >= 64 {
		t.Fatalf("channel too long for Agora: %d", len(ab))
	}
	if strings.Contains(ab, a) || ab == callChannel(a, "другой") {
		t.Fatalf("channel must not leak ids / must differ per pair: %q", ab)
	}
}

func TestRTCTokenEmptyWithoutCertificate(t *testing.T) {
	t.Setenv("AGORA_APP_ID", "0123456789abcdef0123456789abcdef")
	t.Setenv("AGORA_APP_CERTIFICATE", "")
	tok, err := rtcToken("call_x", true)
	if err != nil || tok != "" {
		t.Fatalf("expected empty token in App-ID-only mode, got %q %v", tok, err)
	}
}

func TestRTCTokenBuiltWithCertificate(t *testing.T) {
	t.Setenv("AGORA_APP_ID", "0123456789abcdef0123456789abcdef")
	t.Setenv("AGORA_APP_CERTIFICATE", "fedcba9876543210fedcba9876543210")
	tok, err := rtcToken("call_x", true)
	if err != nil || !strings.HasPrefix(tok, "007") {
		t.Fatalf("expected AccessToken2, got %q %v", tok, err)
	}
	var parsed at2.AccessToken
	if ok, err := parsed.Parse(tok); !ok || err != nil {
		t.Fatalf("token does not parse: %v", err)
	}
	if parsed.AppId != "0123456789abcdef0123456789abcdef" {
		t.Fatalf("wrong app id in token: %q", parsed.AppId)
	}
}
