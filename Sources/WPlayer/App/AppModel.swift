import AppKit
import Foundation
import Observation
import ServiceManagement
import WPlayerCore

/// A message in the middle of the window: what happened and what to do.
struct AppAlert: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    /// An extra button, e.g. "Open Wallpaper Settings".
    var actionTitle: String?
    var action: (() -> Void)?
}

@Observable @MainActor
final class AppModel {
    private(set) var library = Library()
    /// Titles of videos being added or prepared, for the bar under the grid.
    private(set) var busy: [UUID: String] = [:]
    var alert: AppAlert?
    private(set) var conditions = PlaybackConditions()
    /// The welcome sheet: on the first launch, and from the menu.
    var showsWelcome = !UserDefaults.standard.bool(forKey: "welcomeDone")

    /// Set the system wallpaper to the video's first frame, so the menu bar and Mission Control match it.
    var matchesSystemWallpaper: Bool {
        didSet { UserDefaults.standard.set(matchesSystemWallpaper, forKey: "matchesSystemWallpaper") }
    }

    var preferences: PlaybackPreferences {
        didSet {
            UserDefaults.standard.set(preferences.pauseOnBattery, forKey: "pauseOnBattery")
            UserDefaults.standard.set(preferences.speed, forKey: "speed")
            applyPlayback()
        }
    }

    let store: LibraryStore
    /// W-Player's own updates (Sparkle), in a build that carries the release key.
    let updater = AppUpdater()
    let aerials = LockScreenAerials()
    /// False for the snapshot renderer: no desktop windows, no system wallpaper, no Lock Screen, no watching.
    @ObservationIgnored let isLive: Bool
    @ObservationIgnored private let desktop = DesktopWallpaper()
    @ObservationIgnored private let monitor = SystemMonitor()
    @ObservationIgnored private var manifestWatch: DispatchSourceFileSystemObject?
    @ObservationIgnored private var resyncTask: Task<Void, Never>?
    /// Opens the library window; set by the menu bar item, which has SwiftUI's `openWindow`.
    @ObservationIgnored var openLibraryWindow: (() -> Void)?

    init(store: LibraryStore = LibraryStore(), live: Bool = true) {
        self.store = store
        isLive = live
        let defaults = UserDefaults.standard
        matchesSystemWallpaper = defaults.object(forKey: "matchesSystemWallpaper") as? Bool ?? true
        if live { SystemWallpaper.backUpOnce() }
        preferences = PlaybackPreferences(
            pauseOnBattery: defaults.bool(forKey: "pauseOnBattery"),
            speed: defaults.object(forKey: "speed") as? Double ?? 1
        )
        let (loaded, setAside) = store.load()
        library = loaded
        if let setAside {
            alert = AppAlert(title: "The Library Couldn't Be Read",
                             message: "W-Player started with an empty library and kept the old file as \(setAside.lastPathComponent) in \(store.folder.path).")
        }
        guard live else { return }
        desktop.onVisibilityChange = { [weak self] visible in self?.update { $0.desktopHidden = !visible } }
        monitor.onChange = { [weak self] system in
            self?.update {
                let (hidden, paused) = ($0.desktopHidden, $0.userPaused)
                $0 = system
                $0.desktopHidden = hidden
                $0.userPaused = paused
            }
        }
        monitor.start()
        showCurrent()
        // A wallpaper chosen before this version made it the system one (0.1.0 set only a still) gets that once.
        let needsMatch = current.map { defaults.string(forKey: "systemWallpaperID") != $0.id.uuidString } ?? false
        Task {
            if needsMatch, let current { await matchSystemWallpaper(to: current) }
            await resyncLockScreen(atLaunch: true)
        }
        watchManifest()
    }

    // MARK: Playback

    var current: Wallpaper? { library.current }
    var pauseReason: PauseReason? { PlaybackPolicy.pauseReason(conditions, preferences) }

    func setCurrent(_ wallpaper: Wallpaper?) {
        library.currentID = wallpaper?.id
        save()
        showCurrent()
        if let wallpaper { Task { await matchSystemWallpaper(to: wallpaper) } }
    }

