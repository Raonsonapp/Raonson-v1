package handlers

import (
	"context"
	"encoding/xml"
	"html"
	"net/http"
	"regexp"
	"sort"
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
	ts          time.Time
}

type newsSource struct{ name, url string }

var newsSources = []newsSource{
	{"BBC", "https://feeds.bbci.co.uk/russian/rss.xml"},
	{"BBC World", "http://feeds.bbci.co.uk/news/world/rss.xml"},
	{"Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml"},
}

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

// GET /news — рӯйхати ахбор (cache 10 дақиқа).
func GetNews(c *gin.Context) {
	newsMu.Lock()
	fresh := len(newsCache) > 0 && time.Since(newsCacheTime) < 10*time.Minute
	cached := newsCache
	newsMu.Unlock()

	if fresh {
		c.JSON(http.StatusOK, gin.H{"news": cached})
		return
	}

	items := fetchAllNews()
	if len(items) == 0 {
		// Шабака нашуд — кэши кӯҳнаро бармегардонем (агар бошад).
		c.JSON(http.StatusOK, gin.H{"news": cached})
		return
	}

	newsMu.Lock()
	newsCache = items
	newsCacheTime = time.Now()
	newsMu.Unlock()
	c.JSON(http.StatusOK, gin.H{"news": items})
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
			out = append(out, newsItem{
				Title:       strings.TrimSpace(it.Title),
				Link:        strings.TrimSpace(it.Link),
				Description: cleanHTML(it.Description),
				Image:       img,
				Source:      s.name,
				PubDate:     it.PubDate,
				ts:          t,
			})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ts.After(out[j].ts) })
	if len(out) > 60 {
		out = out[:60]
	}
	return out
}
