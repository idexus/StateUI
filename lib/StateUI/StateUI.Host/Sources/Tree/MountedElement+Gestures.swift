// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user does to an element's view with a finger, a pen or the mouse, as the element's events - the same
/// on every host.
/// Design: docs/design/host/runtime.md#what-the-user-does-with-a-finger
extension MountedElement {
    /// What the element's handlers and channels ask to hear: taps, the pointer, a press dragged, a pinch, the hand
    /// over a layout and the two fingers that spread or turn it. A pan asks for a press dragged by one pointer; one
    /// asking for more is not recognized.
    public var hearing: Hearing {
        var hearing: Hearing = []
        if handler(.tapped) != nil { hearing.insert(.taps) }
        if Self.pointerEvents.contains(where: { handler($0) != nil }) { hearing.insert(.pointer) }
        let drags = handler(.panUpdated) != nil || handler(.swiped) != nil
            || channel(.panXChannel) != nil || channel(.panYChannel) != nil
        if drags, (number(.panTouchCount) ?? 1) == 1 { hearing.insert(.drags) }
        if handler(.pinchUpdated) != nil || hearsFingers && value(.magnifies)?.bool == true { hearing.insert(.pinches) }
        if hearsFingers && value(.rotates)?.bool == true { hearing.insert(.rotations) }
        if handler(.handMoved) != nil || handler(.itemMoved) != nil { hearing.insert(.hand) }
        return hearing
    }

    /// The user's input the view heard, as the element's events: a tap each time a run reaches the count asked
    /// for - at once for a press assistive technology made; the pointer where it is; a press dragged moving the
    /// states it carries, a swipe as it ends far enough; a pinch's step; the hand over a layout; a drag between
    /// views by `DropTarget`. Whether the element took it: a hand over a layout across its axis it leaves to
    /// whatever holds it.
    @discardableResult
    public func hear(_ input: HeardInput, in runtime: HostRuntime) -> Bool {
        // A disabled branch hears nothing of the hand; a drag it began still ends there.
        guard isEffectivelyEnabled || input == .dragEnded else { return false }
        switch input {
        case .tap(let run):
            let count = max(1, Int(number(.tapCount) ?? 1))
            if run == 0 || run % count == 0 { send(.tapped, [], in: runtime) }
        case .pointer(let event, let point):
            let said: [HostValue] = event == .pointerEntered || event == .pointerExited ? [] : [.numbers([point.x, point.y])]
            send(event, said, in: runtime)
        case .drag(let phase, let x, let y):
            dragged(phase, x: x, y: y, in: runtime)
        case .pinch(let phase, let scale, let at):
            guard hearsFingers else {
                send(.pinchUpdated, [.enumeration(phase.rawValue), .number(scale), .numbers([at.x, at.y])], in: runtime)
                return true
            }
            return fingers(pinchReading.pinch(phase, scale: scale, at: runtime.clock.now()), in: runtime)
        case .wheelPinch(let scale, let at):
            // A wheel tells no lift: the frames let its pinch go once it stands still.
            for each in wheelPinch.turned(scale, at: at, now: runtime.clock.now()) { hear(each, in: runtime) }
            runtime.handPace.opened(self)
        case .rotation(let phase, let degrees):
            guard hearsFingers else { return false }

            return fingers(pinchReading.rotation(phase, degrees: degrees, at: runtime.clock.now()), in: runtime)
        case .mirrored(let phase, let at, let middle):
            guard hearsMirroredFingers else { return false }

            mirrored(phase, at: at, middle: middle, in: runtime)
        case .hand(let phase, let moved, let speed, let time, let point):
            // When the platform says the hand moved, where it says: input that waited for a busy thread comes in a
            // burst its arrival would read as a throw.
            let now = runtime.clock.now()
            let heard = handReading.hand(
                phase, moved: moved, speed: speed, at: time ?? now, way: handWay, point: point, items: itemDrag,
                now: now)
            gather(heard.reports, in: runtime)
            if handReading.wantsFrames { runtime.handPace.opened(self) }
            return heard.taken
        case .wheel(let moved):
            let heard = handReading.wheel(moved, at: runtime.clock.now(), way: handWay)
            gather(heard.reports, in: runtime)
            if handReading.isWheeling { runtime.handPace.opened(self) }
            return heard.taken
        case .notch(let notches):
            let heard = handReading.notches(notches, way: handWay)
            if let steps = heard.steps { send(.handStepped, [.numbers([steps.x, steps.y])], in: runtime) }
            return heard.taken
        case .dragStarted:
            send(.dragStarting, [], in: runtime)
        case .dragEnded:
            send(.dragEnded, [], in: runtime)
        case .dragOver:
            if dropTarget.over() { send(.dragOver, [], in: runtime) }
        case .dragLeft:
            if dropTarget.left() { send(.dragLeave, [], in: runtime) }
        case .dropped(let words):
            dropTarget.dropped()
            send(.drop, [.string(words)], in: runtime)
        case .filesDropped(let files):
            dropTarget.dropped()
            let taken = dragAndDrop.taken(files)
            if !taken.isEmpty { send(.filesDropped, [taken.propValue], in: runtime) }
        }
        return true
    }

    /// Whether two fingers spreading or turning move the layout this element is.
    private var hearsFingers: Bool { handler(.pinchMoved) != nil }

