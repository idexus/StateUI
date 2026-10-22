// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A NavigationStack: its top page under its bar. The pages below are kept by their elements and held by no view,
/// so each keeps what it showed for when the user comes back to it.
/// Design: docs/design/platforms/android/pages.md#a-navigation-stack
@MainActor
final class AndroidNavigationView: AndroidLayoutView {
    private(set) var bar = AndroidBarView()

    /// Whether the user asked for less motion.
    private let reducesMotion: () -> Bool

    init(reducesMotion: @escaping () -> Bool) {
        self.reducesMotion = reducesMotion
        super.init()
    }

    /// The pages, moving as the host layer says the path changed (`PathChange`): a page pushed slides in from the
    /// end over the one it covers going toward the start, one popped back to the other way - Android's own
    /// transition; any other change shows at once.
    /// Design: docs/design/host/pages.md#a-path-that-changes
    @discardableResult
    override func setItems(_ items: [AndroidLayoutItem]) -> Bool {
        let change = PathChange.of(from: self.items.map(\.view), to: items.map(\.view), same: ===)
        if let change, change.moves(reducingMotion: reducesMotion()) { slide(pushed: change == .push) }
        return super.setItems(items)
    }

    /// Begins Android's transition over the pages' change the next frame lays out: the page arriving slides in from
    /// one edge, the page leaving out toward the other - on one easing, so the arriving page's edge travels on the
    /// leaving one's and neither page crosses the other.
    /// Design: docs/design/platforms/android/pages.md#a-navigation-stack
    private func slide(pushed: Bool) {
        let (arriving, leaving) = pushed ? (Self.end, Self.start) : (Self.start, Self.end)
        let transitions = Java.new(JavaAPI.transitionSet, JavaAPI.newTransitionSet)
        let easing = Java.new(
            JavaAPI.pathInterpolator, JavaAPI.newPathInterpolator, .float(0.4), .float(0), .float(0.2), .float(1))
        Java.release(local: Java.callObject(
            transitions.reference, JavaAPI.setTransitionsInterpolator, .object(easing.reference)))
        for (edge, mode) in [(arriving, Self.appearing), (leaving, Self.disappearing)] {
            let slide = Java.new(JavaAPI.slide, JavaAPI.newSlide, .int(edge))
            Java.call(slide.reference, JavaAPI.setVisibilityMode, .int(mode))
            Java.release(local: Java.callObject(transitions.reference, JavaAPI.addTransition, .object(slide.reference)))
        }
        Java.callStatic(
            JavaAPI.transitionManager, JavaAPI.beginDelayedTransition, .object(reference), .object(transitions.reference))
    }

    /// `Gravity.START` and `Gravity.END`: the edges a page slides from, turned over for a language written from the
    /// right.
    private static let start: Int32 = 0x0080_0003
    private static let end: Int32 = 0x0080_0005

    /// `Visibility.MODE_IN` and `MODE_OUT`: a slide for the view appearing, or for the one disappearing.
    private static let appearing: Int32 = 1
    private static let disappearing: Int32 = 2

    /// The bar whose actions take `words`: the one standing, or one made in their theme in its place - a view's
    /// theme is fixed as it is made.
    func bar(taking words: AndroidBarView.Words) -> AndroidBarView {
        guard words != bar.words else { return bar }

        bar.detach()
        bar = AndroidBarView(words: words)
        holdChildren()
        invalidateMeasurements()
        return bar
    }

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
        let page = SingleChildArithmetic.size(of: items.last, width: width)
        return LayoutSize(width: page.width, height: page.height + barHeight(width: width))
    }

    /// The bar along the top, reaching under what stands over it there, the top page below it with the rest
    /// (`Clearance.underABarAtTheTop`).
    /// Design: docs/design/platforms/android/pages.md#the-safe-area
    override func arrange(in bounds: Rect) {
        let (barInsets, pageInsets) = showsBar ? roomInsets.underABarAtTheTop : (.none, roomInsets)
        bar.pad(barInsets)
        let height = barHeight(width: bounds.width)
        if showsBar { bar.layout(Rect(x: 0, y: 0, width: bounds.width, height: height)) }
        guard let page = items.last else { return }

        (page.view as? AndroidLayoutView)?.roomInsets = pageInsets
        let room = Rect(x: 0, y: height, width: bounds.width, height: max(0, bounds.height - height))
        page.view.layout(SingleChildArithmetic.place(of: page, in: room, direction: direction))
    }

    /// The bar's own height for `width` points, in points; none while it is hidden.
    private func barHeight(width: Double?) -> Double {
        guard showsBar else { return 0 }

        let widthSpec = width.map { ViewConstants.spec(ViewConstants.exactly, pixels($0)) } ?? ViewConstants.unspecified
        return Double(bar.measure(width: widthSpec, height: ViewConstants.unspecified).height) / density
    }
}
