# W-Player

Your own video as a moving desktop wallpaper on a Mac, for free. W-Player plays it under the desktop icons on every
screen, stops it when nobody sees it, and on macOS 26 also puts it on the Lock Screen and the screen saver.

- **Any video you have.** Drop an MP4 or MOV onto the window (or onto the app's icon) and click it. 4K and HEVC are fine.
- **Under your icons, on every Space.** The video runs muted and looping behind everything, like a real wallpaper.
- **Quiet on power.** It pauses while the screen is locked or asleep, when a full-screen app covers the desktop and in
  Low Power Mode, and on battery power if you want. It never keeps the display awake.
- **Lock Screen too (macOS 26).** A click makes the video macOS's own wallpaper as well, so it moves on the Lock Screen
  and the menu bar takes its colours. The **…** button on a card has **Desktop Only**, **Lock Screen Only** and
  **Use as Screen Saver**.
- **Silent unless you ask**, per video.
- **Restore Wallpaper and Quit** (menu bar, or Settings) puts back the wallpaper and screen saver you had.
- **No account, no telemetry.** W-Player only reads the files you give it, and talks to nothing but GitHub, to see
  whether a newer W-Player is out (Settings › Updates). **Find Videos** links to sites to download from.

## Why the desktop needs an app

macOS plays its video wallpapers only on the Lock Screen and in the screen saver; on the desktop it shows a still frame.
To move on the desktop, a video has to be drawn by an app that keeps running: W-Player puts a window at the desktop
level, below the icons, on each screen. Quit W-Player and the desktop shows macOS's own wallpaper again.

For the Lock Screen, W-Player adds its videos to the list macOS reads its own from
(`~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`), converted to HEVC where needed.
It keeps a copy of that file from before its first change (`~/Library/Application Support/W-Player/entries.json.before-w-player`).
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Download

Get `W-Player-<version>.dmg` from [Releases](https://github.com/RiperYT/w-player/releases) (the same files are kept in
[`releases/`](releases/)). Open it and drag **W-Player** onto **Applications**. The app is signed with a Developer ID and notarized by Apple, so it
opens like any other app. W-Player lives in the menu bar; later versions arrive in the app itself
(**Check for Updates…** in its menu).

**Needs:** a Mac with Apple Silicon, macOS 15 Sequoia or later; macOS 26 Tahoe or later for the Lock Screen.

## Build

```bash
make test   # unit tests
make run    # build build/W-Player.app and open it
.build/debug/WPlayer --render-snapshots /tmp/shots   # draw every window into PNGs, light and dark, without opening any
```

Swift 6 toolchain (Xcode 16 or later). The one dependency is [Sparkle](https://sparkle-project.org) for updates.

## License

Apache License 2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
