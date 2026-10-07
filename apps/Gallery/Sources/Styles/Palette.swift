// The few colours the gallery says for itself.
//
// A colour written as a pair - `Color(light:dark:)` - follows the theme: the
// half the system is asking for is picked as the view wearing it is built, and
// a change of theme builds exactly the views wearing one again. So nothing here
// has to know which theme is on, and neither does anything using it - which is
// why every name below is one name rather than two.
//
// The gallery stands in each platform's own look: its pages, bars, sidebar and
// controls are the platform's. What it says for itself is its identity - the
// gradient and the mark - the colours its samples draw with, and neutrals of
// no hue of their own: black let through in the light, white in the dark, so
// they darken or lighten whatever the platform draws behind them.

import StateUI

/// What the gallery draws with: one name per job, each right on both themes.
enum Palette {
    // MARK: Identity

    /// The colour a sample marks something with: Orange, deepened in the light
    /// so white reads on it and lifted in the dark so it does not glare.
    // listing: Palette.sample
    static let accent = Color(light: AppColors.swiftOrangeDeep, dark: AppColors.swiftOrangeLight)
    // listing: end

    /// Violet - a sample's second colour beside the accent.
    static let brand = Color(light: AppColors.violet, dark: AppColors.violetLight)

    /// Text that reads on `accent`: white in both themes, since a near-black
    /// caption on a filled button reads as disabled.
    // listing: Palette.sample
    static let onAccent = Color(light: AppColors.white, dark: AppColors.white)
    // listing: end

    /// Text that reads on `brand` and on the gradient: white in both.
    static let onBrand = AppColors.white

    /// Violet into orange: the two halves of what this library is, in one
    /// mark. The gallery's signature, and deliberately RARE - the sidebar header
    /// and the home page's title, and nothing else.
    static let identity = Brush.linearGradient(
        [
            GradientStop(Color(light: AppColors.violet, dark: AppColors.violetDeep), 0),
            GradientStop(Color(light: AppColors.swiftOrangeDeep, dark: AppColors.swiftOrange), 1),
        ],
        startPoint: Point(0, 0),
        endPoint: Point(1, 1))

    // MARK: Text

    /// Text a view has to say the colour of again - drawn words, a clock's
    /// hands. Text that says nothing takes the platform's own.
    static let text = Color(light: Color("#D9000000"), dark: Color("#D9FFFFFF"))

    /// Anything secondary: summaries, captions, the line under a title.
    // listing: Palette.sample
    static let subtle = Color(light: Color("#8C000000"), dark: Color("#8CFFFFFF"))
    // listing: end

    /// Text and drawings that are not available.
    // listing: Palette.sample
    static let disabled = Color(light: Color("#40000000"), dark: Color("#40FFFFFF"))
    // listing: end

    // MARK: Fills

    /// A panel set apart from the page: a card, a code block.
    static let raised = Color(light: Color("#0D000000"), dark: Color("#0FFFFFFF"))

    /// A region set apart within a panel.
    static let well = Color(light: Color("#0A000000"), dark: Color("#0AFFFFFF"))

    /// Outlines, dividers, the edge of something drawn.
    // listing: Palette.sample
    static let outline = Color(light: Color("#1F000000"), dark: Color("#1FFFFFFF"))
    // listing: end

    /// Behind the thing you are on - the sidebar's current row, a pad held down.
    static let selected = Color(light: Color("#1A000000"), dark: Color("#1FFFFFFF"))

    /// Behind the row under the pointer.
    static let hovered = Color(light: Color("#0A000000"), dark: Color("#0FFFFFFF"))
}
