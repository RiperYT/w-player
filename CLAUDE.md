# CLAUDE.md — W-Player

W-Player is a free, open-source macOS app (Apple Silicon, macOS 15+) that plays a video as the desktop wallpaper and,
on macOS 26, offers it for the Lock Screen and the screen saver. Native SwiftUI, Cupertino-minimal. Everything in this
repository is English.

- Maintainers keep a private development wiki next to this repo at `../w-player-wiki`. If it exists, start there:
  `../w-player-wiki/CLAUDE.md`, then `../w-player-wiki/tasks/now.md` (current state and next steps).
- Architecture: `docs/ARCHITECTURE.md`.

## Rules
- `Sources/WPlayerCore` has no SwiftUI. Decisions (the playback rules, the Lock Screen manifest, titles, library
  decoding) are pure functions with tests in `Tests/WPlayerCoreTests` (Swift Testing).
- Views hold no rules: view → `AppModel` → core.
- ❗ macOS's wallpaper manifest (`entries.json`) is shared with macOS and other apps. One category whose
  `representativeAssetID` names no asset makes macOS drop every video wallpaper, Apple's included. Only edit it through
  `AerialsManifest` / `LockScreenAerials.sync`, which never writes such a file; keep its tests passing.
- No telemetry, no accounts. The only network call is Sparkle's update check (GitHub). Videos come from the user's own files.
- UI text: short, plain verbs, says what happens. Native controls and SF Symbols; tokens in `Views/Components/Theme.swift`.
- New Codable fields use `decodeIfPresent` with a default, so an older library.json stays readable.

## Commands
```bash
make test     # unit tests
make app      # build/W-Player.app
make run      # build and open
make release  # disk image into releases/v<VERSION>/
make publish  # release + GitHub release
.build/debug/WPlayer --render-snapshots <folder>          # every window as PNGs, light and dark
WPLAYER_LIVE=1 swift test --filter LiveSystemTests       # the real Lock Screen list, macOS 26, W-Player quit
```

Commits: Conventional Commits (`feat(core): …`, `fix(app): …`, `docs: …`, `test: …`, `chore: …`).
