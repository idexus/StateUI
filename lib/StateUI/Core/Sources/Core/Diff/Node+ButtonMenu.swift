// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A button is made as its menu, its click and the kind it asks make it open; another opening is another element.
// Design: docs/design/views/controls.md#a-buttons-menu

extension Node {
    /// How a host makes this element open its menu where it is a button; none for anything else.
    var buttonMenuOpening: ButtonMenuOpening {
        guard type == .button else { return .none }
        return ButtonMenuOpening(
            holdsMenu: children.contains { $0.type == .buttonMenu }, clicks: events[.clicked] != nil,
            kind: props[.menuKind].flatMap(ButtonMenuKind.init(propValue:)) ?? .automatic)
    }
}

extension RenderedNode {
    /// How the host made this element open its menu where it is a button; none for anything else.
    var buttonMenuOpening: ButtonMenuOpening {
        guard type == .button else { return .none }
        return ButtonMenuOpening(
            holdsMenu: children.contains { $0.type == .buttonMenu }, clicks: events[.clicked] != nil,
            kind: props[.menuKind].flatMap(ButtonMenuKind.init(propValue:)) ?? .automatic)
    }
}
