---
name: local-voice-notes
description: Use when transcribing meetings, dictation history, or MacParakeet meeting artifacts on this Mac. Covers macparakeet-cli, LAN-only Ollama, and Grok subscription fallback.
---

# Local Voice Notes (MacParakeet fork)

## Startup

```bash
cd /path/to/macparakeet
swift run macparakeet-cli health --json
```

## Rebuild /Applications install

```bash
./scripts/dev/setup_codesign_identity.sh   # once per Mac (stable Privacy grants)
./scripts/dev/update_local_fork.sh          # canonical: test + build + install
./scripts/dev/update_local_fork.sh --sync-upstream --launch
```

Sparkle auto-update is disabled for local `0.0.0` builds. Re-run `update_local_fork.sh`
for updates. Permissions persist when signed with the stable local cert — grant once
in Settings → Permissions after first install.

Docs: [integrations/local-setup.md](../local-setup.md) · [scripts/dev/README.md](../../scripts/dev/README.md)

## Provider routing

- **On home LAN:** Ollama at your configured host (`OLLAMA_DEFAULT_HOST`, default example `192.168.1.100:11434`), model `qwen3:8b`
- **Off LAN:** Grok Build via Local CLI (`grok --verbatim --prompt-file` wrapper)
- STT is always local (Parakeet/WhisperKit on this Mac)

## Core commands

```bash
swift run macparakeet-cli meetings list --json
swift run macparakeet-cli meetings transcript "<id>" --format json
swift run macparakeet-cli transcribe "<path-or-url>" --format json
swift run macparakeet-cli prompts run "Action items" --transcription "<id>" --provider cli --command '<grok-wrapper>' --json
```

See [integrations/local-setup.md](../local-setup.md) for full setup.