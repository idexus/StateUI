// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user does to an element's view with a finger, a pen or the mouse, as the element's events - the same
/// on every host.
/// Design: docs/design/host/runtime.md#what-the-user-does-with-a-finger
extension MountedElement {
    /// What the element's handlers, channels and interaction program ask to hear: taps, a press held, the pointer,
    /// a press dragged, a pinch, the hand over what it moves and the two fingers that spread or turn it. A pan asks for a press dragged by
    /// one pointer; one asking for more is not recognized.
    public var hearing: Hearing {
        var hearing: Hearing = []
        if handler(.tapped) != nil { hearing.insert(.taps) }
        if handler(.longPressed) != nil { hearing.insert(.longPresses) }
        if Self.pointerEvents.contains(where: { handler($0) != nil }) { hearing.insert(.pointer) }
        let drags = handler(.panUpdated) != nil || handler(.swiped) != nil
        if drags, (number(.panTouchCount) ?? 1) == 1 { hearing.insert(.drags) }
        // What the hand moves by the element's program is heard as the program says: two fingers spreading or
        // turning, a hand one way or every way.
        let moved = interactionProgram?.values.map(\.input) ?? []
        let rotates = moved.contains { if case .rotation = $0 { true } else { false } }
        if handler(.pinchUpdated) != nil || moved.contains(.magnification) { hearing.insert(.pinches) }
        if handler(.rotationUpdated) != nil || rotates { hearing.insert(.rotations) }
        if !handWays.isEmpty || interactionProgram?.drag != nil { hearing.insert(.hand) }
        // A view's own press is watched, never taken: heard by the press of its taps where it hears them, so no
        // host tells a press twice.
        if interactionProgram?.press != nil, !hearing.contains(.taps) { hearing.insert(.presses) }
        return hearing
    }

    /// How long a press stands still before the element is held, in milliseconds; nil for the platform's own time.
    public var longPressDuration: Double? {
        number(.longPressDuration)
    }

    /// The user's input the view heard, as the element's events: a tap each time a run reaches the count asked for - at
    /// once for a press assistive technology made; a press held; the pointer where it is; a press dragged, a swipe
    /// as it ends far enough; a pinch's step; the hand over a layout; a drag between views
    /// by `DropTarget`. Whether the element took it: a hand over a layout across its axis it leaves to whatever holds
    /// it.
    @discardableResult
    public func hear(_ input: HeardInput, in runtime: HostRuntime) -> Bool {
        // A view that left the tree hears nothing, and one thrown away and out of its room nothing until its
        // handlers have had their say.
        guard lifecycle == .active, !awaitsDismissal else { return false }
        // A run taken away says nothing more: its own end closes the taking, and so does the next beginning.
        // Design: docs/design/host/interaction.md#a-hand-taken-away
        if let step = input.step, takenAway.contains(step.stream) {
            if step.phase != .changed { takenAway.remove(step.stream) }
            if step.phase != .began { return false }
        }
        guard isTarget else {
            // A view that is no target hears no beginning: what began on it ends there, as cancelled, at the
            // first step it hears - and takes nothing.
            // Design: docs/design/host/runtime.md#a-disabled-branch
            if let ending = ending(of: input) {
                take(ending, in: runtime)
                if let step = input.step, step.phase == .changed { takenAway.insert(step.stream) }
            }
            return false
        }
        return take(input, in: runtime)
    }

    /// `input` as a view that is no target still hears it: the end, as cancelled, of what began on it - a press,
    /// a drag, a pinch, a turn, the hand, at any step after its beginning - a pointer over it leaving, a drag
    /// between views ending or leaving; nil for the rest.
    private func ending(of input: HeardInput) -> HeardInput? {
        switch input {
        case .press(let phase, let at, let size, let byFinger) where phase != .began:
            return .press(.cancelled, at: at, size: size, byFinger: byFinger)
        case .drag(let phase, let x, let y, let from) where phase != .began && panUnderWay:
            return .drag(.cancelled, x: x, y: y, from: from)
        case .pinch(let phase, _, let at) where phase != .began && (pinchFromStart != nil || hearsFingers):
            return .pinch(.cancelled, scale: 1, at: at)
        case .rotation(let phase, _) where phase != .began && (rotationFromStart != nil || hearsFingers):
            return .rotation(.cancelled, degrees: 0)
        case .mirrored(let phase, let at, let middle) where phase != .began:
            return .mirrored(.cancelled, at: at, middle: middle)
        case .hand(let phase, let moved, _, let at, let point) where phase != .began:
            return .hand(.cancelled, moved: moved, speed: nil, at: at, point: point)
        case .pointer(.pointerExited, _, _) where pointerIsOver, .dragEnded, .dragLeft:
            return input
        default:
            return nil
        }
    }

