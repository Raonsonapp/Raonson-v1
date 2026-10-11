package handlers

// «Овоз» — пости овозӣ то 60 сония.
//
// Пост ҳамон пости оддӣ аст (лайк, шарҳ, захира, модератсияи тавсиф),
// танҳо медиаи ягонааш `type: "audio"` аст: суроға аз ҳамон /upload,
// давомнокӣ, шакли мавҷ (то 64 нуқта, 0..100) ва муқоваи ихтиёрӣ.
// Худи садо ба classifier-и расм фиристода намешавад; муқова — ҳа.

import (
	"strconv"
	"strings"
)

// voiceMaxMs — ҳадди пости овозӣ.
const voiceMaxMs = 60000

// voiceWaveformMax — шумораи нуқтаҳои мавҷ.
const voiceWaveformMax = 64

// voiceMedia — медиаи тозашудаи пости овозӣ.
type voiceMedia struct {
	URL        string
	DurationMs int
	Waveform   string // "12,40,…" (0..100)
	Cover      string
}

func httpURL(s string) bool {
	return strings.HasPrefix(s, "https://") || strings.HasPrefix(s, "http://")
}

func numOf(v interface{}) (float64, bool) {
	switch n := v.(type) {
	case float64:
		return n, true
	case int:
		return float64(n), true
	case string:
		f, err := strconv.ParseFloat(n, 64)
		return f, err == nil
	}
	return 0, false
}

// parseVoiceMedia — оё пост овозӣ аст ва медиаи он дуруст аст.
//
// isVoice=false — ягон `audio` нест (пости оддӣ). msg != "" — хато.
func parseVoiceMedia(media []map[string]interface{}) (vm voiceMedia, isVoice bool, msg string) {
	for _, m := range media {
		if t, _ := m["type"].(string); t == "audio" {
			isVoice = true
		}
	}
	if !isVoice {
		return vm, false, ""
	}
	if len(media) != 1 {
		return vm, true, "Пости овозӣ танҳо як файли садо дорад"
	}
	m := media[0]
	vm.URL, _ = m["url"].(string)
	vm.URL = strings.TrimSpace(vm.URL)
	if !httpURL(vm.URL) {
		return vm, true, "Суроғаи садо нодуруст"
	}
	d, _ := numOf(m["durationMs"])
	if d < 1000 {
		return vm, true, "Овоз хеле кӯтоҳ аст"
	}
	// Сабткунак метавонад чанд сад мс зиёдтар гузорад.
	if d > voiceMaxMs+1500 {
		return vm, true, "Овоз то 60 сония"
	}
	if d > voiceMaxMs {
		d = voiceMaxMs
	}
	vm.DurationMs = int(d)
	vm.Waveform = normalizeWaveform(m["waveform"])
	if cv, _ := m["cover"].(string); httpURL(strings.TrimSpace(cv)) {
		vm.Cover = strings.TrimSpace(cv)
	}
	return vm, true, ""
}

// normalizeWaveform — рӯйхати рақамҳо → то 64 нуқтаи 0..100 ("" агар нест).
func normalizeWaveform(v interface{}) string {
	list, _ := v.([]interface{})
	vals := make([]float64, 0, len(list))
	for _, x := range list {
		if f, ok := numOf(x); ok {
			vals = append(vals, f)
		}
	}
	if len(vals) == 0 {
		return ""
	}
	// Агар нуқтаҳо зиёданд — гурӯҳбандӣ ва ҳадди ҳар гурӯҳ.
	if len(vals) > voiceWaveformMax {
		out := make([]float64, voiceWaveformMax)
		for i := range out {
			from := i * len(vals) / voiceWaveformMax
			to := (i + 1) * len(vals) / voiceWaveformMax
			for _, f := range vals[from:to] {
				if f > out[i] {
					out[i] = f
				}
			}
		}
		vals = out
	}
	parts := make([]string, len(vals))
	for i, f := range vals {
		if f < 0 {
			f = 0
		}
		if f > 100 {
			f = 100
		}
		parts[i] = strconv.Itoa(int(f + 0.5))
	}
	return strings.Join(parts, ",")
}
