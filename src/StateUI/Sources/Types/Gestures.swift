// What a gesture reports.
//
// MAUI hands each gesture an EventArgs with two or three values on it -
// a status and a translation, a scale and an origin, a direction. The payload
// carries one typed value per property, in the order MAUI declares them
// (Core/Wire.swift):
//
//     swiped          the direction, as the one number its bits are
//     panUpdated      status, totalX, totalY
//     pinchUpdated    status, scale, then the origin as one pair
//     pointerMoved    the position as one pair
//
// One place to read those shapes, and one place to write them - see the C#
// side's ApplyGestures. Nothing is formatted or parsed: a number crosses as
// its own bits, and a member of a closed vocabulary as THIS LIBRARY's number
// for it - `.enumeration`, the wire's tag 10 - which the host translates onto
// MAUI's member by name before it reports one.

/// How far along a continuous gesture is. MAUI: GestureStatus.
///
/// The numbers are THIS LIBRARY's, declaration order from 0, and the host
/// translates each onto the MAUI member named below it. MAUI's own numbers stay
/// out of it on purpose: a release free to renumber its enum is a release that
/// would have every report here read as a different status, silently.
public enum GestureStatus: Int32, Sendable {
    /// The gesture has begun. Not every platform sends one: a trackpad
    /// magnification on Mac Catalyst reports `.running` and `.completed` only,
    /// each step being a cycle of its own. Arithmetic that captures a value here
    /// works on a phone and does nothing on a laptop - multiply by what each
    /// report carries instead. MAUI: GestureStatus.Started.
    case started = 0

    /// The gesture is under way, and this is where it has got to.
    /// MAUI: GestureStatus.Running.
    case running = 1

    /// The finger has been lifted. MAUI: GestureStatus.Completed.
    case completed = 2

    /// The platform took the gesture away - a call arriving, a scroll winning.
    /// MAUI: GestureStatus.Canceled.
    case canceled = 3

    /// Reads a payload's status value - a member of a closed vocabulary, so
    /// `.enumeration` and not a plain number. Nil for anything that is not
    /// one, so a report that will not read leaves the handler alone.
    init?(_ value: PropValue?) {
        guard let member = value?.enumeration else { return nil }
        self.init(rawValue: member)
    }
}

/// Which way a swipe went, and which ways a view listens for.
/// MAUI: SwipeDirection, a [Flags] enum - with bits numbered here rather than
/// there, `1 << 0` upwards in declaration order.
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

    /// MAUI: SwipeDirection.Right.
    public static let right = SwipeDirection(rawValue: 1)

    /// MAUI: SwipeDirection.Left.
    public static let left = SwipeDirection(rawValue: 2)

    /// MAUI: SwipeDirection.Up.
    public static let up = SwipeDirection(rawValue: 4)

    /// MAUI: SwipeDirection.Down.
    public static let down = SwipeDirection(rawValue: 8)

    /// Every direction - what a view listens for unless it says otherwise.
    public static let all: SwipeDirection = [.left, .right, .up, .down]

    /// The bits, as the one number a bit set already is - a set of every
    /// direction is 15, and the host ORs the MAUI bits it translates them to.
    var propValue: PropValue { .enumeration(rawValue) }

    /// The one direction a swipe went, as the event reports it.
    ///
    /// ONE, and a set of several is refused rather than read as one. That is
    /// not fussiness: MAUI on iOS and Mac Catalyst reports the directions a
    /// recognizer LISTENS for instead of the one the finger went, so a view
    /// listening every way reported all four for every swipe. A set is not an
    /// answer to "which way", and accepting one would have every direction
    /// test on the far side pass at once. The renderer attaches one recognizer
    /// per direction so that a single bit is all that can arrive - see
    /// StateUIRenderer.ApplySwipe, which translates MAUI's bit back into
    /// this side's before it writes one.
    init?(_ value: PropValue?) {
        guard let bits = value?.enumeration else { return nil }

        let direction = SwipeDirection(rawValue: bits)

        switch direction {
        case .left, .right, .up, .down: self = direction
        default: return nil
        }
    }
}

