// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A StateUI layout over the relay's panel: WinUI asks it to measure and arrange, and the core's arithmetic answers.
/// Design: docs/design/platforms/winui/layout.md#a-layout-is-a-panel
@MainActor
class WinUILayoutView: WinUIView {
    /// The sizes measured in the pass under way, by the width offered.
    let measurements = MeasurementCache()

    /// The children, in order.
    private(set) var items: [WinUILayoutItem] = []

    /// The direction the children are laid out in, the element's; a turn lays them out again.
    var direction = LayoutDirection.leftToRight {
        didSet { if direction != oldValue { invalidateMeasurements() } }
    }

    /// The elements the panel holds, in the order it draws them, back to front.
    private var held: [WinUIView] = []

    init() {
        super.init { number in stateui_winui_panel_make(number) }
    }

    /// Puts `items` in the panel, in order, where they differ from the children it holds; whether they did.
    @discardableResult
    func setItems(_ items: [WinUILayoutItem]) -> Bool {
        guard items.count != self.items.count
            || !zip(items, self.items).allSatisfy({ $0.arranges(like: $1) })
        else { return false }

        self.items = items
        for item in items { item.view.placingLayout = self }
        setChildren(items.map(\.view))
        invalidateMeasurements()
        return true
    }

    /// Holds `views` in the panel in this order, the one it draws them in.
    func setChildren(_ views: [WinUIView]) {
        guard views.count != held.count || !zip(views, held).allSatisfy({ $0 === $1 }) else { return }

        let handles: [StateUIObjectRef?] = views.map(\.handle)
        stateui_winui_panel_set_children(handle, handles, Int32(handles.count))
        held = views
    }

    /// Asks WinUI to arrange the children again: a place in the air lands in the pass it asks for.
    func invalidateArrange() {
        stateui_winui_invalidate_arrange(handle)
    }

    /// Forgets the kept sizes and asks WinUI to measure again.
    func invalidateMeasurements() {
        forgetMeasurements()
        invalidateMeasure()
    }

    /// Forgets the sizes this layout keeps.
    func forgetMeasurements() {
        measurements.invalidate()
    }

    /// Answers WinUI's measure: the room the children take for the room offered, every child measured again.
    /// Design: docs/design/platforms/winui/layout.md#measured-every-pass
    func measure(width: Double, height: Double) -> LayoutSize {
        forgetMeasurements()
        let offered = width.isFinite ? width : nil
        return measurements.size(offering: offered) { contentSize(width: offered) }
    }

    /// Answers WinUI's arrange: places every child in `width` by `height` DIPs, inside the pass.
    func arrange(width: Double, height: Double) {
        WinUIView.arranging += 1
        defer { WinUIView.arranging -= 1 }
        arrange(in: Rect(x: 0, y: 0, width: width, height: height))
    }

    /// The room the children take for the width offered, in DIPs.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// Places the children in `bounds`, in DIPs.
    func arrange(in bounds: Rect) {}
}
