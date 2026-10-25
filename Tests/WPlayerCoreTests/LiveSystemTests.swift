import AppKit
import Foundation
import Testing
@testable import WPlayerCore

/// Opt-in, on a real Mac with macOS 26: `WPLAYER_LIVE=1 swift test --filter LiveSystemTests`, with W-Player quit (it owns
/// the same category and would take the test's entry out). Changes the real wallpaper list for a few seconds and puts it
/// back. WPLAYER_LIVE_VIDEO picks the video (default: the first one in W-Player's library).
/// The system wallpaper (`SystemWallpaper`) isn't tested here: `NSWorkspace.setDesktopImageURL` from the test process,
/// which isn't an app, neither takes effect nor reads back (2026-10-25); it's checked in the running app instead.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["WPLAYER_LIVE"] == "1"))
struct LiveSystemTests {
    /// The real manifest takes an entry, WallpaperAgent reads it without a decoding error, and taking it out leaves
    /// the file as it was.
    @Test func theLockScreenListTakesAVideoAndGivesItBack() async throws {
        let aerials = LockScreenAerials(backupFolder: FileManager.default.temporaryDirectory)
        try #require(aerials.isAvailable, "no manifest: open System Settings › Wallpaper once")
        let original = try Data(contentsOf: aerials.manifestFile)
        let source = try #require(Self.video(), "no video: set WPLAYER_LIVE_VIDEO or add one to W-Player")
        let id = UUID()
        defer {
            // Whatever happened, the manifest goes back to how it was.
            try? original.write(to: aerials.manifestFile, options: .atomic)
            aerials.removeFiles(id)
            LockScreenAerials.reloadWallpaperAgent()
        }

        try await VideoFile.exportForLockScreen(source, to: aerials.videoURL(id))
        try await VideoFile.writeThumbnail(of: source, to: aerials.thumbnailURL(id))
        let entry = AerialsManifest.Entry(id: id, title: "W-Player live test", video: aerials.videoURL(id),
                                          thumbnail: aerials.thumbnailURL(id))
        #expect(try aerials.sync([entry]).changed)
        let started = Date()
        LockScreenAerials.reloadWallpaperAgent()
        let log = try await Self.aerialsLog(since: started)
        #expect(log.contains("Did update manifest"), "WallpaperAgent didn't load the manifest:\n\(log)")
        #expect(!log.contains("Unable to load"), "\(log)")
        #expect(!log.contains("No aerial categories"), "\(log)")

        try aerials.sync([])
        let after = try JSONSerialization.jsonObject(with: Data(contentsOf: aerials.manifestFile)) as! [String: Any]
        // W-Player's own videos share the category, so the test's sync([]) takes them out too: compare with that.
        let before = AerialsManifest.applying([], to: try JSONSerialization.jsonObject(with: original) as! [String: Any])
        #expect(NSDictionary(dictionary: after).isEqual(to: before))
    }

    /// Index.plist takes W-Player's aerial as the screen saver alone, then as the wallpaper alone, and is put back.
    @MainActor @Test func theScreenSaverAndTheWallpaperAreChosenSeparately() async throws {
        let aerials = LockScreenAerials(backupFolder: FileManager.default.temporaryDirectory)
        try #require(aerials.isAvailable, "no manifest: open System Settings › Wallpaper once")
        let manifest = try Data(contentsOf: aerials.manifestFile)
        let choice = try Data(contentsOf: SystemWallpaper.store)
        let saved = SystemWallpaper.backup
        SystemWallpaper.backup = FileManager.default.temporaryDirectory.appendingPathComponent("Index-\(UUID().uuidString).plist")
        let source = try #require(Self.video(), "no video: set WPLAYER_LIVE_VIDEO or add one to W-Player")
        let id = UUID()
        defer {
            try? choice.write(to: SystemWallpaper.store, options: .atomic)
            try? manifest.write(to: aerials.manifestFile, options: .atomic)
            aerials.removeFiles(id)
            SystemWallpaper.backup = saved
            LockScreenAerials.reloadWallpaperAgent()
        }
        let before = SystemWallpaper.chosenAerials
        try await VideoFile.exportForLockScreen(source, to: aerials.videoURL(id))
        try await VideoFile.writeThumbnail(of: source, to: aerials.thumbnailURL(id))
        try aerials.sync([.init(id: id, title: "W-Player live test", video: aerials.videoURL(id), thumbnail: aerials.thumbnailURL(id))])
        LockScreenAerials.reloadWallpaperAgent()
        try await Task.sleep(for: .seconds(2))

        try SystemWallpaper.chooseAerial(id.uuidString, for: .screenSaver)
        try await Task.sleep(for: .seconds(4))
        #expect(SystemWallpaper.chosenAerials.screenSaver == id.uuidString)
        #expect(SystemWallpaper.chosenAerials.lockScreen == before.lockScreen)

        try SystemWallpaper.chooseAerial(id.uuidString, for: .lockScreen)
        try await Task.sleep(for: .seconds(4))
        #expect(SystemWallpaper.chosenAerials.lockScreen == id.uuidString)
        let log = try await Self.aerialsLog(since: Date().addingTimeInterval(-10))
        #expect(!log.contains("Unable to load"), "\(log)")
    }

    static func video() -> URL? {
        if let path = ProcessInfo.processInfo.environment["WPLAYER_LIVE_VIDEO"] { return URL(fileURLWithPath: path) }
        let videos = LibraryStore().videosFolder
        return (try? FileManager.default.contentsOfDirectory(at: videos, includingPropertiesForKeys: nil))?
            .sorted { $0.path < $1.path }.first
    }

    /// What WallpaperAerialsExtension said about the manifest since `start`, waiting for it to start again.
    static func aerialsLog(since start: Date) async throws -> String {
        try await Task.sleep(for: .seconds(6))
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let log = Process()
        log.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        log.arguments = ["show", "--style", "compact", "--start", formatter.string(from: start.addingTimeInterval(-1)),
                         "--predicate", #"process == "WallpaperAerialsExtension" AND (category == "aerial-assets" OR category == "aerials")"#]
        let pipe = Pipe()
        log.standardOutput = pipe
        try log.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        log.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
