// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A NavigationStack: its top page under its bar. The pages below are kept by their elements and held by no view,
/// so each keeps what it showed for when the user comes back to it.
/// Design: docs/design/platforms/android/pages.md#a-navigation-stack
@MainActor
final class AndroidNavigationView: AndroidLayoutView {
    let bar = AndroidBarView()

    /// Whether the bar shows over the top page, as the page says.
    private(set) var showsBar = true

    func setShowsBar(_ shows: Bool) {
        guard shows != showsBar else { return }

        showsBar = shows
        holdChildren()
        invalidateMeasurements()
    }

    override func heldViews() -> [AndroidView] {
        (showsBar ? [bar] : []) + (items.last.map { [$0.view] } ?? [])
    }

    override func contentSize(width: Double?) -> LayoutSize {
        let page = SingleChildArithmetic.size(of: items.last, padding: Insets(0), width: width)
        return LayoutSize(width: page.width, height: page.height + barHeight(width: width))
    }

    override func arrange(in bounds: Rect) {
        let height = barHeight(width: bounds.width)
        if showsBar { bar.layout(Rect(x: 0, y: 0, width: bounds.width, height: height)) }
        guard let page = items.last else { return }

        let room = Rect(x: 0, y: height, width: bounds.width, height: max(0, bounds.height - height))
        page.view.layout(SingleChildArithmetic.place(of: page, in: room, padding: Insets(0)))
    }

    /// The bar's own height for `width` points, in points; none while it is hidden.
    private func barHeight(width: Double?) -> Double {
        guard showsBar else { return 0 }

        let widthSpec = width.map { ViewConstants.spec(ViewConstants.exactly, pixels($0)) } ?? ViewConstants.unspecified
        return Double(bar.measure(width: widthSpec, height: ViewConstants.unspecified).height) / density
    }
}