    /// Whether a press dragged with ⌥/Alt over the element is two fingers: where it hears a pinch or a rotation.
    public var hearsMirroredFingers: Bool { !hearing.isDisjoint(with: [.pinches, .rotations]) }

    /// A press dragged with ⌥/Alt at `phase`, standing at `at`, the view's middle at `middle`: the pinch and the
    /// rotation of two fingers, the press and its mirror - each told as the platform tells its own, so they go on as
    /// one stream; the hand stays, their middle standing still.
    /// Design: docs/design/host/runtime.md#two-fingers-from-one-pointer
    private func mirrored(_ phase: GesturePhase, at: Point, middle: Point, in runtime: HostRuntime) {
        let share = Point(0.5, 0.5)
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
        guard !handReading.holdsItem else {
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

    /// Which way the hand moves the layout this element is, where a hand does: along its axis, or every way.
    public var handWay: HandWay? {
        if value(.pans)?.bool == true { return .everyWay }
        return value(.handAxis)?.enumeration.flatMap(LayoutInput.Axis.init(rawValue:)).map(HandWay.init)
    }

    /// Whether the hand over the layout this element is holds one of its views by itself.
    public var holdsItem: Bool { handReading.holdsItem }

    /// How the hand takes one view of the layout this element is by itself, where it does.
    public var itemDrag: ItemDragStart? {
        value(.itemDrag)?.enumeration.flatMap(ItemDragStart.init(rawValue:))
    }

    /// A frame at `now` found the element's wheel open or its hand's reports waiting: the wheel let go where it has
    /// stood still long enough, then what the hand said since the last frame said at once.
    func paced(now: Double, in runtime: HostRuntime) {
        for each in wheelPinch.paced(now: now) { hear(each, in: runtime) }
        gather(handReading.paced(at: now), in: runtime)
        let reports = handOutbox
        handOutbox = []
        said(reports, in: runtime)

        let fingers = pinchOutbox
        pinchOutbox = []
        for report in fingers {
            send(.pinchMoved, [
                .enumeration(report.phase.rawValue), .number(report.scale), .number(report.degrees),
                .numbers([report.speed.x, report.speed.y]),
            ], in: runtime)
        }
    }

    /// The hand's reports kept for the next frame, a move after a move made one: a toolkit telling the hand faster
    /// than the display draws moves the run once a frame.
    /// Design: docs/design/host/runtime.md#the-hand-over-a-layout
    private func gather(_ reports: [HandReading.Report], in runtime: HostRuntime) {
        guard !reports.isEmpty else { return }

        for report in reports {
            if report.phase == .changed, let last = handOutbox.last, last.phase == .changed, last.item == report.item {
                handOutbox[handOutbox.count - 1] = HandReading.Report(
                    .changed, moved: Point(last.moved.x + report.moved.x, last.moved.y + report.moved.y),
                    item: report.item, at: report.at, still: max(last.still, report.still))
            } else {
                handOutbox.append(report)
            }
        }
        runtime.handPace.opened(self)
    }

    /// The hand's reports, as the element's `handMoved` - or `itemMoved`, the hand holding one view.
    private func said(_ reports: [HandReading.Report], in runtime: HostRuntime) {
        for report in reports {
            if report.item {
                send(.itemMoved, [
                    .enumeration(report.phase.rawValue),
                    .numbers([report.at.x, report.at.y]),
                    .numbers([report.speed.x, report.speed.y]),
                    .number(report.still),
                ], in: runtime)
                continue
            }
            send(.handMoved, [
                .enumeration(report.phase.rawValue),
                .numbers([report.moved.x, report.moved.y]),
                .numbers([report.speed.x, report.speed.y]),
            ], in: runtime)
        }
    }

    private static let pointerEvents: [Event] = [
        .pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
    ]

    /// The state a press dragged carries along an axis, where one does.
    private func channel(_ property: Prop) -> Int32? {
        number(property).flatMap { $0 == 0 ? nil : Int32($0) }
    }

    /// A press dragged moves the states it carries by how far it has come, from where they stood as it began, and
    /// says so, in one of the user's transactions; ended, it is a swipe where it went far enough.
    private func dragged(_ phase: GesturePhase, x: Double, y: Double, in runtime: HostRuntime) {
        let across = channel(.panXChannel)
        let down = channel(.panYChannel)
        if phase == .began {
            dragStart = Point(
                x: across.flatMap(runtime.standingGestureValue(state:)) ?? 0,
                y: down.flatMap(runtime.standingGestureValue(state:)) ?? 0)
        }
        runtime.performUserTransaction {
            if phase == .changed {
                if let across { runtime.takeGestureValue(dragStart.x + x, state: across) }
                if let down { runtime.takeGestureValue(dragStart.y + y, state: down) }
            }
            let moved = phase == .changed ? (x, y) : (0, 0)
            send(.panUpdated, [.enumeration(phase.rawValue), .number(moved.0), .number(moved.1)], in: runtime)
        }

        guard phase == .ended, handler(.swiped) != nil else { return }
        let listening = SwipeDirection(rawValue: value(.swipeDirection)?.enumeration ?? SwipeDirection.all.rawValue)
        if let direction = SwipeDirection.swiped(x: x, y: y, listening: listening, threshold: number(.swipeThreshold) ?? 40) {
            send(.swiped, [.enumeration(direction.rawValue)], in: runtime)
        }
    }
}
