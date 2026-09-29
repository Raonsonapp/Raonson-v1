package notify

import "testing"

func TestReelsPrefSilencesReelKinds(t *testing.T) {
	off := false
	p := Prefs{Reels: &off}
	if p.Allows(ReelLike) || p.Allows(ReelReply) {
		t.Fatal("reel notifications must be off when reels pref is off")
	}
	if !p.Allows(Like) {
		t.Fatal("post likes must not be affected by the reels pref")
	}
}
