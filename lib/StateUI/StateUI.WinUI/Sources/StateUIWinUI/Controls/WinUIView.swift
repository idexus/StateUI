// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WinUI element Swift holds, and the number the relay calls back with.
/// Design: docs/design/platforms/winui/relay.md#a-view-and-its-number
@MainActor
class WinUIView {
    /// The element, held until this is released or another stands in its place (`replaceNative`).
    private(set) var handle: StateUIObjectRef

    /// Whether another element came to stand in this one's place, which its values are all written to again.
    var replacedNative = false

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

    /// The tip last laid on the element; nil for none.
    private var writtenTip: HostMatrix?

    /// The opacity, the drawing order and the direction last written.
    private var writtenOpacity = 1.0
    private var writtenZIndex: Int32 = 0
    private var writtenRightToLeft = false

    /// What the view paints with brushes that follow its size, by what they paint.
    private var paintsBySize: [Painted: (LayoutSize) -> Void] = [:]

    /// What a view paints with brushes that may follow its size, in the order they are painted again.
    enum Painted: Comparable {
        case background, look, shape
    }

    private static let live = LiveViews<WinUIView>()

    /// Takes the next number and holds the element `make` makes, handed that number.
    init(_ make: (_ number: Int64) -> StateUIObjectRef?) {
        number = Self.live.reserve()
        guard let handle = make(number) else { fatalError("the relay made no element - its log says why") }
        self.handle = handle
        Self.live.hold(self, as: number)
        // A control's style aligns it inside its place; a StateUI layout decides the place, so it fills it.
        // Design: docs/design/platforms/winui/layout.md#a-place-filled
        stateui_winui_fill_place(handle)
        if keepsTyping { stateui_winui_hear_focus(handle, number, true) }
    }

    isolated deinit {
        Self.live.release(number)
        stateui_winui_release(handle)
    }

    /// Stands `replacement`, made for this view's number, in the element's place and lets the element go: what every
    /// view holds is heard and written on it again, and its element writes it all its values (`replacedNative`).
    /// Design: docs/design/platforms/winui/controls.md#a-password
    func replaceNative(with replacement: StateUIObjectRef) {
        if !hearing.isEmpty { stateui_winui_hear(handle, number, 0) }
        if hearsFocus { stateui_winui_hear_focus(handle, number, false) }
        stateui_winui_replace(handle, replacement)
        stateui_winui_release(handle)
        handle = replacement
        replacedNative = true

        stateui_winui_fill_place(handle)
        if !hearing.isEmpty { stateui_winui_hear(handle, number, hearing.rawValue) }
        if hearsFocus { stateui_winui_hear_focus(handle, number, true) }
        stateui_winui_set_shown(handle, isShown)
        stateui_winui_set_opacity(handle, writtenOpacity)
        stateui_winui_set_z_index(handle, writtenZIndex)
        stateui_winui_set_flow_direction(handle, writtenRightToLeft)
        if offered != .none { stateui_winui_offer_drag(handle, number, offered.words, offered.takesWords, offered.takesFiles) }
        writtenTip = nil
        writeTransform()
        let frame = placedFrame
        for what in paintsBySize.keys.sorted() { paintsBySize[what]?(LayoutSize(width: frame.width, height: frame.height)) }
        invalidateMeasure()
        placingLayout?.invalidateArrange()
    }

