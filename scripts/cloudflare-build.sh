#!/usr/bin/env bash
# Сохтани сайт дар муҳити Cloudflare.
#
# Масъала: дар муҳити сохтани Cloudflare Flutter НЕСТ. Бе он
# `scripts/build-site.sh` қадами барномаро мегузарад ва дар /app/
# танҳо веб-клиенти сабук мемонад — на он чи дар APK аст.
#
# Ҳал: Flutter ҳамин ҷо зеркашӣ мешавад, баъд сайт сохта мешавад.
# Зеркашӣ ~2–4 дақиқа мегирад. Ба ивазаш ҳеҷ калид, ҳеҷ GitHub
# Secret ва ҳеҷ танзими иловагӣ лозим нест.
#
# Дар Cloudflare:
#   Build command:   bash scripts/cloudflare-build.sh
#   Deploy command:  npx wrangler deploy
set -euo pipefail

FLUTTER_VERSION="3.22.2"
SDK="$HOME/flutter"
OUT="_site"

# ⚠️ Ин скрипт ДУ БОР иҷро мешавад.
#
# Як бор ҳамчун «build command»-и Cloudflare, бори дуюм худи
# `wrangler deploy` онро аз майдони `build` дар wrangler.jsonc
# мегирад.
#
# Дар иҷрои аввал ҳама чиз хуб буд (3м 45с). Дар иҷрои дуюм PATH
# нав аст, пас `command -v flutter` кор намекард ва скрипт `git
# clone`-ро ба феҳристи АЛЛАКАЙ МАВҶУД мезад:
#
#   fatal: destination path '/opt/buildhome/flutter' already exists
#
# `set -e` скриптро мекушт ва deploy меафтод — маҳз он 21 сония.
# Барои ҳамин ҳар қадам акнун такроршаванда аст.

if [ -x "$SDK/bin/flutter" ]; then
  echo "→ Flutter аллакай ҳаст"
  export PATH="$PATH:$SDK/bin"
elif ! command -v flutter >/dev/null 2>&1; then
  echo "→ Flutter $FLUTTER_VERSION зеркашӣ мешавад…"
  # --depth 1: таърихи пурра лозим нест ва он ҷо гигабайтҳост.
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$SDK"
  export PATH="$PATH:$SDK/bin"
fi

# Агар сайт аллакай сохта шуда бошад, дубора сохтан лозим нест —
# он боз чор дақиқа мегирифт ва ҳеҷ чизи навро намедод.
if [ -f "$OUT/app/main.dart.js" ]; then
  echo "✅ сайт аллакай тайёр аст ($(du -sh $OUT | cut -f1))"
  exit 0
fi

flutter --version
flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get

bash scripts/build-site.sh _site

# Агар барнома насохта шуда бошад, беҳтар аст ҳозир афтем, назар ба
# он ки сайти нимкора нашр шавад.
if [ ! -f _site/app/main.dart.js ]; then
  echo "❌ Flutter Web сохта нашуд — /app/ нопурра аст" >&2
  exit 1
fi

echo "✅ сайт тайёр ($(du -sh _site | cut -f1))"
