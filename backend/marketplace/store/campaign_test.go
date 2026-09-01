package store

import (
	"errors"
	"testing"
	"time"
)

// Тестҳои тозаи validation — ба DB эҳтиёҷ надоранд.
//
// Ҳама маҳдудият дар сервер аст: client метавонад ҳар JSON фиристад,
// бинобар ин ин ҷо санҷида мешавад, ки вуруди нодуруст рад мешавад.
func TestCampaignInputValidate(t *testing.T) {
	base := func() CampaignInput {
		return CampaignInput{
			Title:        "Реклама",
			BudgetMinor:  50000,
			Currency:     "TJS",
			CreatorCount: 5,
			TargetAgeMin: 18,
			TargetAgeMax: 45,
		}
	}
	now := time.Now()
	earlier := now.Add(-24 * time.Hour)

	cases := []struct {
		name    string
		mutate  func(*CampaignInput)
		wantErr bool
	}{
		{"дуруст", func(*CampaignInput) {}, false},
		{"сарлавҳаи холӣ", func(in *CampaignInput) { in.Title = "   " }, true},
		{"сарлавҳаи хеле дароз", func(in *CampaignInput) {
			in.Title = string(make([]rune, 201))
		}, true},
		{"буҷети сифр", func(in *CampaignInput) { in.BudgetMinor = 0 }, true},
		{"буҷети манфӣ", func(in *CampaignInput) { in.BudgetMinor = -1 }, true},
		{"асъори номаълум", func(in *CampaignInput) { in.Currency = "XYZ" }, true},
		{"асъори холӣ", func(in *CampaignInput) { in.Currency = "" }, true},
		{"сифр эҷодкор", func(in *CampaignInput) { in.CreatorCount = 0 }, true},
		{"аз ҳад зиёд эҷодкор", func(in *CampaignInput) { in.CreatorCount = 101 }, true},
		{"синну соли манфӣ", func(in *CampaignInput) { in.TargetAgeMin = -1 }, true},
		{"синну соли ғайривоқеӣ", func(in *CampaignInput) { in.TargetAgeMax = 200 }, true},
		{"мин > макс", func(in *CampaignInput) { in.TargetAgeMin = 50; in.TargetAgeMax = 20 }, true},
		{"анҷом пеш аз оғоз", func(in *CampaignInput) { in.StartAt = &now; in.EndAt = &earlier }, true},
		{"буҷет барои эҷодкорон кам", func(in *CampaignInput) {
			in.BudgetMinor = 3
			in.CreatorCount = 10
		}, true},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			in := base()
			tc.mutate(&in)
			err := in.Validate()
			if tc.wantErr && err == nil {
				t.Fatal("интизори хато будем, вале nil гирифтем")
			}
			if !tc.wantErr && err != nil {
				t.Fatalf("хатои ғайричашмдошт: %v", err)
			}
			if tc.wantErr && err != nil && !errors.Is(err, ErrInvalidCampaign) {
				t.Fatalf("хато бояд ErrInvalidCampaign бошад, гирифтем %v", err)
			}
		})
	}
}
