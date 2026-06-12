# Local Voice Notes — MacParakeet Fork Setup

Personal fork notes for dictation, meeting transcription, and LAN-only Ollama routing.

**Installed app:** `/Applications/MacParakeet.app`

## First-time setup (new Mac or clone)

```bash
git clone https://github.com/ezumyn-aliegm/macparakeet.git
cd macparakeet
cp integrations/local.env.example .env.local   # optional: customize LAN Ollama host
./scripts/dev/link-macwhisper-models.sh          # optional: reuse MacWhisper Whisper models
./scripts/dev/setup_codesign_identity.sh         # stable cert for Privacy permissions
./scripts/dev/update_local_fork.sh --launch
```

Then in the app: **Settings → Permissions** — grant mic, accessibility, and screen
recording once. Configure AI per [AI provider routing](#ai-provider-routing) below.

## Quick reference

| Task | Command |
|------|---------|
| **One-time codesign cert** | `./scripts/dev/setup_codesign_identity.sh` |
| **Rebuild + install** (canonical) | `./scripts/dev/update_local_fork.sh` |
| Pull upstream + rebuild | `./scripts/dev/update_local_fork.sh --sync-upstream` |
| Fast rebuild (no tests) | `./scripts/dev/update_local_fork.sh --skip-tests --launch` |
| Link MacWhisper Whisper models | `./scripts/dev/link-macwhisper-models.sh` |
| Merge moona3k/macparakeet only | `./scripts/sync-upstream.sh` |
| Debug build (not /Applications) | `./scripts/dev/run_app.sh` |

## LAN Ollama configuration

This fork routes Ollama to a host on your home LAN — not `localhost`. Configure via
**Settings → AI → Ollama** or environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `OLLAMA_DEFAULT_HOST` | Ollama server IP/hostname | `192.168.1.100` (example placeholder) |
| `OLLAMA_LAN_PREFIX` | IPv4 prefix for "on home LAN" detection | `192.168.1.` |
| `OLLAMA_HOST` | Force full base URL (overrides host + LAN check) | unset |

Copy [`local.env.example`](./local.env.example) to `.env.local` at the repo root and
edit for your network. The example IP is a placeholder — replace with your Ollama
server address.

## Permissions across rebuilds

macOS ties Privacy grants to the app’s **codesign identity**, not just its name.
Ad-hoc signing (`-`) changes every build, so mic / accessibility / screen
recording reset after each install.

**One-time setup** (run once per Mac):

```bash
./scripts/dev/setup_codesign_identity.sh
```

This installs a stable keychain certificate: **MacParakeet Local Fork Signing**.
`update_local_fork.sh` runs this automatically before each build.

After switching to the stable identity, **grant permissions once** in the app
(Settings → Permissions). Later `./scripts/dev/update_local_fork.sh` runs should
keep them.

**Best option:** an **Apple Development** cert from Xcode (Settings → Accounts →
Manage Certificates → +). The scripts prefer it automatically when present.

Override manually with `MACPARAKEET_CODESIGN_IDENTITY="Apple Development: …"`.

## Updating the installed app

This fork is **not** updated through Sparkle. Builds from your machine are version **`0.0.0`** (dev sentinel). `SparkleUpdateGuard` blocks update checks so the app is never silently replaced by the official [macparakeet.com](https://macparakeet.com) DMG — that would drop your Ollama/Grok fork settings.

**Canonical workflow** — run from the repo root:

```bash
./scripts/dev/update_local_fork.sh
```

What it does, in order:

1. `setup_codesign_identity.sh` → ensure **MacParakeet Local Fork Signing** cert exists
2. *(optional)* `--sync-upstream` → `git fetch` + merge `upstream/main`
3. `swift test` *(skipped with `--skip-tests`)*
4. `build_app_bundle.sh` → Release `.app` in `dist/`
5. `codesign_app_bundle.sh` → stable sign + `MacParakeet.local.entitlements` (mic + Sparkle load)
6. In-place copy to `/Applications/MacParakeet.app`, remove `dist/` copy (no duplicate Launchpad icon)
7. Verify `codesign --verify --deep --strict`

Script index: [`scripts/dev/README.md`](../scripts/dev/README.md)

Add `--launch` to open the app when finished.

### After each reinstall

- **Permissions** should persist when signed with **MacParakeet Local Fork Signing** (or Apple Development). Only re-grant if you were previously on ad-hoc builds or deleted the keychain cert.
- **First launch** from Finder may require **right-click → Open** once (local/self-signed build).
- **Only one** `/Applications/MacParakeet.app` should exist. The install script deletes `dist/MacParakeet.app` after copy so Spotlight does not list two apps.

### Pull upstream MacParakeet changes

```bash
./scripts/dev/update_local_fork.sh --sync-upstream
```

Resolve merge conflicts if any, then the script builds and installs. Your fork-specific files (Ollama resolver, Grok Local CLI preset, etc.) live on `main` and are preserved unless upstream touches the same lines.

### What is *not* part of local updates

| Official release pipeline | Local fork |
|---------------------------|------------|
| `VERSION=X.Y.Z` + Developer ID sign + notarize | `VERSION` defaults to `0.0.0` |
| R2 DMG + `appcast.xml` on macparakeet.com | No appcast publish |
| Sparkle auto-update | Blocked (`SparkleUpdateGuard`) |
| Menu **Check for Updates** | Shows “Dev builds skip update checks” |

To ship a self-hosted Sparkle channel later you would need your own DMG host, appcast, EdDSA keys, and a non-`0.0.0` version — out of scope for the personal fork workflow.

## Install scripts (internals)

| Script | Role |
|--------|------|
| `scripts/dev/update_local_fork.sh` | **Entry point** — tests, build, install, verify |
| `scripts/dev/install_to_applications.sh` | Build + codesign + `/Applications` copy (called by update script) |
| `scripts/dev/setup_codesign_identity.sh` | One-time stable keychain cert (TCC survives rebuilds) |
| `scripts/dev/codesign_app_bundle.sh` | Inside-out sign with stable identity; `MacParakeet.local.entitlements` |
| `scripts/dev/run_app.sh` | Debug `MacParakeet-Dev.app` in `.build/` (bundle ID `com.macparakeet.dev`) |

Codesign identity: defaults to **MacParakeet Local Fork Signing** (created by
`setup_codesign_identity.sh`). Apple Development from Xcode is preferred when
available. Ad-hoc `-` is **not** used for `/Applications` installs — it resets
Privacy permissions every rebuild.

## STT models

### WhisperKit (reuse MacWhisper cache)

```bash
./scripts/dev/link-macwhisper-models.sh
swift run macparakeet-cli models list --json
```

MacWhisper cache: `~/Library/Application Support/MacWhisper/models/whisperkit/models`

MacParakeet expects: `~/Library/Application Support/MacParakeet/models/stt/whisper`

### Parakeet (FluidAudio — separate download)

MacWhisper's ParakeetKit cache is **not** compatible with MacParakeet's FluidAudio runtime. On first use, MacParakeet downloads ~465 MB of Parakeet CoreML models to FluidAudio's cache under `~/Library/Application Support/FluidAudio/Models/`.

## AI provider routing

| When | Provider | Config |
|------|----------|--------|
| On home LAN (`192.168.1.x` by default) | Ollama @ LAN host | `http://<your-ollama-host>:11434/v1`, model `qwen3:8b` |
| Off LAN | Grok Build (subscription) | Local CLI preset: **Grok Build** |
| Optional backup | xAI API | OpenAI-Compatible → `https://api.x.ai/v1`, `XAI_API_KEY` |

Ollama is **not** probed on `localhost`. Override with `OLLAMA_HOST` only when you mean it.

### Ollama (in-app)

1. Settings → AI → Provider: **Ollama**
2. Base URL: your LAN Ollama host (pre-filled from `OLLAMA_DEFAULT_HOST` or example placeholder)
3. Model: `qwen3:8b` or `gemma4:e4b`
4. Test connection while on home Wi‑Fi

### Grok Build (subscription CLI)

1. Ensure `grok login` has been run (`~/.grok/bin/grok` on PATH)
2. Settings → AI → Provider: **Local CLI**
3. Template: **Grok Build**
4. Command must use `rc=$?` not `status=$?` (zsh read-only variable)
5. Use for meeting Ask / summaries when away from home LAN

### xAI API (optional)

1. Settings → AI → Provider: **OpenAI-Compatible**
2. Base URL: `https://api.x.ai/v1`
3. API key: `XAI_API_KEY` env var or Keychain entry
4. Model: `grok-4.3`

## Troubleshooting

### App does not open after install

Usually a Sparkle Team ID mismatch at launch. Re-run `./scripts/dev/update_local_fork.sh` —
`codesign_app_bundle.sh` signs Sparkle and applies `disable-library-validation` via
`MacParakeet.local.entitlements`.

### Permissions reset after every rebuild

You are on ad-hoc signing or a missing keychain cert. Run:

```bash
./scripts/dev/setup_codesign_identity.sh
./scripts/dev/update_local_fork.sh --launch
```

Grant permissions **once** in Settings → Permissions. Subsequent rebuilds should keep them.

### Microphone denied / app missing in System Settings

The bundle must be signed with a stable identity. Run `setup_codesign_identity.sh` then
`update_local_fork.sh`. Unsigned or ad-hoc-only builds may not appear in System Settings.

### Two MacParakeet icons in Launchpad

Usually a leftover `dist/MacParakeet.app`. The install script removes it; if it reappears after a manual `build_app_bundle.sh`, delete `dist/MacParakeet.app` or rerun the update script.

### Grok Local CLI: `read-only variable: status`

Re-select **Grok Build** template or reinstall — preset uses `rc=$?`.

## Privacy

- STT (Parakeet/WhisperKit) runs on this Mac's Neural Engine — audio never leaves the device
- Only explicit Ask/summary/prompt actions send transcript text to a configured provider
- Disable telemetry: `swift run macparakeet-cli config set telemetry off`

## Useful CLI commands

```bash
swift run macparakeet-cli health --json
swift run macparakeet-cli transcribe meeting.m4a --format json
swift run macparakeet-cli meetings list --json
swift run macparakeet-cli llm summarize transcript.txt --provider cli \
  --command 'tmp=$(mktemp); cat > "$tmp"; grok --verbatim --prompt-file "$tmp"; rc=$?; rm -f "$tmp"; exit $rc'
```

## Sync upstream only (no build)

```bash
./scripts/sync-upstream.sh
```