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
            }
            Section("Wallpaper") {
                Text("Clicking a video puts it on the desktop and makes it macOS's own wallpaper: it moves on the Lock Screen (macOS 26) and the menu bar takes its colours. The … button on a card has Desktop Only, Lock Screen Only and Use as Screen Saver.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Open Wallpaper Settings") { AppModel.openWallpaperSettings() }
                    Spacer()
                    Button("Restore Wallpaper and Quit") { model.restoreAndQuit() }
                        .help("Puts back the wallpaper and screen saver you had before W-Player and takes its videos out of System Settings")
                }
            }
            if model.updater.isEnabled { UpdateSettings() }
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
