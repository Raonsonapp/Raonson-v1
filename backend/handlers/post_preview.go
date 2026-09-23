package handlers

// Саҳифаи пешнамоиши мӯҳтаво.
//
// ⚠️ Чаро ин муҳим аст:
//
// Ҳангоми мубодила ба WhatsApp, Telegram ё ҳар барномаи дигар
// НАХУСТ ҲАМИН саҳифа хонда мешавад. Барнома мӯҳтаворо намефиристад
// — он линкро мефиристад ва гиранда он чиро мебинад, ки дар ин ҷо
// дар тегҳои OpenGraph навишта шудааст.
//
// Пештар:
//   • линки мубодила умуман ба ин ҷо ишора намекард (ба саҳифаи
//     статикии GitHub Pages мерафт, ки ҳеҷ тег надошт) — гиранда
//     танҳо сатри урёнро медид;
//   • барои видео og:image ба худи файли mp4 ишора мекард — ҳеҷ
//     мессенҷер mp4-ро ҳамчун расм нишон дода наметавонад.
//
// Акнун:
//   • видео og:video + og:image (thumbnail) мегирад;
//   • Twitter card навъи «player» мешавад — видео дар худи чат
//     пахш мешавад;
//   • рилс низ саҳифаи худро дорад.

import (
	"context"
	"fmt"
	"html"
	"net/http"
	"strings"

	"raonson/db"

	"github.com/gin-gonic/gin"
)

// previewData — он чи саҳифа нишон медиҳад.
type previewData struct {
	Kind      string // post | reel
	ID        string
	Caption   string
	Username  string
	Avatar    string
	MediaURL  string
	MediaType string // image | video
	Thumbnail string
	Likes     int
	Comments  int
}

// GET /p/:id — пешнамоиши пост.
func PostPreview(c *gin.Context) {
	d, ok := loadPostPreview(c.Request.Context(), c.Param("id"))
	if !ok {
		c.Data(http.StatusNotFound, ctHTML, notFoundHTML())
		return
	}
	c.Header("Cache-Control", "public, max-age=300")
	c.Data(http.StatusOK, ctHTML, renderPreview(d))
}

// GET /r/:id — пешнамоиши рилс.
func ReelPreview(c *gin.Context) {
	d, ok := loadReelPreview(c.Request.Context(), c.Param("id"))
	if !ok {
		c.Data(http.StatusNotFound, ctHTML, notFoundHTML())
		return
	}
	c.Header("Cache-Control", "public, max-age=300")
	c.Data(http.StatusOK, ctHTML, renderPreview(d))
}

const ctHTML = "text/html; charset=utf-8"

func loadPostPreview(ctx context.Context, id string) (previewData, bool) {
	d := previewData{Kind: "post", ID: id}
	err := db.Pool.QueryRow(ctx, `
		SELECT COALESCE(p.caption,''), u.username, COALESCE(u.avatar,''),
		       COALESCE(m.url,''), COALESCE(m.type,'image'),
		       COALESCE(p.likes_count,0), COALESCE(p.comments_count,0)
		FROM posts p
		JOIN users u ON u.id = p.user_id
		LEFT JOIN post_media m ON m.post_id=p.id AND m.position=0
		WHERE p.id=$1 AND COALESCE(p.archived,false)=FALSE
		  -- Ин саҳифа БЕ ВУРУД кушода мешавад. Пеш расм ва матни
		  -- пости ҳисоби ПӮШИДА ба ҳар касе, ки линк дошт, дода мешуд.
		  AND COALESCE(p.hidden,false)=FALSE
		  AND COALESCE(u.is_private,false)=FALSE
		  AND COALESCE(u.banned,false)=FALSE`, id).
		Scan(&d.Caption, &d.Username, &d.Avatar, &d.MediaURL, &d.MediaType,
			&d.Likes, &d.Comments)
	if err != nil {
		return d, false
	}
	return d, true
}

func loadReelPreview(ctx context.Context, id string) (previewData, bool) {
	d := previewData{Kind: "reel", ID: id, MediaType: "video"}
	err := db.Pool.QueryRow(ctx, `
		SELECT COALESCE(r.caption,''), u.username, COALESCE(u.avatar,''),
		       COALESCE(r.video_url,''), COALESCE(r.thumbnail_url,''),
		       COALESCE(r.likes_count,0), COALESCE(r.comments_count,0)
		FROM reels r
		JOIN users u ON u.id = r.user_id
		WHERE r.id=$1
		  AND COALESCE(u.is_private,false)=FALSE
		  AND COALESCE(u.banned,false)=FALSE
		  AND COALESCE(r.media_missing,false)=FALSE`, id).
		Scan(&d.Caption, &d.Username, &d.Avatar, &d.MediaURL, &d.Thumbnail,
			&d.Likes, &d.Comments)
	if err != nil {
		return d, false
	}
	return d, true
}

