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
                Toggle("Match the system wallpaper to the video", isOn: $model.matchesSystemWallpaper)
                Text("Sets the video's first frame as macOS's own wallpaper, so the menu bar and Mission Control take its colours. Restore Wallpaper and Quit in the menu bar puts back the one you had.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if model.updater.isEnabled { UpdateSettings() }
            Section("Lock Screen") {
                Text("Click the lock on a video (or right-click it and choose Use on Lock Screen). It then shows up in System Settings › Wallpaper under W-Player, where you pick it for the Lock Screen and the screen saver.")
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
