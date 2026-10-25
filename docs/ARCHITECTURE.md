# Architecture

```
Sources/
  WPlayerCore/            no SwiftUI; tested in Tests/WPlayerCoreTests
    Model/Wallpaper.swift       Wallpaper, Library (library.json), WallpaperTitle
    Storage/LibraryStore.swift  ~/Library/Application Support/W-Player: library.json, Videos/, Thumbnails/
    Playback/PlaybackPolicy.swift  when the wallpaper plays (battery, Low Power Mode, lock, sleep, covered, Pause)
    Media/VideoFile.swift       reads a video (size, length, codec), writes a thumbnail, exports HEVC for the Lock Screen
    LockScreen/AerialsManifest.swift   pure edits of macOS's wallpaper manifest
    LockScreen/LockScreenAerials.swift the manifest's files, sync, restarting WallpaperAgent
  WPlayer/                the app
    App/WPlayerApp.swift        scenes: library window, Settings, menu bar item
    App/AppModel.swift          state and actions; the only place views call
    App/DesktopWallpaper.swift  the desktop windows and the looping player
    App/SystemMonitor.swift     power source, Low Power Mode, lock and sleep notifications
    Views/                      SwiftUI
```

## The desktop

`DesktopWallpaper` opens one borderless window per screen at `CGWindowLevelForKey(.desktopWindow)` (under the icons,
which sit at `.desktopIconWindow`), on all Spaces (`.canJoinAllSpaces`, `.stationary`), ignoring the mouse. All windows
share one `AVQueuePlayer` driven by an `AVPlayerLooper`, muted, with `preventsDisplaySleepDuringVideoPlayback = false`.
Screens are rebuilt on `didChangeScreenParametersNotification`.

Whether to play is one pure function, `PlaybackPolicy.pauseReason(conditions, preferences)`. `SystemMonitor` fills the
conditions from IOKit (power source), `ProcessInfo` (Low Power Mode), `NSWorkspace` (screens asleep, session switch) and
the `com.apple.screenIsLocked` distributed notifications. The windows' occlusion state says whether the desktop can be
seen at all (a full-screen app hides it).

## The Lock Screen

On macOS 26 the system's video wallpapers are listed in
`~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`: `categories` (each with
`subcategories`) and `assets`. An asset's `url-4K-SDR-240FPS` and `previewImage` may be `file://` URLs. WallpaperAgent
reads the file when it starts, so after a change W-Player runs `killall WallpaperAgent` and launchd starts it again.

W-Player owns one category (`57504C00-0000-4000-8000-000000000001`, "W-Player") and its assets. Each sync:

1. exports the movie to `aerials/videos/<id>.mov` if it's missing (HEVC; an HEVC source only changes container, since
   Apple's HEVC presets inflate 10-bit HEVC to gigabytes), and copies the thumbnail to `aerials/thumbnails/<id>.png`;
2. replaces our category and assets (`AerialsManifest.applying`), keeping every other key and entry as it was;
3. removes categories whose `representativeAssetID` names no asset (`removingDangling`). ❗ macOS fails to decode a
   manifest with one and then lists no video wallpapers at all. Another wallpaper app that rewrites the file can leave
   one behind (seen on 2026-10-25);
4. writes only if something changed, after a one-time backup of the original.

`AppModel` syncs at launch and two seconds after any change to the manifest's folder, so entries dropped by a macOS
update or another app come back.
