import AppKit
import SwiftUI
import WPlayerCore

/// A menu bar app: the wallpaper keeps moving with no window open. The library window opens from the menu, on the
/// first launch, and when W-Player is opened again from Finder.
@main
struct WPlayerApp: App {
    @State private var model: AppModel
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        let model = AppModel()
        _model = State(initialValue: model)
        AppDelegate.model = model
    }

    var body: some Scene {
        Window("W-Player", id: "library") {
            LibraryView()
                .environment(model)
                .frame(minWidth: 640, minHeight: 420)
        }
        .defaultSize(width: 860, height: 600)
        .defaultLaunchBehavior(model.library.wallpapers.isEmpty ? .presented : .suppressed)

        Settings {
            SettingsView()
                .environment(model)
        }

        MenuBarExtra {
            MenuBarMenu()
                .environment(model)
        } label: {
            MenuBarIcon()
                .environment(model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var model: AppModel?

    /// Opening W-Player again (Finder, Spotlight) shows the library.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        AppDelegate.model?.openLibraryWindow?()
        return false
    }

    /// Videos dropped on the app's icon or opened with it (`open -a W-Player video.mp4`) go into the library.
    func application(_ application: NSApplication, open urls: [URL]) {
        AppDelegate.model?.add(urls)
    }
}

/// The menu bar item. It's always drawn, so it is where the model gets SwiftUI's `openWindow`.
private struct MenuBarIcon: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(systemName: model.pauseReason == nil && model.current != nil ? "play.rectangle.fill" : "play.rectangle")
            .onAppear {
                model.openLibraryWindow = {
                    openWindow(id: "library")
                    NSApp.activate()
                }
            }
    }
}
