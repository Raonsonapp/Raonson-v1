package features

import (
	"testing"
	"time"
)

var t0 = time.Date(2026, 10, 11, 12, 0, 0, 0, time.UTC)

// ── Даъватнома ──────────────────────────────────────────────────────

func TestValidateEvent(t *testing.T) {
	end := t0.Add(26 * time.Hour)
	if err := ValidateEvent(t0, "Тӯйи Алӣ", t0.Add(24*time.Hour), &end); err != nil {
		t.Fatalf("дуруст рад шуд: %v", err)
	}
	if ValidateEvent(t0, "x", t0.Add(time.Hour), nil) != ErrTitle {
		t.Error("номи кӯтоҳ қабул шуд")
	}
	if ValidateEvent(t0, "Вохӯрӣ", t0.Add(-time.Hour), nil) != ErrStartPast {
		t.Error("гузашта қабул шуд")
	}
	if ValidateEvent(t0, "Вохӯрӣ", t0.Add(-2*time.Minute), nil) != nil {
		t.Error("фурсати 5 дақиқа кор намекунад")
	}
	if ValidateEvent(t0, "Вохӯрӣ", t0.Add(3*365*24*time.Hour), nil) != ErrStartFar {
		t.Error("аз ҳад дур қабул шуд")
	}
	bad := t0.Add(time.Hour)
	if ValidateEvent(t0, "Вохӯрӣ", t0.Add(2*time.Hour), &bad) != ErrEnd {
		t.Error("анҷом пеш аз оғоз қабул шуд")
	}
}

func TestRSVPAndPlus(t *testing.T) {
	for _, s := range []string{RSVPGoing, RSVPMaybe, RSVPDeclined} {
		if !ValidRSVP(s) {
			t.Errorf("%s бояд дуруст бошад", s)
		}
	}
	if ValidRSVP(RSVPPending) || ValidRSVP("yes") {
		t.Error("ҷавоби нодуруст қабул шуд")
	}
	if ClampPlus(RSVPDeclined, 3, 5) != 0 {
		t.Error("«Намеоям» бо меҳмон")
	}
	if ClampPlus(RSVPGoing, 9, 5) != 5 || ClampPlus(RSVPGoing, -1, 5) != 0 {
		t.Error("ҳадди меҳмон")
	}
	if ClampPlus(RSVPGoing, 50, 99) != EventMaxPlus {
		t.Error("ҳадди умумии меҳмон")
	}
	if NormalizeEventKind(" Wedding ") != "wedding" || NormalizeEventKind("rave") != "other" {
		t.Error("намуди чорабинӣ")
	}
}

func TestDueReminder(t *testing.T) {
	created := t0.Add(-10 * 24 * time.Hour)
	start := t0.Add(30 * time.Hour)
	if r := DueReminder(t0, created, start, false, false); r != "" {
		t.Errorf("30 соат пеш: %q", r)
	}
	if r := DueReminder(start.Add(-23*time.Hour), created, start, false, false); r != ReminderDay {
		t.Errorf("23 соат пеш: %q", r)
	}
	if r := DueReminder(start.Add(-23*time.Hour), created, start, true, false); r != "" {
		t.Errorf("такрори «1 рӯз»: %q", r)
	}
	if r := DueReminder(start.Add(-90*time.Minute), created, start, true, false); r != Reminder2h {
		t.Errorf("90 дақ пеш: %q", r)
	}
	// «1 рӯз» фаромӯш шуд (сервер хомӯш буд) — танҳо «2 соат», на ҳарду.
	if r := DueReminder(start.Add(-time.Hour), created, start, false, false); r != Reminder2h {
		t.Errorf("танҳо 2 соат: %q", r)
	}
	if r := DueReminder(start.Add(-time.Hour), created, start, true, true); r != "" {
		t.Errorf("такрори «2 соат»: %q", r)
	}
	if r := DueReminder(start.Add(time.Minute), created, start, false, false); r != "" {
		t.Errorf("баъди оғоз: %q", r)
	}
	// Дар 10 соат пеш сохта шуд: «1 рӯз» не, «2 соат» ҳа.
	late := start.Add(-10 * time.Hour)
	if r := DueReminder(start.Add(-9*time.Hour), late, start, false, false); r != "" {
		t.Errorf("чорабинии нав «1 рӯз» гирифт: %q", r)
	}
	if r := DueReminder(start.Add(-time.Hour), late, start, false, false); r != Reminder2h {
		t.Errorf("чорабинии нав «2 соат» нагирифт: %q", r)
	}
	// Дар 1 соат пеш сохта шуд: ҳеҷ ёдрасӣ.
	if r := DueReminder(start.Add(-30*time.Minute), start.Add(-time.Hour), start, false, false); r != "" {
		t.Errorf("чорабинии фаврӣ ёдрасӣ гирифт: %q", r)
	}
}