    /// Makes the video macOS's own wallpaper too. On macOS 26 that is W-Player's aerial of it: it moves on the Lock Screen
    /// and the menu bar takes its colours. Without the aerials list (older macOS), the video's first frame.
    private func matchSystemWallpaper(to wallpaper: Wallpaper) async {
        guard matchesSystemWallpaper, isLive else { return }
        do {
            if aerials.isAvailable {
                if let index = library.wallpapers.firstIndex(where: { $0.id == wallpaper.id }),
                   !library.wallpapers[index].onLockScreen {
                    library.wallpapers[index].onLockScreen = true
                    save()
                }
                await resyncLockScreen()
                // The export may have failed (resync said so), or another video been clicked meanwhile.
                guard FileManager.default.fileExists(atPath: aerials.videoURL(wallpaper.id).path),
                      library.currentID == wallpaper.id else { return }
                try? await Task.sleep(for: .seconds(2))            // let the agent restarted by the resync settle
                try SystemWallpaper.chooseAerial(wallpaper.id.uuidString)
            } else {
                try await setStill(of: wallpaper)
            }
            UserDefaults.standard.set(wallpaper.id.uuidString, forKey: "systemWallpaperID")
        } catch {
            alert = AppAlert(title: "The System Wallpaper Wasn't Changed", message: error.localizedDescription)
        }
    }

    private func setStill(of wallpaper: Wallpaper) async throws {
        let still = store.stillURL(wallpaper.id)
        if !FileManager.default.fileExists(atPath: still.path) {
            try await VideoFile.writeStill(of: store.videoURL(wallpaper), to: still)
        }
        try SystemWallpaper.set(still)
    }

    func setSound(_ wallpaper: Wallpaper, _ on: Bool) {
        guard let index = library.wallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { return }
        library.wallpapers[index].playsSound = on
        save()
        showCurrent()
    }

    func finishWelcome() {
        UserDefaults.standard.set(true, forKey: "welcomeDone")
        showsWelcome = false
    }

    /// Puts macOS back the way it was before W-Player: the wallpaper and screen saver the user had, no W-Player videos
    /// in System Settings. The library stays for next time.
    func restoreAndQuit() {
        desktop.show(nil, sound: false)
        for index in library.wallpapers.indices { library.wallpapers[index].onLockScreen = false }
        save()
        let listChanged = aerials.isAvailable && ((try? aerials.sync([]))?.changed ?? false)
        for wallpaper in library.wallpapers { aerials.removeFiles(wallpaper.id) }
        if SystemWallpaper.hasBackup {
            do {
                try SystemWallpaper.restore()                  // restarts WallpaperAgent too
            } catch {
                LockScreenAerials.reloadWallpaperAgent()
            }
        } else if listChanged {
            LockScreenAerials.reloadWallpaperAgent()
        }
        NSApp.terminate(nil)
    }

    func togglePause() {
        update { $0.userPaused.toggle() }
    }

    private func update(_ change: (inout PlaybackConditions) -> Void) {
        change(&conditions)
        applyPlayback()
    }

    private func showCurrent() {
        desktop.show(current.map(store.videoURL), sound: current?.playsSound ?? false)
        applyPlayback()
    }

    private func applyPlayback() {
        desktop.setPlaying(PlaybackPolicy.shouldPlay(conditions, preferences), speed: preferences.speed)
    }

    // MARK: Library

    func add(_ urls: [URL]) {
        for url in urls {
            let pending = UUID()
            busy[pending] = WallpaperTitle.from(fileName: url.lastPathComponent)
            Task {
                defer { busy[pending] = nil }
                do {
                    var wallpaper = try store.copyIn(url)
                    let file = store.videoURL(wallpaper)
                    do {
                        let info = try await VideoFile.info(of: file)
                        wallpaper.duration = info.duration
                        wallpaper.width = info.width
                        wallpaper.height = info.height
                        wallpaper.hasAudio = info.hasAudio
                        try await VideoFile.writeThumbnail(of: file, to: store.thumbnailURL(wallpaper.id))
                    } catch {
                        store.deleteFiles(of: wallpaper)
                        throw error
                    }
                    library.wallpapers.append(wallpaper)
                    if library.currentID == nil {
                        setCurrent(wallpaper)
                    } else {
                        save()
                    }
                } catch {
                    alert = AppAlert(title: "\(url.lastPathComponent) Wasn't Added",
                                     message: "W-Player can't play it: \(error.localizedDescription)")
                }
            }
        }
    }

    func rename(_ wallpaper: Wallpaper, to title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let index = library.wallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { return }
        library.wallpapers[index].title = title
        save()
        if wallpaper.onLockScreen { Task { await resyncLockScreen() } }
    }

    func remove(_ wallpaper: Wallpaper) {
        library.wallpapers.removeAll { $0.id == wallpaper.id }
        if library.currentID == wallpaper.id { library.currentID = nil }
        save()
        showCurrent()
        store.deleteFiles(of: wallpaper)
        if wallpaper.onLockScreen {
            Task {
                await resyncLockScreen()
                aerials.removeFiles(wallpaper.id)
            }
        }
    }

