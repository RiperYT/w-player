import Foundation

/// macOS keeps the user's wallpaper choice in `~/Library/Application Support/com.apple.wallpaper/Store/Index.plist`:
/// `AllSpacesAndDisplays` and `SystemDefault` (and per display or Space under `Displays` and `Spaces`), each with a
/// `Desktop` (the wallpaper, which is also the Lock Screen) and an `Idle` (the screen saver), or one `Linked` choice for
/// both. A choice is a provider and a configuration; an aerial is `com.apple.wallpaper.choice.aerials` with a binary
/// plist `{assetID}`. Choosing W-Player's aerial there is what makes the Lock Screen move with the desktop's video.
/// (2026-10-25, macOS 26.4: written while WallpaperAgent runs, then `killall WallpaperAgent`, the choice holds.)
public enum WallpaperChoice {
    public static let aerialsProvider = "com.apple.wallpaper.choice.aerials"

    public enum Slot: String, Sendable {
        /// The wallpaper: the Lock Screen and, under W-Player's window, the desktop. The menu bar takes its colours.
        case lockScreen = "Desktop"
        case screenSaver = "Idle"
    }

    /// The store with the aerial `assetID` in `slot` everywhere a choice is kept. The other slot stays as it was: a
    /// `Linked` choice is split into `Desktop` and `Idle` first.
    public static func choosingAerial(_ assetID: String, for slot: Slot = .lockScreen, in store: [String: Any],
                                      now: Date = Date()) throws -> [String: Any] {
        let configuration = try PropertyListSerialization.data(fromPropertyList: ["assetID": assetID], format: .binary, options: 0)
        let choice: [String: Any] = [
            "Content": [
                "Choices": [["Provider": aerialsProvider, "Configuration": configuration, "Files": [Any]()]],
                "Shuffle": "$null",
                "EncodedOptionValues": "$null",
            ],
            "LastSet": now,
            "LastUse": now,
        ]
        return rewritten(store) { entry in
            var entry = entry
            if let linked = entry["Linked"] {
                entry["Desktop"] = linked
                entry["Idle"] = linked
                entry["Linked"] = nil
                entry["Type"] = "individual"
            }
            entry[slot.rawValue] = choice
            return entry
        }
    }

    /// The aerial chosen in `slot` for all spaces and displays, if it is one.
    public static func aerialID(in store: [String: Any], for slot: Slot = .lockScreen) -> String? {
        guard let all = store["AllSpacesAndDisplays"] as? [String: Any],
              let choice = (all[slot.rawValue] ?? all["Linked"]) as? [String: Any],
              let content = choice["Content"] as? [String: Any],
              let first = (content["Choices"] as? [[String: Any]])?.first,
              first["Provider"] as? String == aerialsProvider,
              let data = first["Configuration"] as? Data,
              let configuration = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return nil }
        return configuration["assetID"] as? String
    }

    /// Applies `change` to every entry that holds a wallpaper choice: the top two, and each display and Space.
    static func rewritten(_ store: [String: Any], _ change: ([String: Any]) -> [String: Any]) -> [String: Any] {
        func walk(_ value: Any) -> Any {
            guard var dict = value as? [String: Any] else { return value }
            if dict["Desktop"] != nil || dict["Idle"] != nil || dict["Linked"] != nil { return change(dict) }
            for (key, child) in dict { dict[key] = walk(child) }
            return dict
        }
        return walk(store) as? [String: Any] ?? store
    }
}