    /// Whether `phase` ends a gesture, lifted or taken away.
    private static func ends(_ phase: GesturePhase) -> Bool { phase == .ended || phase == .cancelled }

    /// What the view heard, as its events; whether it took it.
    @discardableResult
    private func take(_ input: HeardInput, in runtime: HostRuntime) -> Bool {
        switch input {
        case .press(let phase, let point, let size, let byFinger):
            if phase == .began { tapTaken = false }
            // A press is a button's where the view hears taps, and the view's own where it answers one.
            if hearing.contains(.taps) {
                let over = ButtonPress.isOver(point, in: size, byFinger: byFinger)
                pressed(phase, over: over, waits: byFinger && standsInAScroller, in: runtime)
            }
            pressedLocally(phase, at: point, size: size, in: runtime)
        case .tap(let run):
            // The press its own drag took makes no tap, however its toolkit tells it.
            guard !tapTaken else {
                tapTaken = false
                return true
            }
            let count = max(1, whole(.tapCount) ?? 1)
            if run == 0 || run % count == 0 { send(.tapped, [], in: runtime) }
        case .longPress:
            // A held press is the long press's: no tap.
            pressed(.cancelled, over: false, in: runtime)
            send(.longPressed, [], in: runtime)
        case .pointer(let event, let point, let byFinger):
            // Design: docs/design/host/runtime.md#a-finger-hovers-over-nothing
            if byFinger, [.pointerEntered, .pointerMoved, .pointerExited].contains(event) { return false }
            let said: [HostValue] = event == .pointerEntered || event == .pointerExited ? [] : [.numbers([point.x, point.y])]
            if event == .pointerEntered || event == .pointerExited { pointerIsOver = event == .pointerEntered }
            send(event, said, in: runtime)
        case .drag(let phase, let x, let y, let from):
            dragged(phase, x: x, y: y, from: from, in: runtime)
        case .pinch(let phase, let scale, let at):
            guard hearsFingers else {
                pinched(phase, scale: scale, at: at, in: runtime)
                return true
            }
            return fingers(pinchReading.pinch(phase, scale: scale, at: runtime.clock.now()), in: runtime)
        case .wheelPinch(let scale, let at):
            // A wheel tells no lift: the frames let its pinch go once it stands still.
            for each in wheelPinch.turned(scale, at: at, now: runtime.clock.now()) { hear(each, in: runtime) }
            runtime.handPace.opened(self)
        case .rotation(let phase, let degrees):
            guard hearsFingers else {
                guard handler(.rotationUpdated) != nil else { return false }

                rotated(phase, degrees: degrees, in: runtime)
                return true
            }

            return fingers(pinchReading.rotation(phase, degrees: degrees, at: runtime.clock.now()), in: runtime)
        case .mirrored(let phase, let at, let middle):
            guard hearsMirroredFingers else { return false }

            mirrored(phase, at: at, middle: middle, in: runtime)
        case .hand(let phase, let moved, let speed, let time, let point):
            // When the platform says the hand moved, where it says: input that waited for a busy thread comes in a
            // burst its arrival would read as a throw.
            let now = runtime.clock.now()
            // A press on a view on its way out catches it where it stands: its flight ends, and nothing is told.
            if phase == .began, let stood = interruptFlight() { caught = stood }
            let heard = handReading.hand(
                phase, moved: moved, speed: speed, at: time ?? now, way: claimingWay, point: point, drag: handDrag,
                now: now)
            // Caught and let go with no move, the view goes back to its place.
            if phase == .ended || phase == .cancelled, caught != nil, heard.reports.isEmpty {
                caught = nil
                comeBack(in: runtime)
            }
            gather(heard.reports, in: runtime)
            if handReading.wantsFrames { runtime.handPace.opened(self) }
            if phase == .began { handTookPresses = false }
            // The hand has the touch once it moves the run or holds a view: a press standing still is a tap.
            if handReading.claimed == true || handReading.holdsView, !handTookPresses {
                handTookPresses = true
                takePresses(in: runtime)
            }
            return heard.taken
        case .wheel(let moved):
            let heard = handReading.wheel(moved, at: runtime.clock.now(), way: handWay)
            gather(heard.reports, in: runtime)
            if handReading.isWheeling { runtime.handPace.opened(self) }
            return heard.taken
        case .notch(let notches):
            let heard = handReading.notches(notches, way: handWay)
            if let steps = heard.steps {
                let along = alongRun(steps)
                runtime.interactions.notches(Point(x: along[0], y: along[1]), on: self)
                runtime.displayCycle.drain(now: runtime.clock.now())
            }
            return heard.taken
        case .dragStarted:
            send(.dragStarting, [], in: runtime)
        case .dragEnded:
            send(.dragEnded, [], in: runtime)
        case .dragOver:
            if dropTarget.over() { send(.dragEntered, [], in: runtime) }
        case .dragLeft:
            if dropTarget.left() { send(.dragExited, [], in: runtime) }
        case .dropped(let words):
            dropTarget.dropped()
            send(.dropped, [.string(words)], in: runtime)
        case .filesDropped(let files):
            dropTarget.dropped()
            let taken = dragAndDrop.taken(files)
            if !taken.isEmpty { send(.filesDropped, [taken.propValue], in: runtime) }
        case .accessibilityAction(let name):
            guard accessibilityWords.actions.contains(name) else { return false }

            send(.accessibilityActionPerformed, [.string(name)], in: runtime)
        case .accessibilityAdjustment(let step):
            guard handler(.accessibilityAdjusted) != nil else { return false }

            send(.accessibilityAdjusted, [step.propValue], in: runtime)
        }
        return true
    }

