package handlers

import (
	"net/url"
	"strings"
)

// ── Музикаи пост ва стори ────────────────────────────────────────
//
// Як сохтор барои ҳарду. Пеш пост танҳо `music_title` ва
// `music_artist` дошт ва стори ҳеҷ чиз — «🎵 ном» ба матни стори
// андохта мешуд ва хонанда бо суроға гум мешуд.

type songInfo struct {
	Title   string `json:"title"`
	Artist  string `json:"artist"`
	ArtURL  string `json:"artUrl"`
	URL     string `json:"previewUrl"`
	TrackMs int    `json:"trackMs"`
	StartMs int    `json:"startMs"`
	EndMs   int    `json:"endMs"`
}

// Ҳудудҳо. Телефон ҳар чиро фиристода метавонад, пас ҳамаро ин ҷо
// мебуррем — на дар телефон.
const (
	maxSongTextRunes = 120
	maxSongMs        = 20 * 60 * 1000 // 20 дақиқа
	minWindowMs      = 1000
	maxWindowMs      = 60 * 1000
)

// Суроғаҳое, ки телефон бояд фаро гирад.
//
// ⚠️ Ин рӯйхат ҳимоя аст, на ороиш. Бе он ҳар корбар метавонист
// ҳамчун «суруд» ҳар суроғаро гузорад ва телефони ҲАР тамошобин
// онро худаш фаро мегирифт — SSRF аз тарафи мизоҷ, санҷиши ҳузур
// ва трафики бегона. iTunes ягона манбаи ҷустуҷӯи мост.
var songHosts = []string{
	".apple.com",
	".mzstatic.com",
}

func songURLAllowed(raw string) bool {
	if raw == "" {
		return true // музика бе садо иҷозат аст — танҳо ном навишта мешавад
	}
	u, err := url.Parse(raw)
	if err != nil || u.Scheme != "https" || u.Host == "" {
		return false
	}
	host := strings.ToLower(u.Hostname())
	for _, suf := range songHosts {
		if strings.HasSuffix(host, suf) {
			return true
		}
	}
	return false
}

// clean сохторро ба ҳудудҳои бехатар меорад ва мегӯяд, ки оё чизе
// барои нигоҳ доштан мондааст.
func (s *songInfo) clean() bool {
	s.Title = clampRunes(strings.TrimSpace(s.Title), maxSongTextRunes)
	s.Artist = clampRunes(strings.TrimSpace(s.Artist), maxSongTextRunes)
	s.URL = strings.TrimSpace(s.URL)
	s.ArtURL = strings.TrimSpace(s.ArtURL)

	// Суроғаи номӯътамад партофта мешавад, вале худи суруд не —
	// ном ва хонанда ҳанӯз навишта мешаванд.
	if !songURLAllowed(s.URL) {
		s.URL = ""
	}
	if !songURLAllowed(s.ArtURL) {
		s.ArtURL = ""
	}

	if s.TrackMs < 0 || s.TrackMs > maxSongMs {
		s.TrackMs = 0
	}

	// Дарозии порча ПЕШ аз ислоҳи оғоз ҳисоб мешавад.
	//
	// Вагарна оғози манфӣ дарозиро низ вайрон мекард: (-9с, 5с)
	// порчаи 14-сония аст, вале баъди сифр кардани оғоз он ба
	// 5 сония табдил меёфт. Ҷои нодуруст ислоҳ мешавад, дарозии
	// хостаи муаллиф нигоҳ дошта мешавад.
	win := s.EndMs - s.StartMs
	if win < minWindowMs || win > maxWindowMs {
		win = 15000
	}

	if s.StartMs < 0 || s.StartMs > maxSongMs {
		s.StartMs = 0
	}
	s.EndMs = s.StartMs + win

	return s.Title != "" || s.Artist != ""
}

// Аз сатрҳои база сохтори JSON месозад. Агар ном набошад, `nil`
// бармегардад — то мизоҷ «сатри музикаи холӣ» насозад.
func songJSON(title, artist, artURL, songURL string, trackMs, startMs, endMs int) map[string]any {
	if title == "" && artist == "" {
		return nil
	}
	return map[string]any{
		"title":      title,
		"artist":     artist,
		"artUrl":     artURL,
		"previewUrl": songURL,
		"trackMs":    trackMs,
		"startMs":    startMs,
		"endMs":      endMs,
	}
}
