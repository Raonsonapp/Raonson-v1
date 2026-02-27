// Public post preview handler - returns HTML page (no auth needed)
import { Post } from "../models/post.model.js";

export async function postPreview(req, res) {
  try {
    const post = await Post.findById(req.params.id)
      .populate("user", "username avatar");

    if (!post) {
      return res.status(404).send(`
        <html><body style="background:#000;color:#fff;font-family:sans-serif;
          display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
          <h2>Пост ёфт нашуд</h2>
        </body></html>
      `);
    }

    const media = post.media?.[0];
    const imageUrl = media?.url || '';
    const isVideo = media?.type === 'video';
    const username = post.user?.username || 'Raonson';
    const caption = post.caption || '';
    const avatar = post.user?.avatar || '';

    res.send(`<!DOCTYPE html>
<html lang="tg">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>${username} — Raonson</title>
  <meta property="og:title" content="${username} — Raonson"/>
  <meta property="og:description" content="${caption}"/>
  ${imageUrl ? `<meta property="og:image" content="${imageUrl}"/>` : ''}
  <meta property="og:type" content="article"/>
  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{background:#0a0a0a;color:#fff;font-family:-apple-system,sans-serif;
      min-height:100vh;display:flex;flex-direction:column;align-items:center}
    .header{width:100%;max-width:480px;padding:16px;display:flex;align-items:center;gap:12px}
    .avatar{width:40px;height:40px;border-radius:50%;background:#333;object-fit:cover}
    .avatar-placeholder{width:40px;height:40px;border-radius:50%;background:#333;
      display:flex;align-items:center;justify-content:center;font-size:18px}
    .username{font-weight:600;font-size:15px}
    .brand{color:#888;font-size:13px}
    .media{width:100%;max-width:480px;aspect-ratio:1}
    .media img,.media video{width:100%;height:100%;object-fit:cover}
    .info{width:100%;max-width:480px;padding:16px}
    .caption{font-size:14px;line-height:1.5;color:#eee;margin-top:8px}
    .download{margin-top:24px;padding:14px 32px;background:#0095f6;color:#fff;
      border:none;border-radius:8px;font-size:15px;font-weight:600;cursor:pointer;
      text-decoration:none;display:inline-block}
    .footer{margin-top:32px;color:#555;font-size:12px;padding-bottom:32px}
  </style>
</head>
<body>
  <div class="header">
    ${avatar 
      ? `<img src="${avatar}" class="avatar" alt="${username}"/>`
      : `<div class="avatar-placeholder">👤</div>`}
    <div>
      <div class="username">${username}</div>
      <div class="brand">Raonson</div>
    </div>
  </div>

  <div class="media">
    ${isVideo
      ? `<video src="${imageUrl}" controls autoplay muted loop playsinline></video>`
      : imageUrl
        ? `<img src="${imageUrl}" alt="post"/>`
        : `<div style="background:#1a1a1a;width:100%;height:100%;display:flex;
            align-items:center;justify-content:center;color:#555">🖼️</div>`}
  </div>

  <div class="info">
    ${caption ? `<div class="caption"><strong>${username}</strong> ${caption}</div>` : ''}
    <div style="margin-top:20px;text-align:center">
      <a href="raonson://post/${post._id}" class="download">
        📱 Raonson-да очиш
      </a>
    </div>
  </div>

  <div class="footer">© 2026 Raonson</div>
</body>
</html>`);
  } catch (e) {
    console.error(e);
    res.status(500).send('<html><body>Хато юз берди</body></html>');
  }
                              }