    /// A pinch's step at `phase`, told as the spread since the pinch began and how fast it changes - a step with no
    /// beginning heard, as a trackpad may tell, beginning one first.
    /// Design: docs/design/types/gestures.md#a-pinch-from-its-start
    private func pinched(_ phase: GesturePhase, scale: Double, at: Point, in runtime: HostRuntime) {
        // An end of no pinch under way says nothing: one is taken away once.
        if Self.ends(phase), pinchFromStart == nil { return }
        if phase != .began, pinchFromStart == nil { pinched(.began, scale: 1, at: at, in: runtime) }
        let now = runtime.clock.now()
        if phase == .began { pinchSpeed = SpeedReading() }
        let before = phase == .began ? 1 : pinchFromStart ?? 1
        let spread = before * scale
        pinchSpeed.moved(Point(x: spread - before, y: 0), at: now)
        let speed = phase == .cancelled ? 0 : pinchSpeed.speed(at: now).x
        pinchFromStart = phase == .ended || phase == .cancelled ? nil : spread
        send(.pinchUpdated, [.enumeration(phase.rawValue), .number(spread), .numbers([at.x, at.y]), .number(speed)],
             in: runtime)
    }

    /// Two fingers' turn at `phase`, told as the angle since they began and how fast it changes - a step with no
    /// beginning heard beginning one first, as a pinch's does.
    /// Design: docs/design/types/gestures.md#a-gestures-speed
    private func rotated(_ phase: GesturePhase, degrees: Double, in runtime: HostRuntime) {
        if Self.ends(phase), rotationFromStart == nil { return }
        if phase != .began, rotationFromStart == nil { rotated(.began, degrees: 0, in: runtime) }
        let now = runtime.clock.now()
        if phase == .began { rotationSpeed = SpeedReading() }
        let angle = (phase == .began ? 0 : rotationFromStart ?? 0) + degrees
        rotationSpeed.moved(Point(x: degrees, y: 0), at: now)
        let speed = phase == .cancelled ? 0 : rotationSpeed.speed(at: now).x
        rotationFromStart = phase == .ended || phase == .cancelled ? nil : angle
        send(.rotationUpdated, [.enumeration(phase.rawValue), .number(angle), .number(speed)], in: runtime)
    }

