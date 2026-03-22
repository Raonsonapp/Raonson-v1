package handlers

import (
	"context"
	"fmt"
	"net/http"

	"raonson/db"

	"github.com/gin-gonic/gin"
)

// GET /posts/preview/:id  — public HTML (no auth, for link sharing)
func PostPreview(c *gin.Context) {
	pid := c.Param("id")

	var caption, username, avatar string
	var mediaURL, mediaType string

	err := db.Pool.QueryRow(context.Background(), `
		SELECT p.caption, u.username, u.avatar,
		       COALESCE(m.url,''), COALESCE(m.type,'image')
		FROM posts p
		JOIN users u ON u.id=p.user_id
		LEFT JOIN post_media m ON m.post_id=p.id AND m.position=0
		WHERE p.id=$1`, pid).Scan(&caption, &username, &avatar, &mediaURL, &mediaType)

	if err != nil {
		c.Data(http.StatusNotFound, "text/html; charset=utf-8", []byte(`
		<html><body style="background:#000;color:#fff;font-family:sans-serif;
		  display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
		  <h2>Пост ёфт нашуд</h2></body></html>`))
		return
	}

	isVideo := mediaType == "video"

	var mediaTag string
	if isVideo && mediaURL != "" {
		mediaTag = fmt.Sprintf(`<video src="%s" controls autoplay muted loop playsinline style="width:100%%;height:100%%;object-fit:cover"></video>`, mediaURL)
	} else if mediaURL != "" {
		mediaTag = fmt.Sprintf(`<img src="%s" alt="post" style="width:100%%;height:100%%;object-fit:cover"/>`, mediaURL)
	} else {
		mediaTag = `<div style="background:#1a1a1a;width:100%;height:100%;display:flex;align-items:center;justify-content:center;color:#555">🖼️</div>`
	}

	var avatarTag string
	if avatar != "" {
		avatarTag = fmt.Sprintf(`<img src="%s" class="avatar" alt="%s"/>`, avatar, username)
	} else {
		avatarTag = `<div class="avatar-placeholder">👤</div>`
	}

	ogImage := ""
	if mediaURL != "" {
		ogImage = fmt.Sprintf(`<meta property="og:image" content="%s"/>`, mediaURL)
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
    .header{width:100%%;max-width:480px;padding:16px;display:flex;align-items:center;gap:12px}
    .avatar{width:40px;height:40px;border-radius:50%%;background:#333;object-fit:cover}
    .avatar-placeholder{width:40px;height:40px;border-radius:50%%;background:#333;
      display:flex;align-items:center;justify-content:center;font-size:18px}
    .username{font-weight:600;font-size:15px}
    .media{width:100%%;max-width:480px;aspect-ratio:1}
    .info{width:100%%;max-width:480px;padding:16px}
    .caption{font-size:14px;line-height:1.5;color:#eee;margin-top:8px}
    .btn{margin-top:24px;padding:14px 32px;background:#0095f6;color:#fff;
      border:none;border-radius:8px;font-size:15px;font-weight:600;cursor:pointer;
      text-decoration:none;display:inline-block}
    .footer{margin-top:32px;color:#555;font-size:12px;padding-bottom:32px}
  </style>
</head>
<body>
  <div class="header">
    %s
    <div>
      <div class="username">%s</div>
      <div style="color:#888;font-size:13px">Raonson</div>
    </div>
  </div>
  <div class="media">%s</div>
  <div class="info">
    %s
    <div style="margin-top:20px;text-align:center">
      <a href="raonson://post/%s" class="btn">📱 Raonson-да очиш</a>
    </div>
  </div>
  <div class="footer">© 2026 Raonson</div>
</body>
</html>`,
		username, username, caption, ogImage,
		avatarTag, username, mediaTag,
		func() string {
			if caption != "" {
				return fmt.Sprintf(`<div class="caption"><strong>%s</strong> %s</div>`, username, caption)
			}
			return ""
		}(),
		pid)

	c.Data(http.StatusOK, "text/html; charset=utf-8", []byte(html))
}
