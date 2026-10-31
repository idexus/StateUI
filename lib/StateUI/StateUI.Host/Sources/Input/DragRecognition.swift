// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A press on its way to a drag, the same on every host whose toolkit tells a press and its moves and no drag of its
/// own: a drag once it has moved more than the platform's distance from where it went down, then each move the
/// drag's, measured from there, until the press lets go or the platform takes it away - unless it is held first.
/// Design: docs/design/host/runtime.md#a-press-dragged
/// Design: docs/design/host/runtime.md#a-press-held
@_spi(Host) public struct DragRecognition: Sendable {
    /// How far a press moves before it is a drag, as the platform measures it.
    public enum Distance: Equatable, Sendable {
        /// Along either axis: more than `x` across, or more than `y` down.
        case eachAxis(x: Double, y: Double)

        /// Any way: more than `radius` from where it went down.
        case radius(Double)

        /// Whether a press that moved by `moved` from where it went down is past the distance.
        public func isPassed(by moved: Point) -> Bool {
            switch self {
            case .eachAxis(let x, let y): abs(moved.x) > x || abs(moved.y) > y
            case .radius(let radius): (moved.x * moved.x + moved.y * moved.y).squareRoot() > radius
            }
        }
    }

    /// The platform's distance.
    public let distance: Distance

    /// Whether the press is a drag now.
    public private(set) var isDragging = false

    /// Whether the press was held before it became a drag - until the next press: its release is no tap.
    public private(set) var isHeld = false

    private var start: Point?
    private var moved = Point(x: 0, y: 0)

    /// No press yet, a drag past `distance`.
    public init(distance: Distance) {
        self.distance = distance
    }

    /// A press went down at `point`: whatever came before is over.
    public mutating func pressed(at point: Point) {
        start = point
        moved = Point(x: 0, y: 0)
        isDragging = false
        isHeld = false
    }

    /// The platform's hold came: a press not yet a drag is the hold's, and drags nothing after. Whether the hold
    /// stands - none once the press is a drag.
    public mutating func held() -> Bool {
        guard !isDragging else { return false }
        if start != nil { isHeld = true }
        return true
    }

    /// The press moved to `point`: what the view hears - nothing before it passed the distance, the drag's start and
    /// its first move as it does, and a move after; nothing for a move with no press.
    public mutating func moved(to point: Point) -> [HeardInput] {
        guard let start else { return [] }

        moved = Point(x: point.x - start.x, y: point.y - start.y)
        let running = HeardInput.drag(.changed, x: moved.x, y: moved.y)
        if isDragging { return [running] }
        guard !isHeld, distance.isPassed(by: moved) else { return [] }

        isDragging = true
        return [.drag(.began, x: 0, y: 0), running]
    }

    /// The press let go, or the platform took it away: the drag's end, where the press was one.
    public mutating func ended(letGo: Bool) -> HeardInput? {
        defer {
            start = nil
            isDragging = false
        }
        guard isDragging else { return nil }

        return .drag(letGo ? .ended : .cancelled, x: moved.x, y: moved.y)
    }
}
