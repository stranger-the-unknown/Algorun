#!/usr/bin/env bash
# Publishes the Android APK as a GitHub release of this repository:
#   https://github.com/stranger-the-unknown/Algorun/releases/latest
# The APK is always attached as Algorun.apk, so the newest one is always at
#   https://github.com/stranger-the-unknown/Algorun/releases/latest/download/Algorun.apk
# The release is tagged v<date> (v<date>.2, .3 … on the same day) on the
# current commit, which must already be pushed. Release notes, Turkish for the
# player, come from the file given as the first argument:
#   tool/publish_apk.sh notes.md
set -euo pipefail
cd "$(dirname "$0")/.."
REPO=stranger-the-unknown/Algorun
NOTES=${1:?usage: tool/publish_apk.sh <notes.md>}
NOTES=$(realpath "$NOTES")

SHA=$(git rev-parse HEAD)
git fetch -q origin
if ! git branch -r --contains "$SHA" | grep -q .; then
  echo "Push $SHA first: a release must point at a commit on GitHub." >&2
  exit 1
fi

DATE=$(date +%F)
TAG=v$DATE
N=1
while gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; do
  N=$((N + 1))
  TAG=v$DATE.$N
done

flutter build apk --release
cp build/app/outputs/flutter-apk/app-release.apk "Algorun-$DATE.apk"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp build/app/outputs/flutter-apk/app-release.apk "$WORK/Algorun.apk"
TITLE="Algorun $DATE"
[ "$N" -gt 1 ] && TITLE="$TITLE ($N)"
gh release create "$TAG" "$WORK/Algorun.apk" -R "$REPO" --target "$SHA" \
  --title "$TITLE" --notes-file "$NOTES" --latest
echo "Released $TAG: https://github.com/$REPO/releases/latest/download/Algorun.apk"
