// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI
import ucrt

/// A WinUI element Swift holds, and the number the relay calls back with.
/// Design: docs/design/platforms/winui/relay.md#a-view-and-its-number
@MainActor
class WinUIView {
    /// The element, held until this is released.
    let handle: StateUIObjectRef

    /// The number the relay's callbacks name this view by.
    let number: Int64

    /// The layout that places this view, which a place written between passes asks to arrange again.
    weak var placingLayout: WinUILayoutView?

    /// How deep the layout passes under way stand: a place written inside one lands at once.
    static var arranging = 0

    /// Where the view was last placed, in DIPs of its parent; nil before its first place.
    private(set) var placed: Rect?

    /// How opaque the view's own property draws it, and whether it shows, as the host last wrote them.
    private(set) var opacity = 1.0
    private(set) var isShown = true

    /// How the view's own properties move, turn and scale it.
    private var transform = HostDrawingTransform.identity

    /// How a placing layout draws the view over the place it gave, and how opaque; nil and 1 for as the view says.
    private var placedDrawing: HostDrawingTransform?
    private var placedOpacity = 1.0

    /// The opacity and the drawing order last written.
    private var writtenOpacity = 1.0
    private var writtenZIndex: Int32 = 0

    private static var nextNumber: Int64 = 0
    private static var live: [Int64: Weak] = [:]

    /// Takes the next number and holds the element `make` makes, handed that number.
    init(_ make: (_ number: Int64) -> StateUIObjectRef?) {
        Self.nextNumber += 1
        number = Self.nextNumber
        guard let handle = make(number) else { fatalError("the relay made no element - its log says why") }
        self.handle = handle
        Self.live[number] = Weak(self)
        // A control's style aligns it inside its place; a StateUI layout decides the place, so it fills it.
        // Design: docs/design/platforms/winui/layout.md#a-place-filled
        stateui_winui_fill_place(handle)
    }

    isolated deinit {
        Self.live[number] = nil
        stateui_winui_release(handle)
    }

    /// The live view a callback names; nil once it has left.
    static func find(_ number: Int64) -> WinUIView? {
        live[number]?.view
    }

    /// How many views Swift holds - what a test counts to see every one let go.
    static var liveCount: Int { live.count }

    // MARK: - What every view takes

    func setShown(_ shown: Bool) {
        isShown = shown
        stateui_winui_set_shown(handle, shown)
    }

    /// How opaque the view's own property draws it, with a placing layout's opacity over it; written only where
    /// it differs from what was.
    func setOpacity(_ opacity: Double) {
        self.opacity = opacity
        let drawn = opacity * placedOpacity
        guard drawn != writtenOpacity else { return }
        writtenOpacity = drawn
        stateui_winui_set_opacity(handle, drawn)
    }

    /// How a placing layout draws the view over the place it gave, and how opaque; nil and 1 for as the view says.
    /// Design: docs/design/platforms/winui/drawing.md#a-placed-child
    func setPlacedDrawing(_ drawing: HostDrawingTransform?, opacity: Double) {
        guard drawing != placedDrawing || opacity != placedOpacity else { return }

        placedDrawing = drawing
        placedOpacity = opacity
        writeTransform()
        setOpacity(self.opacity)
    }

    /// Whether clicks and touches go through the view to what is behind it.
    func setIgnoresInput(_ ignores: Bool) {
        stateui_winui_set_hit_testable(handle, !ignores)
    }

    /// Where the view is drawn among its layout's children, written only where it differs.
    func setZIndex(_ z: Int32) {
        guard z != writtenZIndex else { return }
        writtenZIndex = z
        stateui_winui_set_z_index(handle, z)
    }

    /// Moves, turns and scales the view where its layout put it, in DIPs and degrees.
    func setTransform(_ transform: HostDrawingTransform) {
        self.transform = transform
        writeTransform()
    }

    /// Writes the view's own transform, with a placing layout's over it, about its pivot in the size the view was
    /// last placed at - the centre under a placing layout's drawing.
    private func writeTransform() {
        var drawn = transform
        if let placed = placedDrawing {
            let angle = placed.rotation * .pi / 180
            let x = transform.translationX * placed.scaleX
            let y = transform.translationY * placed.scaleY
            drawn.translationX = placed.translationX + x * cos(angle) - y * sin(angle)
            drawn.translationY = placed.translationY + x * sin(angle) + y * cos(angle)
            drawn.rotation += placed.rotation
            drawn.scaleX *= placed.scaleX
            drawn.scaleY *= placed.scaleY
            drawn.pivotX = 0.5
            drawn.pivotY = 0.5
        }
        let size = placed ?? Rect(x: 0, y: 0, width: 0, height: 0)
        stateui_winui_set_transform(
            handle, drawn.translationX, drawn.translationY, drawn.rotation,
            drawn.scaleX, drawn.scaleY, drawn.pivotX * size.width, drawn.pivotY * size.height)
    }

    /// Asks WinUI to measure this element again, and every panel above it.
    func invalidateMeasure() {
        stateui_winui_invalidate_measure(handle)
    }

    /// The element's size for the room offered, in DIPs; nil offers any.
    /// Design: docs/design/platforms/winui/layout.md#measured-every-pass
    func measure(width: Double?, height: Double?) -> LayoutSize {
        var size = [0.0, 0.0]
        stateui_winui_measure(handle, width ?? .infinity, height ?? .infinity, &size)
        return LayoutSize(width: size[0], height: size[1])
    }

