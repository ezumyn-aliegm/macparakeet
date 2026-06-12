#!/usr/bin/env bash
set -euo pipefail

MACWHISPER_WHISPERKIT="$HOME/Library/Application Support/MacWhisper/models/whisperkit/models"
MACPARAKEET_WHISPER="$HOME/Library/Application Support/MacParakeet/models/stt/whisper"

if [[ ! -d "$MACWHISPER_WHISPERKIT" ]]; then
  echo "MacWhisper WhisperKit cache not found at:" >&2
  echo "  $MACWHISPER_WHISPERKIT" >&2
  exit 1
fi

mkdir -p "$(dirname "$MACPARAKEET_WHISPER")"

if [[ -e "$MACPARAKEET_WHISPER" && ! -L "$MACPARAKEET_WHISPER" ]]; then
  echo "MacParakeet whisper dir already exists and is not a symlink:" >&2
  echo "  $MACPARAKEET_WHISPER" >&2
  echo "Move it aside, then rerun this script." >&2
  exit 1
fi

ln -sfn "$MACWHISPER_WHISPERKIT" "$MACPARAKEET_WHISPER"

echo "Linked MacParakeet Whisper cache:"
echo "  $MACPARAKEET_WHISPER -> $MACWHISPER_WHISPERKIT"
du -sh "$MACWHISPER_WHISPERKIT"