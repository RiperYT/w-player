import AppKit
import SwiftUI
import WPlayerCore

/// Debug aid: `WPlayer --render-snapshots <folder>` draws the welcome, the library (empty and with videos) and Settings
/// into PNGs, light and dark, and exits. Nothing real is touched: a throwaway library with drawn frames stands in for the
/// user's, no desktop window opens, and the system wallpaper and the Lock Screen list are left alone. AppKit draws the
/// views in a window far off screen, because `ImageRenderer` draws toggles and forms as placeholders.
@MainActor
enum SnapshotRenderer {
    static func run(into folder: URL) -> Never {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        DispatchQueue.global().asyncAfter(deadline: .now() + 45) {
            FileHandle.standardError.write(Data("WPlayer: rendering took too long, stopped.\n".utf8))
            exit(2)
        }
        let sandbox = FileManager.default.temporaryDirectory.appendingPathComponent("w-player-snapshots-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: sandbox) }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let empty = AppModel(store: LibraryStore(folder: sandbox.appendingPathComponent("empty")), live: false)
            let full = AppModel(store: try sampleLibrary(in: sandbox.appendingPathComponent("full")), live: false)
            full.systemChoice = SystemChoice(lockScreen: full.library.wallpapers[0].id, screenSaver: full.library.wallpapers[1].id)
            let shots: [(String, CGSize?, AnyView)] = [
                ("welcome", nil, AnyView(WelcomeView().environment(empty))),
                ("library-empty", CGSize(width: 860, height: 560), AnyView(LibraryView().environment(empty))),
                ("library", CGSize(width: 860, height: 560), AnyView(LibraryView().environment(full))),
                ("settings", nil, AnyView(SettingsView().environment(full))),
                ("card-menu", nil, AnyView(VStack(alignment: .leading, spacing: 6) {
                    PlacementMenu(wallpaper: full.library.wallpapers[0], rename: {})
                }.toggleStyle(.checkbox).buttonStyle(.borderless).padding(12).environment(full))),
                ("menu", nil, AnyView(VStack(alignment: .leading, spacing: 6) { MenuBarMenu() }
                    .buttonStyle(.borderless).padding(12).environment(full))),
            ]
            var files: [String] = []
            for (name, size, view) in shots {
                for (mode, data) in capture(view, size: size) {
                    let file = folder.appendingPathComponent("\(name)-\(mode).png")
                    try data.write(to: file, options: .atomic)
                    files.append(file.path)
                }
            }
            files.forEach { print($0) }
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("WPlayer: couldn't write the snapshots: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }

    /// Three videos: one on the desktop, one on the Lock Screen, one with sound. Their frames are drawn gradients.
    private static func sampleLibrary(in folder: URL) throws -> LibraryStore {
        let store = LibraryStore(folder: folder)
        try store.prepare()
        let samples: [(String, NSColor, NSColor, Wallpaper)] = [
            ("Rainy bus stop", .systemTeal, .systemIndigo,
             Wallpaper(title: "Rainy bus stop", fileName: "a.mp4", duration: 20, width: 1920, height: 1080)),
            ("Night city", .systemPurple, .black,
             Wallpaper(title: "Night city", fileName: "b.mp4", duration: 31, width: 3840, height: 2160, onLockScreen: true)),
            ("Lofi garden", .systemGreen, .systemYellow,
             Wallpaper(title: "Lofi garden", fileName: "c.mp4", duration: 11, width: 3840, height: 2160, playsSound: true, hasAudio: true)),
        ]
        for (_, top, bottom, wallpaper) in samples {
            let image = NSImage(size: NSSize(width: 640, height: 360), flipped: false) { rect in
                NSGradient(starting: top, ending: bottom)?.draw(in: rect, angle: -90)
                return true
            }
            guard let tiff = image.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else { continue }
            try png.write(to: store.thumbnailURL(wallpaper.id))
        }
        let wallpapers = samples.map(\.3)
        try store.save(Library(wallpapers: wallpapers, currentID: wallpapers[0].id))
        return store
    }

    private static func capture(_ view: AnyView, size: CGSize?) -> [(mode: String, data: Data)] {
        let framed = size.map { AnyView(view.frame(width: $0.width, height: $0.height)) } ?? view
        let host = NSHostingView(rootView: framed.background(Color(nsColor: .windowBackgroundColor)))
        let size = size ?? host.fittingSize
        host.sizingOptions = []
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = host
        window.alphaValue = 0
        window.setFrameOrigin(CGPoint(x: -30_000, y: -30_000))
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        var shots: [(mode: String, data: Data)] = []
        for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            window.appearance = NSAppearance(named: appearance)
            RunLoop.main.run(until: Date().addingTimeInterval(shots.isEmpty ? 0.6 : 0.2))
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            if let data = rep.representation(using: .png, properties: [:]) { shots.append((mode, data)) }
        }
        return shots
    }
}
