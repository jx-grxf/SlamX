#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="SlamX"
LEGACY_APP_NAME="SlamDih"
VERSION="${1:-}"
BUILD_NUMBER="${2:-${BUILD_NUMBER:-}}"
DMG_ROOT="$ROOT_DIR/.build/dmg"

if [[ -z "$VERSION" || -z "$BUILD_NUMBER" ]]; then
  echo "Usage: $0 <version> <build-number>" >&2
  exit 1
fi

"$ROOT_DIR/scripts/create-dmg.sh" "$VERSION" "$BUILD_NUMBER"
APPCAST_DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-https://github.com/jx-grxf/SlamX/releases/download/v$VERSION}" \
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
