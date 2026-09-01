package store

import (
	"testing"
	"time"
)

// Таъхир экспоненсиалӣ меафзояд ва ҳадди боло дорад.
func TestPayoutBackoffIsExponentialAndCapped(t *testing.T) {
	want := []time.Duration{
		1 * time.Minute,  // кӯшиши 0
		2 * time.Minute,  // 1
		4 * time.Minute,  // 2
		8 * time.Minute,  // 3
		16 * time.Minute, // 4
		32 * time.Minute, // 5
	}
	for i, w := range want {
		if got := PayoutBackoff(i); got != w {
			t.Errorf("кӯшиши %d: интизор %v, гирифтем %v", i, w, got)
		}
	}
	// Аз ҳад боло — ҳамон 32 дақиқа, на афзоиши беохир.
	for _, n := range []int{6, 10, 100} {
		if got := PayoutBackoff(n); got != 32*time.Minute {
			t.Errorf("кӯшиши %d: интизори 32m, гирифтем %v", n, got)
		}
	}
	// Вуруди манфӣ набояд таъхири манфӣ диҳад.
	if got := PayoutBackoff(-5); got <= 0 {
		t.Errorf("таъхири манфӣ: %v", got)
	}
}
