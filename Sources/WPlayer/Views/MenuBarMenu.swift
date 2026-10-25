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
        Divider()
        Button("Quit W-Player") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
