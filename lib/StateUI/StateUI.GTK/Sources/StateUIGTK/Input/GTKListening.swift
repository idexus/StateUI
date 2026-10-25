// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK
import StateUIFoundation

/// One view's listening: a GTK controller for each kind of input the view listens for, and what each remembers of
/// the press it follows. The widget owns the controllers; their signals name the view by its number.
/// Design: docs/design/platforms/gtk/input.md
@MainActor
final class GTKListening {
    private let widget: GTKWidget
    private let number: Int64

    /// What the view listens for.
    private(set) var hearing: Hearing = []

    /// The controllers hung on the widget for each kind of input.
    private(set) var controllers: [Hearing: [OpaquePointer]] = [:]

    /// Where the press a tap follows went down, and whether it has since moved too far to be a tap, or was held.
    private var tapFrom = Point(x: 0, y: 0)
    private var tapMoved = false
    private var tapHeld = false

    /// Where the pointer's press went down in the view.
    private var pointerFrom = Point(x: 0, y: 0)

    /// The press dragged, by the host layer's rule: where it went down on the window, and whether it became a drag.
    private var dragFrom = Point(x: 0, y: 0)
    private var drag = DragRecognition(distance: .eachAxis(x: 0, y: 0))

    /// The scale the pinch last said, since it began.
    private var pinch = PinchStep()
    private var rotation = RotationStep()

    /// The drag a press with Alt is, read as two fingers, while the view hears a pinch or a rotation; where that
    /// press went down, and whether one is under way.
    private(set) var mirroredDrag: OpaquePointer?
    private var mirroredFrom = Point(x: 0, y: 0)
    private var mirroring = false

    /// The hand over a layout: where the drag had come to at its last report, whether its first move past the
    /// threshold is yet to come, and whether the layout took it.
    private var handLast = Point(x: 0, y: 0)
    private var handPending = false
    private var handTaking = false

    init(widget: GTKWidget, number: Int64) {
        self.widget = widget
        self.number = number
    }

    /// Listens for what `hearing` names: a kind newly asked for gets its controllers, one no longer asked for loses
    /// them.
    func listen(for hearing: Hearing) {
        for kind in Hearing.kinds where hearing.contains(kind) != self.hearing.contains(kind) {
            if hearing.contains(kind) {
                let made = makeControllers(for: kind)
                for controller in made { gtk_widget_add_controller(widget, controller) }
                controllers[kind] = made
            } else {
                for controller in controllers[kind] ?? [] { gtk_widget_remove_controller(widget, controller) }
                controllers[kind] = nil
            }
        }
        self.hearing = hearing
        if let pan = controllers[.drags]?.first, let press = controllers[.pointer]?.last {
            gtk_gesture_group(pan, press)
        }
        let mirrors = !hearing.isDisjoint(with: [.pinches, .rotations])
        if mirrors, mirroredDrag == nil {
            let drag = makeMirrored()
            gtk_widget_add_controller(widget, drag)
            mirroredDrag = drag
        } else if !mirrors, let drag = mirroredDrag {
            gtk_widget_remove_controller(widget, drag)
            mirroredDrag = nil
        }
    }

    @discardableResult
    private func tell(_ heard: HeardInput) -> Bool {
        GTKView.find(number)?.heard(heard) ?? false
    }

    private func makeControllers(for kind: Hearing) -> [OpaquePointer] {
        switch kind {
        case .taps: [makeTaps()]
        case .holds: [makeHold()]
        case .pointer: makePointer()
        case .drags: [makeDrag()]
        case .hand: makeHand()
        case .rotations: [makeRotation()]
        default: [makePinch(), makeWheelPinch()]
        }
    }

    // MARK: - Taps

