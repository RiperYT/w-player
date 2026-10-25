import SwiftUI
import WPlayerCore

/// The first launch: what W-Player does, that it runs in the background, and the two choices that matter.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome to W-Player").font(.title2.weight(.semibold))
                    Text("Your own video as a moving wallpaper.").foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Point(symbol: "menubar.rectangle", title: "Lives in the menu bar",
                      text: "W-Player keeps running in the background to move your desktop. It's in the menu bar at the top right; its Dock icon shows only while this window is open. Quit it and macOS's own wallpaper comes back.")
                Point(symbol: "leaf", title: "Easy on the battery",
                      text: "The wallpaper stops while the screen is locked or asleep, behind full-screen apps and in Low Power Mode. Video decoding runs on the Mac's media engine.")
                Point(symbol: "speaker.slash", title: "Muted",
                      text: "Videos play without sound. Turn it on for one video from its card.")
                Point(symbol: "lock", title: "Lock Screen too",
                      text: "The video you click becomes macOS's own wallpaper as well: it moves on the Lock Screen (macOS 26) and the menu bar takes its colours. The … button on a card puts a video on one place only, or makes it the screen saver.")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Open W-Player at login", isOn: $model.opensAtLogin)
                Toggle("Pause on battery power", isOn: $model.preferences.pauseOnBattery)
            }

            HStack {
                FindVideosMenu()
                Spacer()
                Button("Get Started") { model.finishWelcome() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 520)
    }
}

private struct Point: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).lineLimit(4)
            }
        }
    }
}

/// Sites with videos that work as wallpapers. Links only: W-Player downloads nothing itself.
struct FindVideosMenu: View {
    static let sites: [(name: String, note: String, url: String)] = [
        ("Pexels", "free videos, free to use", "https://www.pexels.com/videos/"),
        ("Pixabay", "free videos, free to use", "https://pixabay.com/videos/"),
        ("MoeWalls", "anime live wallpapers, fan-made", "https://moewalls.com"),
        ("MotionBGs", "games and anime, fan-made", "https://motionbgs.com"),
    ]

    var body: some View {
        Menu {
            ForEach(Self.sites, id: \.name) { site in
                Link(destination: URL(string: site.url)!) { Text("\(site.name) — \(site.note)") }
            }
            Divider()
            Text("Download a video, then drop it on the W-Player window.")
        } label: {
            Label("Find Videos", systemImage: "safari")
        }
        .fixedSize()
        .help("Sites to download wallpaper videos from")
    }
}
