// The gallery's raw colours: the StateUI ramp.
//
// NOT the .NET MAUI template's Colors.xaml. That template is what every MAUI
// app looks like out of the box, and a gallery for this library should look
// like this library rather than like the template - so the palette says what
// the library IS: Swift's orange meeting .NET's violet.
//
// Two decisions carry the whole look, and neither is decoration:
//
//   - THE NEUTRALS ARE TINTED VIOLET, not grey. A #808080 is what an interface
//     has when nobody chose; a neutral carrying a trace of the brand hue reads
//     as one designed thing. It is a few points of blue in every step of the
//     ramp, and it is the difference between the two.
//   - THE ACCENT IS SWIFT'S ORANGE, against a violet ground. Near-complementary,
//     so anything accented separates from what is around it without being made
//     bigger or bolder - and it is the one pairing that says both halves of what
//     this library is.
//
// The interactive orange is DEEPER than Swift's own in the light theme and
// LIGHTER in the dark: white on #F05138 is 3.5:1, which fails WCAG AA for text,
// while #CE3F1C is 4.8:1. The brand orange stays exactly Swift's wherever
// nothing has to be read on top of it.
//
// What the gallery draws with is next door in Palette.swift - these are the raw
// values, named for what they ARE, and nothing outside that file should reach
// for them.

import StateUI

/// Every colour the gallery is built from, named for what it is rather than
/// what it is for.
enum AppColors {
    // MARK: Swift

    /// Swift's own orange, exactly. For where nothing has to be read on it.
    static let swiftOrange = Color.fromArgb("#F05138")

    /// The same hue, deep enough that white text on it passes WCAG AA (4.8:1).
    /// The interactive colour in the light theme.
    static let swiftOrangeDeep = Color.fromArgb("#CE3F1C")

    /// The same hue lifted for a dark background, where full-strength orange is
    /// heavy and where dark text has to read on it.
    static let swiftOrangeLight = Color.fromArgb("#FF8A6B")

    /// The yellow the WINDOW ITSELF is painted with - read off a running
    /// window's minimise button on macOS, which is exactly this. The chrome's
    /// accent, so what can be pressed up there is the colour of the other
    /// things up there that can be pressed.
    ///
    /// It also measures better than the orange did: 5.0:1 against `violet`,
    /// where `swiftOrangeLight` is 3.4:1 and fails AA for text.
    ///
    /// ONE SVG CARRIES THIS HEX BY HAND - `nav_surprise_chrome.svg` - because
    /// artwork cannot read a palette. Change it here and change it there.
    static let windowYellow = Color.fromArgb("#FAC800")

    /// The warm end of the identity gradient.
    static let amber = Color.fromArgb("#FF9E4F")

    // MARK: .NET

    /// .NET's violet, exactly - what MAUI's own templates use.
    static let violet = Color.fromArgb("#512BD4")

    /// The cool end of the identity gradient.
    static let violetDeep = Color.fromArgb("#3A1BA0")

    /// The violet lifted for a dark background.
    static let violetLight = Color.fromArgb("#A78BFA")

    // MARK: Neutrals, light theme
    //
    // Every one of these carries the brand hue. On their own they read as
    // greys; beside a true grey they do not.

    /// Body text: near-black, violet-tinted.
    static let ink = Color.fromArgb("#14121C")

    /// Anything secondary. 6.3:1 on the page behind it.
    static let inkMuted = Color.fromArgb("#5D5872")

    /// Outlines and dividers.
    static let line = Color.fromArgb("#E5E1F0")

    /// The page. Tinted rather than white, which is what lets a white card LIFT
    /// off it without a shadow.
    static let surface = Color.fromArgb("#F7F5FC")

    /// A card, a code block - anything sitting on the page.
    static let raised = Color.fromArgb("#FFFFFF")

    /// Text and controls that are not available.
    static let muted = Color.fromArgb("#B4AEC6")

    /// The row you are on: a violet wash, well clear of both the page and a
    /// card, because "which page is this" has to be answerable at a glance.
    static let selected = Color.fromArgb("#EBE6F9")

    // MARK: Neutrals, dark theme

    /// Body text in the dark.
    static let inkDark = Color.fromArgb("#F4F2FA")

    /// Anything secondary, in the dark. 7.1:1 on the page behind it.
    static let inkMutedDark = Color.fromArgb("#A09AB4")

    /// Outlines and dividers, in the dark.
    static let lineDark = Color.fromArgb("#2C2838")

    /// The page in the dark: violet-black rather than grey-black.
    static let surfaceDark = Color.fromArgb("#0D0B14")

    /// A card in the dark, one step up from the page.
    static let raisedDark = Color.fromArgb("#17141F")

    /// Not available, in the dark.
    static let mutedDark = Color.fromArgb("#4A4459")

    /// The row you are on, in the dark. Lifted well past a card - a step of two
    /// or three points reads as nothing on a screen at low brightness.
    static let selectedDark = Color.fromArgb("#2A2340")

    // MARK: Absolutes

    /// White, for text on the bar and on the accent.
    static let white = Color.fromArgb("#FFFFFF")

    /// Black, for the few places that mean it.
    static let black = Color.fromArgb("#000000")
}
