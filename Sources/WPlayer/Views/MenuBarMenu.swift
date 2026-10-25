import SwiftUI
import WPlayerCore

struct MenuBarMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let current = model.current {
            Text(current.title)
            if let text = model.pauseReason?.menuText, model.pauseReason != .user {
                Text(text)
            }
            Button(model.conditions.userPaused ? "Resume" : "Pause") { model.togglePause() }
                .keyboardShortcut("p")
        } else {
            Text("No Wallpaper")
        }
        Divider()
        Button("Open Library…") { model.openLibraryWindow?() }
            .keyboardShortcut("l")
        SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
        if model.updater.isEnabled {
            if let version = model.updater.availableVersion {
                Button("Update to \(version) Available…") { model.updater.check() }
            } else {
                Button("Check for Updates…") { model.updater.check() }
                    .disabled(!model.updater.canCheck)
            }
        }
        Button("Welcome to W-Player…") {
            model.showsWelcome = true
            model.openLibraryWindow?()
        }
        Divider()
        Button("Quit W-Player") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
        Button("Restore Wallpaper and Quit") { model.restoreAndQuit() }
            .help("Puts back the wallpaper and screen saver you had before W-Player and takes its videos out of System Settings")
    }
}
