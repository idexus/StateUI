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

        var item = AndroidLayoutItem(view: view, values: element.layoutValues, isShown: isShown)
        item.mount = element.mount
        if fadesIn {
            item.fadeIn = { [weak self] motion in self?.fadeIn(under: motion) }
        }
        return item
    }

    /// Whether the view is shown: as the tree says, or while it fades out.
    var isShown: Bool {
        leaving || value(.isVisible)?.bool != false
    }

    /// The element whose layout places this one: the nearest above it with a view.
    var layoutParent: AndroidElement? {
        guard let parent else { return nil }
        return parent.view != nil ? parent : parent.layoutParent
    }
}
