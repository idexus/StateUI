// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// What of the user's input a view listens for, told by the view's one listener, `StateUIGestures`, and heard in the
/// contract's terms (`HeardInput`): a press dragged by the host layer's rule, the rest as Android tells it.
/// Design: docs/design/platforms/android/controls.md#gestures
extension AndroidView {
    /// What a view's listener is told to listen for.
    struct Listening: Equatable {
        var hearing: Hearing
        var countsTaps: Bool

        static let nothing = Listening(hearing: [], countsTaps: false)
    }

    /// Listens for what `hearing` names, `heard` hearing it - taps counted in runs by the listener where
    /// `countsTaps`, where one tap is no click - taking the view's touches and its hovering pointer the first time
    /// anything is.
    func hear(_ hearing: Hearing, countsTaps: Bool, _ heard: @escaping (HeardInput) -> Bool) {
        onHeard = hearing.isEmpty ? nil : heard
        let told = Listening(hearing: hearing, countsTaps: countsTaps)
        guard told != listening else { return }

        if listening == .nothing || listening.hearing.contains(.hand) != hearing.contains(.hand) { watchTouches(hearing) }
        listening = told
        longPressChanged()
        if hearing.contains(.drags) { press = DragRecognition(distance: .radius(Self.touchSlop(density: density))) }
        if hearing.contains(.hand) { handRecognition = HandRecognition(distance: .radius(Self.touchSlop(density: density))) }
        if countsTaps, hearing.contains(.taps) { taps = Self.doubleTap(density: density) }
        Java.call(
            listener.reference, JavaAPI.setGestures, .object(reference), .float(Float(density)),
            .bool(countsTaps && hearing.contains(.taps)), .bool(hearing.contains(.drags)),
            .bool(hearing.contains(.pinches)), .bool(hearing.contains(.pointer)), .bool(hearing.contains(.hand)),
            .bool(hearing.contains(.rotations)))
    }

    /// What the listener says the view heard, by the kind `StateUIGestures` numbers: a tap where it landed on the
    /// screen and when, in `phase`'s milliseconds - its place in its run counted by the host layer (`TapRun`) - a
    /// pinch's step and where it is centered in points, the pointer.
    func heard(kind: Int32, phase: Int32, x: Double, y: Double, z: Double) {
        let point = Point(x: x, y: y)
        let input: HeardInput? = switch AndroidGestureKind(rawValue: kind) {
        case .tapped: .tap(run: taps.tapped(at: point, time: .milliseconds(Int(phase))))
        case .pinched: GesturePhase(rawValue: phase).map { phase in
            let size = standingFrame
            let at = PinchStep.share(of: Point(x: y, y: z), width: size.width, height: size.height)
            return .pinch(phase, scale: x, at: at)
        }
        case .entered: .pointer(.pointerEntered, point)
        case .exited: .pointer(.pointerExited, point)
        case .moved: .pointer(.pointerMoved, point)
        case .pressed: .pointer(.pointerPressed, point)
        case .released: .pointer(.pointerReleased, point)
        case nil: nil
        }
        if let input { _ = onHeard?(input) }
    }

    /// A finger on a layout a hand moves, as the listener tells it at `phase` - down, moved, let go or taken away -
    /// by its number, where it stands on the screen and in the view, in points, the last lifting at the platform's
    /// speed: read as one hand by the host layer's rule (`HandRecognition`). Whether the layout has the hand now.
    /// Design: docs/design/platforms/android/controls.md#the-hand-over-a-layout
    func heardFinger(phase: Int32, finger: Int, at point: Point, inView: Point, speed: Point) -> Bool {
        guard let phase = AndroidPressPhase(rawValue: phase) else { return false }

        let step = switch phase {
        case .down: handRecognition.down(finger, at: point, inView: inView)
        case .move: handRecognition.moved(finger, to: point)
        case .letGo, .taken: handRecognition.up(finger, letGo: phase == .letGo)
        }
        switch step {
        case .began(let at): _ = onHeard?(.hand(.began, moved: .zero, speed: nil, point: at))
        case .asks(let travel):
            handRecognition.answered(taken: onHeard?(.hand(.changed, moved: travel, speed: nil)) ?? false)
        case .moved(let moved): _ = onHeard?(.hand(.changed, moved: moved, speed: nil))
        case .ended(let letGo):
            _ = onHeard?(.hand(letGo ? .ended : .cancelled, moved: .zero, speed: letGo ? speed : nil))
        case .nothing: break
        }
        return handRecognition.isTaken
    }

