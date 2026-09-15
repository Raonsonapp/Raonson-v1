#!/usr/bin/env bash
# Сайти Raonson-ро дар `_site/` ҷамъ мекунад.
#
# ЯК скрипт барои ҳар ду мизбон:
#   • GitHub Pages  (.github/workflows/pages.yml)
#   • Cloudflare Pages (Build command)
#
# Бе ин, ҳар мизбон рӯйхати худро медошт ва онҳо дер ё зуд аз ҳам
# дур мешуданд — як ҷо файле илова мешуд, дар ҷои дигар не.
#
# Истифода:  bash scripts/build-site.sh
# Натиҷа:    _site/
set -euo pipefail

OUT="${1:-_site}"
rm -rf "$OUT"
mkdir -p "$OUT/assets" "$OUT/app"

# ── Саҳифаи асосӣ ────────────────────────────────────────────────
# Ин саҳифаро Google мехонад. Матни ҳақиқӣ дорад, на canvas.
cp index.html "$OUT/index.html"
cp assets/icon.png "$OUT/assets/icon.png"

# ── Индексатсия ──────────────────────────────────────────────────
cp robots.txt "$OUT/robots.txt"
cp sitemap.xml "$OUT/sitemap.xml"
cp app-ads.txt "$OUT/app-ads.txt"

# ── Барнома дар /app/ ────────────────────────────────────────────
#
# Худи барномаи Flutter — ҳамон чизе, ки дар APK аст.
#
# Чаро ҲАМИН ҶО, на дар реша: Flutter Web ҳамаро дар <canvas>
# мекашад. Googlebot ба он нигоҳ мекунад ва матни ХОЛӢ мебинад.
# Агар саҳифаи асосӣ Flutter Web мебуд, сайт дар Google пайдо
# намешуд. Пас реша HTML мемонад, барнома дар /app/.
#
# Flutter дар муҳити Cloudflare нест — он ҷо ин қадам мегузарад ва
# веб-клиенти сабук гузошта мешавад. Дар GitHub Actions Flutter
# ҳаст, пас барномаи пурра меравад.
if command -v flutter >/dev/null 2>&1; then
  echo "→ Flutter Web сохта мешавад…"
  flutter build web --release --base-href /app/
  cp -r build/web/. "$OUT/app/"
  echo "  барномаи пурра дар $OUT/app/"
else
  echo "→ Flutter нест: веб-клиенти сабук гузошта мешавад"
  cp webapp/index.html "$OUT/app/index.html"
fi

# ── Тасдиқи соҳибӣ ───────────────────────────────────────────────
# Файли Google Search Console ё Yandex Webmaster, агар бошад.
# `|| true` — набудани файл хатогӣ нест.
cp google*.html "$OUT/" 2>/dev/null || true
cp yandex_*.html "$OUT/" 2>/dev/null || true

# GitHub Pages вагарна феҳристҳои бо `_` сарро пинҳон мекунад.
touch "$OUT/.nojekyll"
chmod -R +rX "$OUT"

echo "✅ $OUT тайёр:"
find "$OUT" -type f | sort | sed 's|^|   |'
