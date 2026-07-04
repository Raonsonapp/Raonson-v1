package handlers

import (
	"context"
	"encoding/xml"
	"html"
	"net/http"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// Ахбор — аз RSS-и манбаъҳои боэътимод (ройгон, бе API key).
type newsItem struct {
	Title       string `json:"title"`
	Link        string `json:"link"`
	Description string `json:"description"`
	Image       string `json:"image"`
	Source      string `json:"source"`
	PubDate     string `json:"pubDate"`
	IsoDate     string `json:"isoDate"` // ISO-8601 барои «вақт пеш»-и frontend
	Region      string `json:"region"`  // "tj" | "cis" | "world"
	Lang        string `json:"lang"`    // "tj" | "ru" | "en"
	ts          time.Time
}

type newsSource struct {
	name, url, region, lang string
}

// Манбаъҳо — бо вазни зиёд ба Тоҷикистон.
var newsSources = []newsSource{
	// Тоҷикистон (region "tj") — бояд бартарӣ дошта бошад.
	{"Asia-Plus", "https://asiaplustj.info/ru/rss.xml", "tj", "ru"},
	{"Радио Озоди", "https://www.ozodi.org/api/zrqiteuuir", "tj", "tj"},
	{"Радио Озоди RU", "https://rus.ozodi.org/api/z-pqp_eu-r", "tj", "ru"},
	{"Sputnik Тоҷикистон", "https://tj.sputniknews.ru/export/rss2/archive/index.xml", "tj", "ru"},
	{"Khovar", "https://khovar.tj/feed/", "tj", "tj"},
	{"Avesta", "https://avesta.tj/feed/", "tj", "ru"},

	// СНГ / CIS (region "cis") — дуюмдараҷа.
	{"РИА Новости", "https://ria.ru/export/rss2/archive/index.xml", "cis", "ru"},
	{"Sputnik", "https://sputniknews.ru/export/rss2/archive/index.xml", "cis", "ru"},
	{"Lenta", "https://lenta.ru/rss", "cis", "ru"},
	{"Gazeta", "https://www.gazeta.ru/export/rss/lenta.xml", "cis", "ru"},

	// Ҷаҳон (region "world").
	{"BBC", "https://feeds.bbci.co.uk/russian/rss.xml", "world", "ru"},
	{"BBC World", "https://feeds.bbci.co.uk/news/world/rss.xml", "world", "en"},
	{"Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml", "world", "en"},
}

const (
	newsCacheTTL = 5 * time.Minute
	newsMaxItems = 120
)

var (
	newsCache     []newsItem
	newsCacheTime time.Time
	newsMu        sync.Mutex
	htmlTagRe     = regexp.MustCompile(`<[^>]*>`)
)

func cleanHTML(s string) string {
	s = htmlTagRe.ReplaceAllString(s, "")
	s = html.UnescapeString(s)
	return strings.TrimSpace(s)
}

// regionRank — тартиб: tj аввал, баъд cis, баъд world.
func regionRank(region string) int {
	switch region {
	case "tj":
		return 0
	case "cis":
		return 1
	default:
		return 2
	}
}

// GET /news — рӯйхати ахбор (cache 5 дақиқа).
// Параметрҳо: ?page=<n>&limit=<m>&lang=tj|ru|en|all
func GetNews(c *gin.Context) {
	newsMu.Lock()
	fresh := len(newsCache) > 0 && time.Since(newsCacheTime) < newsCacheTTL
	cached := newsCache
	newsMu.Unlock()

	items := cached
	if !fresh {
		fetched := fetchAllNews()
		if len(fetched) > 0 {
			newsMu.Lock()
			newsCache = fetched
			newsCacheTime = time.Now()
			newsMu.Unlock()
			items = fetched
		}
		// Агар шабака нашуд — кэши кӯҳна (items = cached) боқӣ мемонад.
	}

	respondNews(c, items)
}

// respondNews — филтри забон + pagination аз рӯйхати тартибдодашуда.
func respondNews(c *gin.Context, items []newsItem) {
	// Филтри забон (пеш аз pagination).
	lang := strings.ToLower(strings.TrimSpace(c.Query("lang")))
	if lang == "" {
		lang = "all"
	}
	if lang != "all" {
		filtered := make([]newsItem, 0, len(items))
		for _, it := range items {
			if it.Lang == lang {
				filtered = append(filtered, it)
			}
		}
		items = filtered
	}

	page := parsePositiveInt(c.Query("page"), 1)
	limit := parsePositiveInt(c.Query("limit"), 20)

	total := len(items)
	start := (page - 1) * limit
	end := start + limit
	if start > total {
		start = total
	}
	if end > total {
		end = total
	}

	pageItems := items[start:end]
	if pageItems == nil {
		pageItems = []newsItem{}
	}

	c.JSON(http.StatusOK, gin.H{
		"news":    pageItems,
		"page":    page,
		"hasMore": page*limit < total,
	})
}

func parsePositiveInt(s string, def int) int {
	if s == "" {
		return def
	}
	n, err := strconv.Atoi(s)
	if err != nil || n < 1 {
		return def
	}
	return n
}

func fetchAllNews() []newsItem {
	client := &http.Client{Timeout: 8 * time.Second}
	out := []newsItem{}
	for _, s := range newsSources {
		req, err := http.NewRequestWithContext(
			context.Background(), http.MethodGet, s.url, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "RaonsonNews/1.0")
		resp, err := client.Do(req)
		if err != nil {
			continue
		}

		var feed struct {
			Items []struct {
				Title       string `xml:"title"`
				Link        string `xml:"link"`
				Description string `xml:"description"`
				PubDate     string `xml:"pubDate"`
				Enclosure   struct {
					URL string `xml:"url,attr"`
				} `xml:"enclosure"`
				Thumbnail struct {
					URL string `xml:"url,attr"`
				} `xml:"thumbnail"`
			} `xml:"channel>item"`
		}
		dec := xml.NewDecoder(resp.Body)
		dec.Strict = false
		_ = dec.Decode(&feed)
		resp.Body.Close()

		for _, it := range feed.Items {
			img := it.Enclosure.URL
			if img == "" {
				img = it.Thumbnail.URL
			}
			t, _ := time.Parse(time.RFC1123Z, it.PubDate)
			if t.IsZero() {
				t, _ = time.Parse(time.RFC1123, it.PubDate)
			}
			iso := ""
			if !t.IsZero() {
				iso = t.UTC().Format(time.RFC3339)
			}
			out = append(out, newsItem{
				Title:       strings.TrimSpace(it.Title),
				Link:        strings.TrimSpace(it.Link),
				Description: cleanHTML(it.Description),
				Image:       img,
				Source:      s.name,
				PubDate:     it.PubDate,
				IsoDate:     iso,
				Region:      s.region,
				Lang:        s.lang,
				ts:          t,
			})
		}
	}
	// Тартиб: аввал минтақа (tj < cis < world), баъд навтарин дар дохили минтақа.
	sort.SliceStable(out, func(i, j int) bool {
		ri, rj := regionRank(out[i].Region), regionRank(out[j].Region)
		if ri != rj {
			return ri < rj
		}
		return out[i].ts.After(out[j].ts)
	})
	if len(out) > newsMaxItems {
		out = out[:newsMaxItems]
	}
	return out
}
