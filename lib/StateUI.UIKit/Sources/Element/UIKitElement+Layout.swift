// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a layout holds: its children's views, each as the item the host layer's arithmetic places; and a label, the
/// runs of its spans.
extension UIKitElement {
    func arrangeChildren() {
        if let items = view as? UIKitItemsView { return items.childrenChanged() }
        if let label = view as? UIKitLabelView { return label.setRuns(element.textRuns) }
        guard let layout = view as? UIKitLayoutView else { return }
        layout.direction = element.layoutDirection
        layout.laidOut = { [weak host] in host?.runtime.frames.laidOut() }
        layout.setItems(element.arrangedChildren.compactMap { $0.uiKit.layoutItem })
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element drawn by its
    /// parent.
    var layoutItem: UIKitLayoutItem? {
        guard let view else { return children.lazy.compactMap(\.layoutItem).first }

        var item = UIKitLayoutItem(view: view, values: element.layoutValues, isShown: element.standsShown)
        item.mount = element.mount
        item.placed = self
        item.drawing = drawing
        return item
    }
}
#endif
