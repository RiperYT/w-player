import Foundation
import Testing
@testable import WPlayerCore

@Suite struct LibraryTests {
    @Test(arguments: [
        ("totoro-in-the-rain-moewalls-com.mp4", "Totoro in the rain"),
        ("lofi_home_garden.mov", "Lofi home garden"),
        ("car.mp4", "Car"),
        ("Night City 4K.mp4", "Night City 4K"),
        ("--.mp4", "--"),
    ])
    func titlesFromFileNames(file: String, title: String) {
        #expect(WallpaperTitle.from(fileName: file) == title)
    }

    @Test func labels() {
        let w = Wallpaper(title: "x", fileName: "x.mp4", duration: 20.23, width: 3840, height: 2160)
        #expect(w.resolutionLabel == "4K")
        #expect(w.durationLabel == "0:20")
        #expect(Wallpaper(title: "x", fileName: "x", duration: 3725, width: 1920, height: 1080).durationLabel == "1:02:05")
        #expect(Wallpaper(title: "x", fileName: "x", width: 1080, height: 1920).resolutionLabel == "1080P")
        #expect(Wallpaper(title: "x", fileName: "x").resolutionLabel == nil)
    }

    /// A field a newer version adds can't make an older library.json unreadable.
    @Test func decodesALibraryWithFieldsMissing() throws {
        let json = #"{"wallpapers":[{"id":"11111111-2222-4333-8444-555555555555","fileName":"a.mp4"}]}"#
        let library = try JSONDecoder.library.decode(Library.self, from: Data(json.utf8))
        #expect(library.wallpapers.first?.title == "a.mp4")
        #expect(library.wallpapers.first?.onLockScreen == false)
        #expect(library.current == nil)
    }

    @Test func savesLoadsAndSetsAnUnreadableFileAside() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = LibraryStore(folder: folder)
        let wallpaper = Wallpaper(title: "Rain", fileName: "a.mp4", duration: 20, onLockScreen: true)
        try store.save(Library(wallpapers: [wallpaper], currentID: wallpaper.id))
        let (loaded, aside) = store.load()
        #expect(aside == nil)
        #expect(loaded.current?.title == "Rain")

        try Data("not json".utf8).write(to: store.libraryFile)
        let (empty, setAside) = store.load()
        #expect(empty.wallpapers.isEmpty)
        let kept = try #require(setAside)
        #expect(try String(contentsOf: kept, encoding: .utf8) == "not json")
    }
}

@Suite struct PlaybackPolicyTests {
    @Test func playsWhenNothingStopsIt() {
        #expect(PlaybackPolicy.shouldPlay(.init(), .init()))
    }

    @Test func batteryOnlyWhenAsked() {
        let onBattery = PlaybackConditions(onBattery: true)
        #expect(PlaybackPolicy.shouldPlay(onBattery, .init(pauseOnBattery: false)))
        #expect(PlaybackPolicy.pauseReason(onBattery, .init(pauseOnBattery: true)) == .battery)
    }

    @Test func theUsersPauseComesFirstThenPower() {
        let all = PlaybackConditions(onBattery: true, lowPowerMode: true, screensAsleep: true, locked: true,
                                     desktopHidden: true, userPaused: true)
        #expect(PlaybackPolicy.pauseReason(all, .init(pauseOnBattery: true)) == .user)
        var c = all
        c.userPaused = false
        #expect(PlaybackPolicy.pauseReason(c, .init(pauseOnBattery: true)) == .lowPowerMode)
    }

    @Test func quietPausesSayNothingInTheMenu() {
        #expect(PauseReason.desktopHidden.menuText == nil)
        #expect(PauseReason.locked.menuText == nil)
        #expect(PauseReason.battery.menuText == "Paused on Battery")
    }
}
