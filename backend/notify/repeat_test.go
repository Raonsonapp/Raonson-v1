package notify

import (
	"testing"
	"time"
)

// Ҳар паём ва ҳар шарҳ — ҳодисаи нав. Пеш калиди дедупликатсия абадӣ
// буд ва танҳо паёми АВВАЛИ ҳар чат ба телефон мерасид.
func TestEveryMessageIsANewEvent(t *testing.T) {
	now := time.Now()
	for _, k := range []Kind{Message, Comment, Reply, StoryReply} {
		a := dedupeKey(Event{UserID: "u", ActorID: "a", Kind: k, TargetID: "c",
			DedupeSuffix: RepeatSuffix(k, now)})
		b := dedupeKey(Event{UserID: "u", ActorID: "a", Kind: k, TargetID: "c",
			DedupeSuffix: RepeatSuffix(k, now.Add(time.Millisecond))})
		if a == b {
			t.Errorf("%s: ду ҳодиса як калид гирифтанд", k)
		}
	}
}

// Обуна → бекор → обуна дар як соат — як push; баъдтар — боз push.
// Ин шикояти «касе обуна шуд ва хабар наомад» буд.
func TestRefollowNotifiesAgainLater(t *testing.T) {
	t0 := time.Date(2026, 1, 1, 10, 5, 0, 0, time.UTC)
	same := RepeatSuffix(Follow, t0.Add(20*time.Minute))
	if RepeatSuffix(Follow, t0) != same {
		t.Error("дар як соат обунаи такрорӣ бояд як push бошад")
	}
	if RepeatSuffix(Follow, t0) == RepeatSuffix(Follow, t0.Add(2*time.Hour)) {
		t.Error("обунаи дубора баъди соатҳо бояд боз хабар диҳад")
	}
}

// Лайк — як бор абадӣ: лайк/бекор/лайк телефонро такрор наларзонад.
func TestLikeStaysDedupedForever(t *testing.T) {
	if RepeatSuffix(Like, time.Now()) != "" || RepeatSuffix(ReelLike, time.Now()) != "" {
		t.Error("лайк бояд як бор бошад")
	}
}

func TestNewKindsHaveTextAndLinks(t *testing.T) {
	for _, k := range []Kind{CommentLike, ReelCommentLike, ReelCommentReply,
		ContactJoined, Thanks} {
		if !Known(k) {
			t.Errorf("%s дар ҷадвали қоидаҳо нест", k)
		}
		if _, body := Text(k, TJ, "ali", 0); body == "" {
			t.Errorf("%s матн надорад", k)
		}
		if Link(k, "obj1", "ali") == "" {
			t.Errorf("%s линк надорад", k)
		}
	}
	if Link(ReelCommentLike, "r1", "ali") != "/reel/r1" {
		t.Error("лайки шарҳи Reel бояд ба Reel барад")
	}
	if Link(ContactJoined, "x", "ali") != "/profile/ali" {
		t.Error("ҳамроҳшавии мухотиб бояд профилро кушояд")
	}
}

// Селоби лайк обунаро хомӯш намекунад: ҳадди соатӣ барои ҳар гурӯҳ.
func TestLikeFloodDoesNotSilenceFollows(t *testing.T) {
	c := memCounter{}
	now := time.Date(2026, 1, 1, 10, 0, 0, 0, time.UTC)
	for i := 0; i < MaxPushPerHour+5; i++ {
		budgetLeft(c, "u:"+budgetBucket(Like), now)
	}
	if budgetLeft(c, "u:"+budgetBucket(Like), now) {
		t.Fatal("лайкҳо бояд маҳдуд шаванд")
	}
	if !budgetLeft(c, "u:"+budgetBucket(Follow), now) {
		t.Error("обуна набояд аз ҳадди лайк вобаста бошад")
	}
	if budgetBucket(Follow) == budgetBucket(Like) {
		t.Error("гурӯҳҳо бояд ҷудо бошанд")
	}
}
