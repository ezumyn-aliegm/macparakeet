#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git remote get-url upstream >/dev/null 2>&1; then
  echo "Missing upstream remote. Add it with:" >&2
  echo "  git remote add upstream https://github.com/moona3k/macparakeet.git" >&2
  exit 1
fi

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "main" ]]; then
  echo "Checkout main before syncing (currently on $current_branch)." >&2
  exit 1
fi

git fetch upstream
git merge --no-edit upstream/main

echo "Synced with upstream/main."