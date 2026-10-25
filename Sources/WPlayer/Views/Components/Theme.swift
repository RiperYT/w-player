import SwiftUI

/// Design tokens. Native macOS first: system type, materials and the user's accent colour. The one expressive element
/// is the label strip on each card, in the manner of G-Player's cartridge label: what is playing, its size, its length.
enum Theme {
    static let cardAspect: CGFloat = 16 / 9
    static let cardRadius: CGFloat = 8
    static let tileMinWidth: CGFloat = 230
    static let gridSpacing: CGFloat = 22
    static let pagePadding: CGFloat = 28
    static let labelHeight: CGFloat = 20

    /// The label strip.
    static let label = Font.system(size: 9, weight: .semibold, design: .monospaced)
    static let sectionTitle = Font.system(size: 11, weight: .semibold)
}