func TestAlbum(t *testing.T) {
	if AlbumOpen(t0, t0.Add(time.Minute)) || !AlbumOpen(t0, t0) {
		t.Error("албом пеш аз оғоз")
	}
	if !CanUploadToAlbum(true, RSVPPending) || !CanUploadToAlbum(false, RSVPGoing) ||
		CanUploadToAlbum(false, RSVPMaybe) || CanUploadToAlbum(false, RSVPDeclined) {
		t.Error("кӣ ба албом мегузорад")
	}
}

// ── Пурсиш ──────────────────────────────────────────────────────────

func TestNormalizePoll(t *testing.T) {
	ends := t0.Add(24 * time.Hour)
	one := 1
	p, err := NormalizePoll(PollInput{Question: "  Кадом?  ",
		Options: []string{" Ҳа ", "Не"}, Correct: &one, EndsAt: &ends}, t0)
	if err != nil || p.Question != "Кадом?" || p.Options[0] != "Ҳа" || *p.Correct != 1 {
		t.Fatalf("дуруст рад шуд: %v %+v", err, p)
	}
	cases := map[error]PollInput{
		ErrPollOptions: {Options: []string{"a"}},
		ErrPollOption:  {Options: []string{"a", " "}},
		ErrPollDup:     {Options: []string{"Ҳа", "ҳа"}},
	}
	for want, in := range cases {
		if _, err := NormalizePoll(in, t0); err != want {
			t.Errorf("%v: %v", want, err)
		}
	}
	if _, err := NormalizePoll(PollInput{Options: []string{"a", "b", "c", "d", "e"}}, t0); err != ErrPollOptions {
		t.Error("5 ҷавоб қабул шуд")
	}
	bad := 2
	if _, err := NormalizePoll(PollInput{Options: []string{"a", "b"}, Correct: &bad}, t0); err != ErrPollCorrect {
		t.Error("ҷавоби дурусти берун аз ҳад")
	}
	soon := t0.Add(time.Minute)
	if _, err := NormalizePoll(PollInput{Options: []string{"a", "b"}, EndsAt: &soon}, t0); err != ErrPollEnds {
		t.Error("анҷоми хеле наздик")
	}
}

func TestPollPercentsSumTo100(t *testing.T) {
	for _, c := range [][]int{{1, 1, 1}, {2, 1}, {0, 0}, {7, 3, 0, 1}, {1}} {
		p := PollPercents(c)
		sum := 0
		total := 0
		for i := range p {
			sum += p[i]
			total += c[i]
		}
		if total > 0 && sum != 100 {
			t.Errorf("%v → %v (ҷамъ %d)", c, p, sum)
		}
		if total == 0 && sum != 0 {
			t.Errorf("бе овоз фоиз: %v", p)
		}
	}
	if p := PollPercents([]int{2, 1}); p[0] != 67 || p[1] != 33 {
		t.Errorf("2:1 → %v", p)
	}
}

func TestPollVisibility(t *testing.T) {
	if PollResultsVisible(false, false, false) {
		t.Error("натиҷа пеш аз овоз")
	}
	if !PollResultsVisible(true, false, false) || !PollResultsVisible(false, true, false) ||
		!PollResultsVisible(false, false, true) {
		t.Error("натиҷа пинҳон монд")
	}
	e := t0
	if !PollEnded(t0, &e) || PollEnded(t0, nil) {
		t.Error("анҷоми пурсиш")
	}
}

// ── Савол ба ман ────────────────────────────────────────────────────

func TestQA(t *testing.T) {
	if m, ok := NormalizeQAMode(""); !ok || m != QAFollowers {
		t.Error("пешфарз — обуначиён")
	}
	if _, ok := NormalizeQAMode("all"); ok {
		t.Error("танзими нодуруст")
	}
	if !CanAsk(QAEveryone, false) || CanAsk(QAFollowers, false) || !CanAsk(QAFollowers, true) || CanAsk(QAOff, true) {
		t.Error("CanAsk")
	}
	if AskerVisible(true, false, false) {
		t.Error("беном ба тамошобин/соҳиб ном нишон дод")
	}
	if !AskerVisible(true, false, true) {
		t.Error("модератор бояд савoлдиҳандаро бинад")
	}
	if !AskerVisible(true, true, false) || !AskerVisible(false, false, false) {
		t.Error("AskerVisible")
	}
	if _, err := ValidateQuestion("ҳа"); err != ErrQuestionLen {
		t.Error("саволи кӯтоҳ")
	}
	if q, err := ValidateQuestion("  Чӣ хел?  "); err != nil || q != "Чӣ хел?" {
		t.Error("тоза кардани савол")
	}
	if _, err := ValidateAnswer(" "); err != ErrAnswerLen {
		t.Error("ҷавоби холӣ")
	}
}

// ── Мактуб ба оянда ─────────────────────────────────────────────────

