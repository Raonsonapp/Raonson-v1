package notify

import (
	"testing"
	"time"

	"raonson/push"
)

// Барнома (lib/calls/call_payload.dart) ҳар майдонро аз рӯи ҳамин
// номҳо мехонад. Номи иваз шуда = занге, ки ҳеҷ гоҳ намезанад.
func TestCallDataFields(t *testing.T) {
	now := time.UnixMilli(1_700_000_000_000)
	d := CallData(Call{CalleeID: "b", CallerID: "a", CallType: "VIDEO",
		CallID: "c-1"}, "ali", "https://x/a.jpg", now)
	want := map[string]string{
		"type": "incoming_call", "callId": "c-1", "callerId": "a",
		"callerName": "ali", "callerAvatar": "https://x/a.jpg",
		"callType": "video", "sentAt": "1700000000000",
	}
	for k, v := range want {
		if d[k] != v {
			t.Errorf("data[%q] = %q, интизори %q", k, d[k], v)
		}
	}
}

// Қимати бегона ба «voice» меафтад: барнома танҳо ду намудро мефаҳмад.
func TestNormalizeCallType(t *testing.T) {
	for in, want := range map[string]string{
		"video": "video", " Video ": "video", "voice": "voice",
		"": "voice", "audio": "voice", "hack": "voice",
	} {
		if got := NormalizeCallType(in); got != want {
			t.Errorf("NormalizeCallType(%q) = %q, интизори %q", in, got, want)
		}
	}
}

// Android — data-only ва HIGH; iOS — огоҳиномаи намоён (бе PushKit
// паёми хомӯш дар iOS занг намезанад).
func TestCallMessagePerPlatform(t *testing.T) {
	data := map[string]string{"callerId": "a", "type": "incoming_call"}

	a := CallMessage(push.Device{Token: "t1", Platform: "android"}, data, "ali", "занг")
	if !a.DataOnly || !a.HighPriority {
		t.Errorf("android: DataOnly=%v High=%v", a.DataOnly, a.HighPriority)
	}
	if a.Title != "" || a.Body != "" {
		t.Error("android: матн набояд бошад — барнома худаш экран мекашад")
	}
	if a.TTL != CallRingTTL || a.TTL > time.Minute {
		t.Errorf("TTL: %v", a.TTL)
	}

	i := CallMessage(push.Device{Token: "t2", Platform: "ios"}, data, "ali", "занг")
	if i.DataOnly || i.Title == "" || !i.HighPriority {
		t.Errorf("ios: DataOnly=%v title=%q", i.DataOnly, i.Title)
	}
	if i.ChannelID != string(ChannelCalls) {
		t.Errorf("канал: %q", i.ChannelID)
	}
}

// Занг ба канали зангҳо меравад, на ба паёмҳо (садои дигар).
func TestIncomingCallRule(t *testing.T) {
	r := RuleFor(IncomingCall)
	if r.Priority != High || r.Channel != ChannelCalls {
		t.Errorf("қоида: %+v", r)
	}
}
