// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// One view's listening: a GTK controller for each kind of input the view listens for, and what each remembers of
/// the press it follows. The widget owns the controllers; their signals name the view by its number.
/// Design: docs/design/platforms/gtk/input.md
@MainActor
final class GTKListening {
    private let widget: GTKWidget
    private let number: Int64

    /// What the view listens for.
    private(set) var hearing: GTKHearing = []

    /// The controllers hung on the widget for each kind of input.
    private(set) var controllers: [GTKHearing: [OpaquePointer]] = [:]

    /// Where the press a tap follows went down, and whether it has since moved too far to be a tap.
    private var tapFrom = Point(x: 0, y: 0)
    private var tapMoved = false

    /// Where the pointer's press went down in the view.
    private var pointerFrom = Point(x: 0, y: 0)

    /// The press dragged: where it went down on the window, how far it has come, and whether it became a drag.
    private var dragFrom = Point(x: 0, y: 0)
    private var dragMoved = Point(x: 0, y: 0)
    private var dragging = false

    /// The scale the pinch last said, since it began.
    private var pinchScale = 1.0

    init(widget: GTKWidget, number: Int64) {
        self.widget = widget
        self.number = number
    }

    /// Listens for what `hearing` names: a kind newly asked for gets its controllers, one no longer asked for loses
    /// them.
    func listen(for hearing: GTKHearing) {
        for kind in GTKHearing.kinds where hearing.contains(kind) != self.hearing.contains(kind) {
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
    }

    private func tell(_ heard: GTKHeard) {
        GTKView.find(number)?.heard(heard)
    }

    private func makeControllers(for kind: GTKHearing) -> [OpaquePointer] {
        switch kind {
        case .taps: [makeTaps()]
        case .pointer: makePointer()
        case .drags: [makeDrag()]
        default: [makePinch()]
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
    }

    /// GTK stopped counting the press as a click - it moved past the drag threshold, or it is held past the
    /// double-click time; only a press that moved is no tap.
    /// Design: docs/design/platforms/gtk/input.md#taps
    func tapStopped(at point: Point?) {
        guard let point else { return }
        if moved(from: tapFrom, to: point) { tapMoved = true }
    }

    /// A press let go: a tap where it has not moved and is let go over the view, claimed so no view around it
    /// answers it too.
    func tapReleased(_ gesture: OpaquePointer?, run: Int, at point: Point) {
        defer { tapMoved = false }
        guard !tapMoved, gtk_widget_contains(widget, point.x, point.y) != 0 else { return }

        if let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
        tell(.tap(run: run))
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
        connectSignal(UnsafeMutableRawPointer(drag), "drag-begin", number: number) { gesture, _, _, data in
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
        connectSignal(UnsafeMutableRawPointer(drag), "drag-end", number: number) { gesture, _, _, data in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.dragEnded(OpaquePointer(gesture)) }
        }
        return drag
    }

    private func dragBegan(_ gesture: OpaquePointer?) {
        dragFrom = Self.onWindow(gesture) ?? Point(x: 0, y: 0)
        dragMoved = Point(x: 0, y: 0)
        dragging = false
    }

    /// The press moved: measured on the window, which the view it moves does not move; past the drag threshold it
    /// is a drag, claimed so its press is no tap and no view around it drags too.
    /// Design: docs/design/platforms/gtk/input.md#a-press-dragged
    private func dragUpdated(_ gesture: OpaquePointer?, offset: Point) {
        let now = Self.onWindow(gesture).map { Point(x: $0.x - dragFrom.x, y: $0.y - dragFrom.y) } ?? offset
        dragMoved = now
        if !dragging {
            guard moved(from: Point(x: 0, y: 0), to: now) else { return }
            dragging = true
            if let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
            tell(.drag(phase: 0, x: 0, y: 0))
        }
        tell(.drag(phase: 1, x: now.x, y: now.y))
    }

    /// The press ended: a drag it became ends with it - let go, or cancelled.
    private func dragEnded(_ gesture: OpaquePointer?) {
        guard dragging else { return }
        dragging = false

        var letGo = true
        if let gesture, let last = gtk_gesture_get_last_event(gesture, gtk_gesture_single_get_current_sequence(gesture)) {
            let type = gdk_event_get_event_type(last)
            letGo = type == GDK_BUTTON_RELEASE || type == GDK_TOUCH_END
        }
        tell(.drag(phase: letGo ? 2 : 3, x: dragMoved.x, y: dragMoved.y))
    }

    // MARK: - A pinch

    private func makePinch() -> OpaquePointer {
        let zoom = gtk_gesture_zoom_new()!
        connectSignal(UnsafeMutableRawPointer(zoom), "begin", number: number) { (gesture, _: UnsafeMutableRawPointer?, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.pinched(OpaquePointer(gesture), phase: 0, scale: 1) }
        }
        connectSignal(UnsafeMutableRawPointer(zoom), "scale-changed", number: number) { (gesture, scale: Double, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated {
                GTKListening.find(number)?.pinched(OpaquePointer(gesture), phase: 1, scale: scale)
            }
        }
        connectSignal(UnsafeMutableRawPointer(zoom), "end", number: number) { (gesture, _: UnsafeMutableRawPointer?, data) in
            let number = viewNumber(data)
            nonisolated(unsafe) let gesture = gesture
            MainActor.assumeIsolated { GTKListening.find(number)?.pinched(OpaquePointer(gesture), phase: 2, scale: 1) }
        }
        return zoom
    }

    /// A pinch's step: its scale since the last, and where, as shares of the view's size. Begun, it is claimed,
    /// so no scroller around the view pans with its fingers.
    private func pinched(_ gesture: OpaquePointer?, phase: Int32, scale: Double) {
        if phase == 0, let gesture { gtk_gesture_set_state(gesture, GTK_EVENT_SEQUENCE_CLAIMED) }
        let step = phase == 1 && pinchScale > 0 ? scale / pinchScale : 1
        pinchScale = phase == 1 ? scale : 1

        var at = Point(x: 0.5, y: 0.5)
        var x = 0.0
        var y = 0.0
        let width = Double(gtk_widget_get_width(widget))
        let height = Double(gtk_widget_get_height(widget))
        if let gesture, gtk_gesture_is_active(gesture) != 0, gtk_gesture_get_bounding_box_center(gesture, &x, &y) != 0,
           width > 0, height > 0 {
            at = Point(x: x / width, y: y / height)
        }
        tell(.pinch(phase: phase, scale: step, at: at))
    }

    // MARK: - Measures

    /// Whether a press went past GTK's drag threshold, as GTK's own click tells it.
    private func moved(from start: Point, to point: Point) -> Bool {
        let threshold = Self.dragThreshold(of: widget)
        return abs(point.x - start.x) >= threshold || abs(point.y - start.y) >= threshold
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

    nonisolated private static func tell(_ heard: GTKHeard, to number: Int64) {
        MainActor.assumeIsolated { GTKView.find(number)?.heard(heard) }
    }
}
