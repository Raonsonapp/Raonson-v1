package sockets

import "testing"

func TestValidSwitch(t *testing.T) {
	ok := [][2]string{{"video", "request"}, {"video", "accept"}, {"voice", "apply"},
		{"video", "decline"}, {"video", "cancel"}}
	for _, c := range ok {
		if !validSwitch(c[0], c[1]) {
			t.Fatalf("%v must be valid", c)
		}
	}
	bad := [][2]string{{"", "request"}, {"screen", "request"}, {"video", ""},
		{"video", "<script>"}, {"voice", "hack"}}
	for _, c := range bad {
		if validSwitch(c[0], c[1]) {
			t.Fatalf("%v must be rejected", c)
		}
	}
}
