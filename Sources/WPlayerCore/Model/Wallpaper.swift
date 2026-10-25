import Foundation

/// One video in the library. The file itself lives in the library folder (`LibraryStore.videosFolder`).
public struct Wallpaper: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    /// File name inside the library's Videos folder, `<id>.<extension of the original>`.
    public var fileName: String
    public var addedAt: Date
    /// Seconds; 0 when the file couldn't be read.
    public var duration: Double
    public var width: Int
    public var height: Int
    /// Also offered on the Lock Screen and as a screen saver (System Settings › Wallpaper › W-Player).
    public var onLockScreen: Bool
    /// The video's own sound plays. Off unless the user turns it on for this video.
    public var playsSound: Bool
    /// Whether the file has an audio track; nil when not known (added by a version that didn't look).
    public var hasAudio: Bool?

    public init(id: UUID = UUID(), title: String, fileName: String, addedAt: Date = Date(), duration: Double = 0,
                width: Int = 0, height: Int = 0, onLockScreen: Bool = false, playsSound: Bool = false, hasAudio: Bool? = nil) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.addedAt = addedAt
        self.duration = duration
        self.width = width
        self.height = height
        self.onLockScreen = onLockScreen
        self.playsSound = playsSound
        self.hasAudio = hasAudio
    }

    // A field a newer version adds must not make an older library.json unreadable: everything but the identity has a default.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        fileName = try c.decode(String.self, forKey: .fileName)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? fileName
        addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date(timeIntervalSince1970: 0)
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        width = try c.decodeIfPresent(Int.self, forKey: .width) ?? 0
        height = try c.decodeIfPresent(Int.self, forKey: .height) ?? 0
        onLockScreen = try c.decodeIfPresent(Bool.self, forKey: .onLockScreen) ?? false
        playsSound = try c.decodeIfPresent(Bool.self, forKey: .playsSound) ?? false
        hasAudio = try c.decodeIfPresent(Bool.self, forKey: .hasAudio)
    }

    /// "4K", "1440P", "1080P", "720P" or the height, for the label under a card.
    public var resolutionLabel: String? {
        let short = min(width, height)
        guard short > 0 else { return nil }
        switch short {
        case 2160...: return "4K"
        case 1440..<2160: return "1440P"
        case 1080..<1440: return "1080P"
        case 720..<1080: return "720P"
        default: return "\(short)P"
        }
    }

    /// "0:20", "1:05:00".
    public var durationLabel: String? {
        guard duration > 0 else { return nil }
        let total = Int(duration.rounded())
        let (h, m, s) = (total / 3600, total / 60 % 60, total % 60)
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

/// What library.json holds.
public struct Library: Codable, Equatable, Sendable {
    public var wallpapers: [Wallpaper]
    /// The wallpaper on the desktop, if any.
    public var currentID: UUID?

    public init(wallpapers: [Wallpaper] = [], currentID: UUID? = nil) {
        self.wallpapers = wallpapers
        self.currentID = currentID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        wallpapers = try c.decodeIfPresent([Wallpaper].self, forKey: .wallpapers) ?? []
        currentID = try c.decodeIfPresent(UUID.self, forKey: .currentID)
    }

    public var current: Wallpaper? { wallpapers.first { $0.id == currentID } }
}

public enum WallpaperTitle {
    /// A readable title from a downloaded file's name: "totoro-in-the-rain-moewalls-com.mp4" → "Totoro in the rain".
    /// Separators become spaces and a trailing site name ("-moewalls-com", "_example.net") goes.
    public static func from(fileName: String) -> String {
        var name = (fileName as NSString).deletingPathExtension
        name = name.replacingOccurrences(of: #"[-_ .]+[A-Za-z0-9]+[-_.](com|net|org|app|io)$"#, with: "",
                                         options: [.regularExpression, .caseInsensitive])
        name = name.replacingOccurrences(of: #"[-_]+"#, with: " ", options: .regularExpression)
        name = name.split(separator: " ").joined(separator: " ")
        guard let first = name.first else { return (fileName as NSString).deletingPathExtension }
        return first.uppercased() + name.dropFirst()
    }
}
