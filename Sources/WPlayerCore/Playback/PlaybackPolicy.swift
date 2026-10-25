import Foundation

/// What the Mac is doing right now, as far as the wallpaper cares.
public struct PlaybackConditions: Equatable, Sendable {
    public var onBattery = false
    public var lowPowerMode = false
    public var screensAsleep = false
    public var locked = false
    /// No desktop window can be seen: a full-screen app, or windows cover every screen.
    public var desktopHidden = false
    /// The user pressed Pause.
    public var userPaused = false

    public init(onBattery: Bool = false, lowPowerMode: Bool = false, screensAsleep: Bool = false, locked: Bool = false,
                desktopHidden: Bool = false, userPaused: Bool = false) {
        self.onBattery = onBattery
        self.lowPowerMode = lowPowerMode
        self.screensAsleep = screensAsleep
        self.locked = locked
        self.desktopHidden = desktopHidden
        self.userPaused = userPaused
    }
}

public struct PlaybackPreferences: Equatable, Sendable {
    public var pauseOnBattery: Bool
    /// 0.5, 0.75 or 1.
    public var speed: Double

    public init(pauseOnBattery: Bool = false, speed: Double = 1) {
        self.pauseOnBattery = pauseOnBattery
        self.speed = speed
    }

    public static let speeds: [Double] = [0.5, 0.75, 1]
}

/// Why the wallpaper stands still. The menu shows the ones the user should hear about.
public enum PauseReason: Equatable, Sendable {
    case user, lowPowerMode, battery, screensAsleep, locked, desktopHidden

    /// Text for the menu; nil for the pauses nobody notices (asleep, locked, covered).
    public var menuText: String? {
        switch self {
        case .user: "Paused"
        case .lowPowerMode: "Paused in Low Power Mode"
        case .battery: "Paused on Battery"
        case .screensAsleep, .locked, .desktopHidden: nil
        }
    }
}

public enum PlaybackPolicy {
    /// The first reason to stand still, or nil to play. The user's own Pause comes first, then the power ones.
    public static func pauseReason(_ c: PlaybackConditions, _ p: PlaybackPreferences) -> PauseReason? {
        if c.userPaused { return .user }
        if c.lowPowerMode { return .lowPowerMode }
        if c.onBattery && p.pauseOnBattery { return .battery }
        if c.screensAsleep { return .screensAsleep }
        if c.locked { return .locked }
        if c.desktopHidden { return .desktopHidden }
        return nil
    }

    public static func shouldPlay(_ c: PlaybackConditions, _ p: PlaybackPreferences) -> Bool {
        pauseReason(c, p) == nil
    }
}
