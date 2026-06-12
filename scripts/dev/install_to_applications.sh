#!/usr/bin/env bash
set -euo pipefail

# Build a Release bundle, stable codesign for TCC, and copy to /Applications.
# Prefer scripts/dev/update_local_fork.sh — see scripts/dev/README.md

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_NAME="${INSTALL_NAME:-MacParakeet}"
DEST="/Applications/${INSTALL_NAME}.app"

# Stable keychain identity keeps mic/accessibility/screen TCC across rebuilds.
"$ROOT_DIR/scripts/dev/setup_codesign_identity.sh" >/dev/null 2>&1 \
  || "$ROOT_DIR/scripts/dev/setup_codesign_identity.sh"
export REQUIRE_STABLE_CODESIGN=1

echo "Stopping any running ${INSTALL_NAME}..."
pkill -x MacParakeet 2>/dev/null || true
sleep 1

echo "Building release app bundle..."
"$ROOT_DIR/scripts/dist/build_app_bundle.sh"

SRC="$ROOT_DIR/dist/MacParakeet.app"
if [[ ! -d "$SRC" ]]; then
  echo "Build failed: $SRC not found" >&2
  exit 1
fi

echo "Codesigning app bundle (required for microphone/accessibility TCC)..."
"$ROOT_DIR/scripts/dev/codesign_app_bundle.sh" "$SRC"

echo "Installing to $DEST (in-place when already present)"
mkdir -p "$(dirname "$DEST")"
ditto "$SRC" "$DEST"

# Drop the dist copy so Spotlight/Launchpad don't show two identical MacParakeet apps.
rm -rf "$SRC" "$ROOT_DIR/dist/MacParakeet.dSYM"

if ! codesign --verify --deep --strict "$DEST" >/dev/null 2>&1; then
  echo "Post-install codesign verification failed for $DEST" >&2
  exit 1
fi

COMMIT="$(/usr/libexec/PlistBuddy -c 'Print :MacParakeetGitCommit' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"

echo "Done: $DEST"
echo "  build:  $BUILD"
echo "  commit: $COMMIT"
echo "Launch: open -a $INSTALL_NAME"