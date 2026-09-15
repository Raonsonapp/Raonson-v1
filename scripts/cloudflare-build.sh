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

if ! command -v flutter >/dev/null 2>&1; then
  echo "→ Flutter $FLUTTER_VERSION зеркашӣ мешавад…"
  # --depth 1: таърихи пурра лозим нест ва он ҷо гигабайтҳост.
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$SDK"
  export PATH="$PATH:$SDK/bin"
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
