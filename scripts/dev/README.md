# Dev scripts — personal MacParakeet fork

> Full guide: [`integrations/local-setup.md`](../../integrations/local-setup.md)

## Canonical command

```bash
./scripts/dev/update_local_fork.sh
```

Rebuilds the fork, signs with a **stable keychain identity** (so Privacy
permissions survive across installs), and copies to `/Applications/MacParakeet.app`.

| Flag | Effect |
|------|--------|
| `--sync-upstream` | Merge `upstream/main` before building |
| `--skip-tests` | Skip `swift test` (faster, not recommended for release-quality installs) |
| `--launch` | `open -a MacParakeet` when done |

## Script map

| Script | Purpose |
|--------|---------|
| `update_local_fork.sh` | **Start here** — test, build, install, verify |
| `setup_codesign_identity.sh` | One-time stable cert (`MacParakeet Local Fork Signing`); auto-run by update script |
| `install_to_applications.sh` | Build + sign + copy to `/Applications` |
| `codesign_app_bundle.sh` | Inside-out codesign with local entitlements |
| `codesign_identity.sh` | Shared identity helpers (sourced, not run directly) |
| `run_app.sh` | Debug `MacParakeet-Dev.app` (`com.macparakeet.dev`, not `/Applications`) |
| `link-macwhisper-models.sh` | Symlink MacWhisper WhisperKit cache into MacParakeet |
| `reset_and_run_fresh.sh` | Reset dev-bundle TCC + onboarding for manual QA |

## Environment

| Variable | Default | Notes |
|----------|---------|-------|
| `MACPARAKEET_CODESIGN_IDENTITY` | `MacParakeet Local Fork Signing` | Prefer Apple Development from Xcode when available |
| `LOCAL_FORK_P12_PASSWORD` | *(random per setup)* | Optional override for keychain import |
| `INSTALL_NAME` | `MacParakeet` | `/Applications/<name>.app` |
| `REQUIRE_STABLE_CODESIGN` | `1` in install path | Refuses ad-hoc `-` (resets TCC every build) |
| `OLLAMA_DEFAULT_HOST` | `192.168.1.100` | LAN Ollama server (app runtime; see `integrations/local.env.example`) |
| `OLLAMA_LAN_PREFIX` | `192.168.1.` | Home LAN detection prefix |

## Not Sparkle

Local builds are version `0.0.0`. `SparkleUpdateGuard` blocks auto-update so the
official macparakeet.com DMG never replaces this fork. Re-run `update_local_fork.sh`
for updates.