    /// Whether two fingers spreading or turning move the layout this element is.
    private var hearsFingers: Bool {
        interactionProgram?.values.contains { if case .translation = $0.input { false } else { true } } == true
    }

    /// The ways a hand moves the numbers of the element's interaction program.
    private var handWays: Set<Orientation> {
        Set(interactionProgram?.values.compactMap { value -> Orientation? in
            if case .translation(let way, _, _) = value.input { return way }
            return nil
        } ?? [])
    }

    /// Whether a press dragged with ⌥/Alt over the element is two fingers: where it hears a pinch or a rotation.
    public var hearsMirroredFingers: Bool { !hearing.isDisjoint(with: [.pinches, .rotations]) }

    /// A press dragged with ⌥/Alt at `phase`, standing at `at`, the view's middle at `middle`: the pinch and the
    /// rotation of two fingers, the press and its mirror - each told as the platform tells its own, so they go on as
    /// one stream; the hand stays, their middle standing still.
    /// Design: docs/design/host/runtime.md#two-fingers-from-one-pointer
    private func mirrored(_ phase: GesturePhase, at: Point, middle: Point, in runtime: HostRuntime) {
        let share = Point(x: 0.5, y: 0.5)
        switch phase {
        case .began:
            mirroredFingers.lifted()
            _ = mirroredFingers.moved(at, about: middle)
            hear(.pinch(.began, scale: 1, at: share), in: runtime)
            hear(.rotation(.began, degrees: 0), in: runtime)
        case .changed:
            guard let step = mirroredFingers.moved(at, about: middle) else { return }
            hear(.pinch(.changed, scale: step.scale, at: share), in: runtime)
            hear(.rotation(.changed, degrees: step.degrees), in: runtime)
        case .ended, .cancelled:
            mirroredFingers.lifted()
            hear(.pinch(phase, scale: 1, at: share), in: runtime)
            hear(.rotation(phase, degrees: 0), in: runtime)
        }
    }

    /// What two fingers said, kept for the next frame, beside the hand they carry by their middle - and a view held
    /// by itself keeps the hand, the fingers saying nothing.
    /// Design: docs/design/host/runtime.md#two-fingers-over-a-layout
    private func fingers(_ reports: [PinchReading.Report], in runtime: HostRuntime) -> Bool {
        guard !handReading.holdsView, !children.contains(where: \.holdsPlacedView) else {
            pinchReading = PinchReading()
            return false
        }
        guard !reports.isEmpty else { return true }

        for report in reports {
            if report.phase == .changed, let last = pinchOutbox.last, last.phase == .changed {
                pinchOutbox[pinchOutbox.count - 1] = PinchReading.Report(
                    .changed, scale: last.scale * report.scale, degrees: last.degrees + report.degrees)
            } else {
                pinchOutbox.append(report)
            }
        }
        runtime.handPace.opened(self)
        return true
    }

    /// Which way the hand moves the numbers of the element's program, where a hand does: one way, or - a pan -
    /// every way.
    public var handWay: HandWay? {
        let ways = handWays
        return ways.count > 1 ? .everyWay : ways.first.map(HandWay.init)
    }

    /// Whether the hand holds the view itself.
    public var holdsView: Bool { handReading.holdsView }

    /// Whether the hand's first move, `moved`, begins over the element by the host layer's rule: along the way the
    /// element claims, any way where it holds a view or as its own drag begins - for a platform that gives a touch to
    /// one gesture as it begins.
    /// Design: docs/design/host/interaction.md#one-gesture-taking-anothers-touch
    public func takesHand(first moved: Point) -> Bool {
        HandReading.takes(moved, way: claimingWay, drag: handDrag, holding: holdsView)
    }

