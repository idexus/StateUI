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

    /// The layout's own box: what fills it, its outline, its shape and whether it cuts what it shows.
    struct Box: Equatable {
        var fill: HostValue?
        var stroke: HostValue?
        var width: Double?
        var shape: HostValue?
        var clips = false
    }

    /// The box as the element says it.
    private(set) var box = Box()

    /// The shape drawn behind the children; nil while the box paints nothing.
    private(set) var boxView: WinUIShapeView?

    /// The cut last written, over the size it was written at.
    private var cut: (outline: WinUIOutline, width: Double, height: Double)?

    /// The elements the panel holds, in the order it draws them, back to front.
    private var held: [WinUIView] = []
    private var heldBox: WinUIShapeView?

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
        holdChildren()
        invalidateMeasurements()
        return true
    }

    /// The views the panel holds, in the order it draws them: every child's, unless a layout shows fewer.
    func heldViews() -> [WinUIView] {
        items.map(\.view)
    }

    /// Holds the views this layout shows now.
    func holdChildren() {
        setChildren(heldViews())
    }

    /// Holds `views` in the panel in this order, the one it draws them in, over the box.
    func setChildren(_ views: [WinUIView]) {
        guard boxView !== heldBox || views.count != held.count || !zip(views, held).allSatisfy({ $0 === $1 })
        else { return }

        let handles: [StateUIObjectRef?] = (boxView.map { [$0.handle] } ?? []) + views.map(\.handle)
        stateui_winui_panel_set_children(handle, handles, Int32(handles.count))
        held = views
        heldBox = boxView
    }

    /// What fills the box: a colour or a brush; nil for nothing.
    func setBackground(_ value: HostValue?) {
        box.fill = value
        paintBox()
    }

    /// The box's outline, its shape, and whether it cuts what the layout shows to that shape.
    func setOutline(stroke: HostValue?, width: Double?, shape: HostValue?, clips: Bool) {
        box.stroke = stroke
        box.width = width
        box.shape = shape
        box.clips = clips
        paintBox()
    }

    /// Paints the box behind the children, made, remade for another outline, or let go of, and asks for an
    /// arrangement to place it and its cut.
    /// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush
    private func paintBox() {
        let outline = WinUIOutline(container: box.shape)
        let fill = WinUIBrush(box.fill)
        let stroke = WinUIBrush(box.stroke)
        let width = box.stroke == nil ? 0 : max(0, box.width ?? 1)

        if fill == .none, stroke == .none || width == 0 {
            boxView = nil
        } else {
            let ellipse = outline == .ellipse
            if boxView?.isEllipse != ellipse { boxView = WinUIShapeView(ellipse: ellipse) }
            boxView?.paint(radius: outline.relay.radius, fill: fill, stroke: stroke, width: width)
        }
        setChildren(held)
        invalidateArrange()
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

    /// Answers WinUI's measure, every child measured again: no room where a StateUI layout places this one, which
    /// reads its size from `naturalSize(width:)`, and otherwise the room the children take, within the room offered.
    /// Design: docs/design/platforms/winui/layout.md#no-room-asked
    func measure(width: Double, height: Double) -> LayoutSize {
        Self.measuring += 1
        defer { Self.measuring -= 1 }

        forgetMeasurements()
        _ = boxView?.measure(width: width, height: height)
        let offered = width.isFinite ? width : nil
        let size = naturalSize(width: offered)
        reportChange(of: size, offered: offered)
        guard placingLayout == nil else { return .zero }
        return LayoutSize(width: min(size.width, width), height: min(size.height, height))
    }

    /// How many StateUI layouts are measuring, one inside another.
    private static var measuring = 0

    /// The width of the place this layout was last put in; nil before its first.
    var standsAt: Double?

    /// The natural size last measured, and the width it was offered.
    private var measured: (offered: Double?, size: LayoutSize)?

    /// A natural size that changed outside the placing layout's own measure - a picture loaded, a word changed -
    /// asks that layout to measure again: WinUI hears no change from a layout that asks it for no room.
    /// Design: docs/design/platforms/winui/layout.md#a-change-told-upward
    private func reportChange(of size: LayoutSize, offered: Double?) {
        defer { measured = (offered, size) }
        guard let placingLayout, Self.measuring == 1, let measured, measured.offered == offered, measured.size != size
        else { return }

        placingLayout.invalidateMeasurements()
    }

    /// The room the children take for the width offered, in DIPs, kept until a change beneath marks the layout.
    func naturalSize(width: Double?) -> LayoutSize {
        measurements.size(offering: width) {
            Self.sizings += 1
            return contentSize(width: width)
        }
    }

    /// How many times a layout has sized its children - what a test counts.
    static var sizings = 0

    /// Answers WinUI's arrange: places the box and every child in `width` by `height` DIPs, inside the pass.
    func arrange(width: Double, height: Double) {
        WinUIView.arranging += 1
        defer { WinUIView.arranging -= 1 }
        boxView?.layout(Rect(x: 0, y: 0, width: width, height: height))
        writeCut(width: width, height: height)
        arrange(in: Rect(x: 0, y: 0, width: width, height: height))
    }

    /// A layout skipped with its children hides from assistive technology all that stands in it.
    override func setAccessibility(
        identifier: String?, label: String?, hint: String?, headingLevel: Int32, presence: AccessibilityPresence?
    ) {
        super.setAccessibility(
            identifier: identifier, label: label, hint: hint, headingLevel: headingLevel, presence: presence)
        stateui_winui_panel_hide_children(handle, presence == .hiddenWithChildren)
    }

    /// Cuts what the layout shows to its outline at its size, written only where it differs.
    private func writeCut(width: Double, height: Double) {
        let outline = WinUIOutline(container: box.shape)
        let wanted = box.clips ? (outline, width, height) : nil
        guard wanted?.0 != cut?.outline || wanted?.1 != cut?.width || wanted?.2 != cut?.height else { return }

        cut = wanted
        stateui_winui_set_clip(handle, box.clips, outline.relay.outline, outline.relay.radius, width, height)
    }

    /// The room the children take for the width offered, in DIPs.
    func contentSize(width: Double?) -> LayoutSize {
        .zero
    }

    /// Places the children in `bounds`, in DIPs.
    func arrange(in bounds: Rect) {}
}
