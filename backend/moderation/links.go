package moderation

import (
	"bufio"
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"regexp"
	"strings"
	"sync"
	"time"
)

//go:embed data/adult_domains.txt
var adultDomainsData string

var (
	domainsOnce sync.Once
	domainSet   map[string]bool
)

func adultDomains() map[string]bool {
	domainsOnce.Do(func() {
		domainSet = map[string]bool{}
		sc := bufio.NewScanner(strings.NewReader(adultDomainsData))
		for sc.Scan() {
			l := strings.ToLower(strings.TrimSpace(sc.Text()))
			if l == "" || strings.HasPrefix(l, "#") {
				continue
			}
			domainSet[strings.TrimPrefix(l, "www.")] = true
		}
	})
	return domainSet
}

// Линк дар матн: бо нақша, бо www., ё домени луч («pornhub.com/x»).
var urlRe = regexp.MustCompile(`(?i)(?:https?://|www\.)[^\s<>"'«»]+|\b[a-z0-9][a-z0-9-]{0,62}(?:\.[a-z0-9][a-z0-9-]{0,62})*\.[a-z]{2,24}\b(?:/[^\s<>"'«»]*)?`)

// «pornhub dot com», «pornhub[.]com», «pornhub (.) com» → «pornhub.com».
var dotRe = regexp.MustCompile(`(?i)\s*(?:\[\.\]|\(\.\)|\{\.\}|\[dot\]|\(dot\)|\s+dot\s+|\s+точка\s+|\s+нуқта\s+)\s*`)

// ExtractURLs — линкҳои матн (ҳеҷ кадом кушода НАМЕШАВАД).
func ExtractURLs(text string) []string {
	if text == "" {
		return nil
	}
	t := dotRe.ReplaceAllString(text, ".")
	found := urlRe.FindAllString(t, 50)
	out := make([]string, 0, len(found))
	seen := map[string]bool{}
	for _, f := range found {
		f = strings.TrimRight(f, ".,;:!?)]}")
		if f == "" || seen[f] {
			continue
		}
		// «@user.name» — зикр, на линк.
		seen[f] = true
		out = append(out, f)
	}
	return out
}

// hostOf — номи хост бе порт, бе «www.», бо ҳарфи хурд.
func hostOf(raw string) string {
	s := strings.TrimSpace(raw)
	if !strings.Contains(s, "://") {
		s = "http://" + s
	}
	u, err := url.Parse(s)
	if err != nil {
		return ""
	}
	h := strings.ToLower(strings.TrimSuffix(u.Hostname(), "."))
	h = strings.TrimPrefix(h, "www.")
	// IP-и луч — домен нест.
	if net.ParseIP(h) != nil {
		return ""
	}
	return h
}

// Калимаҳои қавӣ дар номи домен → BLOCK.
var strongDomainWords = []string{
	"porn", "xvideo", "xnxx", "xhamster", "hentai", "sexcam", "sextube",
	"sexchat", "sexvideo", "xxxvideo", "brazzers", "redtube", "youporn",
	"chaturbate", "stripchat", "bongacam", "onlyfans",
}

// Калимаҳои суст → REVIEW (шояд бегуноҳ бошад).
var weakDomainWords = []string{"sexy", "nsfw", "erotic", "nudes", "escort", "fansly"}

var adultTLDs = map[string]bool{"xxx": true, "porn": true, "sex": true, "adult": true, "sexy": true}

// CheckDomain — қарор барои як хост.
func CheckDomain(host string) Verdict {
	host = strings.TrimPrefix(strings.ToLower(strings.TrimSuffix(host, ".")), "www.")
	if host == "" {
		return Verdict{Action: Allow}
	}
	block := func(reason string) Verdict {
		return Verdict{Action: Block, Categories: []string{CatAdultLink, CatSexual},
			Score: 1, Provider: "links", Reason: reason}
	}
	// Рӯйхат: худи домен ё ягон домени волид.
	set := adultDomains()
	parts := strings.Split(host, ".")
	for i := 0; i < len(parts)-1; i++ {
		if set[strings.Join(parts[i:], ".")] {
			return block("blocklist:" + strings.Join(parts[i:], "."))
		}
	}
	if tld := parts[len(parts)-1]; adultTLDs[tld] {
		return block("tld:." + tld)
	}
	// Номи домен бе TLD. Калимаҳо дар қисмҳо ва дар байни «-».
	labels := strings.Join(parts[:len(parts)-1], ".")
	for _, w := range strongDomainWords {
		if strings.Contains(labels, w) {
			return block("domain-word:" + w)
		}
	}
	// «xxx» ва «sex» танҳо ҳамчун қисми ҷудо: «xxx-videos», «sex.example»
	// — вале «essex.ac.uk», «sextant.io», «maxxxi» не.
	for _, lbl := range parts[:len(parts)-1] {
		for _, piece := range strings.Split(lbl, "-") {
			if piece == "xxx" || piece == "porno" {
				return block("domain-word:" + piece)
			}
			if piece == "sex" {
				return Verdict{Action: Review, Categories: []string{CatAdultLink},
					Score: 0.6, Provider: "links", Reason: "domain-word:sex"}
			}
		}
	}
	for _, w := range weakDomainWords {
		if strings.Contains(labels, w) {
			return Verdict{Action: Review, Categories: []string{CatAdultLink},
				Score: 0.6, Provider: "links", Reason: "domain-word:" + w}
		}
	}
	return Verdict{Action: Allow}
}

