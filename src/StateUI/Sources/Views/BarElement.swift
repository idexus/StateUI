// The bar a page ARRANGEMENT draws over its pages.
//
// Its own file rather than a block in Elements.swift, and the reason is a rule
// two tests keep: Elements.swift is the tier every VIEW shares, exactly, and
// `testTheSharedTierIsCoveredOnce` compares the properties declared there
// against the shared set. A bar is not a view's - it belongs to whatever
// arranges pages - so it is a tier of its own, beside them rather than among
// them.

/// The bar over a stack or a set of tabs.
/// MAUI: IBarElement - the interface `NavigationPage` and `TabbedPage` both
/// implement, and the one place MAUI declares the three properties that paint
/// that bar.
///
/// They belong to the ARRANGEMENT rather than to a page on it: the bar looks
/// the same whichever page is showing. What one PAGE asks of the bar - to be
/// hidden, to carry a view instead of its title, to colour the back arrow
/// differently - is an ATTACHED property written on the page; those are the
/// `navigationPage` properties on `Page`, in Views/Application.swift.
///
/// Declared here rather than on `NavigationPage` for the reason every tier in
/// this library exists: `TabbedPage` carries the same three, and a copy on each
/// would be two places to fix one thing.
public protocol BarElement: PropertyContainer {}

extension BarElement {
    /// What the bar is painted, in one flat colour.
    /// MAUI: BarBackgroundColor.
    ///
    ///     NavigationPage($path) {
    ///         HomePage()
    ///     } destination: { route in
    ///         DetailPage(route)
    ///     }
    ///     .barBackgroundColor(.cornflowerBlue)
    ///     .barTextColor(.white)
    ///
    /// Write this or `barBackground`, not both: MAUI lets the brush win
    /// wherever a bar is given the two.
    public func barBackgroundColor(_ value: Color) -> Modified {
        setValue(.barBackgroundColor, value.propValue)
    }

    /// What the bar is painted, where one flat colour will not do.
    /// MAUI: BarBackground, which is a Brush.
    ///
    ///     TabbedPage(Tab.allCases) { tab in
    ///         page(for: tab)
    ///     }
    ///     .barBackground(.linearGradient([
    ///         GradientStop(.cornflowerBlue, 0),
    ///         GradientStop(.indigo, 1),
    ///     ]))
    public func barBackground(_ value: Brush) -> Modified {
        setValue(.barBackground, value.propValue)
    }

    /// The colour of the title on the bar, and of the back arrow beside it.
    /// MAUI: BarTextColor.
    ///
    /// It paints both. A page that wants a different ARROW says so on itself,
    /// with `navigationPageIconColor`.
    public func barTextColor(_ value: Color) -> Modified {
        setValue(.barTextColor, value.propValue)
    }
}
