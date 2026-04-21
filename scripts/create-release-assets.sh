#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SlamX"
LEGACY_APP_NAME="SlamDih"
VERSION="${1:-}"
BUILD_NUMBER="${2:-${BUILD_NUMBER:-}}"
DMG_ROOT="$ROOT_DIR/.build/dmg"
RELEASE_NOTES_SOURCE="${RELEASE_NOTES_FILE:-}"
PREVIOUS_RELEASE_TAG="${PREVIOUS_RELEASE_TAG:-}"
RELEASE_TAG="${RELEASE_TAG:-v$VERSION}"
RELEASE_TITLE="${RELEASE_TITLE:-$APP_NAME $RELEASE_TAG}"

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "Usage: $0 <version> <build-number>" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be CFBundleShortVersionString-compatible, e.g. 0.3.3." >&2
  echo "Use RELEASE_TAG=v$VERSION-fix.1 for GitHub/Sparkle asset URLs." >&2
  exit 1
fi

"$ROOT_DIR/scripts/create-dmg.sh" "$VERSION" "$BUILD_NUMBER"

RELEASE_NOTES_PATH="$DMG_ROOT/$APP_NAME-$VERSION.html"

if [[ -n "$RELEASE_NOTES_SOURCE" ]]; then
  if [[ ! -f "$RELEASE_NOTES_SOURCE" ]]; then
    echo "Release notes file not found: $RELEASE_NOTES_SOURCE" >&2
    exit 1
  fi

  cp "$RELEASE_NOTES_SOURCE" "$RELEASE_NOTES_PATH"
else
  if [[ -z "$PREVIOUS_RELEASE_TAG" ]]; then
    PREVIOUS_RELEASE_TAG="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 --match 'v*' HEAD^ 2>/dev/null || true)"
  fi

  {
    echo "<h2>$RELEASE_TITLE</h2>"
    echo "<h3>Highlights</h3>"
    echo "<ul>"

    if [[ -n "$PREVIOUS_RELEASE_TAG" ]]; then
      while IFS= read -r subject; do
        [[ -z "$subject" ]] && continue
        escaped_subject="${subject//&/&amp;}"
        escaped_subject="${escaped_subject//</&lt;}"
        escaped_subject="${escaped_subject//>/&gt;}"
        echo "  <li>$escaped_subject</li>"
      done < <(git -C "$ROOT_DIR" log --format=%s "$PREVIOUS_RELEASE_TAG"..HEAD)
    else
      echo "  <li>Maintenance update.</li>"
    fi

    echo "</ul>"
  } > "$RELEASE_NOTES_PATH"
fi

APPCAST_DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-https://github.com/jx-grxf/SlamX/releases/download/$RELEASE_TAG/}" \
  "$ROOT_DIR/scripts/generate-appcast.sh" "$DMG_ROOT"

git -C "$ROOT_DIR" archive \
  --format=zip \
  --prefix="$APP_NAME-$VERSION/" \
  --output="$DMG_ROOT/$APP_NAME-$VERSION-source.zip" \
  HEAD

git -C "$ROOT_DIR" archive \
  --format=tar.gz \
  --prefix="$APP_NAME-$VERSION/" \
  --output="$DMG_ROOT/$APP_NAME-$VERSION-source.tar.gz" \
  HEAD

if find "$DMG_ROOT" -maxdepth 1 -type f -name "$LEGACY_APP_NAME*" | grep -q .; then
  echo "Legacy release asset name found in $DMG_ROOT" >&2
  exit 1
fi

echo "Release assets:"
find "$DMG_ROOT" -maxdepth 1 -type f -print | sort