    /// The live view a callback names; nil once it has left.
    static func find(_ number: Int64) -> WinUIView? {
        live.find(number)
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

    /// The view whose native control answers the user: this one, or the control a layout of it holds.
    var answering: WinUIView { self }

    /// Whether the control answers the user; a view that is no control keeps no such state on WinUI.
    func setEnabled(_ enabled: Bool) {
        stateui_winui_set_enabled(answering.handle, enabled)
    }

    /// What the view is drawn over, under its whole frame; nil for WinUI's own. A control paints it as its template
    /// paints its container, field or face; a view that paints no ground of its own takes none.
    /// Design: docs/design/platforms/winui/drawing.md#a-views-background
    func setBackground(_ value: HostValue?) {
        let brush = WinUIBrush(value)
        paint(.background, followsSize: brush.followsSize) { [handle] size in
            brush.withRelayBrush(over: size) { stateui_winui_set_background(handle, $0) }
        }
    }

    /// The keys pressing the view while its window is in front: WinUI's own accelerator on it; nil for none.
    func setShortcut(_ shortcut: KeyboardShortcut?) {
        let spelled = shortcut.flatMap(WinUIKeys.spelled) ?? (key: 0, modifiers: 0)
        let givesWay = shortcut.map(KeyboardShortcuts.givesWayToTyping) ?? false
        stateui_winui_set_shortcut(handle, spelled.key, spelled.modifiers, givesWay)
    }

    /// The words WinUI shows over the view while the pointer rests on it; nil shows none.
    func setTooltip(_ text: String?) {
        stateui_winui_set_tooltip(handle, text)
    }

    /// Whether clicks and touches go through the view to what is behind it.
    func setIgnoresInput(_ ignores: Bool) {
        stateui_winui_set_hit_testable(handle, !ignores)
    }

    /// Whether the view lays itself out and writes in its element's direction: a control does; a layout, whose
    /// places the host layer's arithmetic mirrors, and a drawing, which no direction turns, stand left to right.
    /// Design: docs/design/platforms/winui/layout.md#right-to-left
    var takesDirection: Bool { false }

    /// The view WinUI holds the element's direction in: this one where it takes it; nil where it stands left to right.
    var directionHolder: WinUIView? { takesDirection ? self : nil }

    /// Lays the view out in `direction` where it takes one, else left to right: written either way, as WinUI hands
    /// an element's direction down to what stands in it.
    func setDirection(_ direction: LayoutDirection) {
        writtenRightToLeft = takesDirection && direction == .rightToLeft
        stateui_winui_set_flow_direction(handle, writtenRightToLeft)
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

    /// How the view is drawn over its place: its own transform with a placing layout's over it
    /// (`HostDrawingTransform.under`).
    var drawing: HostDrawingTransform {
        transform.under(placedDrawing)
    }

    /// Writes how the view is drawn about its pivot in the size it was last placed at: moved, turned and scaled flat
    /// by its render transform, then tipped by a projection where it tips (`HostDrawingTransform.tip`).
    /// Design: docs/design/platforms/winui/drawing.md#a-tipped-view
    private func writeTransform() {
        let drawn = drawing
        let size = placed ?? Rect(x: 0, y: 0, width: 0, height: 0)
        stateui_winui_set_transform(
            handle, drawn.translationX, drawn.translationY, drawn.rotation,
            drawn.scaleX, drawn.scaleY, drawn.pivotX * size.width, drawn.pivotY * size.height)
        let tip = drawn.tip(width: size.width, height: size.height)
        guard tip != writtenTip else { return }
        writtenTip = tip
        guard let tip else { return stateui_winui_set_projection(handle, nil) }
        let numbers = [
            tip.m11, tip.m12, tip.m13, tip.m14, tip.m21, tip.m22, tip.m23, tip.m24,
            tip.m31, tip.m32, tip.m33, tip.m34, tip.m41, tip.m42, tip.m43, tip.m44,
        ]
        stateui_winui_set_projection(handle, numbers)
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
            // A layout of StateUI's measures its own children where it lays them out - the room it is bound for,
            // else its place - before it is put there.
            // Design: docs/design/platforms/winui/layout.md#measured-every-pass
            if let layout = self as? WinUILayoutView, placingLayout != nil {
                let width = layout.arrangementRoom?.width ?? place.width
                _ = measure(width: width, height: nil)
                layout.standsAt = width
            }
            stateui_winui_arrange(handle, place.x, place.y, place.width, place.height)
        } else {
            placingLayout?.invalidateArrange()
        }
        if resized, transform != .identity || placedDrawing != nil { writeTransform() }
        if resized {
            for what in paintsBySize.keys.sorted() { paintsBySize[what]?(LayoutSize(width: place.width, height: place.height)) }
        }
    }

    /// Paints `what` with `paint` at the view's size now, and again at each new size where its brushes follow the
    /// size of what they paint (`WinUIBrush.followsSize`).
    /// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush
    func paint(_ what: Painted, followsSize: Bool, _ paint: @escaping (LayoutSize) -> Void) {
        paintsBySize[what] = followsSize ? paint : nil
        let frame = placedFrame
        paint(LayoutSize(width: frame.width, height: frame.height))
    }

    /// Nothing of the view's own follows where its place travels.
    func travels(to destination: Rect?) {}

    /// Where the element's top left corner stands in its window's content, in DIPs.
    var origin: Point {
        var corner = [0.0, 0.0]
        stateui_winui_origin(handle, &corner)
        return Point(x: corner[0], y: corner[1])
    }

    /// Where the view stands, in DIPs: its frame in its parent, its place in the window, and that place from
    /// `safeArea`, the safe area's top left in the window.
    func frameReport(safeArea: Point) -> [Double] {
        MountedElement.frameNumbers(place: placedFrame, corner: origin, content: safeArea)
    }

    /// Where WinUI laid the element out in its parent, in DIPs.
    var laidOutFrame: Rect {
        var frame = [0.0, 0.0, 0.0, 0.0]
        stateui_winui_frame(handle, &frame)
        return Rect(x: frame[0], y: frame[1], width: frame[2], height: frame[3])
    }

    /// The control's one accent color; nil for the platform's.
    /// Design: docs/design/platforms/winui/controls.md#a-controls-accent
    func setTint(_ tint: HostValue?) {
        let argb = tint?.argb
        stateui_winui_set_tint(handle, argb ?? 0, argb != nil, PressedFill.underPointer, PressedFill.pressed)
    }

    /// What assistive technology meets of the view: nil words and presence for the control's own, a heading level
    /// of 0 for none.
    /// Design: docs/design/platforms/winui/controls.md#what-assistive-technology-meets
    func setAccessibility(_ words: AccessibilityWords) {
        let met: StateUIPresence = switch words.presence {
        case nil: .own
        case .met: .met
        case .hidden: .skipped
        // A control's parts are its template's, left out with it; a layout holds its children back itself.
        case .hiddenWithChildren: self is WinUILayoutView ? .skipped : .skippedWithParts
        }
        stateui_winui_set_accessibility(handle, words.identifier, words.label, words.hint, words.headingLevel, met)
    }

    /// The user clicked the view.
    func clicked() {}

    /// The user chose one of the view's entries by its place: an action of the window's chrome, or its way back (-1),
    /// sidebar toggle (-2) or Escape (-3); a tab; a picker's choice.
    func chose(_ index: Int) {}

    /// What the view presents opened or closed of WinUI's accord: a split view's sidebar, a picker's list, a date
    /// picker's calendar.
    func presented(_ open: Bool) {}

    /// The user picked a day - its year, month and day - or a time of day - its hour, minute and 0.
    func picked(_ first: Int32, _ second: Int32, _ third: Int32) {}

    /// The color a color picker holds changed - the user's, or the program's: its channels as one ARGB number.
    func colorChosen(_ argb: UInt32) {}

    /// What the items of the menus the view offers do, in their order: its context menu's, or a menu bar's.
    var menuActions: [() -> Void] = []

    /// Gives the view `menu` as its context menu; an empty one takes it away.
    /// Design: docs/design/platforms/winui/pages.md#menus
    func setContextMenu(_ menu: WinUIMenu) {
        menuActions = menu.actions
        menu.relayed { stateui_winui_set_context_menu(handle, number, $0, $1, $2, $3, $4, $5, $6, $7, $8, $9) }
    }

    /// The user holds the view down or lets it go: a scroller taken hold of, a button's press.
    func held(_ holding: Bool) {}

    /// What the view does when the keyboard comes into it or leaves; nil hears nothing.
    private var onFocusChanged: ((Bool) -> Void)?

    /// Whether the view hears the keyboard come into it whatever the tree hears: a field, the last of which the user
    /// typed into an Edit menu's own entries act on (`WinUIEditing`).
    var keepsTyping: Bool { false }

    /// Whether the relay tells the view of the keyboard coming and going.
    private var hearsFocus: Bool { onFocusChanged != nil || keepsTyping }

    /// Hears the keyboard come into the view and leave it, while `action` is set.
    func setFocusChanged(_ action: ((Bool) -> Void)?) {
        let heard = hearsFocus
        onFocusChanged = action
        if hearsFocus != heard { stateui_winui_hear_focus(handle, number, hearsFocus) }
    }

    /// The keyboard came into the view or left it.
    func focusChanged(_ focused: Bool) {
        if focused, keepsTyping { WinUIEditing.typed = self }
        onFocusChanged?(focused)
    }

    /// The user chose the item at `index` of the view's menus.
    func menuChosen(_ index: Int) {
        if menuActions.indices.contains(index) { menuActions[index]() }
    }

    /// What of the user's input the view listens for, the way a hand moves it where it hears one; what hears it.
    private(set) var hearing: Hearing = []
    private var hand: (way: HandWay?, pinches: Bool) = (nil, false)
    private var onHeard: ((HeardInput) -> Bool)?

    /// What the view offers and takes of a drag, as last told to the relay; what hears it.
    private(set) var offered = DragAndDrop.none
    private var onDragHeard: ((HeardInput) -> Void)?

    /// The press the view heard, on its way to a drag by the host layer's rule.
    private var press = DragRecognition(distance: WinUIView.dragDistance)

    /// The run of taps the view heard, by the host layer's rule, as Windows measures its double click.
    private var taps = WinUIView.doubleTap

    /// The system's double click, as a run of taps.
    private static let doubleTap: TapRun = {
        var tap = [0.5, 2.0]
        stateui_winui_double_tap(&tap)
        return TapRun(interval: .milliseconds(Int((tap[0] * 1000).rounded())), slop: tap[1])
    }()

    /// The system's drag distance, in DIPs.
    private static let dragDistance: DragRecognition.Distance = {
        var distance = [4.0, 4.0]
        stateui_winui_drag_distance(&distance)
        return .eachAxis(x: distance[0], y: distance[1])
    }()

    /// Listens for what `hearing` names - a hand `way` - `heard` hearing it; the relay is told only a change, in its
    /// bits, which are `Hearing`'s, and the hand's way as 0 across, 1 down, 2 every way, with whether the wheel
    /// turned with Control scales.
    /// Design: docs/design/platforms/winui/input.md
    func hear(_ hearing: Hearing, way: HandWay? = nil, _ heard: @escaping (HeardInput) -> Bool) {
        onHeard = hearing.isEmpty ? nil : heard
        if hearing != self.hearing {
            self.hearing = hearing
            stateui_winui_hear(handle, number, hearing.rawValue)
        }
        let way = hearing.contains(.hand) ? way : nil
        let pinches = hearing.contains(.pinches)
        guard way != hand.way || pinches != hand.pinches else { return }

        hand = (way, pinches)
        let axis: StateUIHandAxis = switch way {
        case .horizontal: .horizontal
        case .vertical: .vertical
        case .everyWay: .everyWay
        case nil: .none
        }
        stateui_winui_hear_hand(handle, number, axis, pinches ? 1 : 0)
    }

    /// What the relay says the view heard.
    func heard(_ heard: HeardInput) {
        _ = onHeard?(heard)
    }

    /// A tap the relay says landed at `point` in the view at `time`, its place in its run counted by the host
    /// layer's rule (`TapRun`) - where the view counts runs; a single tap is the press's.
    func heardTap(at point: Point, time: Duration) {
        guard countsRuns else { return }
        heard(.tap(run: taps.tapped(at: point, time: time)))
    }

    /// Whether the view counts a run of taps.
    var countsRuns = false

    /// A press the relay says stands on the view at `phase`, at `point` in it: taken as a button takes one by the
    /// host layer's rule.
    /// Design: docs/design/platforms/winui/input.md#taps
    func heardButtonPress(_ phase: GesturePhase, at point: Point, byFinger: Bool) {
        let size = placed.map { LayoutSize(width: $0.width, height: $0.height) } ?? measure(width: nil, height: nil)
        heard(.press(phase, at: point, size: size, byFinger: byFinger))
    }

    /// A press the relay says WinUI held: the hold's where it has not become a drag, by the host layer's rule.
    /// Design: docs/design/host/runtime.md#a-press-held
    func heardHold() {
        guard press.held() else { return }
        heard(.hold)
    }

    /// The hand over a layout the relay tells - begun where a pointer went down, none for a trackpad's fingers;
    /// moved by what it moved under it; let go; taken away - at `time` on the pointer's clock, its speed at the lift
    /// as the platform tells it, or read by the host layer from its moves: the host's entry. Whether the layout took
    /// it.
    /// Design: docs/design/platforms/winui/input.md#the-hand-over-a-layout
    func heardHand(phase: Int32, moved: Point, at time: Double? = nil, speed: Point? = nil) -> Bool {
        guard let phase = GesturePhase(rawValue: phase) else { return false }

        if phase == .began {
            let point = moved.x.isNaN || moved.y.isNaN ? nil : moved
            return onHeard?(.hand(.began, moved: .zero, speed: nil, at: time, point: point)) ?? false
        }
        return onHeard?(.hand(phase, moved: moved, speed: speed, at: time)) ?? false
    }

    /// A finger over a layout a hand moves, as the relay tells it at `phase` - down, moved, let go or taken away - by
    /// its number, where it stands on the window's content and in the view, at `time` on the pointer's clock: read as
    /// one hand by the host layer's rule (`HandRecognition`). Where the hand stands now.
    /// Design: docs/design/platforms/winui/input.md#the-hand-over-a-layout
    func heardFinger(phase: Int32, pointer: Int, at point: Point, inView: Point, time: Double?) -> StateUIHandState {
        let pressed = StateUIPressPhase(rawValue: .init(phase))
        let step = switch pressed {
        case .down: handRecognition.down(pointer, at: point, inView: inView)
        case .moved: handRecognition.moved(pointer, to: point)
        default: handRecognition.up(pointer, letGo: pressed == .letGo)
        }
        switch step {
        case .began(let at): _ = onHeard?(.hand(.began, moved: .zero, speed: nil, at: time, point: at))
        case .asks(let travel):
            handRecognition.answered(taken: onHeard?(.hand(.changed, moved: travel, speed: nil, at: time)) ?? false)
        case .moved(let moved): _ = onHeard?(.hand(.changed, moved: moved, speed: nil, at: time))
        case .ended(let letGo): _ = onHeard?(.hand(letGo ? .ended : .cancelled, moved: .zero, speed: nil, at: time))
        case .nothing: break
        }
        return handRecognition.isTaken ? .taken : handRecognition.isOpen ? .asking : .left
    }

    /// The fingers on the layout the view shows, read as one hand by the host layer's rule, past the system's drag
    /// distance.
    private var handRecognition = HandRecognition(distance: WinUIView.dragDistance)

    /// A wheel's notch over a layout, as what it moved under the hand. Whether the layout took it.
    func heardWheel(moved: Point) -> Bool {
        onHeard?(.wheel(moved)) ?? false
    }

    /// Offers and takes what `offered` says of a drag, `heard` hearing it; the relay is told only a change.
    /// Design: docs/design/platforms/winui/input.md#a-drag-between-views
    func offer(_ offered: DragAndDrop, _ heard: @escaping (HeardInput) -> Void) {
        onDragHeard = offered == .none ? nil : heard
        guard offered != self.offered else { return }
        self.offered = offered
        stateui_winui_offer_drag(handle, number, offered.words, offered.takesWords, offered.takesFiles)
    }

    /// What the relay says the view heard of a drag, a drop with its words.
    func heardDrag(_ heard: StateUIDragHeard, words: String) {
        let input: HeardInput = switch heard {
        case .started: .dragStarted
        case .ended: .dragEnded
        case .over: .dragOver
        case .left: .dragLeft
        case .dropped: .dropped(words)
        }
        heardDrag(input)
    }

    /// What the view heard of a drag, handed to what hears it.
    func heardDrag(_ heard: HeardInput) {
        onDragHeard?(heard)
    }

    /// A press the relay tells - down, moved, let go or taken away, at `point` of the window's content: a drag by the
    /// host layer's rule, and as it becomes one the view holds the pointer.
    /// Design: docs/design/platforms/winui/input.md#a-press-dragged
    func heardPress(_ phase: StateUIPressPhase, at point: Point) {
        switch phase {
        case .down:
            press.pressed(at: point)
        case .moved:
            let wasDragging = press.isDragging
            let told = press.moved(to: point)
            if press.isDragging, !wasDragging { stateui_winui_press_dragged(number) }
            for each in told { heard(each) }
        case .letGo, .takenAway:
            if let end = press.ended(letGo: phase == .letGo) { heard(end) }
        }
    }

    /// The element left the tree: the view lets go of everything that would call back into it. A view that
    /// overrides this lets go of what every view holds first, then of its own.
    func detach() {
        hear([]) { _ in false }
        setFocusChanged(nil)
        offer(.none) { _ in }
        menuActions = []
        paintsBySize = [:]
    }
}

extension WinUIView: PlacedView {
    /// Where the view stands in its parent, in DIPs - where the host last placed it, or where WinUI has it.
    var placedFrame: Rect {
        get { placed ?? laidOutFrame }
        set { layout(newValue) }
    }

    /// Whether a layout has placed the view: StateUI's, or WinUI's giving it a size.
    var isLaidOut: Bool {
        let frame = placed == nil ? laidOutFrame : Rect(0, 0, 0, 0)
        return MountedElement.isLaidOut(placed: placed != nil, width: frame.width, height: frame.height)
    }
}
