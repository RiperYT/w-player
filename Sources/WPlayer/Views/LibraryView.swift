import SwiftUI
import UniformTypeIdentifiers
import WPlayerCore

/// The library: every video as a card. Clicking one puts it on the desktop.
struct LibraryView: View {
    @Environment(AppModel.self) private var model
    @State private var importing = false
    @State private var dropTargeted = false
    @State private var renaming: Wallpaper?
    @State private var newTitle = ""

    var body: some View {
        @Bindable var model = model
        content
            .safeAreaInset(edge: .bottom) { BusyBar() }
            .dropDestination(for: URL.self) { urls, _ in
                let videos = urls.filter { UTType(filenameExtension: $0.pathExtension)?.conforms(to: .movie) == true }
                model.add(videos)
                return !videos.isEmpty
            } isTargeted: { dropTargeted = $0 }
            .overlay {
                if dropTargeted {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                        .padding(8)
                }
            }
            .sheet(isPresented: $model.showsWelcome) { WelcomeView() }
            // A Dock icon (and ⌘-Tab) while the library is open; the menu bar item the rest of the time.
            .onAppear { if model.isLive { NSApp.setActivationPolicy(.regular) } }
            .onDisappear { if model.isLive { NSApp.setActivationPolicy(.accessory) } }
            .toolbar {
                ToolbarItem { FindVideosMenu() }
                ToolbarItem {
                    SettingsLink { Label("Settings", systemImage: "gearshape") }
                        .help("Settings")
                }
                ToolbarItem {
                    Button { model.togglePause() } label: {
                        Label(model.conditions.userPaused ? "Resume" : "Pause",
                              systemImage: model.conditions.userPaused ? "play.fill" : "pause.fill")
                    }
                    .help(model.conditions.userPaused ? "Resume the wallpaper" : "Pause the wallpaper")
                    .disabled(model.current == nil)
                }
                ToolbarItem {
                    Button { importing = true } label: { Label("Add Video", systemImage: "plus") }
                        .help("Add a video to the library")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
                if case .success(let urls) = result { model.add(urls) }
            }
            .alert(item: $model.alert) { alert in
                if let title = alert.actionTitle, let action = alert.action {
                    Alert(title: Text(alert.title), message: Text(alert.message),
                          primaryButton: .default(Text(title), action: action), secondaryButton: .cancel(Text("OK")))
                } else {
                    Alert(title: Text(alert.title), message: Text(alert.message))
                }
            }
            .alert("Rename", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
                TextField("Title", text: $newTitle)
                Button("Rename") { if let renaming { model.rename(renaming, to: newTitle) } }
                Button("Cancel", role: .cancel) {}
            }
    }

    @ViewBuilder private var content: some View {
        if model.library.wallpapers.isEmpty && model.busy.isEmpty {
            ContentUnavailableView {
                Label("No Wallpapers Yet", systemImage: "play.rectangle")
            } description: {
                Text("Drop a video here, or add one. It plays on your desktop, under the icons.")
            } actions: {
                Button("Add Video…") { importing = true }
                FindVideosMenu()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: Theme.tileMinWidth), spacing: Theme.gridSpacing)],
                          spacing: Theme.gridSpacing) {
                    ForEach(model.library.wallpapers) { wallpaper in
                        WallpaperCard(wallpaper: wallpaper) {
                            newTitle = wallpaper.title
                            renaming = wallpaper
                        }
                    }
                }
                .padding(Theme.pagePadding)
            }
        }
    }
}

/// What's being added or prepared right now.
private struct BusyBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let title = model.busy.values.sorted().first {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(model.busy.count > 1 ? "\(title) and \(model.busy.count - 1) more…" : "\(title)…")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .font(.callout)
            .padding(.horizontal, Theme.pagePadding)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}
