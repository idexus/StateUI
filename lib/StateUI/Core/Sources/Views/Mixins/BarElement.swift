// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The look of the bar over what an arrangement shows. It belongs to the
/// arrangement and looks the same whichever page shows; what the bar says -
/// a title, the line under it, a view in its place, its actions - each page
/// says of itself, `.subtitle(folder.name)`.
///
/// Declared on a window's page, it is the whole window's bar; an arrangement
/// further in stands in its place, one value at a time, while it is shown:
///
///     SplitView($showsMenu) {
///         MenuPage()
///     } detail: {
///         NavigationStack($path) { … }
///             .barBackground(.cornflowerBlue)
///     }
///     .barForegroundColor(.white)
///
/// A split view's bar is both its panes': a sidebar with a bar of its own
/// wears what its split view declares, and nothing from around it. A sheet
/// has no bar of its own: a stack in it brings one, in the look of the bar
/// over the view presenting the sheet unless it declares its own.
public protocol BarElement: PropertyContainer {}

extension BarElement {
    /// What the bar is made of - a color, a gradient, a blur or glass. A
    /// platform that blurs nothing behind its bars shows a blur as its color.
    ///
    ///     NavigationStack($path) {
    ///         HomePage()
    ///     } destination: { route in
    ///         DetailPage(route)
    ///     }
    ///     .barBackground(.blur(.thin))
    ///
    /// Leave it unwritten to retain the native material and appearance.
    public func barBackground(_ value: Material) -> Modified {
        setValue(BarElementContract.barBackground, value)
    }

    /// The bar in one color.
    public func barBackground(_ value: Color) -> Modified {
        barBackground(.color(value))
    }

    /// The bar's color from a state, `$x`: the host animates it to each new value.
    public func barBackground(_ state: Binding<Color>) -> Modified {
        twin(BarElementContract.barBackground, carrying: state)
    }

    /// The bar's material from a state, `$x`: the host shows each new material as it stands.
    public func barBackground(_ state: Binding<Material>) -> Modified {
        twin(BarElementContract.barBackground, by: state)
    }

    /// How the bar's buttons stand where the host draws them itself - the
    /// Web: `.glass`, `.plain`, `.rounded`, or the platform's own,
    /// `.system`, unless said - the look a `Style<ToolbarButton>` writes
    /// over. Native bars keep their platform's buttons.
    ///
    ///     .toolbarStyle(.plain)
    public func toolbarStyle(_ value: ToolbarStyle) -> Modified {
        setValue(BarElementContract.toolbarStyle, value)
    }

    /// The room between the bar's groups - an item standing alone is a
    /// group of its own - and its own buttons, where the host draws the bar
    /// itself: the Web. Native bars keep their platform's room.
    ///
    ///     .toolbarSpacing(12)
    public func toolbarSpacing(_ value: Double) -> Modified {
        setValue(BarElementContract.toolbarSpacing, value)
    }

    /// How what scrolls under the bar shows at its edge: `.automatic` unless said - the platform's own, and where
    /// it draws none a blur that shows only while something passes under the bar - `.hard`, the rows cut off at the
    /// bar on every platform, or `.none`.
    ///
    ///     .barScrollEdge(.hard)
    public func barScrollEdge(_ value: ScrollEdge) -> Modified {
        setValue(BarElementContract.barScrollEdge, value)
    }

    /// The color of what stands on the bar: the title and the native
    /// navigation and toolbar affordances. Destructive actions keep the
    /// platform's warning color.
    public func barForegroundColor(_ value: Color) -> Modified {
        setValue(BarElementContract.barForegroundColor, value)
    }
}
