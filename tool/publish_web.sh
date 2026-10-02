#!/usr/bin/env bash
# Publishes the web version on GitHub Pages:
#   https://stranger-the-unknown.github.io/algorun-play/
# The source stays in this private repository; only the built web files go
# to the public repository stranger-the-unknown/algorun-play. Run it after
# changes that should reach the browser version: tool/publish_web.sh
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=stranger-the-unknown/algorun-play
URL=https://stranger-the-unknown.github.io/algorun-play/
OUT=build/web-pages

flutter build web --release --base-href /algorun-play/ -o "$OUT"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git clone -q --depth 1 "https://github.com/$REPO.git" "$WORK/site"
git -C "$WORK/site" checkout -q -B main
find "$WORK/site" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$OUT"/. "$WORK/site/"
rm -f "$WORK/site/.last_build_id"
# Serve every file as it is (no Jekyll processing).
touch "$WORK/site/.nojekyll"
cat > "$WORK/site/README.md" <<EOF
# Algorun — play in the browser

The built web version of Algorun, an algorithm puzzle game played with
blocks. Play it at $URL — progress is kept in your browser.

This repository holds generated files only; it is updated by a script.
EOF

git -C "$WORK/site" add -A
if git -C "$WORK/site" diff --cached --quiet; then
  echo "Nothing changed; $URL is up to date."
  exit 0
fi
git -C "$WORK/site" commit -q -m "Web build from $(git rev-parse --short HEAD)"
git -C "$WORK/site" push -q origin main
echo "Published: $URL (it can take a minute or two to appear)"
