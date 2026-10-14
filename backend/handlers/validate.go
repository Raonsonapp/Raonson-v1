package handlers

// maxDMRunes — ҳадди матни паёми шахсӣ (фиристодан ва таҳрир).
const maxDMRunes = 4000

// clampRunes — матнро то ҳадди аксари рунаҳо мебурад.
// Бо []rune кор мекунад (на bytes), то ҳарфҳои кириллӣ ва эмоҷӣ дуруст
// ҳисоб шаванд ва матн дар миёни рамзи бисёрбайтӣ бурида нашавад.
func clampRunes(s string, max int) string {
	if max < 0 {
		max = 0
	}
	r := []rune(s)
	if len(r) > max {
		return string(r[:max])
	}
	return s
}