    private func makeTaps() -> OpaquePointer {
        let click = gtk_gesture_click_new()!
        connectSignal(UnsafeMutableRawPointer(click), "pressed", number: number) { _, _, x, y, data in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.tapPressed(at: Point(x: x, y: y)) }
        }
        connectSignal(UnsafeMutableRawPointer(click), "stopped", number: number) { gesture, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.tapStopped(at: GTKListening.point(of: gesture)) }
        }
        connectSignal(UnsafeMutableRawPointer(click), "released", number: number) { gesture, run, x, y, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated {
                GTKListening.find(number)?.tapReleased(OpaquePointer(gesture), run: Int(run), at: Point(x: x, y: y))
            }
        }
        return click
    }

    func tapPressed(at point: Point) {
        tapFrom = point
        tapMoved = false
        tapHeld = false
    }

    /// GTK stopped counting the press as a click - it moved past the drag threshold, or it is held past the
    /// double-click time; only a press that moved is no tap.
    /// Design: docs/design/platforms/gtk/input.md#taps
    func tapStopped(at point: Point?) {
        guard let point else { return }
        if dragDistance.isPassed(by: Point(x: point.x - tapFrom.x, y: point.y - tapFrom.y)) { tapMoved = true }
    }

    /// A press let go: a tap where it has not moved and is let go over the view, claimed so no view around it
    /// answers it too.
    func tapReleased(_ gesture: OpaquePointer?, run: Int, at point: Point) {
        defer { tapMoved = false }
        guard !tapMoved, !tapHeld, gtk_widget_contains(widget, point.x, point.y) != 0 else { return }

        if let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
        tell(.tap(run: run))
    }

    // MARK: - A press held

    private func makeHold() -> OpaquePointer {
        let hold = gtk_gesture_long_press_new()!
        connectSignal(UnsafeMutableRawPointer(hold), "pressed", number: number) { (gesture, _: Double, _: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.held(OpaquePointer(gesture)) }
        }
        return hold
    }

    /// GTK's long press came: a press not yet a drag is the hold's, by the host layer's rule - claimed, so no view
    /// around it answers it, and no tap as it lets go.
    /// Design: docs/design/platforms/gtk/input.md#a-press-held
    func held(_ gesture: OpaquePointer?) {
        guard drag.held() else { return }
        tapHeld = true
        if let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
        tell(.hold)
    }

    /// Waits `milliseconds` for a hold - between half and twice GTK's long-press time, the most GTK waits apart from
    /// it - or GTK's own time for nil.
    func wait(_ milliseconds: Double?) {
        guard let hold = controllers[.holds]?.first else { return }
        let factor = milliseconds.map { $0 / Self.longPressTime(of: widget) } ?? 1
        gtk_gesture_long_press_set_delay_factor(hold, min(max(factor, 0.5), 2))
    }

    /// How long the view's hold waits, in milliseconds; nil while it listens for none.
    var holdTime: Double? {
        controllers[.holds]?.first.map { gtk_gesture_long_press_get_delay_factor($0) * Self.longPressTime(of: widget) }
    }

    private static func longPressTime(of widget: GTKWidget) -> Double {
        var value = GValue()
        g_value_init(&value, g_type_from_name("gint"))
        defer { g_value_unset(&value) }
        g_object_get_property(
            UnsafeMutablePointer<GObject>(gtk_widget_get_settings(widget)), "gtk-long-press-time", &value)
        return Double(g_value_get_int(&value))
    }

    // MARK: - The pointer

    private func makePointer() -> [OpaquePointer] {
        let motion = gtk_event_controller_motion_new()!
        connectSignal(UnsafeMutableRawPointer(motion), "enter", number: number) { _, x, y, data in
            GTKListening.tell(.pointer(.pointerEntered, Point(x: x, y: y)), to: viewNumber(data))
        }
        connectSignal(UnsafeMutableRawPointer(motion), "motion", number: number) { _, x, y, data in
            GTKListening.tell(.pointer(.pointerMoved, Point(x: x, y: y)), to: viewNumber(data))
        }
        connectSignal(UnsafeMutableRawPointer(motion), "leave", number: number) { _, data in
            GTKListening.tell(.pointer(.pointerExited, Point(x: 0, y: 0)), to: viewNumber(data))
        }

        // Any button's press, followed to its end however far it goes.
        let press = gtk_gesture_drag_new()!
        gtk_gesture_single_set_button(press, 0)
        connectSignal(UnsafeMutableRawPointer(press), "drag-begin", number: number) { _, x, y, data in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.pointerPressed(at: Point(x: x, y: y)) }
        }
        connectSignal(UnsafeMutableRawPointer(press), "drag-end", number: number) { _, x, y, data in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.pointerReleased(moved: Point(x: x, y: y)) }
        }
        return [motion, press]
    }

    private func pointerPressed(at point: Point) {
        pointerFrom = point
        tell(.pointer(.pointerPressed, point))
    }

    private func pointerReleased(moved: Point) {
        tell(.pointer(.pointerReleased, Point(x: pointerFrom.x + moved.x, y: pointerFrom.y + moved.y)))
    }

    // MARK: - A press dragged

    private func makeDrag() -> OpaquePointer {
        let drag = gtk_gesture_drag_new()!
        connectSignal(UnsafeMutableRawPointer(drag), "drag-begin", number: number) { (gesture, _: Double, _: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.dragBegan(OpaquePointer(gesture)) }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-update", number: number) { gesture, x, y, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated {
                GTKListening.find(number)?.dragUpdated(OpaquePointer(gesture), offset: Point(x: x, y: y))
            }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-end", number: number) { (gesture, _: Double, _: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.dragEnded(OpaquePointer(gesture)) }
        }
        return drag
    }

    private func dragBegan(_ gesture: OpaquePointer?) {
        dragFrom = Self.onWindow(gesture) ?? Point(x: 0, y: 0)
        drag = DragRecognition(distance: dragDistance)
        drag.pressed(at: dragFrom)
    }

    /// The press moved: measured on the window, which the view it moves does not move; past the drag threshold it
    /// is a drag, claimed so its press is no tap and no view around it drags too.
    /// Design: docs/design/platforms/gtk/input.md#a-press-dragged
    private func dragUpdated(_ gesture: OpaquePointer?, offset: Point) {
        let point = Self.onWindow(gesture) ?? Point(x: dragFrom.x + offset.x, y: dragFrom.y + offset.y)
        let wasDragging = drag.isDragging
        let heard = drag.moved(to: point)
        if drag.isDragging, !wasDragging, let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
        for each in heard { tell(each) }
    }

    /// The press ended: a drag it became ends with it - let go, or cancelled.
    private func dragEnded(_ gesture: OpaquePointer?) {
        guard drag.isDragging else {
            _ = drag.ended(letGo: true)
            return
        }

        var letGo = true
        if let gesture, let last = gtk_gesture_get_last_event(gesture, gtk_gesture_single_get_current_sequence(gesture)) {
            let type = gdk_event_get_event_type(last)
            letGo = type == GDK_BUTTON_RELEASE || type == GDK_TOUCH_END
        }
        if let end = drag.ended(letGo: letGo) { tell(end) }
    }

    // MARK: - The hand over a layout

    /// A press dragged by any pointer, and a scroll - a touchpad's two fingers, a wheel's notches.
    /// Design: docs/design/platforms/gtk/input.md#the-hand-over-a-layout
    private func makeHand() -> [OpaquePointer] {
        let drag = gtk_gesture_drag_new()!
        connectSignal(UnsafeMutableRawPointer(drag), "drag-begin", number: number) { (gesture, x: Double, y: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.handBegan(OpaquePointer(gesture), at: Point(x: x, y: y)) }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-update", number: number) { gesture, x, y, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated {
                GTKListening.find(number)?.handUpdated(OpaquePointer(gesture), offset: Point(x: x, y: y))
            }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-end", number: number) { (gesture, _: Double, _: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.handEnded(OpaquePointer(gesture)) }
        }

        let scroll = gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES)!
        connectSignal(UnsafeMutableRawPointer(scroll), "scroll-begin", number: number) { controller, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let controller = controller
            MainActor.assumeIsolated {
                _ = GTKListening.find(number)?.hand(.began, moved: .zero, at: GTKListening.time(of: OpaquePointer(controller)))
            }
        }
        connectAnswering(UnsafeMutableRawPointer(scroll), "scroll", number: number) { controller, dx, dy, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let controller = controller
            return MainActor.assumeIsolated {
                GTKListening.find(number)?.scrolled(OpaquePointer(controller), by: Point(x: dx, y: dy)) == true ? 1 : 0
            }
        }
        connectSignal(UnsafeMutableRawPointer(scroll), "scroll-end", number: number) { controller, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let controller = controller
            MainActor.assumeIsolated {
                _ = GTKListening.find(number)?.hand(.ended, moved: .zero, at: GTKListening.time(of: OpaquePointer(controller)))
            }
        }
        return [drag, scroll]
    }

    /// The hand at `phase`, having moved what is under it by `moved`, lifting at `speed` where told, at `time` on the
    /// events' clock, a press going down at `point` of the view: the host's entry. Whether the layout took it.
    @discardableResult
    func hand(
        _ phase: GesturePhase, moved: Point, speed: Point? = nil, at time: Double? = nil, point: Point? = nil
    ) -> Bool {
        tell(.hand(phase, moved: moved, speed: speed, at: time, point: point))
    }

    /// A press going down at `point` of the view: told where at once - a press standing still may hold a view. A
    /// press with Alt over a view two fingers move is theirs.
    private func handBegan(_ gesture: OpaquePointer?, at point: Point) {
        if mirroredDrag != nil, let gesture, Self.takesMirrored(gtk_event_controller_get_current_event_state(gesture)) {
            gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_DENIED)
            return
        }
        handPending = true
        handTaking = false
        handLast = Point(x: 0, y: 0)
        hand(.began, moved: .zero, at: Self.time(of: gesture), point: point)
    }

    /// The drag moved: past the threshold its first move says whose it is - claimed for the layout, so no view
    /// around it drags or scrolls with it, or denied, for a scroller holding it to take.
    private func handUpdated(_ gesture: OpaquePointer?, offset: Point) {
        if handPending {
            guard dragDistance.isPassed(by: offset) else { return }

            handPending = false
            handTaking = hand(.changed, moved: offset, at: Self.time(of: gesture))
            if let gesture { gtk_gesture_set_state(gesture, handTaking ? GTK_EVENT_SEQUENCE_CLAIMED : GTK_EVENT_SEQUENCE_DENIED) }
            handLast = offset
        } else if handTaking {
            hand(.changed, moved: Point(x: offset.x - handLast.x, y: offset.y - handLast.y), at: Self.time(of: gesture))
            handLast = offset
        }
    }

    /// The press let go or taken away: told whatever it moved - a press that held a view and never moved lets it go.
    private func handEnded(_ gesture: OpaquePointer?) {
        defer {
            handPending = false
            handTaking = false
        }

        var letGo = true
        if let gesture, let last = gtk_gesture_get_last_event(gesture, gtk_gesture_single_get_current_sequence(gesture)) {
            let type = gdk_event_get_event_type(last)
            letGo = type == GDK_BUTTON_RELEASE || type == GDK_TOUCH_END
        }
        hand(letGo ? .ended : .cancelled, moved: .zero, at: Self.time(of: gesture))
    }

    /// A scroll step: a wheel's notches - parts of one for a fine wheel - or a touchpad's move of what is under the
    /// fingers. Whether the layout took it; a step it leaves goes on to whatever holds it.
    private func scrolled(_ controller: OpaquePointer?, by step: Point) -> Bool {
        let wheel = controller.map { gtk_event_controller_scroll_get_unit($0) == GDK_SCROLL_UNIT_WHEEL } ?? true
        guard wheel else { return hand(.changed, moved: Point(x: -step.x, y: -step.y), at: Self.time(of: controller)) }

        return notched(Point(x: -step.x, y: -step.y))
    }

    /// A wheel's notches over a layout, as many as it turned, across and down: the host's entry. Whether the layout
    /// took them.
    @discardableResult
    func notched(_ notches: Point) -> Bool {
        tell(.notch(notches))
    }

    /// When the event a controller handles happened, in milliseconds on the events' clock.
    nonisolated private static func time(of controller: OpaquePointer?) -> Double? {
        guard let controller else { return nil }
        let time = gtk_event_controller_get_current_event_time(controller)
        return time == 0 ? nil : Double(time)
    }

    // MARK: - A pinch

    private func makePinch() -> OpaquePointer {
        let zoom = gtk_gesture_zoom_new()!
        connectSignal(UnsafeMutableRawPointer(zoom), "begin", number: number) { (gesture, _: UnsafeMutableRawPointer?, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.pinched(OpaquePointer(gesture), phase: .began, scale: 1) }
        }
        connectSignal(UnsafeMutableRawPointer(zoom), "scale-changed", number: number) { (gesture, scale: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated {
                GTKListening.find(number)?.pinched(OpaquePointer(gesture), phase: .changed, scale: scale)
            }
        }
        connectSignal(UnsafeMutableRawPointer(zoom), "end", number: number) { (gesture, _: UnsafeMutableRawPointer?, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.pinched(OpaquePointer(gesture), phase: .ended, scale: 1) }
        }
        return zoom
    }

    /// A wheel turned with Control, notch by notch, as a pinch - GNOME's applications zoom so; a touchpad's pinch is
    /// GTK's own zoom gesture.
    /// Design: docs/design/host/runtime.md#a-wheel-turned-as-a-pinch
    private func makeWheelPinch() -> OpaquePointer {
        let scroll = gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_VERTICAL)!
        connectAnswering(UnsafeMutableRawPointer(scroll), "scroll", number: number) { controller, _, dy, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let controller = controller
            return MainActor.assumeIsolated {
                GTKListening.find(number)?.wheelPinched(OpaquePointer(controller), notches: -dy) == true ? 1 : 0
            }
        }
        return scroll
    }

    /// The wheel turned `notches` away from the user: a pinch where Control is held and it turns notch by notch;
    /// whether it was one.
    private func wheelPinched(_ controller: OpaquePointer?, notches: Double) -> Bool {
        guard let controller, gtk_event_controller_scroll_get_unit(controller) == GDK_SCROLL_UNIT_WHEEL,
              gtk_event_controller_get_current_event_state(controller).rawValue & GDK_CONTROL_MASK.rawValue != 0
        else { return false }
        return tell(.wheelPinch(scale: pow(WheelPinch.notch, notches), at: Point(x: 0.5, y: 0.5)))
    }

    /// A pinch's step: its scale since the last, and where, as shares of the view's size. Begun, it is claimed,
    /// so no scroller around the view pans with its fingers.
    private func pinched(_ gesture: OpaquePointer?, phase: GesturePhase, scale: Double) {
        if phase == .began, let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
        let step = pinch.step(phase, scale: scale)

        var x = 0.0
        var y = 0.0
        let center: Point? = if let gesture, gtk_gesture_is_active(gesture) != 0,
                                gtk_gesture_get_bounding_box_center(gesture, &x, &y) != 0 { Point(x: x, y: y) } else { nil }
        let at = PinchStep.share(
            of: center, width: Double(gtk_widget_get_width(widget)), height: Double(gtk_widget_get_height(widget)))
        tell(.pinch(phase, scale: step, at: at))
    }

    // MARK: - A rotation

    private func makeRotation() -> OpaquePointer {
        let rotate = gtk_gesture_rotate_new()!
        connectSignal(UnsafeMutableRawPointer(rotate), "begin", number: number) { (_, _: UnsafeMutableRawPointer?, data) in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.rotated(phase: .began, radians: 0) }
        }
        connectSignal(UnsafeMutableRawPointer(rotate), "angle-changed", number: number) { (_, _: Double, delta: Double, data) in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.rotated(phase: .changed, radians: delta) }
        }
        connectSignal(UnsafeMutableRawPointer(rotate), "end", number: number) { (_, _: UnsafeMutableRawPointer?, data) in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.rotated(phase: .ended, radians: 0) }
        }
        return rotate
    }

    /// A rotation's step: the degrees clockwise since the last, from GTK's turn since it began, in radians.
    func rotated(phase: GesturePhase, radians: Double) {
        tell(.rotation(phase, degrees: rotation.step(phase, degrees: radians * 180 / .pi)))
    }

    // MARK: - Two fingers from one press

    private func makeMirrored() -> OpaquePointer {
        let drag = gtk_gesture_drag_new()!
        connectSignal(UnsafeMutableRawPointer(drag), "drag-begin", number: number) { (gesture, x: Double, y: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated {
                GTKListening.find(number)?.mirroredBegan(OpaquePointer(gesture), at: Point(x: x, y: y))
            }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-update", number: number) { _, x, y, data in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.mirroredMoved(Point(x: x, y: y)) }
        }
        connectSignal(UnsafeMutableRawPointer(drag), "drag-end", number: number) { (_, _: Double, _: Double, data) in
            let number = viewNumber(data)
            MainActor.assumeIsolated { GTKListening.find(number)?.mirroredEnded() }
        }
        return drag
    }

    /// Whether a press with `state` held is two fingers: Alt.
    static func takesMirrored(_ state: GdkModifierType) -> Bool {
        state.rawValue & GDK_ALT_MASK.rawValue != 0
    }

    /// The press with Alt at `phase`, at `at`, the view's middle at `middle`: the host's entry.
    /// Design: docs/design/host/runtime.md#two-fingers-from-one-pointer
    func mirrored(_ phase: GesturePhase, at: Point, middle: Point) {
        tell(.mirrored(phase, at: at, middle: middle))
    }

    /// A press going down at `point`: with Alt it is claimed - no view around it drags with it - and two fingers;
    /// without, it is denied, left to the view's own.
    private func mirroredBegan(_ gesture: OpaquePointer?, at point: Point) {
        guard let gesture else { return }
        guard Self.takesMirrored(gtk_event_controller_get_current_event_state(gesture)) else {
            gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_DENIED)
            return
        }
        gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED)
        mirroring = true
        mirroredFrom = point
        mirrored(.began, at: point, middle: middle)
    }

    private func mirroredMoved(_ offset: Point) {
        guard mirroring else { return }
        mirrored(.changed, at: Point(x: mirroredFrom.x + offset.x, y: mirroredFrom.y + offset.y), middle: middle)
    }

    private func mirroredEnded() {
        guard mirroring else { return }
        mirroring = false
        mirrored(.ended, at: mirroredFrom, middle: middle)
    }

    /// The view's middle, in its own points.
    private var middle: Point {
        Point(x: Double(gtk_widget_get_width(widget)) / 2, y: Double(gtk_widget_get_height(widget)) / 2)
    }

    // MARK: - Measures

    /// GTK's drag threshold, across and down alike, which its own click measures too.
    private var dragDistance: DragRecognition.Distance {
        let threshold = Self.dragThreshold(of: widget)
        return .eachAxis(x: threshold, y: threshold)
    }

    private static func dragThreshold(of widget: GTKWidget) -> Double {
        var value = GValue()
        g_value_init(&value, g_type_from_name("gint"))
        defer { g_value_unset(&value) }
        g_object_get_property(
            UnsafeMutablePointer<GObject>(gtk_widget_get_settings(widget)), "gtk-dnd-drag-threshold", &value)
        return Double(g_value_get_int(&value))
    }

    /// Where the event a controller handles is, on its window.
    private static func onWindow(_ controller: OpaquePointer?) -> Point? {
        var x = 0.0
        var y = 0.0
        guard let controller, let event = gtk_event_controller_get_current_event(controller),
              gdk_event_get_position(event, &x, &y) != 0
        else { return nil }
        return Point(x: x, y: y)
    }

    /// Where the press a gesture follows is now, in its widget; nil while it follows none.
    nonisolated private static func point(of gesture: UnsafeMutableRawPointer?) -> Point? {
        guard let gesture else { return nil }
        let single = OpaquePointer(gesture)
        var x = 0.0
        var y = 0.0
        guard gtk_gesture_get_point(single, gtk_gesture_single_get_current_sequence(single), &x, &y) != 0
        else { return nil }
        return Point(x: x, y: y)
    }

    private static func find(_ number: Int64) -> GTKListening? {
        GTKView.find(number)?.listening
    }

    nonisolated private static func tell(_ heard: HeardInput, to number: Int64) {
        MainActor.assumeIsolated { _ = GTKView.find(number)?.heard(heard) }
    }
}
