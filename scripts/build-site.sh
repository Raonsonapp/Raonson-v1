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

# ── Веб-клиент ───────────────────────────────────────────────────
# Саҳифаи асосӣ таблиғотӣ мемонад; худи барнома дар /app/.
cp webapp/index.html "$OUT/app/index.html"

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
