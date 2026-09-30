#!/usr/bin/env bash
# Algorun in a desktop browser. Builds the web version when the code has
# changed since the last build, serves it at http://localhost:8080 and opens
# it. Progress is kept by the browser for this address, so always play at
# this same address (same port) in the same browser. Ctrl+C stops it.
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=8080
URL="http://localhost:$PORT"

if [ ! -f build/web/main.dart.js ] ||
   [ -n "$(find lib assets web packages/algorun_engine/lib pubspec.yaml -newer build/web/main.dart.js -print -quit)" ]; then
  flutter build web --release
fi

echo "Algorun: $URL  (Ctrl+C to stop)"
(sleep 1 && xdg-open "$URL" >/dev/null 2>&1 || true) &
exec python3 -m http.server "$PORT" --bind 127.0.0.1 --directory build/web
