// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A SplitView: its detail page, and its sidebar - a drawer sliding over the detail where the room is narrow,
/// beside it where it is wide.
/// Design: docs/design/platforms/android/pages.md#a-split-view
@MainActor
final class AndroidSplitView: AndroidLayoutView {
    /// The width from which the sidebar stands beside the detail rather than over it, in points.
    static let sideBySide = 720.0

    /// How long the drawer slides, in milliseconds.
    static let slide: Int64 = 250

    /// Whether the sidebar shows.
    private(set) var isPresented = false

    /// Whether the sidebar slides over the detail, as the room was when the view was last laid out.
    private(set) var overlays = true

    /// What the split does when the user taps the detail beside an open drawer: closes it.
    var onScrimTapped: (() -> Void)?

    /// The drawer holding the sidebar page, and the shade over the detail while it is open.
    private let drawer = AndroidSingleChildView()
    private let scrim = AndroidColorBoxView()
    private var drawerWidth = 0.0

    override init() {
        super.init()
        Java.call(scrim.reference, JavaAPI.setBackgroundColor, .int(0x6600_0000))
        Java.call(scrim.reference, JavaAPI.setAlpha, .float(0))
    }

    /// The sidebar page goes in the drawer; the detail, the shade and the drawer in the split, front last.
    @discardableResult
    override func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        drawer.setItems(Array(items.prefix(1)))
        return super.setItems(items)
    }

    override func heldViews() -> [AndroidView] {
        Array(items.dropFirst().prefix(1).map(\.view)) + [scrim, drawer]
    }

    override func forgetMeasurements() {
        super.forgetMeasurements()
        drawer.forgetMeasurements()
    }

    /// Shows or hides the sidebar, sliding where it slides over the detail.
    func present(_ presented: Bool) {
        guard presented != isPresented else { return }

        isPresented = presented
        if overlays {
            showDrawer(animated: true)
        } else {
            invalidateMeasurements()
        }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.dropFirst().first, padding: Insets(0), width: width)
    }

    override func arrange(in bounds: Rect) {
        overlays = bounds.width < Self.sideBySide
        drawerWidth = min(320, bounds.width * (overlays ? 0.84 : 0.4))
        let beside = !overlays && isPresented ? drawerWidth : 0

        if let detail = items.dropFirst().first {
            let room = Rect(x: beside, y: 0, width: bounds.width - beside, height: bounds.height)
            detail.view.layout(SingleChildArithmetic.place(of: detail, in: room, padding: Insets(0)))
        }
        scrim.layout(Rect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        drawer.layout(Rect(x: 0, y: 0, width: drawerWidth, height: bounds.height))
        showDrawer(animated: false)
    }

    /// Stands the drawer and the shade where the sidebar's state puts them. The shade takes a tap only while the
    /// drawer is open over the detail; otherwise every touch goes through it.
    private func showDrawer(animated: Bool) {
        let duration = animated ? Self.slide : 0
        drawer.setShown(overlays || isPresented)
        slide(drawer, to: overlays && !isPresented ? -drawerWidth : 0, alpha: 1, duration: duration)

        let shaded = overlays && isPresented
        slide(scrim, to: 0, alpha: shaded ? 1 : 0, duration: duration)
        scrim.setTapped(shaded ? { [weak self] in self?.onScrimTapped?() } : nil)
    }

    private func slide(_ view: AndroidView, to points: Double, alpha: Float, duration: Int64) {
        Java.callStatic(
            JavaAPI.views, JavaAPI.slideView, .object(view.reference),
            .float(Float(points * density)), .float(alpha), .long(duration))
    }

    override func detach() {
        super.detach()
        onScrimTapped = nil
    }
}
