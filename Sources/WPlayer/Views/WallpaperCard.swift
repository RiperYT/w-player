import SwiftUI
import WPlayerCore

/// One video: its frame, a label strip that says where it is (● DESKTOP · LOCK SCREEN · SCREEN SAVER, as macOS has it),
/// and its title. A click puts it everywhere; the … menu has the other places.
struct WallpaperCard: View {
    @Environment(AppModel.self) private var model
    let wallpaper: Wallpaper
    let rename: () -> Void
    @State private var hovering = false

    private var isCurrent: Bool { model.library.currentID == wallpaper.id }
    private var places: [String] {
        var places: [String] = []
        if isCurrent { places.append(model.pauseReason == nil ? "DESKTOP" : "PAUSED") }
        if model.isOnLockScreen(wallpaper) { places.append("LOCK SCREEN") }
        if model.isScreenSaver(wallpaper) { places.append("SCREEN SAVER") }
        return places
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.place(wallpaper, .everywhere) } label: { frame }
                .buttonStyle(.plain)
                .help("Set as Wallpaper: the desktop and the Lock Screen")
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

            if hovering && !isCurrent {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.white, .black.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if hovering || wallpaper.playsSound {
                cornerButtons
            }
            label
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(isCurrent ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isCurrent ? 2 : 1)
        }
        .shadow(color: .black.opacity(hovering ? 0.18 : 0.08), radius: hovering ? 14 : 6, y: 3)
        .scaleEffect(hovering ? 1.015 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: hovering)
        .onHover { hovering = $0 }
    }

    /// The sound (only for a video that has some) and the … menu, in the top right corner.
    private var cornerButtons: some View {
        HStack(spacing: 6) {
            if wallpaper.hasAudio == true {
                Button { model.setSound(wallpaper, !wallpaper.playsSound) } label: {
                    CornerIcon(symbol: wallpaper.playsSound ? "speaker.wave.2.fill" : "speaker.slash", on: wallpaper.playsSound)
                }
                .buttonStyle(.plain)
                .help(wallpaper.playsSound ? "Mute this video" : "Play this video's sound")
            }
            if hovering {
                Menu {
                    PlacementMenu(wallpaper: wallpaper, rename: rename)
                } label: {
                    CornerIcon(symbol: "ellipsis", on: false)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Where to use this video, and more")
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    /// The strip at the bottom of the frame: where the video is, then its size and length.
    private var label: some View {
        HStack(spacing: 6) {
            if !places.isEmpty {
                Circle().fill(model.pauseReason == nil || !isCurrent ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(places.joined(separator: " · "))
                    .lineLimit(1)
            }
            if wallpaper.playsSound {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 8))
            }
            Spacer(minLength: 4)
            // Two places fill the strip: the length gives way.
            Text((places.count > 1 ? [wallpaper.resolutionLabel] : [wallpaper.resolutionLabel, wallpaper.durationLabel])
                .compactMap { $0 }.joined(separator: " · "))
                .lineLimit(1)
        }
        .font(Theme.label)
        .tracking(0.6)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: Theme.labelHeight)
        .background(.black.opacity(0.55))
    }
}

/// The card's menu: where the video goes, then the rest. The same on right-click and on the … button.
private struct PlacementMenu: View {
    @Environment(AppModel.self) private var model
    let wallpaper: Wallpaper
    let rename: () -> Void

    var body: some View {
        Button("Set as Wallpaper") { model.place(wallpaper, .everywhere) }
        Button("Desktop Only") { model.place(wallpaper, .desktopOnly) }
        Button("Lock Screen Only") { model.place(wallpaper, .lockScreenOnly) }
        Button("Use as Screen Saver") { model.place(wallpaper, .screenSaver) }
            .disabled(!model.aerials.isAvailable)
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