/// A point. MAUI: Point.
///
/// Where a gesture happened, in the view's own coordinates - and also where a
/// polygon turns a corner, or where a gradient begins. MAUI's Point is the same
/// value in all of them, in whatever units the property reading it works in.
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

    /// The same, written the way MAUI's own constructor takes one - for a list
    /// of them, where the labels would drown the numbers.
    ///
    ///     Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
    public init(_ x: Double, _ y: Double) {
        self.init(x: x, y: y)
    }

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
    /// Numbers rather than the `20,0 40,40 0,40` MAUI's
    /// `PointCollectionConverter` reads: a corner crosses as its own bits, so
    /// an outline of a hundred of them is neither spelled out in decimal here
    /// nor parsed again on arrival.
    var propValue: PropValue {
        .numbers(flatMap { [$0.x, $0.y] })
    }
}

/// One report from a pan - what `.onPanUpdated` hands its handler.
/// MAUI: PanUpdatedEventArgs.
///
///     BoxView(.cornflowerBlue)
///         .translationX(offsetX)
///         .onPanUpdated { pan in
///             if pan.status == .running { offsetX = pan.totalX }
///         }
///
/// One of these arrives per movement, each carrying `status` and how far the
/// finger has come since the pan began.
public struct PanUpdate: Equatable, Sendable {
    /// How far along the pan is. MAUI: PanUpdatedEventArgs.StatusType.
    public var status: GestureStatus

    /// How far the finger has moved sideways since the pan began, in device
    /// units. MAUI: TotalX.
    public var totalX: Double

    /// The same, vertically. MAUI: TotalY.
    ///
    /// Measured from where the pan began, which is what makes moving a view a
    /// matter of assigning these to its translation. That holds on every
    /// platform: Android measures a pan against a frame that moves with the
    /// view, so a handler answering by translating it would feed its own answer
    /// back into the next report - the host puts that back. See the renderer's
    /// PanFrame.
    public var totalY: Double

    /// Reads a payload's three values - status, totalX, totalY, the order
    /// MAUI declares them. Nil for anything else, so a report that will not
    /// read leaves the handler alone.
    init?(_ payload: [PropValue]) {
        guard let status = GestureStatus(payload.value(0)),
              let totalX = payload.value(1)?.number,
              let totalY = payload.value(2)?.number else { return nil }

        self.status = status
        self.totalX = totalX
        self.totalY = totalY
    }
}

/// One report from a pinch - what `.onPinchUpdated` hands its handler.
/// MAUI: PinchGestureUpdatedEventArgs.
///
///     Image("map.png")
///         .scale(zoom)
///         .onPinchUpdated { pinch in zoom *= pinch.scale }
///
/// `scale` is how much the fingers moved since the LAST report, so a handler
/// multiplies what it holds rather than assigning.
public struct PinchUpdate: Equatable, Sendable {
    /// How far along the pinch is. MAUI: PinchGestureUpdatedEventArgs.Status.
    public var status: GestureStatus

    /// How much the fingers have moved apart since the last report - MAUI's
    /// Scale is relative, not cumulative.
    public var scale: Double

    /// Where the pinch is centred, as a fraction of the view: (0,0) is the top
    /// left, (1,1) the bottom right. MAUI: ScaleOrigin.
    public var scaleOrigin: Point

    /// Reads a payload's three values - status, scale, then the origin as one
    /// pair, the order MAUI declares them. Nil for anything else, so a report
    /// that will not read leaves the handler alone.
    init?(_ payload: [PropValue]) {
        guard let status = GestureStatus(payload.value(0)),
              let scale = payload.value(1)?.number,
              let origin = Point(payload.value(2)) else { return nil }

        self.status = status
        self.scale = scale
        self.scaleOrigin = origin
    }
}
