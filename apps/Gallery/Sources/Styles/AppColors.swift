// The gallery's raw colors: Swift's orange against a deep violet - the
// identity the gradient and the mark carry, and the colors its samples draw
// with. Everything else the gallery stands on is the platform's own, its
// accent the one in force.
//
// What the gallery draws with is next door in Palette.swift - these are the raw
// values, named for what they ARE, and almost everything reaches them through
// that file; the colors that must not follow the theme, and a sample showing a
// color of its own, read them directly.

import StateUI

/// Every color the gallery is built from, named for what it is rather than
/// what it is for.
enum AppColors {
    // MARK: Swift

    /// Swift's own orange, exactly. For where nothing has to be read on it.
    static let swiftOrange = Color(hex: 0xF05138)

    /// The same hue, deep enough that white text on it passes WCAG AA (4.8:1)
    /// - the identity gradient's warm end in the light.
    static let swiftOrangeDeep = Color(hex: 0xCE3F1C)

    /// A warm yellow - the dark half of the color the Transforms sample marks
    /// a size with.
    static let windowYellow = Color(hex: 0xFAC800)

    /// A warm amber - the light half of the color the Transforms sample marks
    /// a size with.
    static let amber = Color(hex: 0xFF9E4F)

    // MARK: Violet

    /// The brand violet - the start of the identity gradient, and a bar the
    /// Colors window paints violet.
    static let violet = Color(hex: 0x512BD4)

    /// The cool end of the identity gradient.
    static let violetDeep = Color(hex: 0x3A1BA0)

    /// The violet lifted for a dark background.
    static let violetLight = Color(hex: 0xA78BFA)

    // MARK: Red

    /// The red of an action that destroys something.
    static let red = Color(hex: 0xD92D20)

    /// The red lifted for a dark background.
    static let redLight = Color(hex: 0xFF8A80)

    // MARK: Sample colors

    /// A near-black ink, violet-tinted - what the animated caption starts in.
    static let ink = Color(hex: 0x14121C)

    /// A deep violet-gray - what the animated panel starts in.
    static let lineDark = Color(hex: 0x352F55)

    // MARK: Absolutes

    /// White, for text on a painted bar, the gradient and the accent.
    static let white = Color(hex: 0xFFFFFF)
}