func TestCapsule(t *testing.T) {
	week := t0.Add(7 * 24 * time.Hour)
	if err := ValidateCapsule(t0, "Салом, ман аз гузашта", "", 0, week, time.Hour); err != nil {
		t.Fatalf("дуруст рад шуд: %v", err)
	}
	if ValidateCapsule(t0, " ", "", 0, week, time.Hour) != ErrCapsuleEmpty {
		t.Error("холӣ")
	}
	if ValidateCapsule(t0, "x", "", 0, t0.Add(10*time.Minute), time.Hour) != ErrCapsuleSoon {
		t.Error("хеле наздик")
	}
	if ValidateCapsule(t0, "x", "", 5, week, time.Hour) != ErrCapsuleMedia {
		t.Error("медиаи зиёд")
	}
	if ValidateCapsule(t0, "x", "", 0, t0.Add(11*365*24*time.Hour), time.Hour) != ErrCapsuleFar {
		t.Error("аз ҳад дур")
	}
	if a, ok := NormalizeAudience("Friend"); !ok || a != CapsuleFriend {
		t.Error("audience")
	}
	if _, ok := NormalizeAudience("world"); ok {
		t.Error("audience-и нодуруст")
	}
	if !CapsuleAudienceAllows("a", "a", CapsuleSelf, "", false) ||
		CapsuleAudienceAllows("b", "a", CapsuleSelf, "", true) {
		t.Error("барои худ")
	}
	if !CapsuleAudienceAllows("b", "a", CapsuleFriend, "b", false) ||
		CapsuleAudienceAllows("c", "a", CapsuleFriend, "b", true) {
		t.Error("барои дӯст")
	}
	if !CapsuleAudienceAllows("c", "a", CapsuleFollowers, "", true) ||
		CapsuleAudienceAllows("c", "a", CapsuleFollowers, "", false) {
		t.Error("барои обуначиён")
	}
	if CapsuleContentVisible(t0, week, true) {
		t.Error("мӯҳр пеш аз вақт кушода шуд (ҳатто ба муаллиф набояд)")
	}
	if !CapsuleContentVisible(week, week, true) || CapsuleContentVisible(week, week, false) {
		t.Error("кушодан")
	}
}

// ── Чаленҷ ──────────────────────────────────────────────────────────

func TestValidateChallenge(t *testing.T) {
	if err := ValidateChallenge(t0, "Рақси миллӣ", "", t0, t0.Add(7*24*time.Hour)); err != nil {
		t.Fatalf("дуруст рад шуд: %v", err)
	}
	if ValidateChallenge(t0, "ab", "", t0, t0.Add(time.Hour)) != ErrChallengeTitle {
		t.Error("номи кӯтоҳ")
	}
	if ValidateChallenge(t0, "Рақс", "", t0, t0.Add(61*24*time.Hour)) != ErrChallengeWindow {
		t.Error("дароз")
	}
	if ValidateChallenge(t0, "Рақс", "", t0.Add(-2*time.Hour), t0.Add(time.Hour)) != ErrChallengeWindow {
		t.Error("гузашта")
	}
	if ChallengeStatus(t0, t0.Add(time.Hour), t0.Add(2*time.Hour)) != "upcoming" ||
		ChallengeStatus(t0, t0, t0.Add(time.Hour)) != "active" ||
		ChallengeStatus(t0, t0.Add(-2*time.Hour), t0) != "ended" {
		t.Error("ҳолат")
	}
}

func TestLeaderboardOneEntryPerUserAndTies(t *testing.T) {
	es := []Entry{
		{UserID: "a", Kind: "post", ID: "a1", CreatedAt: t0, Likers: 3},
		{UserID: "a", Kind: "reel", ID: "a2", CreatedAt: t0.Add(time.Minute), Likers: 1, Commenters: 2},
		{UserID: "a", Kind: "post", ID: "a3", CreatedAt: t0, Likers: 1},
		{UserID: "b", Kind: "post", ID: "b1", CreatedAt: t0.Add(-time.Minute), Likers: 5},
		{UserID: "c", Kind: "post", ID: "c1", CreatedAt: t0.Add(time.Hour), Likers: 5},
		{UserID: "", Kind: "post", ID: "x", Likers: 99},
	}
	lb := Leaderboard(es, 0)
	if len(lb) != 3 {
		t.Fatalf("ҳар корбар як бор: %+v", lb)
	}
	// Ҳама 5 хол: барвақттар боло (b 11:59, a 12:01, c 13:00).
	if lb[0].UserID != "b" || lb[1].UserID != "a" || lb[2].UserID != "c" {
		t.Errorf("тартиб: %+v", lb)
	}
	if lb[1].ID != "a2" || lb[1].Score != 5 {
		t.Errorf("беҳтарин иштироки a: %+v", lb[1])
	}
	if lb[0].Rank != 1 || lb[2].Rank != 3 {
		t.Error("рақами ҷой")
	}
	if l := Leaderboard(es, 1); len(l) != 1 || l[0].UserID != "b" {
		t.Error("limit")
	}
	if (Entry{Likers: -3, Commenters: -1}).Score() != 0 {
		t.Error("хол манфӣ")
	}
}
