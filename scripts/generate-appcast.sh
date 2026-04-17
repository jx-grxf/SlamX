#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATES_DIR="${1:-$ROOT_DIR/.build/dmg}"
SPARKLE_TOOLS_DIR="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin"
GENERATE_APPCAST="$SPARKLE_TOOLS_DIR/generate_appcast"

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  swift package --package-path "$ROOT_DIR" resolve
fi

if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "Sparkle generate_appcast tool not found at $GENERATE_APPCAST" >&2
  exit 1
fi

"$GENERATE_APPCAST" "$UPDATES_DIR"

echo "Generated $UPDATES_DIR/appcast.xml"
