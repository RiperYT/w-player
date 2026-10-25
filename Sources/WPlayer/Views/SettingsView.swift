import SwiftUI
import WPlayerCore

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Form {
            Section("Playback") {
                Toggle("Pause on battery power", isOn: $model.preferences.pauseOnBattery)
                Picker("Speed", selection: $model.preferences.speed) {
                    ForEach(PlaybackPreferences.speeds, id: \.self) { speed in
                        Text(speed == 1 ? "Normal" : "\(speed.formatted())×").tag(speed)
                    }
                }
                Text("The wallpaper always stops in Low Power Mode, while the screen is locked or asleep, and when a full-screen app covers the desktop.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Section("General") {
                Toggle("Open at login", isOn: $model.opensAtLogin)
                Toggle("Use the video as the system wallpaper", isOn: $model.matchesSystemWallpaper)
                Text("The video you click also becomes macOS's own wallpaper: it moves on the Lock Screen (macOS 26) and the menu bar takes its colours. Restore Wallpaper and Quit in the menu bar puts back the one you had.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if model.updater.isEnabled { UpdateSettings() }
            Section("Lock Screen") {
                Text("The video on the desktop is on the Lock Screen too. The lock on a card adds another video to System Settings › Wallpaper under W-Player, for example to pick it as the screen saver.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Open Wallpaper Settings") { AppModel.openWallpaperSettings() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct UpdateSettings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var updater = model.updater
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
            Text("W-Player asks GitHub whether a newer version is out. The request says which W-Player you have; nothing else is sent.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
