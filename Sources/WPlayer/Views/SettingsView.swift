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
            Section("Lock Screen") {
                Text("Right-click a video and choose Use on Lock Screen. It then shows up in System Settings › Wallpaper under W-Player, where you pick it for the Lock Screen and the screen saver.")
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
