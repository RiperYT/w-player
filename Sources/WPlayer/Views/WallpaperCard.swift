import SwiftUI
import WPlayerCore

/// One video: its frame, a label strip (● ON DESKTOP · 4K · 0:20), and its title. Click to put it on the desktop.
struct WallpaperCard: View {
    @Environment(AppModel.self) private var model
    let wallpaper: Wallpaper
    let rename: () -> Void
    @State private var hovering = false

    private var isCurrent: Bool { model.library.currentID == wallpaper.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button { model.setCurrent(wallpaper) } label: { frame }
                .buttonStyle(.plain)
                .help(isCurrent ? "On your desktop" : "Set as Wallpaper")
            Text(wallpaper.title)
                .font(.body.weight(.medium))
                .lineLimit(1)
        }
        .contextMenu { menu }
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

    /// The strip at the bottom of the frame: whether it's on the desktop or the Lock Screen, then size and length.
    private var label: some View {
        HStack(spacing: 6) {
            if isCurrent {
                Circle().fill(model.pauseReason == nil ? Color.green : Color.orange).frame(width: 6, height: 6)
                Text(model.pauseReason == nil ? "ON DESKTOP" : "PAUSED")
            }
            if wallpaper.onLockScreen {
                if isCurrent { Text("·") }
                Image(systemName: "lock.fill").font(.system(size: 8))
                Text("LOCK SCREEN")
            }
            Spacer(minLength: 0)
            Text([wallpaper.resolutionLabel, wallpaper.durationLabel].compactMap { $0 }.joined(separator: " · "))
        }
        .font(Theme.label)
        .tracking(0.6)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(height: Theme.labelHeight)
        .background(.black.opacity(0.55))
    }

    @ViewBuilder private var menu: some View {
        Button("Set as Wallpaper") { model.setCurrent(wallpaper) }
            .disabled(isCurrent)
        Toggle("Use on Lock Screen", isOn: Binding(get: { wallpaper.onLockScreen },
                                                   set: { model.setOnLockScreen(wallpaper, $0) }))
        Divider()
        Button("Rename…", action: rename)
        Button("Show in Finder") { model.revealInFinder(wallpaper) }
        Divider()
        Button("Remove from Library", role: .destructive) { model.remove(wallpaper) }
    }
}
