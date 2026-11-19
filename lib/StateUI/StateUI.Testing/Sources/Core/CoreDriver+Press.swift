// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A press under way in a test's window: the view it went down on, and what it has become by the host layer's own
/// recognition - a drag past where it went down, the hand over a layout - with no distance to pass first.
/// Design: docs/design/host/testing.md#a-press-in-phases
@MainActor
struct CorePress {
    weak var element: MountedElement?
    var drag = DragRecognition(distance: .radius(0))
    var hand = HandRecognition(distance: .radius(0))
}

extension CoreDriver {
    /// A press went down on `element` at `point`: its pointer's press, a drag's and the hand's beginning, each where
    /// the view listens for it.
    func pressDown(at point: Point, on element: MountedElement, in runtime: HostRuntime) throws {
        guard press == nil else {
            throw DriverCannot("pressDown on \(element.type.name)", because: "a press is already under way")
        }
        let hearing = element.hearing
        guard !hearing.isDisjoint(with: [.taps, .pointer, .drags, .hand]) || element.handler(.clicked) != nil else {
            throw DriverCannot("pressDown on \(element.type.name)", because: "it listens for no press")
        }
        var made = CorePress(element: element)
        if hearing.contains(.pointer) { element.hear(.pointer(.pointerPressed, point), in: runtime) }
        if hearing.contains(.drags) { made.drag.pressed(at: point) }
        if hearing.contains(.hand), case .began(let at) = made.hand.down(0, at: point, inView: point) {
            element.hear(.hand(.began, moved: Point(x: 0, y: 0), speed: nil, point: at), in: runtime)
        }
        press = made
    }

    /// The press under way on `element` moved to `point`.
    func drag(to point: Point, on element: MountedElement, in runtime: HostRuntime) throws {
        guard var made = press, made.element === element else {
            throw DriverCannot("drag on \(element.type.name)", because: "no press went down on it")
        }
        let hearing = element.hearing
        if hearing.contains(.pointer) { element.hear(.pointer(.pointerMoved, point), in: runtime) }
        if hearing.contains(.drags) {
            for input in made.drag.moved(to: point) { element.hear(input, in: runtime) }
        }
        if hearing.contains(.hand) {
            switch made.hand.moved(0, to: point) {
            case .asks(let travel):
                made.hand.answered(taken: element.hear(.hand(.changed, moved: travel, speed: nil), in: runtime))
            case .moved(let step):
                element.hear(.hand(.changed, moved: step, speed: nil), in: runtime)
            default:
                break
            }
        }
        press = made
    }

    /// The press under way on `element` let go at `point`, or - with none - taken away: a drag's and the hand's end,
    /// and for a press let go that never moved the view's tap or click.
    func endPress(at point: Point?, on element: MountedElement, in runtime: HostRuntime) throws {
        let letGo = point != nil
        guard var made = press, made.element === element else {
            throw DriverCannot("\(letGo ? "lift" : "cancelInteraction") on \(element.type.name)",
                               because: "no press went down on it")
        }
        press = nil
        let hearing = element.hearing
        let moved = made.drag.isDragging || made.hand.isTaken
        if let ended = made.drag.ended(letGo: letGo) { element.hear(ended, in: runtime) }
        if case .ended = made.hand.up(0, letGo: letGo) {
            element.hear(.hand(letGo ? .ended : .cancelled, moved: Point(x: 0, y: 0), speed: nil), in: runtime)
        }
        guard let point else { return }
        if hearing.contains(.pointer) { element.hear(.pointer(.pointerReleased, point), in: runtime) }
        guard !moved, element.isEffectivelyEnabled else { return }
        if element.handler(.clicked) != nil {
            element.send(.clicked, [], in: runtime)
        } else if hearing.contains(.taps) {
            element.hear(.tap(run: 1), in: runtime)
        }
    }
}
