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

    /// Reads a payload's phase value - a member of a closed vocabulary, so
    /// `.enumeration` and not a plain number. Nil for anything that is not
    /// one, so a report that will not read leaves the handler alone.
    init?(_ value: PropValue?) {
        guard let member = value?.enumeration else { return nil }
        self.init(rawValue: member)
    }
}

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

    /// The bits as the one number a bit set already is; every direction is 15.
    var propValue: PropValue { .enumeration(rawValue) }

    /// The one direction a swipe went, as the event reports it.
    ///
    /// ONE, and a set of several is refused rather than read as one. A set is
    /// what a view listens for, not an answer to "which way did it go?" Every
    /// host must therefore report one dominant direction bit.
    init?(_ value: PropValue?) {
        guard let bits = value?.enumeration else { return nil }

        let direction = SwipeDirection(rawValue: bits)

        switch direction {
        case .left, .right, .up, .down: self = direction
        default: return nil
        }
    }
}

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

    /// Reads the pair a payload carries - one `numbers` value, x then y. Nil
    /// for anything else, so a report that will not read leaves the handler
    /// alone.
    init?(_ value: PropValue?) {
        guard let pair = value?.numbers, pair.count == 2 else { return nil }
        self.init(x: pair[0], y: pair[1])
    }
}

extension Array where Element == Point {
    /// The points as one flat run of numbers, x then y, a pair per point -
    /// which is what a Polygon's or a Polyline's corners travel as, and the
    /// same shape a pointerMoved payload reports ONE of.
    ///
    /// Numbers rather than a formatted `20,0 40,40 0,40`: a corner crosses as
    /// its own bits, so a long outline is neither formatted nor parsed again.
    var propValue: PropValue {
        .numbers(flatMap { [$0.x, $0.y] })
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

    /// Reads a payload's three values: phase, totalX, totalY. Nil for anything
    /// else, so a report that will not read leaves the handler alone.
    init?(_ payload: [PropValue]) {
        guard let phase = GesturePhase(payload.value(0)),
              let totalX = payload.value(1)?.number,
              let totalY = payload.value(2)?.number else { return nil }

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

    /// Reads a payload's three values: phase, scale, then the origin as one
    /// pair. Nil for anything else, so a report that will not read leaves the
    /// handler alone.
    init?(_ payload: [PropValue]) {
        guard let phase = GesturePhase(payload.value(0)),
              let scale = payload.value(1)?.number,
              let origin = Point(payload.value(2)) else { return nil }

        self.phase = phase
        self.scale = scale
        self.scaleOrigin = origin
    }
}