    /// The way the hand moves the element's numbers: none while a view its layout places, which the hand already
    /// holds by itself, keeps it.
    /// Design: docs/design/host/interaction.md#one-gesture-taking-anothers-touch
    private var claimingWay: HandWay? {
        handReading.claimed == nil && placesAHeldView ? nil : handWay
    }

    /// Whether a view the element's layout program places is held by the hand by itself.
    var placesAHeldView: Bool {
        layoutProgram != nil && children.contains { $0.holdsPlacedView }
    }

    /// A frame at `now` found the element's wheel open or its hand's reports waiting: the wheel let go where it has
    /// stood still long enough, then what the hand said since the last frame said at once.
    func paced(now: Double, in runtime: HostRuntime) {
        tell(buttonPress.paced(now: now), in: runtime)
        pacedLocally(in: runtime)
        for each in wheelPinch.paced(now: now) { hear(each, in: runtime) }
        gather(handReading.paced(at: now), in: runtime)
        let reports = handOutbox
        handOutbox = []
        said(reports, in: runtime)

        // Laid out right to left, the run's turn is drawn the other way round, and so is the fingers'.
        let fingers = pinchOutbox
        pinchOutbox = []
        let turn = runDirection == .rightToLeft ? -1.0 : 1
        for report in fingers {
            runtime.interactions.fingers(
                report.phase, scale: report.scale, degrees: report.degrees * turn,
                speed: Point(x: report.speed.x, y: report.speed.y * turn), on: self)
        }
    }

    /// The hand's reports kept for the next frame, a move after a move made one: a toolkit telling the hand faster
    /// than the display draws moves the run once a frame.
    /// Design: docs/design/host/runtime.md#the-hand-over-a-layout
    private func gather(_ reports: [HandReading.Report], in runtime: HostRuntime) {
        guard !reports.isEmpty else { return }

        for report in reports {
            if report.phase == .changed, let last = handOutbox.last, last.phase == .changed, last.holdsView == report.holdsView {
                handOutbox[handOutbox.count - 1] = HandReading.Report(
                    .changed, moved: Point(x: last.moved.x + report.moved.x, y: last.moved.y + report.moved.y),
                    speed: report.speed, holdsView: report.holdsView, at: report.at, still: max(last.still, report.still))
            } else {
                handOutbox.append(report)
            }
        }
        runtime.handPace.opened(self)
    }

    /// The hand's reports, said to the sessions that hold what it moves - or, the hand holding the view itself,
    /// to the view's own drag.
    private func said(_ reports: [HandReading.Report], in runtime: HostRuntime) {
        for report in reports {
            if report.holdsView {
                draggedLocally(report, in: runtime)
                continue
            }
            let (moved, speed) = (alongRun(report.moved), alongRun(report.speed))
            runtime.interactions.hand(
                report.phase, moved: Point(x: moved[0], y: moved[1]), speed: Point(x: speed[0], y: speed[1]), on: self)
        }
    }

    /// A move along and down - the hand's, a speed, a wheel's notches - as the run's arithmetic reads it: right to
    /// left, the other way along.
    /// Design: docs/design/host/layout.md#right-to-left
    func alongRun(_ move: Point) -> [Double] {
        [runDirection == .rightToLeft ? -move.x : move.x, move.y]
    }

    /// A point over the layout as the run's arithmetic reads it: right to left, turned about the middle of the room
    /// it last said it has.
    func inRun(_ point: Point) -> [Double] {
        guard runDirection == .rightToLeft else { return [point.x, point.y] }
        let width = laidOutRoom?.width ?? 0
        return [width - point.x, point.y]
    }

    private static let pointerEvents: [Event] = [
        .pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
    ]

    /// A press dragged moves the states it carries by how far it has come, from where they stood as it began, and
    /// says so, in one of the user's transactions; ended, it is a swipe where it went far enough.
    /// A press on the view as a button takes it: its pressed state lit and put out, and a tap where it lets go over
    /// the view - a single one; a run of taps keeps the platform's own count.
    /// Design: docs/design/host/runtime.md#a-press-as-a-button-takes-it
    private func pressed(_ phase: GesturePhase, over: Bool, waits: Bool = false, in runtime: HostRuntime) {
        tell(buttonPress.step(phase, over: over, waits: waits, at: runtime.clock.now()), in: runtime)
        if buttonPress.isWaiting { runtime.handPace.opened(self) }
    }

