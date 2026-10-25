import AppKit
import Foundation
import IOKit.ps
import WPlayerCore

/// Watches what the wallpaper pauses for: battery power, Low Power Mode, sleeping screens, a locked screen.
/// (Whether the desktop can be seen comes from `DesktopWallpaper`.)
@MainActor
final class SystemMonitor {
    var onChange: ((PlaybackConditions) -> Void)?
    private(set) var conditions = PlaybackConditions()
    private var tokens: [(NotificationCenter, NSObjectProtocol)] = []
    private var powerSource: CFRunLoopSource?

    func start() {
        conditions.onBattery = Self.onBattery()
        conditions.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.screensAsleep = true }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.screensAsleep = false }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.locked = true }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.locked = false }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.locked = true }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.locked = false }
        observe(NotificationCenter.default, .NSProcessInfoPowerStateDidChange) {
            $0.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }

        // IOKit calls a C function when the power source changes; it reaches the monitor through `shared`.
        SystemMonitor.shared = self
        if let source = IOPSNotificationCreateRunLoopSource({ _ in
            DispatchQueue.main.async { SystemMonitor.shared?.update { $0.onBattery = SystemMonitor.onBattery() } }
        }, nil)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        onChange?(conditions)
    }

    private static weak var shared: SystemMonitor?

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ change: @escaping (inout PlaybackConditions) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.update(change) }
        }
        tokens.append((center, token))
    }

    private func update(_ change: (inout PlaybackConditions) -> Void) {
        var next = conditions
        change(&next)
        guard next != conditions else { return }
        conditions = next
        onChange?(conditions)
    }

    static func onBattery() -> Bool {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?
        else { return false }
        return type == kIOPSBatteryPowerValue
    }
}
