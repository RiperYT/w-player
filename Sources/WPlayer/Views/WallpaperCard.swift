import SwiftUI
import WPlayerCore

/// One video: its frame with badges for where it is (Desktop, Lock Screen, Screen Saver, as macOS has them), a strip
/// with its size and length, and its title. A click opens the menu of places; so does a right-click.
struct WallpaperCard: View {
    @Environment(AppModel.self) private var model
    let wallpaper: Wallpaper
    let rename: () -> Void
    @State private var hovering = false

    /// Where the video is: the desktop (W-Player's window), and what macOS has as its wallpaper and screen saver.
    private var places: [Place] {
        var places: [Place] = []
        if model.library.currentID == wallpaper.id { places.append(.desktop) }
        if model.isOnLockScreen(wallpaper) { places.append(.lockScreen) }
        if model.isScreenSaver(wallpaper) { places.append(.screenSaver) }
        return places
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                PlacementMenu(wallpaper: wallpaper, rename: rename)
            } label: {
                frame
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .help("Choose where this video goes")
            Text(wallpaper.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
        }
        .contextMenu { PlacementMenu(wallpaper: wallpaper, rename: rename) }
    }

    private var frame: some View {
        ZStack(alignment: .bottom) {
            AsyncImage(url: model.thumbnail(wallpaper)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(.quaternary)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(Theme.cardAspect, contentMode: .fit)
            .clipped()

            if hovering {
                Label("Set as…", systemImage: "rectangle.stack.badge.play")
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            badges
            if wallpaper.hasAudio == true && (hovering || wallpaper.playsSound) {
                soundButton
            }
            strip
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(hovering ? 0.18 : 0.08), radius: hovering ? 14 : 6, y: 3)
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
    }

    /// Top left: one badge per place the video is in, readable at a glance.
    private var badges: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(places, id: \.self) { place in
                HStack(spacing: 4) {
                    Image(systemName: place.symbol)
                    Text(place == .desktop && model.pauseReason != nil ? "Desktop · Paused" : place.name)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.62), in: Capsule())
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Top right, on a video that has sound.
    private var soundButton: some View {
        Button { model.setSound(wallpaper, !wallpaper.playsSound) } label: {
            CornerIcon(symbol: wallpaper.playsSound ? "speaker.wave.2.fill" : "speaker.slash", on: wallpaper.playsSound)
        }
        .buttonStyle(.plain)
        .help(wallpaper.playsSound ? "Mute this video" : "Play this video's sound")
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    /// The strip at the bottom of the frame: size and length.
    private var strip: some View {
        HStack(spacing: 6) {
            if wallpaper.playsSound {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 8))
            }
            Spacer(minLength: 0)
            Text([wallpaper.resolutionLabel, wallpaper.durationLabel].compactMap { $0 }.joined(separator: " · "))
        }
        .lineLimit(1)
        .font(Theme.label)
        .tracking(0.6)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: Theme.labelHeight)
        .background(.black.opacity(0.55))
    }
}

/// A place a video can be. The same symbols on the card and in its menu.
enum Place: Hashable {
    case desktop, lockScreen, screenSaver

    var title: String {
        switch self {
        case .desktop: "DESKTOP"
        case .lockScreen: "LOCK SCREEN"
        case .screenSaver: "SCREEN SAVER"
        }
    }

    var name: String {
        switch self {
        case .desktop: "Desktop"
        case .lockScreen: "Lock Screen"
        case .screenSaver: "Screen Saver"
        }
    }

    var symbol: String {
        switch self {
        case .desktop: "menubar.dock.rectangle"
        case .lockScreen: "lock.fill"
        case .screenSaver: "moon.fill"
        }
    }
}

/// The card's menu: where the video goes, then the rest. The same on right-click and on the … button.
struct PlacementMenu: View {
    @Environment(AppModel.self) private var model
    let wallpaper: Wallpaper
    let rename: () -> Void

    var body: some View {
        let onDesktop = model.library.currentID == wallpaper.id
        let onLockScreen = model.isOnLockScreen(wallpaper)
        let isScreenSaver = model.isScreenSaver(wallpaper)
        Button("Set as Wallpaper") { model.place(wallpaper, .everywhere) }
            .disabled(onDesktop && onLockScreen)
        Section("Show On") {
            // Ticked where the video is now. Unticking the desktop shows macOS's own wallpaper there; the Lock Screen and
            // the screen saver change by picking another video for them.
            Toggle(isOn: Binding(get: { onDesktop }, set: { model.place(wallpaper, $0 ? .desktopOnly : .offDesktop) })) {
                Label("Desktop", systemImage: Place.desktop.symbol)
            }
            Toggle(isOn: Binding(get: { onLockScreen }, set: { if $0 { model.place(wallpaper, .lockScreenOnly) } })) {
                Label("Lock Screen and Menu Bar", systemImage: Place.lockScreen.symbol)
            }
            Toggle(isOn: Binding(get: { isScreenSaver }, set: { if $0 { model.place(wallpaper, .screenSaver) } })) {
                Label("Screen Saver", systemImage: Place.screenSaver.symbol)
            }
            .disabled(!model.aerials.isAvailable)
        }
        Divider()
        if wallpaper.hasAudio == true {
            Toggle("Play Sound", isOn: Binding(get: { wallpaper.playsSound }, set: { model.setSound(wallpaper, $0) }))
        }
        Button("Rename…", action: rename)
        Button("Show in Finder") { model.revealInFinder(wallpaper) }
        Divider()
        Button("Remove from Library", role: .destructive) { model.remove(wallpaper) }
    }
}

/// A small round button face on a card's frame.
private struct CornerIcon: View {
    let symbol: String
    let on: Bool

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 26, height: 26)
            .foregroundStyle(on ? Color.white : Color.primary)
            .background(on ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.regularMaterial), in: Circle())
    }
}
