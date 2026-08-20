// The few colours the gallery says for itself.
//
// A colour written as a pair is MAUI's `{AppThemeBinding Light=…, Dark=…}`: the
// half the system is asking for is picked as the colour is written onto a node,
// and the view that used it is rebuilt when that changes. So nothing here has to
// know which theme is on, and neither does anything using it - which is why
// every name below is one name rather than two.
//
// These are for what a colour is FOR. What it IS is in AppColors beside this,
// and this file is the only one that should read it.

import StateUI

/// What the gallery draws with: one name per job, each right on both themes.
///
/// The styles in `AppStyles` set most of these once, for every control of a
/// type. These are for the places a view says something for itself - a caption
/// that has to be quieter than the text beside it, the fill of a card.
enum Palette {
    // MARK: Brand

    /// The interactive colour: Orange, deepened in the light so white
    /// reads on it and lifted in the dark so it does not glare.
    ///
    /// Complementary to the violet, so an accented thing separates from the
    /// page without also being bigger or bolder than what is around it.
    static let accent = Color(light: AppColors.swiftOrangeDeep, dark: AppColors.swiftOrangeLight)

    /// Violet: the navigation bar, the cool end of the identity. Not an
    /// alternative accent - one interface, one accent.
    static let brand = Color(light: AppColors.violet, dark: AppColors.violetLight)

    /// Text that reads on `accent`. White in BOTH themes, deliberately: a
    /// near-black caption on a filled button reads as DISABLED, and an
    /// affordance the reader misreads costs more than the contrast buys. The
    /// trap is that white on the accent's dark half measures 2.3:1 - a deeper
    /// dark-theme accent is what raises that without darkening the text.
    static let onAccent = Color(light: AppColors.white, dark: AppColors.white)

    /// Text that reads on `brand`, and on the bar. White in both, which is what
    /// lets one toolbar icon be right on both - see `GalleryPage`.
    static let onBrand = AppColors.white

    /// Violet into orange: the two halves of what this library is, in one
    /// mark. The gallery's signature, and deliberately RARE - the flyout header
    /// and the home page's title, and nothing else. A gradient on every surface
    /// is a gradient that says nothing.
    ///
    /// Every stop carries both themes, so the whole brush follows the system the
    /// way a single colour does.
    static let identity = Brush.linearGradient(
        [
            GradientStop(Color(light: AppColors.violet, dark: AppColors.violetDeep), 0),
            GradientStop(Color(light: AppColors.swiftOrangeDeep, dark: AppColors.swiftOrange), 1),
        ],
        startPoint: Point(0, 0),
        endPoint: Point(1, 1))

    // MARK: Text

    /// Ordinary text. The implicit Label style sets this; it is here for the
    /// places that need to say it again - over a filled panel, say.
    static let text = Color(light: AppColors.ink, dark: AppColors.inkDark)

    /// Anything secondary: summaries, captions, the line under a title.
    static let subtle = Color(light: AppColors.inkMuted, dark: AppColors.inkMutedDark)

    /// Text and controls that are not available.
    static let disabled = Color(light: AppColors.muted, dark: AppColors.mutedDark)

    // MARK: Surfaces

    /// The page behind everything. Tinted, not white - which is what lets a
    /// card lift off it with a fill rather than a shadow.
    static let surface = Color(light: AppColors.surface, dark: AppColors.surfaceDark)

    /// One step up from the page: a card, a code block, a panel.
    static let raised = Color(light: AppColors.raised, dark: AppColors.raisedDark)

    /// Outlines, dividers, the edge of a card.
    static let outline = Color(light: AppColors.line, dark: AppColors.lineDark)

    /// Behind the thing you are on - the flyout's current row. A violet wash,
    /// deliberately well clear of both the page and a card: "which page is
    /// this" has to be answerable at a glance, and a step of two or three
    /// points reads as nothing on a dark screen at low brightness.
    static let selected = Color(light: AppColors.selected, dark: AppColors.selectedDark)
}
