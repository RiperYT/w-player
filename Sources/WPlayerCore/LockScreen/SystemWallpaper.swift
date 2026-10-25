import AppKit

/// macOS's own wallpaper, under the moving one. The menu bar takes its colour from it, and Mission Control and the
/// moment before W-Player starts show it, so it's set to the video's first frame. macOS keeps the user's choice in
/// `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`; a copy from before W-Player's first change
/// is what "Restore Wallpaper and Quit" puts back.
@MainActor
public enum SystemWallpaper {
    public static var store: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")
    }

    /// Where the copy goes. The live test points it elsewhere so the user's copy stays.
    public static var backup = LibraryStore.defaultFolder.appendingPathComponent("Index.plist.before-w-player")

    public static var hasBackup: Bool { FileManager.default.fileExists(atPath: backup.path) }

    /// Copies the user's wallpaper choice once, before W-Player changes anything.
    public static func backUpOnce() {
        guard !hasBackup, FileManager.default.fileExists(atPath: store.path) else { return }
        try? FileManager.default.createDirectory(at: backup.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? FileManager.default.copyItem(at: store, to: backup)
    }

    /// The image on every screen, filling it like the video does.
    public static func set(_ image: URL) throws {
        backUpOnce()
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        for screen in NSScreen.screens {
            try NSWorkspace.shared.setDesktopImageURL(image, for: screen, options: options)
        }
    }

    /// W-Player's aerial `assetID` as the wallpaper (desktop and Lock Screen) of every space and display
    /// (`WallpaperChoice`), then WallpaperAgent reads it again. The aerial must be in the manifest already.
    public static func chooseAerial(_ assetID: String) throws {
        backUpOnce()
        let data = try Data(contentsOf: store)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let chosen = try WallpaperChoice.choosingAerial(assetID, in: plist)
        try PropertyListSerialization.data(fromPropertyList: chosen, format: .binary, options: 0).write(to: store, options: .atomic)
        LockScreenAerials.reloadWallpaperAgent()
    }

    /// The aerial macOS has as the wallpaper now, if it is one.
    public static var chosenAerialID: String? {
        guard let data = try? Data(contentsOf: store),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return WallpaperChoice.desktopAerialID(in: plist)
    }

    /// Puts back the wallpaper (and screen saver) the user had before W-Player, then forgets the copy so the next change
    /// takes a new one.
    public static func restore() throws {
        guard hasBackup else { return }
        let data = try Data(contentsOf: backup)
        try data.write(to: store, options: .atomic)
        try FileManager.default.removeItem(at: backup)
        LockScreenAerials.reloadWallpaperAgent()
    }
}