    /// The view's own drag began: it takes the press under way, whose release is no tap - neither the press's nor
    /// one the view's toolkit tells after it. The press's own effect on the view goes on with the drag.
    /// Design: docs/design/host/interaction.md#a-views-own-press-and-drag
    func dragTakesThePress(in runtime: HostRuntime) {
        guard hearing.contains(.taps) else { return }
        if buttonPress.isPressed { pressed(.cancelled, over: false, in: runtime) }
        tapTaken = true
    }

    /// What a press said of the view, as its events.
    private func tell(_ saids: [ButtonPress.Said], in runtime: HostRuntime) {
        for said in saids {
            switch said {
            case .lit: send(.pressed, [], in: runtime)
            case .out: send(.released, [], in: runtime)
            case .tapped: if (whole(.tapCount) ?? 1) <= 1 { send(.tapped, [], in: runtime) }
            }
        }
    }

    /// Whether the view stands in what a finger's press may still begin to scroll: a scroller, a collection, a
    /// layout a hand moves.
    private var standsInAScroller: Bool {
        var each = parent
        while let element = each {
            if [.scrollView, .itemsView].contains(element.type) || element.hearing.contains(.hand) { return true }
            each = element.parent
        }
        return false
    }

    /// A hand taking the touch takes every press under way in the layout - its own and those of the views it holds:
    /// a swipe across them taps none, and a view's own press lets its effect go. The press on the element the
    /// hand is over keeps its effect: the hand and the press there are one touch on one view.
    /// Design: docs/design/host/interaction.md#one-gesture-taking-anothers-touch
    private func takePresses(in runtime: HostRuntime) {
        if buttonPress.isPressed { pressed(.cancelled, over: false, in: runtime) }
        for child in children { child.yieldPresses(in: runtime) }
    }

    /// The presses under way on the element and in it are taken away: a button's goes out, a view's own lets go.
    private func yieldPresses(in runtime: HostRuntime) {
        if buttonPress.isPressed { pressed(.cancelled, over: false, in: runtime) }
        if pressReading.isDown {
            pressReading.takenAway(time: runtime.clock.now())
            runtime.handPace.opened(self)
        }
        for child in children { child.yieldPresses(in: runtime) }
    }

    private func dragged(_ phase: GesturePhase, x: Double, y: Double, from: Point, in runtime: HostRuntime) {
        // A step of no drag under way says nothing: one ends once, and none goes on after its end.
        guard phase == .began || panUnderWay else { return }
        // A drag takes the press: no tap.
        if phase == .began { pressed(.cancelled, over: false, in: runtime) }
        // Every report tells how far the pan came since it began and how fast it goes - its end as fast as it lifted.
        // Design: docs/design/types/gestures.md#a-gestures-speed
        let now = runtime.clock.now()
        if phase == .began { (panFromStart, panSpeed) = (Point(x: 0, y: 0), SpeedReading()) }
        panUnderWay = !Self.ends(phase)
        if phase == .changed {
            panSpeed.moved(Point(x: x - panFromStart.x, y: y - panFromStart.y), at: now)
            panFromStart = Point(x: x, y: y)
        }
        let speed = phase == .began || phase == .cancelled ? Point(x: 0, y: 0) : panSpeed.speed(at: now)
        runtime.performUserTransaction {
            send(.panUpdated, [
                .enumeration(phase.rawValue), .numbers([panFromStart.x, panFromStart.y]), .numbers([speed.x, speed.y]),
                .numbers([from.x + panFromStart.x, from.y + panFromStart.y]),
            ], in: runtime)
        }

        guard phase == .ended, handler(.swiped) != nil else { return }
        let listening = SwipeDirections(rawValue: value(.swipeDirections)?.enumeration ?? SwipeDirections.all.rawValue)
        if let direction = SwipeDirection.swiped(x: x, y: y, listening: listening, threshold: number(.swipeThreshold) ?? 40) {
            send(.swiped, [.enumeration(direction.rawValue)], in: runtime)
        }
    }
}
