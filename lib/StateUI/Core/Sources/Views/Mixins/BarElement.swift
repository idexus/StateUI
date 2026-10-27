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

    /// The color behind the bar's buttons - a glass or a rounded one, and a
    /// plain one under the pointer - where the host draws them a background:
    /// the Web. Native bars keep their platform's own.
    ///
    ///     .barButtonBackgroundColor(Color(light: Color(hex: 0xD5E0E4), dark: Color(hex: 0x272D39)))
    public func barButtonBackgroundColor(_ value: Color) -> Modified {
        setValue(BarElementContract.barButtonBackgroundColor, value)
    }

    /// The weight of the words on the bar's buttons, where the platform's
    /// bar button takes one; nil - and unsaid - each platform's own, nil
    /// even under an arrangement around it that says one.
    ///
    ///     .barButtonFontWeight(.bold)
    public func barButtonFontWeight(_ value: FontWeight?) -> Modified {
        setValue(BarElementContract.barButtonFontWeight.token, value.propValue)
    }

    /// How the bar's buttons stand where the host draws them itself - the
    /// Web: `.glass`, `.plain`, `.rounded`, or the platform's own,
    /// `.system`, unless said. Native bars keep their platform's buttons.
    ///
    ///     .toolbarStyle(.plain)
    public func toolbarStyle(_ value: ToolbarStyle) -> Modified {
        setValue(BarElementContract.toolbarStyle, value)
    }

    /// The color of what stands on the bar: the title and the native
    /// navigation and toolbar affordances. Destructive actions keep the
    /// platform's warning color.
    public func barForegroundColor(_ value: Color) -> Modified {
        setValue(BarElementContract.barForegroundColor, value)
    }
}
