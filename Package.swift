// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WPlayer",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "WPlayerCore", targets: ["WPlayerCore"]),
        .executable(name: "WPlayer", targets: ["WPlayer"]),
    ],
    targets: [
        // The library, the playback rules and the Lock Screen manifest. No SwiftUI here.
        .target(
            name: "WPlayerCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The macOS app (SwiftUI + the AppKit desktop windows). Assembled into W-Player.app by scripts/build-app.sh.
        .executableTarget(
            name: "WPlayer",
            dependencies: ["WPlayerCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "WPlayerCoreTests",
            dependencies: ["WPlayerCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