// esc — ҳар арзиши аз БД пеш аз HTML escape мешавад.
func esc(s string) string { return html.EscapeString(s) }

// truncate — тавсифи дароз дар пешнамоиш буриш мешавад.
func truncate(s string, n int) string {
	s = strings.TrimSpace(strings.ReplaceAll(s, "\n", " "))
	if len(s) <= n {
		return s
	}
	r := []rune(s)
	if len(r) <= n {
		return s
	}
	return strings.TrimSpace(string(r[:n])) + "…"
}

// renderPreview саҳифаро месозад.
func renderPreview(d previewData) []byte {
	isVideo := d.MediaType == "video" && d.MediaURL != ""

	// og:image бояд РАСМ бошад. Барои видео ин thumbnail аст —
	// мессенҷер mp4-ро ҳамчун расм хонда наметавонад.
	ogImage := d.Thumbnail
	if ogImage == "" && !isVideo {
		ogImage = d.MediaURL
	}

	title := d.Username
	if title == "" {
		title = "Raonson"
	}
	desc := truncate(d.Caption, 160)
	if desc == "" {
		if isVideo {
			desc = "Видео дар Raonson"
		} else {
			desc = "Акс дар Raonson"
		}
	}

	var meta strings.Builder
	w := func(f string, a ...any) { fmt.Fprintf(&meta, f+"\n", a...) }

	w(`<meta property="og:site_name" content="Raonson"/>`)
	w(`<meta property="og:title" content="%s"/>`, esc(title))
	w(`<meta property="og:description" content="%s"/>`, esc(desc))
	if ogImage != "" {
		w(`<meta property="og:image" content="%s"/>`, esc(ogImage))
		w(`<meta property="og:image:width" content="1080"/>`)
		w(`<meta property="og:image:height" content="1080"/>`)
	}

	if isVideo {
		// Ҳамин чор тег кор мекунанд, ки видео дар чат ПАХШ шавад,
		// на ҳамчун линки урён монад.
		w(`<meta property="og:type" content="video.other"/>`)
		w(`<meta property="og:video" content="%s"/>`, esc(d.MediaURL))
		w(`<meta property="og:video:secure_url" content="%s"/>`, esc(d.MediaURL))
		w(`<meta property="og:video:type" content="video/mp4"/>`)
		w(`<meta property="og:video:width" content="720"/>`)
		w(`<meta property="og:video:height" content="1280"/>`)
		w(`<meta name="twitter:card" content="player"/>`)
		w(`<meta name="twitter:player:stream" content="%s"/>`, esc(d.MediaURL))
		w(`<meta name="twitter:player:stream:content_type" content="video/mp4"/>`)
	} else {
		w(`<meta property="og:type" content="article"/>`)
		w(`<meta name="twitter:card" content="summary_large_image"/>`)
	}
	w(`<meta name="twitter:title" content="%s"/>`, esc(title))
	w(`<meta name="twitter:description" content="%s"/>`, esc(desc))
	if ogImage != "" {
		w(`<meta name="twitter:image" content="%s"/>`, esc(ogImage))
	}

	// Медиаи худи саҳифа.
	var mediaTag string
	switch {
	case isVideo:
		poster := ""
		if d.Thumbnail != "" {
			poster = fmt.Sprintf(` poster="%s"`, esc(d.Thumbnail))
		}
		mediaTag = fmt.Sprintf(
			`<video src="%s"%s controls playsinline preload="metadata"></video>`,
			esc(d.MediaURL), poster)
	case d.MediaURL != "":
		mediaTag = fmt.Sprintf(`<img src="%s" alt=""/>`, esc(d.MediaURL))
	default:
		mediaTag = `<div class="ph">🖼️</div>`
	}

	avatarTag := `<div class="av ph2">👤</div>`
	if d.Avatar != "" {
		avatarTag = fmt.Sprintf(`<img class="av" src="%s" alt=""/>`, esc(d.Avatar))
	}

	capHTML := ""
	if d.Caption != "" {
		capHTML = fmt.Sprintf(
			`<p class="cap"><b>%s</b> %s</p>`, esc(d.Username), esc(d.Caption))
	}

	deepLink := fmt.Sprintf("raonson://%s/%s", d.Kind, d.ID)

	return []byte(fmt.Sprintf(previewHTML,
		esc(title), meta.String(), avatarTag, esc(d.Username),
		esc(kindLabel(d.Kind)), mediaTag,
		d.Likes, d.Comments, capHTML, esc(deepLink)))
}

func kindLabel(kind string) string {
	if kind == "reel" {
		return "Reel"
	}
	return "Post"
}
