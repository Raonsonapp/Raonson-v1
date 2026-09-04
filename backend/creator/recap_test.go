package creator

import (
	"testing"
	"time"
)

// Оғози ҳафта хатои классикӣ дорад: дар Go якшанбе рӯзи 0 аст,
// бинобар ин якшанбе ба ҳафтаи ОЯНДА афтода метавонад.
func TestWeekStartIsMonday(t *testing.T) {
	cases := map[string]string{
		// Душанбе — худи ҳамон рӯз.
		"2026-08-31T00:00:00Z": "2026-08-31",
		"2026-08-31T23:59:59Z": "2026-08-31",
		// Чоршанбе.
		"2026-09-02T12:00:00Z": "2026-08-31",
		// Якшанбе — ҳанӯз ҳамон ҳафта, на ҳафтаи оянда.
		"2026-09-06T23:00:00Z": "2026-08-31",
		// Душанбеи оянда — ҳафтаи нав.
		"2026-09-07T00:00:01Z": "2026-09-07",
	}
	for in, want := range cases {
		ts, err := time.Parse(time.RFC3339, in)
		if err != nil {
			t.Fatal(err)
		}
		got := WeekStart(ts)
		if got.Format("2006-01-02") != want {
			t.Errorf("%s → %s, интизори %s", in, got.Format("2006-01-02"), want)
		}
		if got.Weekday() != time.Monday {
			t.Errorf("%s: рӯзи %v, интизори душанбе", in, got.Weekday())
		}
		if h, m, s := got.Clock(); h|m|s != 0 {
			t.Errorf("%s: вақт %02d:%02d:%02d, интизори нимишаб", in, h, m, s)
		}
	}
}

// Минтақаи вақт набояд ҳафтаро тағйир диҳад: вагарна ду корбар
// ҷамъбасти ҳамон ҳафтаро бо калидҳои гуногун кэш мекарданд.
func TestWeekStartIgnoresLocalZone(t *testing.T) {
	utc := time.Date(2026, 9, 2, 12, 0, 0, 0, time.UTC)
	east := utc.In(time.FixedZone("UTC+5", 5*3600))
	west := utc.In(time.FixedZone("UTC-8", -8*3600))
	want := WeekStart(utc)
	for _, ts := range []time.Time{east, west} {
		if got := WeekStart(ts); !got.Equal(want) {
			t.Errorf("%v → %v, интизори %v", ts, got, want)
		}
	}
	if want.Location() != time.UTC {
		t.Errorf("натиҷа бояд UTC бошад, на %v", want.Location())
	}
}

// Ҳафта дақиқ ҳафт рӯз аст — ҳудуди ҷамъбаст ба ҳамин такя мекунад.
func TestWeekStartsAreSevenDaysApart(t *testing.T) {
	ts := time.Date(2026, 1, 1, 9, 30, 0, 0, time.UTC)
	for i := 0; i < 60; i++ {
		a := WeekStart(ts)
		b := WeekStart(ts.AddDate(0, 0, 7))
		if d := b.Sub(a); d != 7*24*time.Hour {
			t.Fatalf("%v: фарқи ҳафтаҳо %v", ts, d)
		}
		ts = ts.AddDate(0, 0, 6)
	}
}
