import Foundation
import Testing
@testable import WPlayerCore

/// The Lock Screen goes through macOS's own list of video wallpapers. One wrong category there hides all of them.
@Suite struct AerialsManifestTests {
    let manifest: [String: Any]
    let entry = AerialsManifest.Entry(id: UUID(uuidString: "11111111-2222-4333-8444-555555555555")!, title: "Totoro in the rain",
                                      video: URL(fileURLWithPath: "/Users/me/Library/Application Support/x/videos/a.mov"),
                                      thumbnail: URL(fileURLWithPath: "/Users/me/Library/Application Support/x/thumbnails/a.png"))

    init() throws {
        let url = try #require(Bundle.module.url(forResource: "entries", withExtension: "json", subdirectory: "Fixtures"))
        manifest = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func assets(_ m: [String: Any]) -> [[String: Any]] { m["assets"] as? [[String: Any]] ?? [] }
    private func categories(_ m: [String: Any]) -> [[String: Any]] { m["categories"] as? [[String: Any]] ?? [] }

    @Test func addsOneCategoryAndTheAssetsAndKeepsEverythingElse() {
        let updated = AerialsManifest.applying([entry], to: manifest)
        #expect(assets(updated).count == 3)
        #expect(categories(updated).count == 3)
        #expect(updated["localizationVersion"] as? String == "test-1")
        // A key we don't know about stays where Apple put it.
        #expect(assets(updated).first?["group"] as? String == "unknown-key-apple-may-add")
        #expect(AerialsManifest.danglingCategories(in: updated).isEmpty)

        let ours = assets(updated).last!
        #expect(ours["localizedNameKey"] as? String == "Totoro in the rain")
        #expect(ours["categories"] as? [String] == [AerialsManifest.categoryID])
        // Spaces in the path are escaped, the way Apple's file URLs and Wallper's are.
        #expect((ours["url-4K-SDR-240FPS"] as? String)?.hasPrefix("file:///Users/me/Library/Application%20Support/") == true)
    }

    @Test func applyingAgainReplacesInsteadOfAdding() {
        let once = AerialsManifest.applying([entry], to: manifest)
        let twice = AerialsManifest.applying([entry], to: once)
        #expect(NSDictionary(dictionary: once).isEqual(to: twice))
    }

    @Test func noEntriesTakesTheCategoryAwayToo() {
        let added = AerialsManifest.applying([entry], to: manifest)
        let removed = AerialsManifest.applying([], to: added)
        #expect(NSDictionary(dictionary: removed).isEqual(to: manifest))
    }

    @Test func findsOurAssetsAfterARewrite() {
        let added = AerialsManifest.applying([entry], to: manifest)
        #expect(AerialsManifest.ourAssetIDs(in: added) == [entry.id.uuidString])
        #expect(AerialsManifest.ourAssetIDs(in: manifest).isEmpty)
    }

    /// What hid every video wallpaper on 2026-10-25: another app rewrote the file, dropped an asset and kept its category.
    @Test func aCategoryWithoutItsAssetIsFoundAndTakenOut() {
        var broken = manifest
        broken["assets"] = assets(manifest).filter { ($0["id"] as? String)?.hasPrefix("BBBB") != true }
        #expect(AerialsManifest.danglingCategories(in: broken) == ["BBBBBBBB-0000-4000-8000-000000000001"])

        let repaired = AerialsManifest.removingDangling(from: broken)
        #expect(AerialsManifest.danglingCategories(in: repaired).isEmpty)
        #expect(categories(repaired).map { $0["id"] as? String } == ["AAAAAAAA-0000-4000-8000-000000000001"])
    }

    @Test func aBrokenSubcategoryGoesAndItsCategoryStays() {
        var broken = manifest
        var cats = categories(manifest)
        var subs = cats[0]["subcategories"] as! [[String: Any]]
        subs.append(["id": "CCCC", "representativeAssetID": "missing"])
        cats[0]["subcategories"] = subs
        broken["categories"] = cats
        #expect(AerialsManifest.danglingCategories(in: broken) == ["CCCC"])
        let repaired = AerialsManifest.removingDangling(from: broken)
        #expect((categories(repaired)[0]["subcategories"] as? [[String: Any]])?.count == 1)
    }
}
