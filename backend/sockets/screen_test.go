package sockets

import "testing"

func TestValidScreen(t *testing.T) {
	for _, a := range []string{"start", "stop"} {
		if !validScreen(a) {
			t.Fatalf("%q must be valid", a)
		}
	}
	for _, a := range []string{"", "START", "pause", "<script>", "request"} {
		if validScreen(a) {
			t.Fatalf("%q must be rejected", a)
		}
	}
}

func TestScreenRelayOnlyBetweenCallParticipants(t *testing.T) {
	// Гуфтугӯи ҷорӣ: танҳо a ↔ b.
	inCall := func(x, y string) bool {
		return (x == "a" && y == "b") || (x == "b" && y == "a")
	}
	yes := func(string, string) bool { return true }
	no := func(string, string) bool { return false }

	if !screenRelayOK("a", "b", "start", yes, inCall) {
		t.Fatal("a → b start must relay")
	}
	if !screenRelayOK("b", "a", "stop", yes, inCall) {
		t.Fatal("b → a stop must relay")
	}
	cases := []struct {
		name, from, to, action string
		allowed                func(string, string) bool
	}{
		{"not in a call with target", "a", "c", "start", yes},
		{"stranger", "c", "b", "start", yes},
		{"self", "a", "a", "start", yes},
		{"empty target", "a", "", "start", yes},
		{"unknown action", "a", "b", "hack", yes},
		{"blocked", "a", "b", "start", no},
	}
	for _, c := range cases {
		if screenRelayOK(c.from, c.to, c.action, c.allowed, inCall) {
			t.Fatalf("%s: must be rejected", c.name)
		}
	}
}
