// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: each child's view in its layout, with its place written as CSS.
extension WebElement {
    /// Hands a text its runs, a collection its changed entries and a page structure its pages; else a layout its
    /// children's views in order, each with what its place reads.
    func arrangeChildren() {
        if let text = view as? WebTextView { return text.setRuns(element.textRuns, over: element.textLook) }
        if let items = view as? WebItemsView { return items.childrenChanged() }
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
