// The gallery's raw colours: Swift's orange against a deep violet - the
// identity the gradient and the mark carry, and the colours its samples draw
// with. Everything else the gallery stands on is the platform's own.
//
// The interactive orange is DEEPER than Swift's own in the light theme and
// LIGHTER in the dark: white on #F05138 is 3.5:1, which fails WCAG AA for text,
// while #CE3F1C is 4.8:1. The brand orange stays exactly Swift's wherever
// nothing has to be read on top of it.
//
// What the gallery draws with is next door in Palette.swift - these are the raw
// values, named for what they ARE, and almost everything reaches them through
// that file; the colours that must not follow the theme, and a sample showing a
// colour of its own, read them directly.

import StateUI

/// Every colour the gallery is built from, named for what it is rather than
/// what it is for.
enum AppColors {
    // MARK: Swift

    /// Swift's own orange, exactly. For where nothing has to be read on it.
    static let swiftOrange = Color("#F05138")

    /// The same hue, deep enough that white text on it passes WCAG AA (4.8:1).
    /// The interactive colour in the light theme.
    static let swiftOrangeDeep = Color("#CE3F1C")

    /// The same hue lifted for a dark background, where full-strength orange is
    /// heavy. White text on it measures 2.3:1 - `Palette.onAccent` says why the
    /// caption stays white regardless.
    static let swiftOrangeLight = Color("#FF8A6B")

    /// A warm yellow - the dark half of the colour the Transforms sample marks
    /// a size with.
    static let windowYellow = Color("#FAC800")

    /// A warm amber - the light half of the colour the Transforms sample marks
    /// a size with.
    static let amber = Color("#FF9E4F")

    // MARK: Violet

    /// The brand violet - the start of the identity gradient, and a bar the
    /// Colours window paints violet.
    static let violet = Color("#512BD4")

    /// The cool end of the identity gradient.
    static let violetDeep = Color("#3A1BA0")

    /// The violet lifted for a dark background.
    static let violetLight = Color("#A78BFA")

    // MARK: Sample colours

    /// A near-black ink, violet-tinted - what the animated caption starts in.
    static let ink = Color("#14121C")

    /// A deep violet-grey - what the animated panel starts in.
    static let lineDark = Color("#352F55")

    // MARK: Absolutes

    /// White, for text on a painted bar, the gradient and the accent.
    static let white = Color("#FFFFFF")
}
