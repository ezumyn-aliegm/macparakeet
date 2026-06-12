#!/usr/bin/env bash
set -euo pipefail

# Codesign a .app bundle for local installs. Prefer a stable keychain identity
# (scripts/dev/setup_codesign_identity.sh) so TCC permissions survive rebuilds.
#
# Usage: scripts/dev/codesign_app_bundle.sh /path/to/MacParakeet.app
#
# Environment:
#   REQUIRE_STABLE_CODESIGN=1   Fail instead of falling back to ad-hoc "-"
#   MACPARAKEET_CODESIGN_IDENTITY Override signing identity name

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/dev/codesign_identity.sh
source "$ROOT_DIR/scripts/dev/codesign_identity.sh"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/App.app" >&2
  exit 1
fi

APP_PATH="$1"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

REQUIRE_STABLE="${REQUIRE_STABLE_CODESIGN:-0}"
ALLOW_ADHOC=1
if [[ "$REQUIRE_STABLE" == "1" ]]; then
  ALLOW_ADHOC=0
fi

if ! SIGN_IDENTITY="$(pick_codesign_identity "$ALLOW_ADHOC")"; then
  echo "No stable codesign identity found." >&2
  echo "Run: $ROOT_DIR/scripts/dev/setup_codesign_identity.sh" >&2
  exit 1
fi

APP_NAME="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$APP_PATH/Contents/Info.plist" 2>/dev/null || basename "${APP_PATH%.app}")"

# Local builds always use dev entitlements (Sparkle load + mic/calendar/network).
ENTITLEMENTS="$ROOT_DIR/scripts/dev/MacParakeet.local.entitlements"
NODE_RUNTIME_ENTITLEMENTS="$ROOT_DIR/scripts/dist/NodeRuntime.entitlements"
YTDLP_RUNTIME_ENTITLEMENTS="$ROOT_DIR/scripts/dist/YtDlpRuntime.entitlements"

timestamp_args=()
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  timestamp_args=(--timestamp)
fi

if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Warning: ad-hoc codesign resets Privacy permissions on every rebuild." >&2
  echo "Run scripts/dev/setup_codesign_identity.sh for a stable identity." >&2
fi

echo "Codesigning $APP_PATH with identity: $SIGN_IDENTITY"
xattr -cr "$APP_PATH" || true

SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_FW" ]]; then
  while IFS= read -r -d '' xpc; do
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$xpc"
  done < <(find "$SPARKLE_FW" -name "*.xpc" -type d -print0 2>/dev/null || true)
  while IFS= read -r -d '' nested_app; do
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$nested_app"
  done < <(find "$SPARKLE_FW" -name "*.app" -type d -print0 2>/dev/null || true)
  while IFS= read -r -d '' bin; do
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$bin"
  done < <(find "$SPARKLE_FW/Versions/B" -maxdepth 1 -type f -perm -111 -print0 2>/dev/null || true)
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$SPARKLE_FW"
fi

while IFS= read -r -d '' dylib; do
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$dylib"
done < <(
  find "$APP_PATH/Contents/Frameworks" -maxdepth 1 -type f -name "*.dylib" -print0 2>/dev/null || true
)

while IFS= read -r -d '' bin; do
  base="$(basename "$bin")"
  if [[ "$base" == "node" || "$base" == "node-arm64" || "$base" == "node-x86_64" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" \
      --entitlements "$NODE_RUNTIME_ENTITLEMENTS" "$bin"
  elif [[ "$base" == "yt-dlp" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" \
      --entitlements "$YTDLP_RUNTIME_ENTITLEMENTS" "$bin"
  else
    codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$bin"
  fi
done < <(
  find "$APP_PATH/Contents/Resources" -maxdepth 1 -type f -perm -111 \
    \( -name "ffmpeg" -o -name "yt-dlp" -o -name "node" -o -name "node-arm64" -o -name "node-x86_64" \) -print0 2>/dev/null || true
)

while IFS= read -r -d '' bin; do
  base="$(basename "$bin")"
  if [[ "$base" == "$APP_NAME" ]]; then
    continue
  fi
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" "$bin"
done < <(
  find "$APP_PATH/Contents/MacOS" -maxdepth 1 -type f -perm -111 -print0 2>/dev/null || true
)

MAIN_BIN="$APP_PATH/Contents/MacOS/$APP_NAME"
if [[ -f "$MAIN_BIN" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" \
    --entitlements "$ENTITLEMENTS" "$MAIN_BIN"
fi

codesign --force --sign "$SIGN_IDENTITY" --options runtime "${timestamp_args[@]}" \
  --entitlements "$ENTITLEMENTS" "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
echo "Codesign complete: $SIGN_IDENTITY"