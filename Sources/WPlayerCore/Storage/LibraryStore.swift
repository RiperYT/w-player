import Foundation

/// The library folder: `library.json`, the videos and their thumbnails.
/// `~/Library/Application Support/W-Player/{library.json, Videos/, Thumbnails/}`.
public struct LibraryStore: Sendable {
    public let folder: URL

    public init(folder: URL = LibraryStore.defaultFolder) {
        self.folder = folder
    }

    public static var defaultFolder: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("W-Player", isDirectory: true)
    }

    public var libraryFile: URL { folder.appendingPathComponent("library.json") }
    public var videosFolder: URL { folder.appendingPathComponent("Videos", isDirectory: true) }
    public var thumbnailsFolder: URL { folder.appendingPathComponent("Thumbnails", isDirectory: true) }

    public func videoURL(_ wallpaper: Wallpaper) -> URL { videosFolder.appendingPathComponent(wallpaper.fileName) }
    public func thumbnailURL(_ id: UUID) -> URL { thumbnailsFolder.appendingPathComponent("\(id.uuidString).png") }

    public func prepare() throws {
        for url in [folder, videosFolder, thumbnailsFolder] {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// The library, or an empty one when there is none yet. A file this version can't read is moved aside
    /// (`library.json.unreadable-<date>`), never overwritten, and its new place is returned so the app can say so.
    public func load(now: Date = Date()) -> (library: Library, setAside: URL?) {
        guard let data = try? Data(contentsOf: libraryFile) else { return (Library(), nil) }
        do {
            return (try JSONDecoder.library.decode(Library.self, from: data), nil)
        } catch {
            let stamp = ISO8601DateFormatter.string(from: now, timeZone: .current, formatOptions: [.withFullDate, .withTime])
            let aside = folder.appendingPathComponent("library.json.unreadable-\(stamp)")
            try? FileManager.default.moveItem(at: libraryFile, to: aside)
            return (Library(), aside)
        }
    }

    public func save(_ library: Library) throws {
        try prepare()
        try JSONEncoder.library.encode(library).write(to: libraryFile, options: .atomic)
    }

    /// Copies a video into the library under a new id. The caller fills in what `VideoInfo` reads from it.
    public func copyIn(_ source: URL) throws -> Wallpaper {
        try prepare()
        let id = UUID()
        let ext = source.pathExtension.isEmpty ? "mov" : source.pathExtension.lowercased()
        let wallpaper = Wallpaper(id: id, title: WallpaperTitle.from(fileName: source.lastPathComponent),
                                  fileName: "\(id.uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: videoURL(wallpaper))
        return wallpaper
    }

    public func deleteFiles(of wallpaper: Wallpaper) {
        try? FileManager.default.removeItem(at: videoURL(wallpaper))
        try? FileManager.default.removeItem(at: thumbnailURL(wallpaper.id))
    }
}

extension JSONEncoder {
    static var library: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var library: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
