import Foundation

/// The files behind `AerialsManifest`: the manifest itself, the movies and thumbnails next to it, and the agent that
/// has to re-read them.
public struct LockScreenAerials: Sendable {
    public let folder: URL
    /// Where the untouched manifest is copied once, before the first change.
    public let backupFolder: URL

    public init(folder: URL = LockScreenAerials.defaultFolder, backupFolder: URL = LibraryStore.defaultFolder) {
        self.folder = folder
        self.backupFolder = backupFolder
    }

    public static var defaultFolder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.apple.wallpaper/aerials", isDirectory: true)
    }

    public var manifestFile: URL { folder.appendingPathComponent("manifest/entries.json") }
    public func videoURL(_ id: UUID) -> URL { folder.appendingPathComponent("videos/\(id.uuidString).mov") }
    public func thumbnailURL(_ id: UUID) -> URL { folder.appendingPathComponent("thumbnails/\(id.uuidString).png") }

    /// macOS 26 keeps its manifest here once System Settings › Wallpaper has loaded Apple's videos. Older macOS has none.
    public var isAvailable: Bool { FileManager.default.fileExists(atPath: manifestFile.path) }

    /// Puts the library's Lock Screen videos into the manifest. Entries whose movie is missing are left out. Returns
    /// whether the file changed (then `reloadWallpaperAgent()`), how many entries weren't in it (at launch, the ones a
    /// macOS update or another app dropped), and how many broken categories it took out (`AerialsManifest.danglingCategories`).
    @discardableResult
    public func sync(_ entries: [AerialsManifest.Entry]) throws -> SyncResult {
        let data = try Data(contentsOf: manifestFile)
        guard let manifest = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let present = entries.filter { FileManager.default.fileExists(atPath: $0.video.path) }
        let before = AerialsManifest.ourAssetIDs(in: manifest)
        let applied = AerialsManifest.applying(present, to: manifest)
        let repaired = AerialsManifest.danglingCategories(in: applied).count
        let updated = AerialsManifest.removingDangling(from: applied)
        guard AerialsManifest.danglingCategories(in: updated).isEmpty else { throw CocoaError(.fileWriteUnknown) }
        guard !NSDictionary(dictionary: manifest).isEqual(to: updated) else { return SyncResult() }

        try backUpOnce(data)
        let out = try JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .withoutEscapingSlashes])
        try out.write(to: manifestFile, options: .atomic)
        return SyncResult(changed: true, restored: present.filter { !before.contains($0.id.uuidString) }.count,
                          repaired: repaired)
    }

    public struct SyncResult: Equatable, Sendable {
        public var changed = false
        public var restored = 0
        public var repaired = 0
    }

    public func removeFiles(_ id: UUID) {
        try? FileManager.default.removeItem(at: videoURL(id))
        try? FileManager.default.removeItem(at: thumbnailURL(id))
    }

    /// WallpaperAgent reads the manifest when it starts; launchd starts it again right away.
    public static func reloadWallpaperAgent() {
        let killall = Process()
        killall.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        killall.arguments = ["WallpaperAgent"]
        try? killall.run()
        killall.waitUntilExit()
    }

    private func backUpOnce(_ data: Data) throws {
        let backup = backupFolder.appendingPathComponent("entries.json.before-w-player")
        guard !FileManager.default.fileExists(atPath: backup.path) else { return }
        try FileManager.default.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        try data.write(to: backup)
    }
}
