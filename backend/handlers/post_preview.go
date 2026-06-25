package handlers

import (
	"context"
	"fmt"
	"html"
	"net/http"

	"raonson/db"

	"github.com/gin-gonic/gin"
)

// GET /posts/preview/:id — public HTML (no auth, no templates needed)
// Uses c.Data() directly — NO LoadHTMLGlob required
func PostPreview(c *gin.Context) {
	pid := c.Param("id")

	var caption, username, avatar string
	var mediaURL, mediaType string

	err := db.Pool.QueryRow(context.Background(), `
		SELECT p.caption, u.username, COALESCE(u.avatar,''),
		       COALESCE(m.url,''), COALESCE(m.type,'image')
		FROM posts p
		JOIN users u ON u.id = p.user_id
		LEFT JOIN post_media m ON m.post_id=p.id AND m.position=0
		WHERE p.id=$1`, pid).Scan(&caption, &username, &avatar, &mediaURL, &mediaType)

	if err != nil {
		c.Data(http.StatusNotFound, "text/html; charset=utf-8", notFoundHTML())
		return
	}

	// XSS guard — ҳар арзиши аз БД пеш аз гузоштан ба HTML escape мешавад.
	caption = html.EscapeString(caption)
	username = html.EscapeString(username)
	avatar = html.EscapeString(avatar)
	mediaURL = html.EscapeString(mediaURL)

	var mediaTag string
	switch {
	case mediaType == "video" && mediaURL != "":
		mediaTag = fmt.Sprintf(
			`<video src="%s" controls autoplay muted loop playsinline `+
				`style="width:100%%;height:100%%;object-fit:cover"></video>`, mediaURL)
	case mediaURL != "":
		mediaTag = fmt.Sprintf(
			`<img src="%s" alt="post" style="width:100%%;height:100%%;object-fit:cover"/>`,
			mediaURL)
	default:
		mediaTag = `<div style="background:#1a1a1a;width:100%;height:100%;` +
			`display:flex;align-items:center;justify-content:center;font-size:48px">🖼️</div>`
	}

	avatarTag := ""
	if avatar != "" {
		avatarTag = fmt.Sprintf(`<img src="%s" class="av" alt="%s"/>`, avatar, username)
	} else {
		avatarTag = `<div class="av" style="font-size:18px">👤</div>`
	}

	ogImage := ""
	if mediaURL != "" {
		ogImage = fmt.Sprintf(`<meta property="og:image" content="%s"/>`, mediaURL)
	}

	captionHTML := ""
	if caption != "" {
		captionHTML = fmt.Sprintf(
			`<div class="cap"><strong>%s</strong> %s</div>`, username, caption)
	}

	html := fmt.Sprintf(`<!DOCTYPE html>
<html lang="tg">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>%s — Raonson</title>
  <meta property="og:title" content="%s — Raonson"/>
  <meta property="og:description" content="%s"/>
  %s
  <meta property="og:type" content="article"/>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#0a0a0a;color:#fff;font-family:-apple-system,sans-serif;
      min-height:100vh;display:flex;flex-direction:column;align-items:center}
    .hdr{width:100%%;max-width:480px;padding:14px 16px;
      display:flex;align-items:center;gap:12px}
    .av{width:40px;height:40px;border-radius:50%%;background:#2a2a2a;
      object-fit:cover;display:flex;align-items:center;justify-content:center}
    .uname{font-weight:600;font-size:15px}
    .media{width:100%%;max-width:480px;aspect-ratio:1;overflow:hidden;background:#111}
    .info{width:100%%;max-width:480px;padding:14px 16px}
    .cap{font-size:14px;line-height:1.5;color:#eee;margin-top:4px}
    .btn{margin-top:20px;padding:13px 28px;background:#0095f6;color:#fff;
      border:none;border-radius:8px;font-size:15px;font-weight:600;
      cursor:pointer;text-decoration:none;display:inline-block}
    .btn:hover{background:#0086e0}
    .foot{margin-top:32px;color:#444;font-size:12px;padding-bottom:24px}
  </style>
</head>
<body>
  <div class="hdr">
    %s
    <div>
      <div class="uname">%s</div>
      <div style="color:#888;font-size:12px">Raonson</div>
    </div>
  </div>
  <div class="media">%s</div>
  <div class="info">
    %s
    <div style="margin-top:18px;text-align:center">
      <a href="raonson://post/%s" class="btn">📱 Raonson-да очиш</a>
    </div>
  </div>
  <div class="foot">© 2026 Raonson</div>
</body>
</html>`,
		username, username, caption, ogImage,
		avatarTag, username, mediaTag, captionHTML, pid)

	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))
}

func notFoundHTML() []byte {
	return []byte(`<!DOCTYPE html>
<html><head><meta charset="UTF-8"/>
<style>body{background:#000;color:#fff;font-family:sans-serif;
  display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
</style></head>
<body><h2>Пост ёфт нашуд 🔍</h2></body></html>`)
}
