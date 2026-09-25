// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What the user does to the element's view with a finger, a pen or the mouse, as the element's events.
/// Design: docs/design/platforms/gtk/input.md
extension GTKElement {
    /// Listens for what the element's handlers and channels ask for: taps, the pointer, a press dragged, a pinch.
    func configureGestures() {
        guard let view else { return }

        var hearing: GTKHearing = []
        if element.handler(.tapped) != nil { hearing.insert(.taps) }
        if Self.pointerEvents.contains(where: { element.handler($0) != nil }) { hearing.insert(.pointer) }
        let drags = element.handler(.panUpdated) != nil || element.handler(.swiped) != nil
            || channel(.panXChannel) != nil || channel(.panYChannel) != nil
        // A press dragged is one pointer's; a pan asking for more is not recognized.
        if drags, (value(.panTouchCount)?.number ?? 1) == 1 { hearing.insert(.drags) }
        if element.handler(.pinchUpdated) != nil { hearing.insert(.pinches) }

        view.hear(hearing) { [weak self] heard in self?.heard(heard) }
    }

    private static let pointerEvents: [Event] = [
        .pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
    ]

    /// The state a press dragged carries along an axis, where one does.
    private func channel(_ property: Prop) -> Int32? {
        value(property)?.number.flatMap { $0 == 0 ? nil : Int32($0) }
    }

    private func heard(_ heard: GTKHeard) {
        switch heard {
        case .tap(let run):
            // A run answers each time it reaches the count asked for; a press assistive technology made, at once.
            let count = max(1, Int(value(.tapCount)?.number ?? 1))
            if run == 0 || run % count == 0 { send(.tapped, []) }
        case .pointer(let event, let point):
            send(event, event == .pointerEntered || event == .pointerExited ? [] : [.numbers([point.x, point.y])])
        case .drag(let phase, let x, let y):
            dragged(phase, x: x, y: y)
        case .pinch(let phase, let scale, let origin):
            send(.pinchUpdated, [.enumeration(phase), .number(scale), .numbers([origin.x, origin.y])])
        }
    }

    /// A press dragged moves the states it carries by how far it has come, from where they stood as it began, and
    /// says so, in one of the user's transactions; ended, it is a swipe where it went far enough.
    private func dragged(_ phase: Int32, x: Double, y: Double) {
        guard let host else { return }
        let across = channel(.panXChannel)
        let down = channel(.panYChannel)

        if phase == 0 {
            panFrom = (
                across.flatMap(host.runtime.standingGestureValue(state:)) ?? 0,
                down.flatMap(host.runtime.standingGestureValue(state:)) ?? 0)
        }
        host.runtime.performUserTransaction {
            if phase == 1 {
                if let across { host.runtime.takeGestureValue(panFrom.x + x, state: across) }
                if let down { host.runtime.takeGestureValue(panFrom.y + y, state: down) }
            }
            let moved = phase == 1 ? (x, y) : (0, 0)
            send(.panUpdated, [.enumeration(phase), .number(moved.0), .number(moved.1)])
        }

        guard phase == 2, element.handler(.swiped) != nil else { return }
        let listening = SwipeDirection(rawValue: value(.swipeDirection)?.enumeration ?? SwipeDirection.all.rawValue)
        if let direction = SwipeDirection.swiped(
            x: x, y: y, listening: listening, threshold: value(.swipeThreshold)?.number ?? 40) {
            send(.swiped, [.enumeration(direction.rawValue)])
        }
    }
}
