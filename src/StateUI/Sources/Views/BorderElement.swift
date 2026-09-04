// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The outline a button-shaped control draws around itself.
//
// Its own file rather than a block in Elements.swift, for the reason
// BarElement.swift gives: Elements.swift is the tier every VIEW shares,
// exactly, and `testTheSharedTierIsCoveredOnce` checks its properties against
// one fixture built from a stack and a label. A border is not every view's -
// three controls have one - so it is a tier of its own, beside them rather
// than among them.

/// The outline of a control that draws one.
/// MAUI: IBorderElement - the interface `Button`, `ImageButton` and
/// `RadioButton` all implement, and the one place MAUI declares the three
/// properties that paint an outline.
///
///     Button("Save")
///         .borderColor(.cornflowerBlue)
///         .borderWidth(1)
///         .cornerRadius(8)
///
/// Declared here rather than on each of the three for the reason every tier in
/// this library exists: a copy per control is three places to fix one thing,
/// and the driven forms in Driven.swift are written once against this
/// interface, so `.borderWidth($thickness)` drives all three.
///
/// A `Border` control is NOT one of these. MAUI's Border is a view that puts a
/// `Stroke` around whatever it holds - a brush, with its own shape, dash and
/// cap - and none of that is this interface; see Views/Border.swift.
public protocol BorderElement: PropertyContainer {}

extension BorderElement {
    /// The colour of the outline. MAUI: IBorderElement.BorderColor.
    ///
    /// Nothing is drawn until `borderWidth` is set as well: a colour on its own
    /// shows no outline at all.
    public func borderColor(_ value: Color) -> Modified {
        setValue(.borderColor, value.propValue)
    }

    /// How thick the outline is, in device units.
    /// MAUI: IBorderElement.BorderWidth.
    public func borderWidth(_ value: Double) -> Modified {
        setValue(.borderWidth, .number(value))
    }

    /// How rounded the corners are, in device units - the control's own
    /// corners, outline or none.
    /// MAUI: IBorderElement.CornerRadius, which is an Int rather than a Double.
    ///
    /// A whole number, which is why there is no driven form beside it in
    /// Driven.swift: nothing walks an integer.
    public func cornerRadius(_ value: Int) -> Modified {
        setValue(.cornerRadius, .number(Double(value)))
    }
}

