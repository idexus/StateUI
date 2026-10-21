// The few colors the gallery says for itself.
//
// A color written as a pair - `Color(light:dark:)` - follows the theme: the
// half the system is asking for is picked as the view wearing it is built, and
// a change of theme builds exactly the views wearing one again. So nothing here
// has to know which theme is on, and neither does anything using it - which is
// why every name below is one name rather than two.
//
// The gallery stands in each platform's own look: its pages, bars, sidebar and
// controls are the platform's. What it says for itself is its identity - the
// gradient and the mark - the colors its samples draw with, and neutrals of
// no hue of their own: black let through in the light, white in the dark, so
// they darken or lighten whatever the platform draws behind them.

import StateUI

/// What the gallery draws with: one name per job, each right on both themes.
enum Palette {
    // MARK: Identity

    /// The color a sample marks something with: the gallery's violet, a light
    /// lavender in the dark as the glass's own edge is, deep in the light.
    // listing: Palette.sample
    static let accent = Color(light: AppColors.violet, dark: AppColors.violetLight)
    // listing: end

    /// Swift's orange - a sample's second color beside the accent, the
    /// identity's warm half.
    static let brand = Color(light: AppColors.swiftOrangeDeep, dark: AppColors.swiftOrange)

    /// Text that reads on `accent`: white in both themes, since a near-black
    /// caption on a filled button reads as disabled.
    // listing: Palette.sample
    static let onAccent = Color(light: AppColors.white, dark: AppColors.white)
    // listing: end

    /// What a view marked with the accent stands on: its violet let faintly through.
    static let accentWash = Color(light: Color(hex: 0x512BD4, opacity: 0.08), dark: Color(hex: 0xA78BFA, opacity: 0.14))

    /// Text that reads on `brand` and on the gradient: white in both.
    static let onBrand = AppColors.white

    /// Violet into orange: the two halves of what this library is, in one
    /// mark. The gallery's signature, and deliberately RARE - the home page's
    /// title, and the Materials sample's gradient.
    static let identity = Brush.linearGradient(
        [
            GradientStop(Color(light: AppColors.violet, dark: AppColors.violetDeep), 0),
            GradientStop(Color(light: AppColors.swiftOrangeDeep, dark: AppColors.swiftOrange), 1),
        ],
        startPoint: Point(0, 0),
        endPoint: Point(1, 1))

    // MARK: Text

    /// Text a view has to say the color of again - drawn words, a clock's
    /// hands. Text that says nothing takes the platform's own.
    static let text = Color(light: Color(hex: 0x000000, opacity: 0.85), dark: Color(hex: 0xFFFFFF, opacity: 0.85))

    /// Anything secondary: summaries, captions, the line under a title.
    // listing: Palette.sample
    static let subtle = Color(light: Color(hex: 0x000000, opacity: 0.55), dark: Color(hex: 0xFFFFFF, opacity: 0.55))
    // listing: end

    /// Text and drawings that are not available.
    // listing: Palette.sample
    static let disabled = Color(light: Color(hex: 0x000000, opacity: 0.25), dark: Color(hex: 0xFFFFFF, opacity: 0.25))
    // listing: end

    // MARK: Fills

    /// A panel set apart from the page: a card, a code block. Let through
    /// enough that a window's blur and its tint carry into the panel.
    static let raised = Color(light: Color(hex: 0xFFFFFF, opacity: 0.5), dark: Color(hex: 0x383838, opacity: 0.4))

    /// The edge of a panel: a hairline holding it apart where the page behind
    /// is as light as the panel.
    static let edge = Color(light: Color(hex: 0x000000, opacity: 0.08), dark: Color(hex: 0xFFFFFF, opacity: 0.081))

    /// Behind a sample and its code, and a list of samples: the page
    /// darkened a breath, all else let through - in the dark a fifth, as dark
    /// as the sidebar over the window, and an eighth on Windows, whose
    /// acrylic is deeper.
    #if WINUI
    static let shade = Color(light: Color(hex: 0x000000, opacity: 0.04), dark: Color(hex: 0x000000, opacity: 0.12))
    #else
    static let shade = Color(light: Color(hex: 0x000000, opacity: 0.04), dark: Color(hex: 0x000000, opacity: 0.2))
    #endif

    /// The ground words are typed on: what lies behind lit a breath, all else
    /// let through.
    static let field = Color(light: Color(hex: 0x000000, opacity: 0.05), dark: Color(hex: 0xFFFFFF, opacity: 0.08))

    /// A region set apart within a panel.
    static let well = Color(light: Color(hex: 0x000000, opacity: 0.04), dark: Color(hex: 0xFFFFFF, opacity: 0.04))

    /// Outlines, dividers, the edge of something drawn.
    // listing: Palette.sample
    static let outline = Color(light: Color(hex: 0x000000, opacity: 0.12), dark: Color(hex: 0xFFFFFF, opacity: 0.12))
    // listing: end

    /// Behind the thing you are on - the sidebar's current row, a pad held down.
    static let selected = Color(light: Color(hex: 0x000000, opacity: 0.1), dark: Color(hex: 0xFFFFFF, opacity: 0.12))

    /// Behind the row under the pointer.
    static let hovered = Color(light: Color(hex: 0x000000, opacity: 0.04), dark: Color(hex: 0xFFFFFF, opacity: 0.06))

    // MARK: Roles

    /// The words of an action that destroys something.
    // listing: Palette.sample
    static let danger = Color(light: AppColors.red, dark: AppColors.redLight)

    /// What such an action stands on: its red let faintly through.
    static let dangerWash = Color(light: Color(hex: 0xD92D20, opacity: 0.12), dark: Color(hex: 0xFF8A80, opacity: 0.2))
    // listing: end
}
