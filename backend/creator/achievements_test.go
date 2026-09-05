package creator

import "testing"

// Зина набояд аз ЯК рақами калон дода шавад: як видеои тасодуфан
// вирусӣ эҷодкорро ба зинаи 4 намебарорад.
func TestLevelNeedsEveryCondition(t *testing.T) {
	// Биниши бузург, вале бе обуначӣ ва бе мӯҳтаво.
	one := LevelFor(CreatorStats{Views: 1000000})
	if one.Level != 1 {
		t.Errorf("танҳо биниш зинаи %d дод, интизори 1", one.Level)
	}
	// Обуначии зиёд, вале мӯҳтаво кам.
	two := LevelFor(CreatorStats{Followers: 5000, Views: 50000, Posts: 2})
	if two.Level != 1 {
		t.Errorf("бе мӯҳтаво зинаи %d, интизори 1", two.Level)
	}
}

func TestLevelRises(t *testing.T) {
	cases := []struct {
		s    CreatorStats
		want int
	}{
		{CreatorStats{}, 1},
		{CreatorStats{Followers: 10, Views: 100, Posts: 3}, 2},
		{CreatorStats{Followers: 100, Views: 1000, Posts: 5, Reels: 5}, 3},
		{CreatorStats{Followers: 1000, Views: 10000, Posts: 30}, 4},
		{CreatorStats{Followers: 10000, Views: 100000, Reels: 100}, 5},
	}
	for _, c := range cases {
		if got := LevelFor(c.s).Level; got != c.want {
			t.Errorf("%+v → зинаи %d, интизори %d", c.s, got, c.want)
		}
	}
}

// Эҷодкор бояд бидонад, ки то зинаи оянда чӣ лозим аст.
func TestNextTargetIsTheFirstUnmetStep(t *testing.T) {
	l := LevelFor(CreatorStats{Followers: 10, Views: 100, Posts: 3})
	if l.Next == nil {
		t.Fatal("ҳадафи оянда набояд холӣ бошад")
	}
	if l.Next.Level != 3 {
		t.Errorf("ҳадафи зинаи %d, интизори 3", l.Next.Level)
	}
	if l.Next.Followers != 100 || l.Next.Views != 1000 || l.Next.Content != 10 {
		t.Errorf("шартҳои нодуруст: %+v", *l.Next)
	}
}

func TestTopLevelHasNoNext(t *testing.T) {
	l := LevelFor(CreatorStats{Followers: 99999, Views: 9999999, Reels: 999})
	if l.Next != nil {
		t.Errorf("зинаи охирин набояд ҳадаф дошта бошад: %+v", *l.Next)
	}
}

// Мӯҳтаво ҷамъи пост ва рилс аст — на танҳо яке аз онҳо.
func TestContentCountsPostsAndReelsTogether(t *testing.T) {
	if got := LevelFor(CreatorStats{Followers: 10, Views: 100, Posts: 2, Reels: 1}).Level; got != 2 {
		t.Errorf("2 пост + 1 рилс зинаи %d дод, интизори 2", got)
	}
}

// Ҳар нишон шарти мусбат дорад: нишони «бе шарт» ҳамеша дода мешуд.
func TestEveryAchievementNeedsRealWork(t *testing.T) {
	seen := map[string]bool{}
	for _, a := range achievements {
		if a.need <= 0 {
			t.Errorf("нишони %q бе шарт аст", a.Code)
		}
		if a.value(CreatorStats{}) >= a.need {
			t.Errorf("нишони %q ба аккаунти холӣ дода мешавад", a.Code)
		}
		if seen[a.Code] {
			t.Errorf("рамзи такрорӣ: %q", a.Code)
		}
		seen[a.Code] = true
	}
}
