// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How the text of a control is set in type - its step of the platform's type
/// ramp, its size, its family, its weight, its slant and its digits.
public protocol FontElement: PropertyContainer {}

extension FontElement {
    /// How big the text is, in device units.
    public func fontSize(_ value: Double) -> Modified { setValue(FontElementContract.fontSize, value) }

    /// Which font, by the alias the app registered it under - not the file name.
    public func fontFamily(_ value: String) -> Modified { setValue(FontElementContract.fontFamily, Name(value)) }

    /// Italic or upright, and digits of one width or of their own.
    ///
    ///     Text("Total").fontAttributes(.italic)
    ///     Text("\(seconds) s").fontAttributes(.monospacedDigits)
    public func fontAttributes(_ value: FontAttributes) -> Modified { setValue(FontElementContract.fontAttributes, value) }

    /// How heavy the strokes are - regular, medium, semibold or bold - over the
    /// weight of the text's style.
    ///
    ///     Text("3 unread").fontWeight(.semibold)
    public func fontWeight(_ value: FontWeight) -> Modified { setValue(FontElementContract.fontWeight, value) }

    /// The step of the platform's type ramp the text is set in: the platform's
    /// own size and weight for it, growing with the user's text size. A
    /// `fontSize` or `fontWeight` stands over the style's.
    ///
    ///     Text("Inbox").textStyle(.title)
    public func textStyle(_ value: TextStyle) -> Modified { setValue(FontElementContract.textStyle, value) }

    /// Whether the text grows with the system's text-size setting. On by
    /// default.
    public func isFontAutoScalingEnabled(_ value: Bool) -> Modified { setValue(FontElementContract.isFontAutoScalingEnabled, value) }
}

extension FontElement where Self: VisualElement {
    /// `fontAttributes` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fontAttributes(_ state: Binding<FontAttributes>) -> Modified {
        twin(FontElementContract.fontAttributes, by: state)
    }

    /// `fontWeight` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fontWeight(_ state: Binding<FontWeight>) -> Modified {
        twin(FontElementContract.fontWeight, by: state)
    }

    /// `textStyle` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func textStyle(_ state: Binding<TextStyle>) -> Modified {
        twin(FontElementContract.textStyle, by: state)
    }

    /// `isFontAutoScalingEnabled` from a state, `$x`: the host sets each new
    /// value as it stands, and no view is rebuilt for it.
    public func isFontAutoScalingEnabled(_ state: Binding<Bool>) -> Modified {
        twin(FontElementContract.isFontAutoScalingEnabled, by: state)
    }

    /// `fontSize` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func fontSize(_ state: Binding<Double>) -> Modified {
        twin(FontElementContract.fontSize, by: state)
    }
}
