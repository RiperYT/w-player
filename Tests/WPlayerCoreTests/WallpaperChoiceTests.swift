import Foundation
import Testing
@testable import WPlayerCore

/// Clicking a video makes W-Player's aerial the system wallpaper, so the Lock Screen moves too.
@Suite struct WallpaperChoiceTests {
    let image: [String: Any] = [
        "Content": ["Choices": [["Provider": "com.apple.wallpaper.choice.image", "Files": [Any]()]]],
        "LastSet": Date(timeIntervalSince1970: 0),
    ]
    let saver: [String: Any] = [
        "Content": ["Choices": [["Provider": "com.apple.wallpaper.choice.aerials", "Files": [Any]()]]],
    ]

    private func store() -> [String: Any] {
        [
            "AllSpacesAndDisplays": ["Type": "individual", "Desktop": image, "Idle": saver],
            "SystemDefault": ["Type": "linked", "Linked": saver],
            "Displays": ["37D8832A": ["Type": "individual", "Desktop": image, "Idle": saver]],
            "Spaces": [String: Any](),
        ]
    }

    @Test func everyDesktopGetsTheAerialAndTheScreenSaverStays() throws {
        let chosen = try WallpaperChoice.choosingAerial("11111111-2222-4333-8444-555555555555", in: store())
        #expect(WallpaperChoice.aerialID(in: chosen) == "11111111-2222-4333-8444-555555555555")

        let all = try #require(chosen["AllSpacesAndDisplays"] as? [String: Any])
        #expect(NSDictionary(dictionary: all["Idle"] as! [String: Any]).isEqual(to: saver))
        let display = try #require((chosen["Displays"] as? [String: Any])?["37D8832A"] as? [String: Any])
        #expect(display["Desktop"] != nil)
        #expect((chosen["Spaces"] as? [String: Any])?.isEmpty == true)
    }

    /// One choice for both becomes two, so the screen saver doesn't change with the wallpaper.
    @Test func aLinkedChoiceIsSplit() throws {
        let chosen = try WallpaperChoice.choosingAerial("AAAA", in: store())
        let system = try #require(chosen["SystemDefault"] as? [String: Any])
        #expect(system["Linked"] == nil)
        #expect(system["Type"] as? String == "individual")
        #expect(NSDictionary(dictionary: system["Idle"] as! [String: Any]).isEqual(to: saver))
    }

    /// The screen saver alone: the wallpaper and Lock Screen stay.
    @Test func theScreenSaverAlone() throws {
        let chosen = try WallpaperChoice.choosingAerial("BBBB", for: .screenSaver, in: store())
        #expect(WallpaperChoice.aerialID(in: chosen, for: .screenSaver) == "BBBB")
        #expect(WallpaperChoice.aerialID(in: chosen, for: .lockScreen) == nil)
        let all = try #require(chosen["AllSpacesAndDisplays"] as? [String: Any])
        #expect(NSDictionary(dictionary: all["Desktop"] as! [String: Any]).isEqual(to: image))
        // A linked pair keeps its wallpaper as the Desktop half.
        let system = try #require(chosen["SystemDefault"] as? [String: Any])
        #expect(NSDictionary(dictionary: system["Desktop"] as! [String: Any]).isEqual(to: saver))
    }

    @Test func theConfigurationIsTheBinaryPlistMacOSWrites() throws {
        let chosen = try WallpaperChoice.choosingAerial("AAAA", in: store())
        let all = chosen["AllSpacesAndDisplays"] as! [String: Any]
        let content = (all["Desktop"] as! [String: Any])["Content"] as! [String: Any]
        let choice = (content["Choices"] as! [[String: Any]])[0]
        let data = try #require(choice["Configuration"] as? Data)
        #expect(data.starts(with: Data("bplist00".utf8)))
        #expect(WallpaperChoice.aerialID(in: store()) == nil)
    }
}