// CheckLinkURL — як линк: рӯйхат + эвристика + (ихтиёрӣ) Safe Browsing.
func CheckLinkURL(ctx context.Context, raw string) Verdict {
	h := hostOf(raw)
	v := CheckDomain(h)
	if v.Action == Block || h == "" {
		return v
	}
	return Merge(v, safeBrowsing(ctx, []string{raw}))
}

// CheckLinksInText — ҳамаи линкҳои матн.
func CheckLinksInText(ctx context.Context, text string) Verdict {
	urls := ExtractURLs(text)
	if len(urls) == 0 {
		return Verdict{Action: Allow}
	}
	v := Verdict{Action: Allow}
	for _, u := range urls {
		v = Merge(v, CheckDomain(hostOf(u)))
		if v.Action == Block {
			return v
		}
	}
	return Merge(v, safeBrowsing(ctx, urls))
}

// ── Google Safe Browsing (ихтиёрӣ) ─────────────────────────────────
//
// Танҳо СУРОҒА ба Google фиристода мешавад; сервери мо саҳифаро
// намекушояд. Safe Browsing категорияи «18+» НАДОРАД — он сайтҳои
// вирус ва фиребро (phishing) мегирад. Порнографияро рӯйхати боло
// мегирад.

var sbClient = &http.Client{Timeout: 4 * time.Second}

func safeBrowsingURL() string {
	if u := strings.TrimSpace(os.Getenv("MODERATION_SAFE_BROWSING_URL")); u != "" {
		return u
	}
	return "https://safebrowsing.googleapis.com/v4/threatMatches:find"
}

func safeBrowsing(ctx context.Context, urls []string) Verdict {
	key := strings.TrimSpace(os.Getenv("SAFE_BROWSING_KEY"))
	if key == "" || len(urls) == 0 {
		return Verdict{Action: Allow}
	}
	entries := []map[string]string{}
	for _, u := range urls {
		if !strings.Contains(u, "://") {
			u = "http://" + u
		}
		entries = append(entries, map[string]string{"url": u})
		if len(entries) >= 20 {
			break
		}
	}
	body, _ := json.Marshal(map[string]any{
		"client": map[string]string{"clientId": "raonson", "clientVersion": "1.0"},
		"threatInfo": map[string]any{
			"threatTypes": []string{"MALWARE", "SOCIAL_ENGINEERING",
				"UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION"},
			"platformTypes":    []string{"ANY_PLATFORM"},
			"threatEntryTypes": []string{"URL"},
			"threatEntries":    entries,
		},
	})
	cctx, cancel := timeoutCtx(ctx, 4*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(cctx, http.MethodPost,
		safeBrowsingURL()+"?key="+url.QueryEscape(key), bytes.NewReader(body))
	if err != nil {
		return Verdict{Action: Allow}
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := sbClient.Do(req)
	if err != nil {
		log.Printf("[moderation] Safe Browsing дастнорас: %v — танҳо рӯйхати доменҳо", redactErr(err))
		return Verdict{Action: Allow}
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if resp.StatusCode != http.StatusOK {
		log.Printf("[moderation] Safe Browsing HTTP %d", resp.StatusCode)
		return Verdict{Action: Allow}
	}
	var out struct {
		Matches []struct {
			ThreatType string `json:"threatType"`
		} `json:"matches"`
	}
	if json.Unmarshal(data, &out) != nil || len(out.Matches) == 0 {
		return Verdict{Action: Allow}
	}
	return Verdict{Action: Block, Categories: []string{CatMalicious}, Score: 1,
		Provider: "safebrowsing", Reason: strings.ToLower(out.Matches[0].ThreatType)}
}

// redactErr — хатои шабака бе калид (URL-и дархост калидро дорад).
func redactErr(err error) string {
	s := err.Error()
	if i := strings.Index(s, "key="); i >= 0 {
		j := strings.IndexAny(s[i:], "\" &")
		if j < 0 {
			return s[:i] + "key=***"
		}
		return s[:i] + "key=***" + s[i+j:]
	}
	return s
}
