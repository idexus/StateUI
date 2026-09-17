// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a gesture reports.
//
// A gesture payload carries one typed value per part of its stable StateUI
// contract (Core/Wire.swift):
//
//     swiped          the direction, as the one number its bits are
//     panUpdated      phase, totalX, totalY
//     pinchUpdated    phase, scale, then the origin as one pair
//     pointerMoved    the position as one pair
//
// Nothing is formatted or parsed: a number crosses as its own bits, and a
// member of a closed vocabulary as THIS LIBRARY's number for it -
// `.enumeration`, the wire's tag 10. Every host maps native input onto this
// vocabulary before reporting it.

/// How far along a continuous gesture is.
///
/// The numbers are StateUI's declaration order from 0. Native enum values stay
/// outside the boundary so a platform release cannot silently reinterpret a
/// stored or transported report.
public enum GesturePhase: Int32, Sendable {
    /// The gesture has begun. A host that receives no distinct native begin
    /// phase may start with `.running`; handlers must use the values carried by
    /// each report rather than relying on capture here.
    case started = 0

    /// The gesture is under way, and this is where it has got to.
    case running = 1

    /// The pointer or fingers have been lifted.
    case completed = 2

    /// The platform took the gesture away - a call arriving, a scroll winning.
    case canceled = 3
}

extension GesturePhase: HostRepresentable {}

/// Which way a swipe went, and which ways a view listens for. Bits are StateUI's
/// own, `1 << 0` upwards in declaration order.
public struct SwipeDirection: OptionSet, Sendable {
    /// The bits, as an OptionSet keeps them - this library's own, and the one
    /// number the whole set travels as. `Int32` because that is what a closed
    /// vocabulary crosses in.
    public let rawValue: Int32

    /// From the raw bits. `.left`, `[.left, .right]` and `.all` are the ordinary
    /// way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// A swipe whose dominant movement goes towards the right edge.
    public static let right = SwipeDirection(rawValue: 1)

    /// A swipe whose dominant movement goes towards the left edge.
    public static let left = SwipeDirection(rawValue: 2)

    /// A swipe whose dominant movement goes towards the top edge.
    public static let up = SwipeDirection(rawValue: 4)

    /// A swipe whose dominant movement goes towards the bottom edge.
    public static let down = SwipeDirection(rawValue: 8)

    /// Every direction - what a view listens for unless it says otherwise.
    public static let all: SwipeDirection = [.left, .right, .up, .down]

    /// Whether this is ONE direction - what a swipe reports - rather than a
    /// set of them, which is what a view listens for. Every host reports one
    /// dominant direction bit, so a set of several is no answer to "which way
    /// did it go?"
    var isOneDirection: Bool {
        switch self {
        case .left, .right, .up, .down: true
        default: false
        }
    }

    /// The one direction a swipe went, as the event reports it - and nil for
    /// a set of several, or for anything else.
    init?(_ value: PropValue?) {
        guard let value, let direction = SwipeDirection(propValue: value), direction.isOneDirection else {
            return nil
        }

        self = direction
    }
}

extension SwipeDirection: HostRepresentable {}

/// A point.
///
/// Where a gesture happened in the view's own coordinates, where a polygon
/// turns a corner, or where a gradient begins. Its units belong to the property
/// that reads it.
public struct Point: Equatable, Sendable {
    /// How far across, from the left edge. Device units where the property
    /// reading it works in those - a pointer's position, a polygon's corner -
    /// and a fraction of the view where it works in fractions, as a gradient's
    /// start and end points do.
    public var x: Double

    /// How far down, from the top edge, read the same way.
    public var y: Double

    /// A point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// The same without labels, for a list where the labels would drown the
    /// numbers.
    ///
    ///     Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
    public init(_ x: Double, _ y: Double) {
        self.init(x: x, y: y)
    }

    /// The origin: both numbers nought.
    ///
    ///     @State private var offset = Point.zero
    ///
    /// Where a point is a PLACE this is the top left corner, and where it is a
    /// distance - a drag so far, a scroller's offset - it is having gone
    /// nowhere.
    public static let zero = Point(0, 0)
}

extension Point: HostRepresentable {
    /// Across, then down: one pair of numbers - what a pointer's position
    /// crosses as.
    public var propValue: PropValue { .numbers([x, y]) }

    /// A point back from its pair - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let pair = propValue.numbers, pair.count == 2 else { return nil }

        self.init(x: pair[0], y: pair[1])
    }

    /// Points cross as one flat run of numbers, x then y, a pair per point -
    /// what a Polygon's or a Polyline's corners travel as. Numbers rather than
    /// a formatted `20,0 40,40 0,40`: a corner crosses as its own bits, so a
    /// long outline is neither formatted nor parsed again.
    /// - Parameter list: the points, in order.
    public static func propValue(of list: [Point]) -> PropValue {
        .numbers(list.flatMap { [$0.x, $0.y] })
    }

    /// The points back from their run of pairs - nil for an odd run or for
    /// anything else.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [Point]? {
        guard let numbers = value.numbers, numbers.count.isMultiple(of: 2) else { return nil }

        return stride(from: 0, to: numbers.count, by: 2).map { Point(numbers[$0], numbers[$0 + 1]) }
    }
}

/// One report from a pan - what `.onPanUpdated` hands its handler.
///
///     ColorBox(.cornflowerBlue)
///         .translationX(offsetX)
///         .onPanUpdated { pan in
///             if pan.phase == .running { offsetX = pan.totalX }
///         }
///
/// One of these arrives per movement, each carrying `phase` and how far the
/// finger has come since the pan began.
public struct PanUpdate: Equatable, Sendable {
    /// How far along the pan is.
    public var phase: GesturePhase

    /// How far the pointer has moved sideways since the pan began, in device
    /// units.
    public var totalX: Double

    /// The same, vertically.
    ///
    /// Measured from where the pan began, which is what makes moving a view a
    /// matter of assigning these to its translation. That holds on every
    /// platform: Android measures a pan against a frame that moves with the
    /// view, so a handler answering by translating it would feed its own answer
    /// back into the next report - the host puts that back. See the renderer's
    /// PanFrame.
    public var totalY: Double

    /// One report, from the three values a pan carries: phase, totalX, totalY.
    init(phase: GesturePhase, totalX: Double, totalY: Double) {
        self.phase = phase
        self.totalX = totalX
        self.totalY = totalY
    }
}

/// One report from a pinch - what `.onPinchUpdated` hands its handler.
///
///     Image("map.png")
///         .scale(zoom)
///         .onPinchUpdated { pinch in zoom *= pinch.scale }
///
/// `scale` is how much the fingers moved since the LAST report, so a handler
/// multiplies what it holds rather than assigning.
public struct PinchUpdate: Equatable, Sendable {
    /// How far along the pinch is.
    public var phase: GesturePhase

    /// How much the fingers have moved apart since the last report. The scale
    /// is relative, not cumulative.
    public var scale: Double

    /// Where the pinch is centred, as a fraction of the view: (0,0) is the top
    /// left and (1,1) the bottom right.
    public var scaleOrigin: Point

    /// One report, from the three values a pinch carries: phase, scale, and
    /// the origin.
    init(phase: GesturePhase, scale: Double, scaleOrigin: Point) {
        self.phase = phase
        self.scale = scale
        self.scaleOrigin = scaleOrigin
    }
}
