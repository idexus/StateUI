// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Children placed: the layout item each child gives its parent.
extension AndroidElement {
    /// Hands a layout its children's items, in order.
    func arrangeChildren() {
        (view as? AndroidLayoutView)?.setItems(children.compactMap(\.layoutItem))
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its parent.
    var layoutItem: AndroidLayoutItem? {
        guard let view else { return children.lazy.compactMap(\.layoutItem).first }

        return AndroidLayoutItem(
            view: view,
            values: element.layoutValues,
            isShown: value(.isVisible)?.bool != false)
    }
}
