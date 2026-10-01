// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How the text of a control is set in type - its size, its family, its
/// weight.
public protocol FontElement: PropertyContainer {}

extension FontElement {
    /// How big the text is, in device units.
    public func fontSize(_ value: Double) -> Modified { setValue(FontElementContract.fontSize, value) }

    /// Which font, by the alias the app registered it under - not the file name.
    public func fontFamily(_ value: String) -> Modified { setValue(FontElementContract.fontFamily, Name(value)) }

    /// Bold, italic, or both.
    ///
    ///     Label("Total").fontAttributes([.bold, .italic])
    public func fontAttributes(_ value: FontAttributes) -> Modified { setValue(FontElementContract.fontAttributes, value) }

    /// Whether the text grows with the system's text-size setting. On by
    /// default.
    public func fontAutoScalingEnabled(_ value: Bool) -> Modified { setValue(FontElementContract.fontAutoScalingEnabled, value) }
}

extension FontElement where Self: VisualElement {
    /// `fontAttributes` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fontAttributes(_ state: Binding<FontAttributes>) -> Modified {
        plain(FontElementContract.fontAttributes, by: state)
    }

    /// `fontAutoScalingEnabled` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func fontAutoScalingEnabled(_ state: Binding<Bool>) -> Modified {
        plain(FontElementContract.fontAutoScalingEnabled, by: state)
    }

    /// `fontSize` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func fontSize(_ state: Binding<Double>) -> Modified {
        journey(FontElementContract.fontSize, by: state)
    }
}
