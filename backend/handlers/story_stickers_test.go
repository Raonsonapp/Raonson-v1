package handlers

import (
	"testing"
	"time"
)

func TestValidateSticker(t *testing.T) {
	now := time.Now()
	future := now.Add(48 * time.Hour).Format(time.RFC3339)
	past := now.Add(-time.Hour).Format(time.RFC3339)
	ok := []stickerInput{
		{Kind: "question"},
		{Kind: "quiz", Prompt: "Пойтахт?", Options: []string{"Душанбе", "Хуҷанд"}, Correct: 0},
		{Kind: "quiz", Prompt: "?", Options: []string{"a", "b", "c", "d"}, Correct: 3},
		{Kind: "slider", Prompt: "Чӣ қадар?"},
		{Kind: "countdown", Prompt: "Зодрӯз", EndsAt: future},
	}
	for _, in := range ok {
		if _, err := validateSticker(in, now); err != nil {
			t.Errorf("%+v бояд қабул шавад: %v", in, err)
		}
	}
	bad := []stickerInput{
		{Kind: "nest"},
		{Kind: "quiz", Prompt: "?", Options: []string{"танҳо як"}, Correct: 0},
		{Kind: "quiz", Prompt: "?", Options: []string{"a", "b", "c", "d", "e"}, Correct: 0},
		{Kind: "quiz", Prompt: "?", Options: []string{"a", "b"}, Correct: 2},  // берун
		{Kind: "quiz", Prompt: "?", Options: []string{"a", "b"}, Correct: -1},
		{Kind: "quiz", Options: []string{"a", "b"}, Correct: 0},              // бе савол
		{Kind: "quiz", Prompt: "?", Options: []string{"a", "  "}, Correct: 0}, // холӣ
		{Kind: "countdown", Prompt: "x", EndsAt: past},
		{Kind: "countdown", Prompt: "x", EndsAt: "не-сана"},
		{Kind: "countdown", EndsAt: future},
	}
	for _, in := range bad {
		if _, err := validateSticker(in, now); err == nil {
			t.Errorf("%+v бояд рад шавад", in)
		}
	}
}

func TestStickerPositionClamped(t *testing.T) {
	s, _ := validateSticker(stickerInput{Kind: "question", X: 5, Y: -3}, time.Now())
	if s.X < 0 || s.X > 1 || s.Y < 0 || s.Y > 1 {
		t.Errorf("ҷойгиршавӣ берун аз экран: %v,%v", s.X, s.Y)
	}
}

func TestValidateAddYours(t *testing.T) {
	now := time.Now()
	if _, err := validateSticker(stickerInput{Kind: "addyours"}, now); err == nil {
		t.Fatal("addyours without prompt and joinOf must fail")
	}
	s, err := validateSticker(stickerInput{Kind: "addyours", Prompt: "Акси аввал"}, now)
	if err != nil || s.Prompt != "Акси аввал" {
		t.Fatalf("new chain: %v %+v", err, s)
	}
	s, err = validateSticker(stickerInput{Kind: "addyours", JoinOf: "story-1"}, now)
	if err != nil || s.JoinOf != "story-1" {
		t.Fatalf("join: %v %+v", err, s)
	}
}

// Стикери «📍 Ҷой»: ном ҳатмист; id-и рӯйхат нигоҳ дошта мешавад, id-и
// бегона партофта мешавад (ҷойи дастӣ), номи айнан мувофиқ худ пайваст.
func TestValidateLocationSticker(t *testing.T) {
	now := time.Now()
	if _, err := validateSticker(stickerInput{Kind: "location"}, now); err == nil {
		t.Error("стикери ҷой бе ном қабул шуд")
	}
	s, err := validateSticker(stickerInput{Kind: "location", Prompt: "Хуҷанд", URL: "tj-khujand"}, now)
	if err != nil || s.URL != "tj-khujand" {
		t.Errorf("ҷойи рӯйхат: %+v %v", s, err)
	}
	s, err = validateSticker(stickerInput{Kind: "location", Prompt: "Боғи мо", URL: "javascript:x"}, now)
	if err != nil || s.URL != "" {
		t.Errorf("id-и бегона бояд партофта шавад: %+v %v", s, err)
	}
	s, err = validateSticker(stickerInput{Kind: "location", Prompt: "Душанбе"}, now)
	if err != nil || s.URL != "tj-dushanbe" {
		t.Errorf("номи айнан мувофиқ пайваст намешавад: %+v %v", s, err)
	}
}
