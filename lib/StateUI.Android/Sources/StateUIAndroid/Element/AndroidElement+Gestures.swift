// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The gestures an element listens for, on its view, and what each says.
/// Design: docs/design/platforms/android/controls.md#gestures
extension AndroidElement {
    /// A tap - a click, where one tap makes it - and the gestures the element's handlers and channels ask for.
    func configureGestures() {
        guard let view else { return }

        let taps = element.handler(.tapped) != nil
        let tapCount = Int(value(.tapCount)?.number ?? 1)
        view.setTapped(taps && tapCount <= 1 ? { [weak self] in self?.send(.tapped, []) } : nil)

        var wanted = AndroidView.Gestures()
        if taps, tapCount > 1 { wanted.taps = tapCount }
        if element.handler(.panUpdated) != nil || channel(.panXChannel) != nil || channel(.panYChannel) != nil {
            wanted.panFingers = max(1, Int(value(.panTouchCount)?.number ?? 1))
        }
        if element.handler(.swiped) != nil {
            wanted.swipeDirections = value(.swipeDirection)?.enumeration ?? 15
            wanted.swipeThreshold = max(0, value(.swipeThreshold)?.number ?? 40)
        }
        wanted.pinch = element.handler(.pinchUpdated) != nil
        wanted.pointer = Self.pointerEvents.contains { element.handler($0) != nil }

        view.setGestures(wanted)
        view.onGesture = wanted == .none ? nil : { [weak self] gesture in self?.heard(gesture) }
    }

    private static let pointerEvents: [Event] = [
        .pointerEntered, .pointerExited, .pointerMoved, .pointerPressed, .pointerReleased,
    ]

    /// The state a pan carries along an axis, where one does.
    private func channel(_ property: Prop) -> Int32? {
        value(property)?.number.flatMap { $0 == 0 ? nil : Int32($0) }
    }

    private func heard(_ gesture: AndroidView.Gesture) {
        switch gesture {
        case .tapped:
            send(.tapped, [])
        case .panned(let phase, let x, let y):
            panned(phase, x: x, y: y)
        case .swiped(let direction):
            send(.swiped, [.enumeration(direction)])
        case .pinched(let phase, let scale, let originX, let originY):
            send(.pinchUpdated, [.enumeration(phase), .number(scale), .numbers([originX, originY])])
        case .pointer(let event, let x?, let y?):
            send(event, [.numbers([x, y])])
        case .pointer(let event, _, _):
            send(event, [])
        }
    }

    /// A pan moves the states it carries by how far it has come, from where they stood as it started, and
    /// says so - in one of the user's transactions.
    private func panned(_ phase: Int32, x: Double, y: Double) {
        guard let host else { return }
        let across = channel(.panXChannel)
        let down = channel(.panYChannel)

        if phase == 0 {
            panFrom = (
                across.flatMap(host.standingGestureValue(state:)) ?? 0,
                down.flatMap(host.standingGestureValue(state:)) ?? 0)
        }
        host.performUserTransaction {
            if phase == 1 {
                if let across { host.takeGestureValue(panFrom.x + x, state: across) }
                if let down { host.takeGestureValue(panFrom.y + y, state: down) }
            }
            send(.panUpdated, [.enumeration(phase), .number(x), .number(y)])
        }
    }
}
