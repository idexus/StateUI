// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The room it is offered, made of a material - a color, a gradient, a blur of what lies behind it, or the
/// platform's glass - or clear, in its box's shape and outlined where it says so.
///
///     ZStack {
///         Fill(.blur(.regular))
///             .shape(.roundedRectangle(16))
///
///         Text("Over the blur")
///     }
///     .height(120)
///
/// A fill takes the room it is offered - a `ZStack`'s, a grid's cell, a page, the width of a column - and along a
/// stack only the length it states: `Fill(.gray).height(1)` is a rule, and a fill stating none stands 0 long there.
/// Room that pushes along a stack is a `Space`. What a fill is made of is its background, which the platform draws
/// as a layout's: a blur or glass where it has one, the material's own color where it has none; a later
/// `background` replaces it. A clear `Fill()` still takes a tap - a region for a gesture.
///
/// A figure - its line dashed or joined, its corners rounded one by one - is a `Rectangle` or another shape.
///
/// Design: docs/design/host/layout.md#a-fill
public struct Fill: ElementView, BorderElement {
    /// The node this fill describes.
    public var node: Node

    /// A clear fill - which is also what a `Style<Fill>` is written against.
    public init() {
        node = Node(contract: FillContract.self)
    }

    /// A fill made of `material`; a `Material(light:dark:)` follows the theme.
    public init(_ material: Material) {
        self = Fill().setValue(VisualElementContract.background, material)
    }

    /// A fill of one color; a `Color(light:dark:)` follows the theme.
    public init(_ color: Color) {
        self.init(Material.color(color))
    }

    /// A fill painted with a gradient.
    public init(_ brush: Brush) {
        self.init(Material.gradient(brush))
    }

    /// A fill whose color follows a state, `$x`: the host animates it to each new color, and no view is rebuilt for
    /// it.
    public init(_ state: Binding<Color>) {
        self = Fill().twin(VisualElementContract.background, carrying: state)
    }

    /// A fill whose material follows a state, `$x`: the host shows each new material as it stands, and no view is
    /// rebuilt for it.
    public init(_ state: Binding<Material>) {
        self = Fill().twin(VisualElementContract.background, by: state)
    }
}
