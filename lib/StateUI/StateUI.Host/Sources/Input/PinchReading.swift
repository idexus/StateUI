// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import StateUIFoundation

/// Two fingers over a layout engine, read alike on every host: the pinch and the rotation the platform tells as two
/// gestures made one stream - begun with the first of them, ended with the last, each move how far the fingers
/// spread and turned since the last report, and as they lift, how fast, read from their last tenth of a second.
/// What it answers is the element's `pinchMoved`.
/// Design: docs/design/host/runtime.md#two-fingers-over-a-layout
@_spi(Host) public struct PinchReading: Sendable {
    /// One report of the fingers: its phase, how far they spread - a scale - and turned, in degrees clockwise, since
    /// the last, and as they lift how fast, per second: the scale's logarithm across, the degrees down.
    public struct Report: Equatable, Sendable {
        /// Where the fingers are: begun, moving, lifted or taken away.
        public let phase: GesturePhase

        /// How far they spread since the last report: a scale, 1 for none.
        public let scale: Double

        /// How far they turned since the last report, in degrees clockwise.
        public let degrees: Double

        /// How fast they went as they lifted, per second - the scale's logarithm across, the degrees down; nought
        /// before.
        public let speed: Point

        /// A report of `phase`.
        public init(_ phase: GesturePhase, scale: Double = 1, degrees: Double = 0, speed: Point = .zero) {
            self.phase = phase
            self.scale = scale
            self.degrees = degrees
            self.speed = speed
        }
    }

    /// Which of the two gestures the platform tells.
    public enum Gesture: Sendable {
        /// Two fingers spreading or closing.
        case pinch

        /// Two fingers turning.
        case rotation
    }

    /// The gestures under way.
    private var open: Set<Gesture> = []

    /// The moves of the last `HandReading.reading` milliseconds: when each was made, the scale's logarithm and the
    /// degrees.
    private var moves: [(time: Double, spread: Double, degrees: Double)] = []

    /// No fingers yet.
    public init() {}

    /// Whether the fingers are under way.
    public var isOpen: Bool { !open.isEmpty }

    /// The platform's pinch at `phase`, spread by `scale` since its last step, at `time`.
    public mutating func pinch(_ phase: GesturePhase, scale: Double, at time: Double) -> [Report] {
        told(.pinch, phase, spread: scale > 0 ? log(scale) : 0, degrees: 0, at: time)
    }

    /// The platform's rotation at `phase`, turned by `degrees` clockwise since its last step, at `time`.
    public mutating func rotation(_ phase: GesturePhase, degrees: Double, at time: Double) -> [Report] {
        told(.rotation, phase, spread: 0, degrees: degrees, at: time)
    }

    /// One of the two gestures told: the stream begins with the first of them - a move with no beginning heard is
    /// one - and ends with the last; a cancel of the last cancels it.
    private mutating func told(
        _ gesture: Gesture, _ phase: GesturePhase, spread: Double, degrees: Double, at time: Double
    ) -> [Report] {
        switch phase {
        case .began:
            let begins = open.isEmpty
            open.insert(gesture)
            if begins { moves = [] }
            return begins ? [Report(.began)] : []

        case .changed:
            let begins = open.isEmpty ? [Report(.began)] : []
            if begins.count > 0 { moves = [] }
            open.insert(gesture)
            guard spread != 0 || degrees != 0 else { return begins }

            moves = moves.filter { time - $0.time <= HandReading.reading } + [(time, spread, degrees)]
            return begins + [Report(.changed, scale: exp(spread), degrees: degrees)]

        case .ended, .cancelled:
            guard open.remove(gesture) != nil, open.isEmpty else { return [] }

            guard phase == .ended else {
                moves = []
                return [Report(.cancelled)]
            }
            let recent = moves.filter { time - $0.time <= HandReading.reading }
            let span = max(time - (recent.first?.time ?? time), HandReading.frame)
            let spread = recent.reduce(0) { $0 + $1.spread }
            let turned = recent.reduce(0) { $0 + $1.degrees }
            moves = []
            return [Report(.ended, speed: recent.isEmpty ? .zero : Point(spread / span * 1_000, turned / span * 1_000))]
        }
    }
}

/// A rotation the platform tells as how far it has turned since it began, said as its steps.
@_spi(Host) public struct RotationStep: Sendable {
    private var last = 0.0

    /// A rotation not begun.
    public init() {}

    /// The degrees since the last step of a rotation standing at `degrees` from where it began, in `phase`: none as
    /// it begins and ends.
    public mutating func step(_ phase: GesturePhase, degrees: Double) -> Double {
        let step = phase == .changed ? degrees - last : 0
        last = phase == .changed ? degrees : 0
        return step
    }
}

/// Two fingers a toolkit tells as two pointers, and no gesture of two: how far apart they stand, and which way the
/// line between them points, against the last time - the steps of a pinch and of a rotation.
/// Design: docs/design/host/runtime.md#two-fingers-over-a-layout
@_spi(Host) public struct TwoFingers: Sendable {
    private var last: (span: Double, angle: Double)?

    /// No fingers yet.
    public init() {}

    /// The fingers stand at `first` and `second`, in points of a view whose y grows down: how far they spread - a
    /// scale - and turned, in degrees clockwise, since the last time; nil as they first stand, or stand together.
    public mutating func moved(_ first: Point, _ second: Point) -> (scale: Double, degrees: Double)? {
        let (dx, dy) = (second.x - first.x, second.y - first.y)
        let span = (dx * dx + dy * dy).squareRoot()
        let angle = atan2(dy, dx) * 180 / .pi
        defer { last = span > 0 ? (span, angle) : nil }
        guard let last, span > 0 else { return nil }

        var turned = angle - last.angle
        if turned > 180 { turned -= 360 }
        if turned <= -180 { turned += 360 }
        return (span / last.span, turned)
    }

    /// The fingers lifted: the next two begin afresh.
    public mutating func lifted() {
        last = nil
    }
}
