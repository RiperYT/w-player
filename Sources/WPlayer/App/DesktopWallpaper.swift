import AppKit
import AVFoundation
import os

/// `log show --predicate 'subsystem == "io.github.riperyt.wplayer"'`
let log = Logger(subsystem: "io.github.riperyt.wplayer", category: "desktop")

/// The moving desktop: one borderless window per screen at the desktop level, under the icons, on every Space, showing
/// one looping, muted player. macOS itself only animates video wallpapers on the Lock Screen; on the desktop it shows a
/// still frame, so this is how a wallpaper moves there.
@MainActor
final class DesktopWallpaper {
    /// Whether any of the windows can be seen. False under a full-screen app or windows that cover every screen.
    var onVisibilityChange: ((Bool) -> Void)?

    private var windows: [NSWindow] = []
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private(set) var url: URL?
    private var playing = false
    private var observers: [NSObjectProtocol] = []
    private var windowObservers: [NSObjectProtocol] = []

    init() {
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false        // the display may still go to sleep
        player.automaticallyWaitsToMinimizeStalling = false           // local files
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutWindows() }
        })
    }

    /// Shows a video, or takes the windows away for nil.
    func show(_ url: URL?) {
        guard url != self.url else { return }
        self.url = url
        looper?.disableLooping()
        player.removeAllItems()
        looper = nil
        guard let url else {
            closeWindows()
            return
        }
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        layoutWindows()
        if playing { player.play() }
    }

    func setPlaying(_ playing: Bool, speed: Double) {
        if playing != self.playing { log.info("\(playing ? "play" : "pause", privacy: .public) at \(speed, privacy: .public)×") }
        self.playing = playing
        player.defaultRate = Float(speed)
        if playing, url != nil {
            player.play()
        } else {
            player.pause()
        }
    }

    private func layoutWindows() {
        closeWindows()
        guard url != nil else { return }
        windows = NSScreen.screens.map(makeWindow)
        log.info("\(self.url?.lastPathComponent ?? "-", privacy: .public) on \(self.windows.count, privacy: .public) screen(s)")
        reportVisibility()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.setFrame(screen.frame, display: false)
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.hasShadow = false
        window.backgroundColor = .black
        window.contentView = PlayerView(player: player)
        window.orderFront(nil)
        windowObservers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportVisibility() }
        })
        return window
    }

    private func reportVisibility() {
        let visible = windows.contains { $0.occlusionState.contains(.visible) }
        log.debug("desktop visible: \(visible, privacy: .public)")
        onVisibilityChange?(visible)
    }

    private func closeWindows() {
        windowObservers.forEach(NotificationCenter.default.removeObserver)
        windowObservers = []
        for window in windows { window.orderOut(nil) }
        windows = []
    }
}

/// A view whose layer is the player's.
private final class PlayerView: NSView {
    private let playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = NSColor.black.cgColor
        super.init(frame: .zero)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { nil }

    override func makeBackingLayer() -> CALayer { playerLayer }
}
