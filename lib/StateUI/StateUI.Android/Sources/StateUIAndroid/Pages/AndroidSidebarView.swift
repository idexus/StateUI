// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A split view's sidebar column: the sidebar's own bar - the application's name and mark, the toggle at its end -
/// over the sidebar page, in the drawer over the detail or beside it, apart from it then by the theme's line.
/// Design: docs/design/platforms/android/pages.md#a-split-view
@MainActor
final class AndroidSidebarView: AndroidLayoutView {
    private(set) var bar = AndroidBarView()

    /// The theme's line down the column's edge toward the detail, and how wide the theme draws it, in pixels.
    let edge = AndroidView { _ in Java.new(JavaAPI.view, JavaAPI.newView, .object(AndroidRenderer.context)) }
    private lazy var edgePixels = Double(Java.callStaticInt(JavaAPI.views, JavaAPI.divideView, .object(edge.reference)))

    /// Whether the column stands apart from the detail by its line: while it stands beside the detail.
    var showsEdge = false {
        didSet { if showsEdge != oldValue { holdChildren() } }
    }

    /// The bar whose words are `words`: the one standing, or one made in their theme in its place - a view's theme
    /// is fixed as it is made.
    func bar(taking words: AndroidBarView.Words) -> AndroidBarView {
        guard words != bar.words else { return bar }

        bar.detach()
        bar = AndroidBarView(words: words)
        holdChildren()
        invalidateMeasurements()
        return bar
    }

    override func heldViews() -> [AndroidView] {
        [bar] + (items.first.map { [$0.view] } ?? []) + (showsEdge ? [edge] : [])
    }

    override func contentSize(width: Double?) -> LayoutSize {
        let page = SingleChildArithmetic.size(of: items.first, width: width)
        return LayoutSize(width: page.width, height: page.height + bar.height(width: width))
    }

    /// The bar along the top, reaching under what stands over it there, the sidebar page below it with the rest
    /// (`Clearance.underABarAtTheTop`).
    /// Design: docs/design/platforms/android/pages.md#the-safe-area
    override func arrange(in bounds: Rect) {
        if showsEdge {
            let width = edgePixels / density
            edge.layout(Rect(
                x: direction == .leftToRight ? bounds.width - width : 0, y: 0, width: width, height: bounds.height))
        }
        let (barInsets, pageInsets) = roomInsets.underABarAtTheTop
        bar.pad(barInsets)
        let height = bar.height(width: bounds.width)
        bar.layout(Rect(x: 0, y: 0, width: bounds.width, height: height))
        guard let page = items.first, page.isShown else { return }

        (page.view as? AndroidLayoutView)?.roomInsets = pageInsets
        let room = Rect(x: 0, y: height, width: bounds.width, height: max(0, bounds.height - height))
        page.view.layout(SingleChildArithmetic.place(of: page, in: room, direction: direction))
    }
}
