package calllog

import (
	"testing"
	"time"
)

var t0 = time.Date(2026, 10, 1, 12, 0, 0, 0, time.UTC)

func at(sec int) *time.Time {
	t := t0.Add(time.Duration(sec) * time.Second)
	return &t
}

func TestClassifyCompletedBothSides(t *testing.T) {
	r := Row{CallerID: "a", CalleeID: "b", StartedAt: t0,
		AnsweredAt: at(5), EndedAt: at(65), EndReason: ReasonCompleted}
	va := Classify(r, "a", t0.Add(time.Hour))
	vb := Classify(r, "b", t0.Add(time.Hour))
	if va.Direction != "outgoing" || vb.Direction != "incoming" {
		t.Fatalf("directions: %+v %+v", va, vb)
	}
	if va.Status != "completed" || vb.Status != "completed" {
		t.Fatalf("status: %+v %+v", va, vb)
	}
	if va.DurationSec != 60 || vb.DurationSec != 60 {
		t.Fatalf("duration counts from answer, not ring: %d", va.DurationSec)
	}
}

func TestClassifyCancelledIsMissedForCallee(t *testing.T) {
	r := Row{CallerID: "a", CalleeID: "b", StartedAt: t0,
		EndedAt: at(20), EndReason: ReasonCancelled}
	if v := Classify(r, "a", t0.Add(time.Hour)); v.Status != "cancelled" {
		t.Fatalf("caller sees cancelled, got %q", v.Status)
	}
	if v := Classify(r, "b", t0.Add(time.Hour)); v.Status != "missed" {
		t.Fatalf("callee sees missed, got %q", v.Status)
	}
}

func TestClassifyDeclined(t *testing.T) {
	r := Row{CallerID: "a", CalleeID: "b", StartedAt: t0,
		EndedAt: at(3), EndReason: ReasonDeclined}
	for _, me := range []string{"a", "b"} {
		if v := Classify(r, me, t0.Add(time.Hour)); v.Status != "declined" {
			t.Fatalf("%s: declined expected, got %q", me, v.Status)
		}
	}
}

func TestClassifyOpenRowTimesOut(t *testing.T) {
	r := Row{CallerID: "a", CalleeID: "b", StartedAt: t0}
	if v := Classify(r, "b", t0.Add(30*time.Second)); v.Status != "ringing" {
		t.Fatalf("fresh row is ringing, got %q", v.Status)
	}
	if v := Classify(r, "b", t0.Add(2*time.Minute)); v.Status != "missed" {
		t.Fatalf("stale unanswered row is missed for callee, got %q", v.Status)
	}
	if v := Classify(r, "a", t0.Add(2*time.Minute)); v.Status != "no_answer" {
		t.Fatalf("stale unanswered row is no_answer for caller, got %q", v.Status)
	}
}

func TestClassifyOngoingAndAbandoned(t *testing.T) {
	r := Row{CallerID: "a", CalleeID: "b", StartedAt: t0, AnsweredAt: at(2)}
	v := Classify(r, "a", t0.Add(62*time.Second))
	if v.Status != "ongoing" || v.DurationSec != 60 {
		t.Fatalf("ongoing: %+v", v)
	}
	v = Classify(r, "a", t0.Add(7*time.Hour))
	if v.Status != "completed" || v.DurationSec != 0 {
		t.Fatalf("abandoned answered row → completed, unknown duration: %+v", v)
	}
}

func TestClassifyNoAnswerReason(t *testing.T) {
	r := Row{CallerID: "a", CalleeID: "b", StartedAt: t0, EndedAt: at(60), EndReason: ReasonNoAnswer}
	if v := Classify(r, "a", t0.Add(time.Hour)); v.Status != "no_answer" {
		t.Fatalf("got %q", v.Status)
	}
	if v := Classify(r, "b", t0.Add(time.Hour)); v.Status != "missed" {
		t.Fatalf("got %q", v.Status)
	}
}

func TestCursorRoundTrip(t *testing.T) {
	c := Cursor{At: t0.Add(123456789 * time.Nanosecond), ID: "abc-1"}
	got, err := DecodeCursor(c.Encode())
	if err != nil || got == nil || !got.At.Equal(c.At) || got.ID != c.ID {
		t.Fatalf("round trip: %+v %v", got, err)
	}
	if got, err := DecodeCursor(""); got != nil || err != nil {
		t.Fatalf("empty cursor = first page")
	}
	for _, bad := range []string{"%%%", "bm9waXBl", "MjAyNnx4"} {
		if _, err := DecodeCursor(bad); err == nil {
			t.Fatalf("bad cursor %q accepted", bad)
		}
	}
}

func TestClampLimit(t *testing.T) {
	cases := map[int]int{0: 30, -5: 30, 10: 10, 50: 50, 500: 50}
	for in, want := range cases {
		if got := ClampLimit(in); got != want {
			t.Fatalf("ClampLimit(%d)=%d want %d", in, got, want)
		}
	}
}