    func revealInFinder(_ wallpaper: Wallpaper) {
        NSWorkspace.shared.activateFileViewerSelecting([store.videoURL(wallpaper)])
    }

    func thumbnail(_ wallpaper: Wallpaper) -> URL { store.thumbnailURL(wallpaper.id) }

    private func save() {
        do {
            try store.save(library)
        } catch {
            alert = AppAlert(title: "The Library Wasn't Saved", message: error.localizedDescription)
        }
    }

    // MARK: Lock Screen

    /// Offers the video in System Settings › Wallpaper (for the Lock Screen and the screen saver), or takes it away.
    func setOnLockScreen(_ wallpaper: Wallpaper, _ on: Bool) {
        guard let index = library.wallpapers.firstIndex(where: { $0.id == wallpaper.id }) else { return }
        guard !on || aerials.isAvailable else {
            alert = AppAlert(title: "Lock Screen Isn't Ready",
                             message: "Open System Settings › Wallpaper once and wait until Apple's videos show up, then try again. This needs macOS 26 or later.",
                             actionTitle: "Open Wallpaper Settings", action: Self.openWallpaperSettings)
            return
        }
        library.wallpapers[index].onLockScreen = on
        save()
        let isSystemWallpaper = SystemWallpaper.chosenAerialID == wallpaper.id.uuidString
        Task {
            await resyncLockScreen()
            if on {
                alert = AppAlert(title: "\(wallpaper.title) Is in Wallpaper Settings",
                                 message: "Choose it in System Settings › Wallpaper under W-Player, for example as the screen saver. Clicking a video in W-Player makes it the wallpaper and the Lock Screen by itself.",
                                 actionTitle: "Open Wallpaper Settings", action: Self.openWallpaperSettings)
            } else {
                aerials.removeFiles(wallpaper.id)
                // It was macOS's wallpaper: its first frame takes over, instead of an aerial that is gone.
                if isSystemWallpaper { try? await setStill(of: wallpaper) }
            }
        }
    }

    /// Makes the manifest match the library: prepares missing movies (another app may have deleted them), writes our
    /// category, takes out broken categories, and restarts WallpaperAgent when something changed.
    func resyncLockScreen(atLaunch: Bool = false) async {
        guard aerials.isAvailable else { return }
        let wanted = library.wallpapers.filter(\.onLockScreen)
        for wallpaper in wanted where !FileManager.default.fileExists(atPath: aerials.videoURL(wallpaper.id).path) {
            busy[wallpaper.id] = "Preparing \(wallpaper.title) for the Lock Screen"
            defer { busy[wallpaper.id] = nil }
            do {
                try await VideoFile.exportForLockScreen(store.videoURL(wallpaper), to: aerials.videoURL(wallpaper.id))
            } catch {
                alert = AppAlert(title: "\(wallpaper.title) Isn't on the Lock Screen", message: error.localizedDescription)
            }
        }
        for wallpaper in wanted {
            let thumbnail = aerials.thumbnailURL(wallpaper.id)
            if !FileManager.default.fileExists(atPath: thumbnail.path) {
                try? FileManager.default.copyItem(at: store.thumbnailURL(wallpaper.id), to: thumbnail)
            }
        }
        let entries = wanted.map {
            AerialsManifest.Entry(id: $0.id, title: $0.title, video: aerials.videoURL($0.id), thumbnail: aerials.thumbnailURL($0.id))
        }
        do {
            let result = try aerials.sync(entries)
            if result.changed { LockScreenAerials.reloadWallpaperAgent() }
        } catch {
            if !atLaunch {
                alert = AppAlert(title: "Wallpaper Settings Weren't Updated", message: error.localizedDescription)
            }
        }
    }

    /// Another app (or macOS) rewriting the manifest can drop our videos or leave a broken category, which hides every
    /// video wallpaper. Each change gets a quiet resync a moment later.
    private func watchManifest() {
        let folder = aerials.manifestFile.deletingLastPathComponent()
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.resyncTask?.cancel()
                self.resyncTask = Task {
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    await self.resyncLockScreen(atLaunch: true)
                }
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        manifestWatch = source
    }

    static func openWallpaperSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")!)
    }

    // MARK: Login item

    var opensAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                alert = AppAlert(title: "Open at Login Didn't Change", message: error.localizedDescription)
            }
        }
    }
}
