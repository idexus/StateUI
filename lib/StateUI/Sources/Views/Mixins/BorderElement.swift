// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The outline a `Button` or a `RadioButton` draws around itself.
///
///     Button("Save")
///         .borderColor(.cornflowerBlue)
///         .borderWidth(1)
///         .cornerRadius(8)
///
/// A `Border` is a different thing: a view that strokes whatever it holds,
/// with a brush, a shape and a dash pattern.
public protocol BorderElement: PropertyContainer {}

extension BorderElement {
    /// The colour of the outline.
    ///
    /// Nothing is drawn until `borderWidth` is set as well: a colour on its own
    /// shows no outline at all.
    public func borderColor(_ value: Color) -> Modified {
        setValue(BorderElementContract.borderColor, value)
    }

    /// How thick the outline is, in device units.
    public func borderWidth(_ value: Double) -> Modified {
        setValue(BorderElementContract.borderWidth, value)
    }

    /// How rounded the control's own corners are, in device units, outline or
    /// none.
    public func cornerRadius(_ value: Int) -> Modified {
        setValue(BorderElementContract.cornerRadius, value)
    }

    /// The shape the background and the outline follow, and - with `clipsContent` - what the element holds.
    public func shape(_ value: BorderShape) -> Modified {
        setValue(BorderElementContract.shape, value)
    }

    /// What the outline is painted with; nothing is outlined without one.
    public func stroke(_ value: Brush) -> Modified {
        setValue(BorderElementContract.stroke, value)
    }

    /// The outline in one colour.
    public func stroke(_ value: Color) -> Modified {
        stroke(.solidColor(value))
    }

    /// How wide the outline is, in device units; one where none is said.
    public func strokeWidth(_ value: Double) -> Modified {
        setValue(BorderElementContract.strokeWidth, value)
    }
}

extension BorderElement where Self: VisualElement {
    /// `borderColor` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func borderColor(_ state: Binding<Color>) -> Modified {
        journey(BorderElementContract.borderColor, by: state)
    }

    /// `borderWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func borderWidth(_ state: Binding<Double>) -> Modified {
        journey(BorderElementContract.borderWidth, by: state)
    }

    /// `cornerRadius` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func cornerRadius(_ state: Binding<Int>) -> Modified {
        plain(BorderElementContract.cornerRadius, by: state)
    }

    /// `strokeWidth` from a state, `$x`: the host animates the outline to each new width, and no view is
    /// rebuilt for it.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(BorderElementContract.strokeWidth, by: state)
    }
}
