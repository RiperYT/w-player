import AppKit
import Foundation
import WPlayerCore
import Observation
import Sparkle

/// W-Player's own updates, by Sparkle: it asks GitHub for the appcast, shows its own windows and installs a new version over
/// this one. Sparkle only exists here, and only runs, in a build that carries the key the releases are signed with
/// (`SelfUpdate.isEnabled`): a development build never looks for updates.
///
/// W-Player lives in the menu bar, so Sparkle's window would open behind other apps: W-Player comes to the front before it
/// shows, and a found update also waits in the menu ("Update to … Available") until the user has looked at it.
@MainActor @Observable
final class AppUpdater: NSObject, SPUUpdaterDelegate, @preconcurrency SPUStandardUserDriverDelegate {   // Sparkle calls it on the main thread
    /// Sparkle's controller; nil in a build that doesn't update itself.
    @ObservationIgnored private var controller: SPUStandardUpdaterController?
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    /// This build updates itself (the menu item and the Settings toggle only exist then).
    private(set) var isEnabled = false
    /// Sparkle can start a check now (not while one is already showing).
    private(set) var canCheck = false
    /// A newer version Sparkle found and the user hasn't looked at yet, for the menu.
    private(set) var availableVersion: String?
    /// Checks in the background by itself. Sparkle keeps the answer, and asks for it once itself, the second time W-Player opens.
    var automaticallyChecks = false {
        didSet {
            guard let updater = controller?.updater, updater.automaticallyChecksForUpdates != automaticallyChecks else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecks
        }
    }

    /// Starts Sparkle when the bundle has the key; does nothing otherwise.
    func start() {
        let key = Bundle.main.object(forInfoDictionaryKey: SelfUpdate.publicKeyInfoKey) as? String
        guard controller == nil, SelfUpdate.isEnabled(publicKey: key) else { return }
        let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: self)
        self.controller = controller
        isEnabled = true
        let updater = controller.updater
        canCheck = updater.canCheckForUpdates
        automaticallyChecks = updater.automaticallyChecksForUpdates
        observations = [
            updater.observe(\.canCheckForUpdates) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
            },
            updater.observe(\.automaticallyChecksForUpdates) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.automaticallyChecks = updater.automaticallyChecksForUpdates }
            },
        ]
    }

    /// "Check for Updates…": shows Sparkle's window, with the answer, in front.
    func check() {
        NSApp.activate()
        controller?.checkForUpdates(nil)
    }

    // MARK: SPUStandardUserDriverDelegate

    /// A background app has to say it handles updates found by the scheduled check (Sparkle's "gentle reminders").
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle shows its window itself; W-Player only makes sure it's in front and keeps a note in the menu.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        true
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        availableVersion = update.displayVersionString
        NSApp.activate()
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        availableVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        availableVersion = nil
    }
}
