package handlers

import (
	"testing"
	"time"
)

// Instagram: паём танҳо дар 15 дақиқаи аввал таҳрир мешавад.
func TestCanEditMessageWindow(t *testing.T) {
	now := time.Now()
	if !canEditMessage(now.Add(-time.Minute), now) {
		t.Error("паёми 1-дақиқаина таҳрир намешавад")
	}
	if !canEditMessage(now.Add(-15*time.Minute), now) {
		t.Error("дақиқаи 15-ум ҳанӯз бояд иҷозат дошта бошад")
	}
	if canEditMessage(now.Add(-16*time.Minute), now) {
		t.Error("паёми 16-дақиқаина таҳрир шуд — равзана кор намекунад")
	}
}
