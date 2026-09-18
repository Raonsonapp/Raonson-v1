package handlers

import "testing"

// Суроғаи суруд аз телефон меояд ва ба телефони ҲАР тамошобин
// мерасад. Агар ҳар суроға иҷозат мешуд, як корбар метавонист
// сервери худро ҳамчун «суруд» гузорад ва телефони ҳар кас онро
// худаш фаро мегирифт.
func TestSongURLAllowed(t *testing.T) {
	ok := []string{
		"", // бе садо иҷозат аст — танҳо ном навишта мешавад
		"https://audio-ssl.itunes.apple.com/itunes-assets/x/y.m4a",
		"https://is1-ssl.mzstatic.com/image/thumb/a/300x300bb.jpg",
	}
	for _, u := range ok {
		if !songURLAllowed(u) {
			t.Errorf("бояд иҷозат мебуд: %q", u)
		}
	}

	bad := []string{
		"http://audio-ssl.itunes.apple.com/x.m4a", // бе TLS
		"https://evil.com/track.mp3",
		"https://apple.com.evil.com/x.m4a", // суффикси қалбакӣ
		"https://192.168.1.1/x.m4a",        // шабакаи дохилӣ
		"https://localhost/x.m4a",
		"file:///etc/passwd",
		"://",
	}
	for _, u := range bad {
		if songURLAllowed(u) {
			t.Errorf("бояд рад мешуд: %q", u)
		}
	}
}

// `clean` бояд суроғаи бадро партояд, вале худи сурудро нигоҳ дорад:
// ном ва хонанда ҳанӯз навишта мешаванд, танҳо садо намебарояд.
func TestCleanDropsBadURLKeepsSong(t *testing.T) {
	s := songInfo{
		Title:   "  Суруди ман  ",
		Artist:  "Хонанда",
		URL:     "https://evil.com/x.mp3",
		ArtURL:  "https://evil.com/a.jpg",
		StartMs: 60000,
		EndMs:   75000,
		TrackMs: 210000,
	}
	if !s.clean() {
		t.Fatal("суруд бояд мемонд")
	}
	if s.URL != "" || s.ArtURL != "" {
		t.Errorf("суроғаи бегона намонад: %q %q", s.URL, s.ArtURL)
	}
	if s.Title != "Суруди ман" {
		t.Errorf("фосилаҳо бурида нашуданд: %q", s.Title)
	}
	if s.StartMs != 60000 || s.EndMs != 75000 {
		t.Errorf("порчаи дуруст тағйир ёфт: %d..%d", s.StartMs, s.EndMs)
	}
}

// Телефон ҳар рақамро фиристода метавонад. Тиреза бояд ҳамеша
// маъно дошта бошад — вагарна плеер абадан ҳалқа мезад ё ҳеҷ гоҳ
// намехонд.
func TestCleanClampsWindow(t *testing.T) {
	cases := []struct {
		name             string
		start, end       int
		wantStart, wantW int
	}{
		{"анҷом пеш аз оғоз", 5000, 1000, 5000, 15000},
		{"тирезаи сифр", 5000, 5000, 5000, 15000},
		{"аз ҳад дароз", 0, 600000, 0, 15000},
		// Ҷои нодуруст ислоҳ мешавад, вале дарозии хоста (14с) мемонад.
		{"оғози манфӣ", -9000, 5000, 0, 14000},
		{"дуруст", 30000, 45000, 30000, 15000},
		{"дурусти хурд", 1000, 6000, 1000, 5000},
	}
	for _, c := range cases {
		s := songInfo{Title: "т", StartMs: c.start, EndMs: c.end}
		s.clean()
		if s.StartMs != c.wantStart {
			t.Errorf("%s: оғоз %d, интизор %d", c.name, s.StartMs, c.wantStart)
		}
		if got := s.EndMs - s.StartMs; got != c.wantW {
			t.Errorf("%s: тиреза %d, интизор %d", c.name, got, c.wantW)
		}
	}
}

// Суруди бе ном чизе нест — набояд сабт шавад, вагарна тамошобин
// сатри музикаи холӣ мебинад.
func TestCleanRejectsNameless(t *testing.T) {
	s := songInfo{URL: "https://audio-ssl.itunes.apple.com/x.m4a"}
	if s.clean() {
		t.Error("суруди бе ном набояд қабул шавад")
	}
	if songJSON("", "", "", "https://audio-ssl.itunes.apple.com/x.m4a", 0, 0, 0) != nil {
		t.Error("songJSON бояд nil медод")
	}
}
