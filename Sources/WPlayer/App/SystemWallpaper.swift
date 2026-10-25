import AppKit
import WPlayerCore

/// macOS's own wallpaper, under the moving one. The menu bar takes its colour from it, and Mission Control and the
/// moment before W-Player starts show it, so it's set to the video's first frame. macOS keeps the user's choice in
/// `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`; a copy from before W-Player's first change
/// is what "Restore Wallpaper and Quit" puts back.
@MainActor
enum SystemWallpaper {
    static var store: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }

    static var backup: URL { LibraryStore.defaultFolder.appendingPathComponent("Index.plist.before-w-player") }

    static var hasBackup: Bool { FileManager.default.fileExists(atPath: backup.path) }

    /// Copies the user's wallpaper choice once, before W-Player changes anything.
    static func backUpOnce() {
        guard !hasBackup, FileManager.default.fileExists(atPath: store.path) else { return }
        try? FileManager.default.createDirectory(at: LibraryStore.defaultFolder, withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: store, to: backup)
    }

    /// The image on every screen, filling it like the video does.
    static func set(_ image: URL) throws {
        backUpOnce()
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: options)
        }
    }

    /// Puts back the wallpaper (and screen saver) the user had before W-Player, then forgets the copy so the next change
    /// takes a new one.
    static func restore() throws {
        guard hasBackup else { return }
        let data = try Data(contentsOf: backup)
        try data.write(to: store, options: .atomic)
        try FileManager.default.removeItem(at: backup)
        LockScreenAerials.reloadWallpaperAgent()
    }
}
