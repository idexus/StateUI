// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: each child's view in its layout, with its place written as CSS.
extension WebElement {
    /// Hands a layout its children's views in order, each with what its place reads.
    func arrangeChildren() {
        if let text = view as? WebTextView { return text.setRuns(element.textRuns) }
        if arrangePages() { return }
        guard let layout = view as? WebLayoutView else { return }
        let items = element.arrangedChildren.compactMap(\.web.placedElement)
        layout.setItems(
            items.map { ($0.view!, $0.element.layoutValues) },
            travellers: items.map { item in (item.element.mount, { [weak item] motion in item?.fadeIn(under: motion) }) })
    }

    /// The element whose view stands in the layout for this one: itself, or the first with a view of an element with
    /// none.
    var placedElement: WebElement? {
        view != nil ? self : element.arrangedChildren.lazy.compactMap(\.web.placedElement).first
    }
}
