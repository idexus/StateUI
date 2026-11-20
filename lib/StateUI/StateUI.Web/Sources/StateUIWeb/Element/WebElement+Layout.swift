// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Children placed: each child's view in its layout, with its place written as CSS.
extension WebElement {
    /// The browser measures a layout again itself; the host writes again the size a motion layout's program says.
    func invalidateMeasurements() { writeProgramSize() }

    /// Writes the size a motion layout's program says as the size CSS takes a contained box to have.
    /// Design: docs/design/host/layout.md#a-motion-layout
    func writeProgramSize() {
        guard element.type == .motionLayout, let view else { return }
        let said = element.programSize(nil)
        view.style("contain-intrinsic-size", said.map { "\(WebCSS.signedPixels($0.width)) \(WebCSS.signedPixels($0.height))" })
    }

    /// Hands a text its runs, a collection its changed entries and a page structure its pages; else a layout its
    /// children's views in order, each with what its place reads.
    func arrangeChildren() {
        if let text = view as? WebTextView { return text.setRuns(element.textRuns, over: element.textLook) }
        if let items = view as? WebItemsView { return items.childrenChanged() }
        if arrangePages() { return }
        guard let layout = view as? WebLayoutView else { return }
        let items = element.arrangedChildren.compactMap(\.web.placedElement)
        layout.setItems(
            items.map { item in (item.view!, { [weak item] in item?.element.layoutValues ?? LayoutValues() }) },
            travelers: items.map { item in (item.element.mount, { [weak item] entry in item?.enter(entry) }) })
    }

    /// The element's own size in the room offered, as the browser lays its view out; it tells no first baseline.
    func measured(width: Double?, height: Double?) -> HostChildMeasured {
        guard let placed = placedElement?.view else { return HostChildMeasured(size: .zero, firstBaseline: nil) }
        let size = placed.heldWords ?? WebRelay.fitting(placed.node, width: width)
        return HostChildMeasured(size: size, firstBaseline: nil)
    }

    /// The element whose view stands in the layout for this one: itself, or the first with a view of an element with
    /// none.
    var placedElement: WebElement? {
        view != nil ? self : element.arrangedChildren.lazy.compactMap(\.web.placedElement).first
    }
}
