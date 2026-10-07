// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an element draws of its own box - a layout's, a scroller's, a
/// button's: the shape its background fills, and an outline on it.
///
///     Button("Save")
///         .stroke(.cornflowerBlue)
///         .lineWidth(1)
///         .shape(.roundedRectangle(8))
public protocol BorderElement: PropertyContainer {}

extension BorderElement {
    /// The shape the background and the outline follow, and - with `clipsContent` - what the element holds.
    public func shape(_ value: ContainerShape) -> Modified {
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
    public func lineWidth(_ value: Double) -> Modified {
        setValue(BorderElementContract.lineWidth, value)
    }
}

extension BorderElement where Self: VisualElement {
    /// `lineWidth` from a state, `$x`: the host animates the outline to each new width, and no view is
    /// rebuilt for it.
    public func lineWidth(_ state: Binding<Double>) -> Modified {
        journey(BorderElementContract.lineWidth, by: state)
    }
}
