// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What the GTK host moves frame by frame: the host layer's surface (`TransitionSurface`), less what GTK paints only
/// at rest, which arrives at once.
/// Design: docs/design/platforms/gtk/motion.md#what-moves
@MainActor
enum GTKTransitionSurface {
    /// Whether the host moves `property` on an element of `type`.
    static func presents(_ property: Prop, on type: NodeType) -> Bool {
        if classPainted.contains(property), !drawsItsOwnBox.contains(type) { return false }
        return TransitionSurface.presents(property, on: type, atRest: atRest)
    }

    /// What a class of the host's style sheet paints on every widget but a layout's - its background, its room, its
    /// accent - a class a value, which a value on its way would add every frame.
    static let classPainted: Set<Prop> = [.background, .padding, .tint]

    /// What draws its own box in its snapshot - a layout's, a page arrangement's - which moves frame by frame.
    static let drawsItsOwnBox: Set<NodeType> = [
        .vStack, .hStack, .zStack, .grid, .layoutEngine, .scrollView, .itemsView,
        .tabView, .splitView, .navigationStack,
    ]

    /// What else a class paints on one kind of widget, and a window's place and size, which the desktop keeps.
    static let atRest: [NodeType: Set<Prop>] = [
        .button: [.stroke, .lineWidth, .shape],
        .textField: [.fontSize, .textColor, .placeholderColor],
        .searchField: [.fontSize, .textColor, .placeholderColor],
        .textEditor: [.fontSize, .textColor, .placeholderColor],
        .picker: [.fontSize, .textColor],
        .datePicker: [.fontSize, .textColor],
        .timePicker: [.fontSize, .textColor],
        .navigationStack: [.barBackground, .barForegroundColor],
        .tabView: [.barBackground, .barForegroundColor],
        .splitView: [.barBackground, .barForegroundColor],
        .window: [.x, .y, .width, .height],
    ]
}
