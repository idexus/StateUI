// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A StateUI layout over the browser's own: a stack is a flexbox, a page or a window's room a grid of one cell. The
/// browser measures and places; each child's margin, alignments and sizes are written as its CSS.
/// Design: docs/design/platforms/web/layout.md#a-layout-is-the-browsers
@MainActor
class WebLayoutView: WebDOMView {
    /// How the layout sets its children.
    enum Arrangement: Equatable {
        /// One after another along an axis, a flexbox.
        case stack(StackArithmetic.Axis)

        /// One child in the whole room, a grid of one cell.
        case single
    }

    let arrangement: Arrangement

    /// The children's views, in order.
    private(set) var children: [WebDOMView] = []

    init(tag: String = "div", arrangement: Arrangement) {
        self.arrangement = arrangement
        super.init(tag: tag)
        switch arrangement {
        case .stack(let axis):
            style("display", "flex")
            style("flex-direction", axis == .vertical ? "column" : "row")
        case .single:
            style("display", "grid")
            style("grid-template", "minmax(0, 1fr) / minmax(0, 1fr)")
        }
    }

    /// The room left between the children of a stack.
    func setSpacing(_ spacing: Double) {
        style("gap", spacing == 0 ? nil : WebCSS.pixels(spacing))
    }

    /// What fills the layout's box.
    func setBackground(_ value: HostValue?) {
        style("background", WebCSS.fill(value))
    }

    /// Puts `items` in the element in their order, where it holds them otherwise, and writes each one's place; a
    /// child this layout no longer holds leaves the element.
    /// Design: docs/design/platforms/web/layout.md#children-in-order
    func setItems(_ items: [(view: WebDOMView, values: LayoutValues)]) {
        let views = items.map(\.view)
        if views.count != children.count || !zip(views, children).allSatisfy({ $0 === $1 }) {
            for (index, view) in views.enumerated() { WebRelay.insert(view.node, into: node, at: index) }
        }
        for gone in children where gone.placingLayout === self && !items.contains(where: { $0.view === gone }) {
            WebRelay.detach(gone.node)
            gone.placingLayout = nil
        }
        children = views
        for item in items {
            item.view.placingLayout = self
            place(item.view, item.values)
        }
    }

    /// Writes where `view` stands in this layout: its margin, its stated sizes and their bounds, and its alignment
    /// across its slot - in a grid's cell, along both axes.
    /// Design: docs/design/platforms/web/layout.md#a-childs-place
    func place(_ view: WebDOMView, _ values: LayoutValues) {
        for (side, length) in WebCSS.sides(values.margin) { view.style("margin-\(side)", length) }
        view.style("width", WebCSS.pixels(values.width))
        view.style("height", WebCSS.pixels(values.height))
        view.style("min-width", WebCSS.pixels(values.minimumWidth))
        view.style("min-height", WebCSS.pixels(values.minimumHeight))
        view.style("max-width", WebCSS.pixels(values.maximumWidth))
        view.style("max-height", WebCSS.pixels(values.maximumHeight))

        let across = WebCSS.alignment(values.horizontal, stops: values.width != nil || values.maximumWidth != nil)
        let down = WebCSS.alignment(values.vertical, stops: values.height != nil || values.maximumHeight != nil)
        switch arrangement {
        case .stack(let axis):
            view.style("flex", "none")
            view.style("justify-self", nil)
            view.style("align-self", axis == .vertical ? across : down)
        case .single:
            view.style("flex", nil)
            view.style("justify-self", across)
            view.style("align-self", down)
        }
    }
}
