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
}