    /// Two fingers over a layout the listener tells, by the phase StateUI numbers, where each stands in points: the
    /// turn between them since the last time, by the host layer's reading of two pointers.
    /// Design: docs/design/host/runtime.md#two-fingers-over-a-layout
    func heardFingers(phase: Int32, first: Point, second: Point) {
        guard let phase = GesturePhase(rawValue: phase) else { return }

        switch phase {
        case .began:
            fingers.lifted()
            _ = fingers.moved(first, second)
            _ = onHeard?(.rotation(.began, degrees: 0))
        case .changed:
            if let turned = fingers.moved(first, second) { _ = onHeard?(.rotation(.changed, degrees: turned.degrees)) }
        case .ended, .cancelled:
            fingers.lifted()
            _ = onHeard?(.rotation(phase, degrees: 0))
        }
    }

    /// A wheel's notches over a layout, as many as it turned, across and down: the host's entry. Whether the layout
    /// took them.
    func heardNotches(_ notches: Point) -> Bool {
        onHeard?(.notch(notches)) ?? false
    }

    /// Tells the view's drag listener what a drag of it carries and whether it takes drops, `heard` hearing them.
    /// Design: docs/design/platforms/android/controls.md#a-drag-between-views
    func offer(_ offered: DragAndDrop, _ heard: @escaping (HeardInput) -> Void) {
        onDragHeard = offered == .none ? nil : heard
        guard offered != self.offered else { return }
        self.offered = offered
        Java.frame {
            Java.callStatic(
                JavaAPI.drags, JavaAPI.offerDrag, .object(reference), .long(number),
                .object(offered.words.flatMap(Java.string)), .bool(offered.takesWords), .bool(offered.takesFiles))
        }
        longPressChanged()
    }

    /// Starts the view's drag, where it can be dragged: whether it started.
    func startDrag() -> Bool {
        guard let words = offered.words else { return false }
        let started = Java.frame {
            Java.callStaticBool(JavaAPI.drags, JavaAPI.startDrag, .object(reference), .long(number), .object(Java.string(words)))
        }
        if started { heardDrag(kind: AndroidDragEvent.started.rawValue, words: nil) }
        return started
    }

    /// What the drag listener says the view heard, by the kind `StateUIDrags` numbers.
    func heardDrag(kind: Int32, words: String?) {
        let input: HeardInput? = switch AndroidDragEvent(rawValue: kind) {
        case .started: .dragStarted
        case .ended: .dragEnded
        case .over: .dragOver
        case .left: .dragLeft
        case .dropped: .dropped(words ?? "")
        case nil: nil
        }
        if let input { onDragHeard?(input) }
    }

    /// Documents another application dragged here were let go over the view, by their addresses and names.
    func heardDroppedFiles(addresses: [String], names: [String]) {
        onDragHeard?(.filesDropped(zip(addresses, names).map { ChosenFile(address: $0, name: $1) }))
    }

    /// A press the listener tells - down, moved, let go or taken away, at `point` of the screen: a drag by the host
    /// layer's rule. Whether it is one now, which takes the rest of the touch.
    /// Design: docs/design/platforms/android/controls.md#gestures
    func heardPress(phase: Int32, at point: Point) -> Bool {
        switch AndroidPressPhase(rawValue: phase) {
        case .down: press.pressed(at: point)
        case .move: press.moved(to: point).forEach { _ = onHeard?($0) }
        case .letGo, .taken, nil:
            if let end = press.ended(letGo: phase == AndroidPressPhase.letGo.rawValue) { _ = onHeard?(end) }
        }
        return press.isDragging
    }

    /// How far a finger moves before it is a drag, as Android measures it, in points at `density`.
    /// A run of taps as Android measures its double tap: its timeout, and its slop in points.
    private static func doubleTap(density: Double) -> TapRun {
        let timeout = Java.callStaticInt(JavaAPI.viewConfiguration, JavaAPI.doubleTapTimeout)
        let slop = Java.frame {
            guard let configuration = Java.callStaticObject(
                JavaAPI.viewConfiguration, JavaAPI.viewConfigurationOf, .object(AndroidRenderer.context))
            else { return 100.0 }
            return Double(Java.callInt(configuration, JavaAPI.scaledDoubleTapSlop)) / density
        }
        return TapRun(interval: .milliseconds(Int(timeout)), slop: slop)
    }

    private static func touchSlop(density: Double) -> Double {
        Java.frame {
            guard let configuration = Java.callStaticObject(
                JavaAPI.viewConfiguration, JavaAPI.viewConfigurationOf, .object(AndroidRenderer.context))
            else { return 8 }
            return Double(Java.callInt(configuration, JavaAPI.scaledTouchSlop)) / density
        }
    }
}
