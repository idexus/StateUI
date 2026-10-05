// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: each child's view in its layout, with its place written as CSS.
extension WebElement {
    /// Hands a layout its children's views in order, each with what its place reads.
    func arrangeChildren() {
        guard let layout = view as? WebLayoutView else { return }
        layout.setItems(element.arrangedChildren.compactMap(\.web.layoutItem))
    }

    /// What this element gives the layout it stands in: its view, or the first view of an element with none.
    var layoutItem: (view: WebDOMView, values: LayoutValues)? {
        guard let view else { return element.arrangedChildren.lazy.compactMap(\.web.layoutItem).first }
        return (view, element.layoutValues)
    }
}