    /// Places the element at `place`, in DIPs of its parent: at once inside a pass, and between passes by asking
    /// the layout for one.
    /// Design: docs/design/platforms/winui/layout.md#a-place-between-passes
    func layout(_ place: Rect) {
        let resized = placed.map { $0.width != place.width || $0.height != place.height } ?? true
        placed = place
        if Self.arranging > 0 {
            stateui_winui_arrange(handle, place.x, place.y, place.width, place.height)
        } else {
            placingLayout?.invalidateArrange()
        }
        if resized, transform != .identity || placedDrawing != nil { writeTransform() }
    }

    /// Where the element's top left corner stands in its window's content, in DIPs.
    var origin: Point {
        var corner = [0.0, 0.0]
        stateui_winui_origin(handle, &corner)
        return Point(x: corner[0], y: corner[1])
    }

    /// Where the view stands, in DIPs: its frame in its parent, its place in the window, and that place from
    /// `safeArea`, the safe area's top left in the window.
    func frameReport(safeArea: Point) -> [Double] {
        let place = placedFrame
        let corner = origin
        return [place.x, place.y, place.width, place.height, corner.x, corner.y,
                corner.x - safeArea.x, corner.y - safeArea.y]
    }

    /// Where WinUI laid the element out in its parent, in DIPs.
    var laidOutFrame: Rect {
        var frame = [0.0, 0.0, 0.0, 0.0]
        stateui_winui_frame(handle, &frame)
        return Rect(x: frame[0], y: frame[1], width: frame[2], height: frame[3])
    }

    /// The control's one accent colour; nil for the platform's.
    /// Design: docs/design/platforms/winui/controls.md#a-controls-accent
    func setTint(_ tint: HostValue?) {
        let argb = tint.flatMap(WinUIBrush.argb)
        stateui_winui_set_tint(handle, argb ?? 0, argb != nil)
    }

    /// Whether assistive technology meets a view: met, skipped, or skipped with everything that stands in it.
    enum AccessibilityPresence {
        case met
        case hidden
        case hiddenWithChildren
    }

    /// What assistive technology meets of the view: nil words and presence for the control's own, a heading level
    /// of 0 for none.
    /// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets
    func setAccessibility(
        identifier: String?, label: String?, hint: String?, headingLevel: Int32, presence: AccessibilityPresence?
    ) {
        let met: Int32 = switch presence {
        case nil: 0
        case .met: 1
        case .hidden, .hiddenWithChildren: 2
        }
        stateui_winui_set_accessibility(handle, identifier, label, hint, headingLevel, met)
    }

    /// The user clicked the view.
    func clicked() {}

    /// The user chose one of the view's entries by its place: an action of the window's chrome, or its way back (-1)
    /// or sidebar toggle (-2); a tab.
    func chose(_ index: Int) {}

    /// What the view presents opened or closed of WinUI's accord: a split view's sidebar, a picker's list, a date
    /// picker's calendar.
    func presented(_ open: Bool) {}

    /// The user picked a day - its year, month and day - or a time of day - its hour, minute and 0.
    func picked(_ first: Int32, _ second: Int32, _ third: Int32) {}

    /// What the items of the menus the view offers do, in their order: its context menu's, or a menu bar's.
    var menuActions: [() -> Void] = []

    /// Gives the view `menu` as its context menu; an empty one takes it away.
    /// Design: docs/design/platforms/winui/pages.md#menus
    func setContextMenu(_ menu: WinUIMenu) {
        menuActions = menu.actions
        WinUIStrings.withCStrings(menu.titles) { titles in
            menu.kinds.withUnsafeBufferPointer { kinds in
                menu.enabled.withUnsafeBufferPointer { enabled in
                    stateui_winui_set_context_menu(
                        handle, number, kinds.baseAddress, titles, enabled.baseAddress, Int32(kinds.count))
                }
            }
        }
    }

    /// The user holds the view down or lets it go: a scroller taken hold of, a button's press.
    func held(_ holding: Bool) {}

    /// What the view does when the keyboard comes into it or leaves; nil hears nothing.
    private var onFocusChanged: ((Bool) -> Void)?

    /// Hears the keyboard come into the view and leave it, while `action` is set.
    func setFocusChanged(_ action: ((Bool) -> Void)?) {
        if (action != nil) != (onFocusChanged != nil) { stateui_winui_hear_focus(handle, number, action != nil) }
        onFocusChanged = action
    }

    /// The keyboard came into the view or left it.
    func focusChanged(_ focused: Bool) {
        onFocusChanged?(focused)
    }

    /// The user chose the item at `index` of the view's menus.
    func menuChosen(_ index: Int) {
        if menuActions.indices.contains(index) { menuActions[index]() }
    }

    /// What of the user's input the view listens for, as the relay's bits; what hears it.
    private(set) var hearing: UInt32 = 0
    private var onHeard: ((WinUIHeard) -> Void)?

    /// Listens for what `hearing` names, `heard` hearing it; the relay is told only a change.
    /// Design: docs/design/platforms/winui/input.md
    func hear(_ hearing: UInt32, _ heard: @escaping (WinUIHeard) -> Void) {
        onHeard = hearing == 0 ? nil : heard
        guard hearing != self.hearing else { return }

        self.hearing = hearing
        stateui_winui_hear(handle, number, hearing)
    }

    /// What the relay says the view heard.
    func heard(_ heard: WinUIHeard) {
        onHeard?(heard)
    }

    /// The element left the tree: the view lets go of everything that would call back into it. A view that
    /// overrides this lets go of what every view holds first, then of its own.
    func detach() {
        hear(0) { _ in }
        setFocusChanged(nil)
        menuActions = []
    }

    private struct Weak {
        weak var view: WinUIView?

        init(_ view: WinUIView) { self.view = view }
    }
}

extension WinUIView: PlacedView {
    /// Where the view stands in its parent, in DIPs - where the host last placed it, or where WinUI has it.
    var placedFrame: Rect {
        get { placed ?? laidOutFrame }
        set { layout(newValue) }
    }
}
