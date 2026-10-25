import Foundation

/// macOS 26 lists its video wallpapers (the "aerials") in
/// `~/Library/Application Support/com.apple.wallpaper/aerials/manifest/entries.json`. A category and assets added there,
/// with `file://` addresses of local HEVC movies, show up in System Settings › Wallpaper next to Apple's own and play on
/// the Lock Screen and as a screen saver. On the desktop macOS shows them as a still frame.
///
/// The manifest is edited as plain JSON objects so that every key Apple puts there survives untouched.
public enum AerialsManifest {
    /// Our category and its one subcategory. Fixed, so every sync finds and replaces what an earlier one wrote.
    public static let categoryID = "57504C00-0000-4000-8000-000000000001"
    public static let subcategoryID = "57504C00-0000-4000-8000-000000000002"
    public static let categoryName = "W-Player"

    public struct Entry: Equatable, Sendable {
        public var id: UUID
        public var title: String
        public var video: URL
        public var thumbnail: URL

        public init(id: UUID, title: String, video: URL, thumbnail: URL) {
            self.id = id
            self.title = title
            self.video = video
            self.thumbnail = thumbnail
        }
    }

    /// The manifest with exactly `entries` in our category: earlier ones are dropped, other categories and assets kept
    /// as they are. No entries → no category either.
    public static func applying(_ entries: [Entry], to manifest: [String: Any]) -> [String: Any] {
        var manifest = manifest
        let assets = (manifest["assets"] as? [[String: Any]]) ?? []
        let categories = (manifest["categories"] as? [[String: Any]]) ?? []
        var keptAssets = assets.filter { !(($0["categories"] as? [String]) ?? []).contains(categoryID) }
        var keptCategories = categories.filter { ($0["id"] as? String) != categoryID }

        if let first = entries.first {
            let cover: [String: Any] = ["previewImage": first.thumbnail.absoluteString,
                                        "representativeAssetID": first.id.uuidString]
            var subcategory: [String: Any] = ["id": subcategoryID, "localizedNameKey": categoryName,
                                              "localizedDescriptionKey": categoryName, "preferredOrder": 0]
            subcategory.merge(cover) { $1 }
            var category: [String: Any] = ["id": categoryID, "localizedNameKey": categoryName,
                                           "localizedDescriptionKey": categoryName, "preferredOrder": 0,
                                           "subcategories": [subcategory]]
            category.merge(cover) { $1 }
            keptCategories.append(category)
            keptAssets += entries.enumerated().map { index, entry in asset(entry, order: index) }
        }
        manifest["assets"] = keptAssets
        manifest["categories"] = keptCategories
        return manifest
    }

    /// Categories and subcategories whose `representativeAssetID` names no asset. ❗ macOS can't decode a manifest with one
    /// and then shows none of the video wallpapers, Apple's included. It happens when another app (Wallper) rewrites the
    /// file, drops our assets and keeps our category.
    public static func danglingCategories(in manifest: [String: Any]) -> [String] {
        let assets = (manifest["assets"] as? [[String: Any]]) ?? []
        let ids = Set(assets.compactMap { $0["id"] as? String })
        let categories = (manifest["categories"] as? [[String: Any]]) ?? []
        let all = categories + categories.flatMap { ($0["subcategories"] as? [[String: Any]]) ?? [] }
        return all.compactMap { category in
            guard let representative = category["representativeAssetID"] as? String, !ids.contains(representative)
            else { return nil }
            return category["id"] as? String ?? "?"
        }
    }

    /// The manifest without the categories `danglingCategories` finds: what brings Apple's videos back.
    public static func removingDangling(from manifest: [String: Any]) -> [String: Any] {
        let dangling = Set(danglingCategories(in: manifest))
        guard !dangling.isEmpty else { return manifest }
        var manifest = manifest
        let categories = (manifest["categories"] as? [[String: Any]]) ?? []
        manifest["categories"] = categories.compactMap { category -> [String: Any]? in
            if let id = category["id"] as? String, dangling.contains(id) { return nil }
            var category = category
            if let subcategories = category["subcategories"] as? [[String: Any]] {
                category["subcategories"] = subcategories.filter { !dangling.contains($0["id"] as? String ?? "") }
            }
            return category
        }
        return manifest
    }

    /// Ids of our assets in a manifest: after a macOS update rewrites the file, fewer than the library expects.
    public static func ourAssetIDs(in manifest: [String: Any]) -> Set<String> {
        let assets = (manifest["assets"] as? [[String: Any]]) ?? []
        return Set(assets.compactMap { asset in
            (asset["categories"] as? [String] ?? []).contains(categoryID) ? asset["id"] as? String : nil
        })
    }

    /// One asset, in the shape Apple's own entries have. The title goes in `localizedNameKey`: a key macOS finds no
    /// translation for is shown as it is.
    static func asset(_ entry: Entry, order: Int) -> [String: Any] {
        [
            "id": entry.id.uuidString,
            "accessibilityLabel": entry.title,
            "localizedNameKey": entry.title,
            "categories": [categoryID],
            "subcategories": [subcategoryID],
            "includeInShuffle": true,
            "showInTopLevel": true,
            "pointsOfInterest": [String: Any](),
            "preferredOrder": order,
            "previewImage": entry.thumbnail.absoluteString,
            "shotID": "WPLAYER_" + entry.id.uuidString.prefix(8),
            "url-4K-SDR-240FPS": entry.video.absoluteString,
        ]
    }
}
