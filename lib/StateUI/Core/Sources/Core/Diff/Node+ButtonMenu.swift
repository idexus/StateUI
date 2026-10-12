// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A button is made as the kind its menu and its click make it; another kind is another element.
// Design: docs/design/views/controls.md#a-buttons-menu

extension Node {
    /// The kind a host makes of this element where it is a button; plain for anything else.
    var buttonMenuKind: ButtonMenuKind {
        guard type == .button else { return .plain }
        return ButtonMenuKind(holdsMenu: children.contains { $0.type == .buttonMenu }, clicks: events[.clicked] != nil)
    }
}

extension RenderedNode {
    /// The kind the host made of this element where it is a button; plain for anything else.
    var buttonMenuKind: ButtonMenuKind {
        guard type == .button else { return .plain }
        return ButtonMenuKind(holdsMenu: children.contains { $0.type == .buttonMenu }, clicks: events[.clicked] != nil)
    }
}
