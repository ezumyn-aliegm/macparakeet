#!/usr/bin/env bash
# Shared codesign identity helpers for local fork builds.
# Sourced by other scripts — not executed directly.

LOCAL_FORK_IDENTITY_NAME="${LOCAL_FORK_IDENTITY_NAME:-MacParakeet Local Fork Signing}"
LOCAL_FORK_KEYCHAIN="${LOCAL_FORK_KEYCHAIN:-${HOME}/Library/Keychains/login.keychain-db}"
# Ephemeral password for the local PKCS#12 export unless LOCAL_FORK_P12_PASSWORD is set.

has_stable_codesign_identity() {
  security find-certificate -c "${LOCAL_FORK_IDENTITY_NAME}" "$LOCAL_FORK_KEYCHAIN" >/dev/null 2>&1
}

codesign_identity_usable() {
  local identity="$1"
  local probe="${2:-/usr/bin/true}"
  codesign --force --sign "$identity" --dryrun "$probe" >/dev/null 2>&1
}

pick_codesign_identity() {
  local allow_adhoc="${1:-1}"
  local preferred="${MACPARAKEET_CODESIGN_IDENTITY:-}"

  if [[ -n "$preferred" ]]; then
    printf '%s\n' "$preferred"
    return 0
  fi

  if has_stable_codesign_identity; then
    printf '%s\n' "$LOCAL_FORK_IDENTITY_NAME"
    return 0
  fi

  local identities
  identities="$(security find-identity -v -p codesigning 2>/dev/null || true)"

  while IFS= read -r candidate; do
    if grep -Fq "\"$candidate" <<<"$identities"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done < <(printf '%s\n' "Apple Development" "Mac Development")

  local named_identity
  named_identity="$(sed -n 's/^[[:space:]]*[0-9]*)[[:space:]]*[A-F0-9]*[[:space:]]*"\(.*\)"/\1/p' <<<"$identities" | head -n 1)"
  if [[ -n "$named_identity" ]]; then
    printf '%s\n' "$named_identity"
    return 0
  fi

  local developer_id
  developer_id="$(sed -n 's/.*"\(Developer ID Application:.*\)".*/\1/p' <<<"$identities" | head -n 1)"
  if [[ -n "$developer_id" ]]; then
    printf '%s\n' "$developer_id"
    return 0
  fi

  if [[ "$allow_adhoc" == "0" ]]; then
    return 1
  fi

  printf '%s\n' "-"
  return 0
}

cleanup_local_fork_certificates() {
  local hash
  while IFS= read -r hash; do
    [[ -n "$hash" ]] || continue
    security delete-certificate -Z "$hash" "$LOCAL_FORK_KEYCHAIN" >/dev/null 2>&1 || true
  done < <(
    security find-certificate -a -c "${LOCAL_FORK_IDENTITY_NAME}" -Z "$LOCAL_FORK_KEYCHAIN" 2>/dev/null \
      | awk '/SHA-1 hash:/ {print $3}'
  )
  # Legacy name from earlier attempts.
  while IFS= read -r hash; do
    [[ -n "$hash" ]] || continue
    security delete-certificate -Z "$hash" "$LOCAL_FORK_KEYCHAIN" >/dev/null 2>&1 || true
  done < <(
    security find-certificate -a -c "MacParakeet Local Fork" -Z "$LOCAL_FORK_KEYCHAIN" 2>/dev/null \
      | awk '/SHA-1 hash:/ {print $3}'
  )
}

setup_local_fork_codesign_identity() {
  if has_stable_codesign_identity; then
    echo "Codesign identity already installed: ${LOCAL_FORK_IDENTITY_NAME}"
    return 0
  fi

  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is required to create a local codesign identity." >&2
    return 1
  fi

  cleanup_local_fork_certificates

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/macparakeet-codesign.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp_dir'" RETURN

  local p12_password="${LOCAL_FORK_P12_PASSWORD:-$(openssl rand -hex 16)}"

  echo "Creating stable local codesign identity: ${LOCAL_FORK_IDENTITY_NAME}"
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$tmp_dir/key.pem" -out "$tmp_dir/cert.pem" -days 825 \
    -subj "/CN=${LOCAL_FORK_IDENTITY_NAME}/O=Local Voice Notes/C=US" \
    -addext "basicConstraints=critical,CA:FALSE" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning" >/dev/null 2>&1

  openssl pkcs12 -export -legacy \
    -inkey "$tmp_dir/key.pem" -in "$tmp_dir/cert.pem" \
    -out "$tmp_dir/identity.p12" -passout pass:"${p12_password}" >/dev/null 2>&1

  if ! security import "$tmp_dir/identity.p12" -k "$LOCAL_FORK_KEYCHAIN" \
    -P "${p12_password}" -T /usr/bin/codesign -T /usr/bin/security -A >/dev/null 2>&1; then
    echo "Failed to import codesign identity into the login keychain." >&2
    echo "Unlock Keychain Access, then re-run:" >&2
    echo "  ./scripts/dev/setup_codesign_identity.sh" >&2
    return 1
  fi

  security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
    -k "" "$LOCAL_FORK_KEYCHAIN" >/dev/null 2>&1 || true

  if ! has_stable_codesign_identity; then
    echo "Failed to install codesign identity '${LOCAL_FORK_IDENTITY_NAME}'." >&2
    return 1
  fi

  echo "Installed codesign identity: ${LOCAL_FORK_IDENTITY_NAME}"
  echo "Grant mic / accessibility / screen recording once in the app;"
  echo "future ./scripts/dev/update_local_fork.sh runs should keep them."
  return 0
}

print_apple_development_hint() {
  cat <<EOF
For the most reliable TCC behavior, you can instead use an Apple Development
certificate (free Apple ID + Xcode):

  1. Open Xcode -> Settings -> Accounts -> your Apple ID
  2. Manage Certificates -> + -> Apple Development
  3. Re-run: ./scripts/dev/update_local_fork.sh

Then set MACPARAKEET_CODESIGN_IDENTITY to the "Apple Development: …" name if
the script does not pick it automatically.
EOF
}