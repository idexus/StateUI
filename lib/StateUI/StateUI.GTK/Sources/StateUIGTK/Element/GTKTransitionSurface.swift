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
        TransitionSurface.presents(property, on: type, atRest: atRest)
    }

    /// What a class of the host's style sheet paints - a class a value, which a value on its way would add every
    /// frame - and a window's place and size, which the desktop keeps.
    static let atRest: [NodeType: Set<Prop>] = [
        .text: [.padding, .background],
        .button: [.padding, .background, .stroke, .lineWidth, .shape],
        .radioButton: [.padding],
        .textField: [.fontSize, .textColor, .placeholderColor],
        .searchField: [.fontSize, .textColor, .placeholderColor],
        .textEditor: [.fontSize, .textColor, .placeholderColor],
        .slider: [.tint],
        .navigationStack: [.barBackgroundColor, .barForegroundColor],
        .tabView: [.barBackgroundColor, .barForegroundColor],
        .splitView: [.barBackgroundColor, .barForegroundColor],
        .modalStack: [.barBackgroundColor, .barForegroundColor],
        .window: [.x, .y, .width, .height],
    ]
}
