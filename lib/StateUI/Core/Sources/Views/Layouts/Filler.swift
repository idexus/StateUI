// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A region that takes the room it is given, made of a material - a color, a gradient, a blur of what lies behind
/// it, or the platform's glass - or clear, in its box's shape and outlined where it says so.
///
///     ZStack {
///         Filler(.blur(.regular))
///             .shape(.roundedRectangle(16))
///
///         Text("Over the blur")
///     }
///     .height(120)
///
/// A filler fills its room - a `ZStack`'s, a grid's cell, a page - and in a stack takes what the other children
/// leave, alike with any spacer, unless it states its length: `Filler(.gray).height(1)` is a rule. What it is made
/// of is its background, which the platform draws as a layout's: a blur or glass where it has one, the material's
/// own color where it has none; a later `background` replaces it. A clear `Filler()` still takes a tap - a region
/// for a gesture.
///
/// A gap is a `Spacer`; a figure - its line dashed or joined, its corners rounded one by one - is a `Rectangle` or
/// another shape.
///
/// Design: docs/design/host/layout.md#a-filler
public struct Filler: ElementView, BorderElement {
    /// The node this filler describes.
    public var node: Node

    /// A clear filler - which is also what a `Style<Filler>` is written against.
    public init() {
        node = Node(contract: FillerContract.self)
    }

    /// A filler made of `material`; a `Material(light:dark:)` follows the theme.
    public init(_ material: Material) {
        self = Filler().setValue(VisualElementContract.background, material)
    }

    /// A filler of one color; a `Color(light:dark:)` follows the theme.
    public init(_ color: Color) {
        self.init(Material.color(color))
    }

    /// A filler painted with a gradient.
    public init(_ brush: Brush) {
        self.init(Material.gradient(brush))
    }

    /// A filler whose color follows a state, `$x`: the host animates it to each new color, and no view is rebuilt
    /// for it.
    public init(_ state: Binding<Color>) {
        self = Filler().twin(VisualElementContract.background, carrying: state)
    }

    /// A filler whose material follows a state, `$x`: the host shows each new material as it stands, and no view
    /// is rebuilt for it.
    public init(_ state: Binding<Material>) {
        self = Filler().twin(VisualElementContract.background, by: state)
    }
}

