package handlers

// Шаклаи саҳифаи пешнамоиш.
//
// Ҷудо нигоҳ дошта мешавад, то мантиқ дар post_preview.go хонда
// шавад ва тарҳ бе даст задан ба мантиқ тағйир ёбад.

// previewHTML — ҷойгирҳо бо тартиб:
//
//	1 сарлавҳа  2 тегҳои meta  3 аватар  4 ном  5 навъ
//	6 медиа     7 писанд       8 шарҳ    9 тавсиф 10 линки чуқур
const previewHTML = `<!DOCTYPE html>
<html lang="tg">
<head>
<meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"/>
<meta name="theme-color" content="#000000"/>
<title>%s — Raonson</title>
%s
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  :root{
    --bg:#000; --card:#0f1115; --line:#1e2128;
    --text:#fff; --muted:#8b909a;
    --a:#00C6FF; --b:#00E87A;
  }
  body{
    background:var(--bg);color:var(--text);
    font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;
    min-height:100dvh;display:flex;align-items:center;justify-content:center;
    padding:16px;
  }
  .card{
    width:100%%;max-width:440px;background:var(--card);
    border:1px solid var(--line);border-radius:18px;overflow:hidden;
    box-shadow:0 16px 50px rgba(0,0,0,.55);
  }
  .hdr{display:flex;align-items:center;gap:11px;padding:13px 15px}
  .av{
    width:38px;height:38px;border-radius:50%%;object-fit:cover;
    background:#1a1d23;flex:none;
  }
  /* Ҳалқаи story — ҳамон ду ранги барнома. */
  .ring{
    padding:2px;border-radius:50%%;flex:none;
    background:linear-gradient(135deg,var(--a),var(--b));
  }
  .ph2{display:flex;align-items:center;justify-content:center;font-size:17px}
  .who{min-width:0}
  .name{font-size:14.5px;font-weight:650;line-height:1.25}
  .kind{font-size:11.5px;color:var(--muted);margin-top:1px}
  .media{
    position:relative;width:100%%;background:#07080a;
    display:flex;align-items:center;justify-content:center;
    max-height:70dvh;overflow:hidden;
  }
  .media img,.media video{
    width:100%%;height:auto;max-height:70dvh;object-fit:contain;display:block;
  }
  .ph{
    width:100%%;aspect-ratio:1;display:flex;align-items:center;
    justify-content:center;font-size:42px;opacity:.35;
  }
  .stats{
    display:flex;gap:18px;padding:12px 15px 0;
    font-size:13px;color:var(--muted);
  }
  .stats b{color:var(--text);font-weight:600}
  .cap{
    padding:10px 15px 0;font-size:14px;line-height:1.5;color:#dfe2e7;
    word-wrap:break-word;
  }
  .cap b{color:#fff;font-weight:650}
  .act{padding:16px 15px 18px}
  .open{
    display:block;text-align:center;text-decoration:none;
    padding:13px;border-radius:11px;font-size:15px;font-weight:650;
    color:#04121a;background:linear-gradient(135deg,var(--a),var(--b));
  }
  .open:active{opacity:.85}
  .foot{
    text-align:center;font-size:11.5px;color:#4a4f58;
    padding:11px 0 0;letter-spacing:.2px;
  }
  @media (prefers-color-scheme: light){
    :root{--bg:#f2f3f5;--card:#fff;--line:#e3e5e9;--text:#101114;--muted:#6b7078}
    body{color:var(--text)}
    .cap{color:#33363c}
  }
</style>
</head>
<body>
  <main class="card">
    <div class="hdr">
      <div class="ring">%s</div>
      <div class="who">
        <div class="name">%s</div>
        <div class="kind">%s · Raonson</div>
      </div>
    </div>
    <div class="media">%s</div>
    <div class="stats"><span><b>%d</b> писанд</span><span><b>%d</b> шарҳ</span></div>
    %s
    <div class="act">
      <a class="open" href="%s">Дар Raonson кушодан</a>
      <div class="foot">RAONSON</div>
    </div>
  </main>
</body>
</html>`

func notFoundHTML() []byte {
	return []byte(`<!DOCTYPE html>
<html lang="tg"><head><meta charset="UTF-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Raonson</title>
<style>
 *{margin:0;padding:0;box-sizing:border-box}
 body{background:#000;color:#fff;min-height:100dvh;display:flex;
   align-items:center;justify-content:center;text-align:center;padding:24px;
   font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif}
 .i{font-size:40px;opacity:.4}
 h2{font-size:17px;font-weight:600;margin-top:14px}
 p{color:#8b909a;font-size:13.5px;margin-top:7px;line-height:1.5}
</style></head>
<body><div>
  <div class="i">🔍</div>
  <h2>Мӯҳтаво дастрас нест</h2>
  <p>Шояд он нест карда шуд ё пӯшида аст.</p>
</div></body></html>`)
}
