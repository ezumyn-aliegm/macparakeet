#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/dev/codesign_identity.sh
source "$ROOT_DIR/scripts/dev/codesign_identity.sh"

case "${1:-}" in
  --check)
    if has_stable_codesign_identity; then
      echo "ok: ${LOCAL_FORK_IDENTITY_NAME}"
      exit 0
    fi
    echo "missing: ${LOCAL_FORK_IDENTITY_NAME}" >&2
    exit 1
    ;;
  -h|--help)
    cat <<EOF
Install a stable local codesign certificate so macOS keeps Privacy permissions
across fork rebuilds (adhoc "-" signing resets TCC every build).

Usage:
  $(basename "$0")         Create identity if missing
  $(basename "$0") --check Exit 0 when identity exists

Override with MACPARAKEET_CODESIGN_IDENTITY if you use Apple Development.
EOF
    exit 0
    ;;
esac

if setup_local_fork_codesign_identity; then
  security find-certificate -c "${LOCAL_FORK_IDENTITY_NAME}" "$LOCAL_FORK_KEYCHAIN" >/dev/null 2>&1 \
    && echo "Keychain certificate: ${LOCAL_FORK_IDENTITY_NAME}"
  exit 0
fi

print_apple_development_hint
exit 1