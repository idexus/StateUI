// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Children placed: the layout item each child gives its parent.
extension WinUIElement {
    /// Hands a layout its children's items, in order.
    func arrangeChildren() {
        let layout = view as? WinUILayoutView
        layout?.direction = element.layoutDirection
        layout?.setItems(children.compactMap(\.layoutItem))
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its parent.
    var layoutItem: WinUILayoutItem? {
        guard let view else { return children.lazy.compactMap(\.layoutItem).first }

        return WinUILayoutItem(view: view, values: element.layoutValues, isShown: isShown)
    }

    /// Whether the view is shown, as the tree says.
    var isShown: Bool {
        value(.isVisible)?.bool != false
    }
}
