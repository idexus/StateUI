// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user does to an element's view with a finger, a pen or the mouse, as the element's events - the same
/// on every host.
/// Design: docs/design/host/runtime.md#what-the-user-does-with-a-finger
extension MountedElement {
    /// What the element's handlers and channels ask to hear: taps, the pointer, a press dragged, a pinch. A pan asks
    /// for a press dragged by one pointer; one asking for more is not recognized.
    public var hearing: Hearing {
        var hearing: Hearing = []
        if handler(.tapped) != nil { hearing.insert(.taps) }
        if Self.pointerEvents.contains(where: { handler($0) != nil }) { hearing.insert(.pointer) }
        let drags = handler(.panUpdated) != nil || handler(.swiped) != nil
            || channel(.panXChannel) != nil || channel(.panYChannel) != nil
        if drags, (number(.panTouchCount) ?? 1) == 1 { hearing.insert(.drags) }
        if handler(.pinchUpdated) != nil { hearing.insert(.pinches) }
        if handler(.handMoved) != nil { hearing.insert(.hand) }
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
            send(.pinchUpdated, [.enumeration(phase.rawValue), .number(scale), .numbers([at.x, at.y])], in: runtime)
        case .hand(let phase, let moved, let speed, let time):
            // When the platform says the hand moved, where it says: input that waited for a busy thread comes in a
            // burst its arrival would read as a throw.
            let heard = handReading.hand(
                phase, moved: moved, speed: speed, at: time ?? runtime.clock.now(), along: handAxis)
            said(heard.reports, in: runtime)
            return heard.taken
        case .wheel(let moved):
            let heard = handReading.wheel(moved, at: runtime.clock.now(), along: handAxis)
            said(heard.reports, in: runtime)
            if handReading.isWheeling { runtime.handPace.opened(self) }
            return heard.taken
        case .notch(let notches):
            let heard = handReading.notches(notches, along: handAxis)
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

    /// Which way the hand moves the layout this element is, where a hand does.
    public var handAxis: LayoutInput.Axis? {
        value(.handAxis)?.enumeration.flatMap(LayoutInput.Axis.init(rawValue:))
    }

    /// A frame at `now` found the element's wheel open: let go where it has stood still long enough.
    func paced(now: Double, in runtime: HostRuntime) {
        said(handReading.paced(at: now), in: runtime)
    }

    /// The hand's reports, as the element's `handMoved`.
    private func said(_ reports: [HandReading.Report], in runtime: HostRuntime) {
        for report in reports {
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
