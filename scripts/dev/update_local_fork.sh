#!/usr/bin/env bash
set -euo pipefail

# Canonical rebuild + reinstall for the personal MacParakeet fork.
#
# This is the only script you need for future local /Applications updates.
# It does NOT use Sparkle — dev builds are version 0.0.0 and update checks
# are blocked so the app is never replaced by the official macparakeet.com DMG.
#
# Usage:
#   ./scripts/dev/update_local_fork.sh              # test, build, sign, install
#   ./scripts/dev/update_local_fork.sh --skip-tests # faster iteration
#   ./scripts/dev/update_local_fork.sh --sync-upstream
#   ./scripts/dev/update_local_fork.sh --launch     # install then open the app
#
# Environment:
#   MACPARAKEET_CODESIGN_IDENTITY  override signing identity (default: stable local cert)
#   INSTALL_NAME                   app name in /Applications (default: MacParakeet)
#
# See scripts/dev/README.md and integrations/local-setup.md

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_NAME="${INSTALL_NAME:-MacParakeet}"
DEST="/Applications/${INSTALL_NAME}.app"

SYNC_UPSTREAM=0
SKIP_TESTS=0
LAUNCH=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Rebuild the fork, stable codesign (TCC survives rebuilds), and install to:
  $DEST

Options:
  --sync-upstream   Merge upstream/main into this repo before building
  --skip-tests      Skip 'swift test' (not recommended before a "real" install)
  --launch          Run 'open -a $INSTALL_NAME' after a successful install
  -h, --help        Show this help

See integrations/local-setup.md for the full personal-fork workflow.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sync-upstream) SYNC_UPSTREAM=1 ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --launch) LAUNCH=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

cd "$ROOT_DIR"

echo "==> Ensuring stable codesign identity (TCC survives rebuilds)"
"$ROOT_DIR/scripts/dev/setup_codesign_identity.sh"

echo "==> MacParakeet fork update"
echo "    repo:   $ROOT_DIR"
echo "    branch: $(git branch --show-current 2>/dev/null || echo unknown)"
echo "    commit: $(git rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
echo ""

if [[ "$SYNC_UPSTREAM" == "1" ]]; then
  echo "==> [1/4] Syncing upstream/main"
  "$ROOT_DIR/scripts/sync-upstream.sh"
else
  echo "==> [1/4] Skipping upstream sync (pass --sync-upstream to merge moona3k/macparakeet)"
fi

if [[ "$SKIP_TESTS" == "1" ]]; then
  echo "==> [2/4] Skipping tests (--skip-tests)"
else
  echo "==> [2/4] Running swift test"
  swift test
fi

echo "==> [3/4] Build, codesign, install to /Applications"
"$ROOT_DIR/scripts/dev/install_to_applications.sh"

echo "==> [4/4] Verifying installation"
if [[ ! -d "$DEST" ]]; then
  echo "Install verification failed: $DEST missing" >&2
  exit 1
fi

if ! codesign --verify --deep --strict "$DEST" >/dev/null 2>&1; then
  echo "Install verification failed: codesign --verify on $DEST" >&2
  exit 1
fi

COMMIT="$(/usr/libexec/PlistBuddy -c 'Print :MacParakeetGitCommit' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"
SOURCE="$(/usr/libexec/PlistBuddy -c 'Print :MacParakeetBuildSource' "$DEST/Contents/Info.plist" 2>/dev/null || echo unknown)"

cat <<EOF

==> Installed successfully
    path:    $DEST
    version: $VERSION (build $BUILD)
    commit:  $COMMIT
    source:  $SOURCE

Sparkle auto-update: disabled for version 0.0.0 dev builds (see SparkleUpdateGuard).
To update again later, re-run:
  ./scripts/dev/update_local_fork.sh

Permissions: with the stable "MacParakeet Local Fork Signing" certificate,
grant mic / accessibility / screen recording once — rebuilds should keep them.
Re-grant only when switching from older ad-hoc installs or deleting the cert.

EOF

if [[ "$LAUNCH" == "1" ]]; then
  echo "==> Launching $INSTALL_NAME"
  open -a "$INSTALL_NAME"
fi