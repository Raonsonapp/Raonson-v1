package handlers

import (
	"testing"
	"time"
)

func prefs(enabled bool, start, end, off int) notifPrefs {
	var p notifPrefs
	p.QuietHours.Enabled = enabled
	p.QuietHours.StartHour = &start
	p.QuietHours.EndHour = &end
	p.QuietHours.TZOffsetMinutes = &off
	return p
}

func at(hourUTC int) time.Time {
	return time.Date(2026, 9, 5, hourUTC, 30, 0, 0, time.UTC)
}

// Хатари асосии ин код — хомӯшии НОДУРУСТ. Бе хости возеҳи корбар
// ҳеҷ огоҳинома хомӯш намешавад.
func TestQuietHoursOffByDefault(t *testing.T) {
	var empty notifPrefs
	for h := 0; h < 24; h++ {
		if inQuietHours(empty, at(h)) {
			t.Fatalf("бе танзимот соати %d ором ҳисоб шуд", h)
		}
	}
	// Танзим ҳаст, вале хомӯш аст.
	off := prefs(false, 23, 8, 0)
	if inQuietHours(off, at(2)) {
		t.Error("танзими хомӯш набояд кор кунад")
	}
}

// Бе минтақаи вақт вақти маҳаллӣ маълум нест — тахмин намезанем.
func TestQuietHoursNeedTimezone(t *testing.T) {
	var p notifPrefs
	p.QuietHours.Enabled = true
	s, e := 23, 8
	p.QuietHours.StartHour = &s
	p.QuietHours.EndHour = &e
	if inQuietHours(p, at(2)) {
		t.Error("бе фарқи вақт набояд ором ҳисоб шавад")
	}
}

// Давраи шабона аз нимишаб мегузарад — ҳолати маъмултарин.
func TestQuietHoursCrossMidnight(t *testing.T) {
	p := prefs(true, 23, 8, 0) // UTC
	quiet := []int{23, 0, 3, 7}
	loud := []int{8, 12, 18, 22}
	for _, h := range quiet {
		if !inQuietHours(p, at(h)) {
			t.Errorf("соати %d бояд ором бошад", h)
		}
	}
	for _, h := range loud {
		if inQuietHours(p, at(h)) {
			t.Errorf("соати %d набояд ором бошад", h)
		}
	}
}

// Давраи оддии рӯзона низ кор мекунад.
func TestQuietHoursSameDay(t *testing.T) {
	p := prefs(true, 9, 17, 0)
	if !inQuietHours(p, at(12)) {
		t.Error("соати 12 бояд дар давраи 9–17 бошад")
	}
	if inQuietHours(p, at(20)) {
		t.Error("соати 20 берун аз давра аст")
	}
}

// Минтақаи вақт воқеан татбиқ мешавад: Душанбе UTC+5.
func TestQuietHoursUsesLocalTime(t *testing.T) {
	p := prefs(true, 23, 8, 300) // +5 соат
	// 19:30 UTC = 00:30 маҳаллӣ → ором.
	if !inQuietHours(p, at(19)) {
		t.Error("нимишаби маҳаллӣ бояд ором бошад")
	}
	// 05:30 UTC = 10:30 маҳаллӣ → не.
	if inQuietHours(p, at(5)) {
		t.Error("субҳи маҳаллӣ набояд ором бошад")
	}
}

// Арзиши бемаънӣ набояд корбарро хомӯш кунад.
func TestQuietHoursIgnoresNonsense(t *testing.T) {
	cases := []notifPrefs{
		prefs(true, -1, 8, 0),
		prefs(true, 23, 99, 0),
		prefs(true, 8, 8, 0), // давраи сифр
		prefs(true, 23, 8, 100000),
	}
	for i, p := range cases {
		for h := 0; h < 24; h++ {
			if inQuietHours(p, at(h)) {
				t.Fatalf("ҳолати %d: соати %d бе асос ором шуд", i, h)
			}
		}
	}
}

// Хабарҳои фаврӣ ҳеҷ гоҳ маҳдуд намешаванд.
func TestUrgentTypesBypassEverything(t *testing.T) {
	for ntype := range urgentTypes {
		if !allowPush("nobody-"+ntype, ntype, at(3)) {
			t.Errorf("навъи фаврии %q маҳдуд шуд", ntype)
		}
	}
}

// Буҷет соатро маҳдуд мекунад, вале дар соати нав аз нав кушода мешавад.
func TestPushBudgetResetsEachHour(t *testing.T) {
	user := "budget-user"
	now := at(10)
	for i := 0; i < maxPushPerHour; i++ {
		if !pushBudgetLeft(user, now) {
			t.Fatalf("push-и %d рад шуд, ҳадди иҷозат %d", i+1, maxPushPerHour)
		}
	}
	if pushBudgetLeft(user, now) {
		t.Error("аз ҳад зиёд иҷозат дода шуд")
	}
	if !pushBudgetLeft(user, at(11)) {
		t.Error("соати нав бояд буҷети нав диҳад")
	}
}

// Буҷет барои ҳар корбар ҷудост.
func TestPushBudgetIsPerUser(t *testing.T) {
	now := at(14)
	for i := 0; i < maxPushPerHour; i++ {
		pushBudgetLeft("noisy", now)
	}
	if !pushBudgetLeft("quiet", now) {
		t.Error("корбари дигар набояд аз ҳисоби каси дигар маҳрум шавад")
	}
}
