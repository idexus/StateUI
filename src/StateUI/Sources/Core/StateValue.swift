// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT A VALUE MUST BE TO CROSS TO THE HOST, AND WHERE IT LIVES ONCE IT HAS -
// both of them outside the path that describes the interface.
//
// A scroller's offset changes with every touch report. Held as `@State` it is
// correct and expensive: each report is a write, a write is a render, and a
// render describes every view that read the value - which for a run of cards
// placed by arithmetic is the whole example, forty times per movement of a
// finger. Measured on a phone: 3.5 ms describing, 2.2 ms applying and a whole
// platform relayout, per report, against a frame budget of 11.
//
// So a state can be declared to say NOTHING to the tree, and then it carries
// no tree at all:
//
//   the STATE   `@Bus`, which is declared in Core/Bus.swift.
//               A value both sides hold, in one IMAGE of plain bytes, moved by
//               the host on the display's own frames and by arithmetic that
//               runs inside them. Nothing here asks for a render when it
//               moves. It is the same `@State` in every other way - declared
//               beside the view, kept across renders, found by the property's
//               own name.
//
//               THIS FILE IS THE LAYER UNDER IT: what a value must be to cross
//               (`StateValue`), what it turns into (`StateCarried`), which way
//               and through which door (`StateMode`, `StateKind`), the value
//               that carries a journey (`AnimatedValue`), and `HostStorage`,
//               which is where one lives.
//
//   the ENGINE  the author's arithmetic, in Swift, run on every cycle in which
//               something it follows was written - where each child of a
//               layout goes, what a caption says, where a thrown object is.
//               Written with `.engine(following:)`.
//
// The host then writes what came back onto the controls it already has. No
// build, no diff, no message: what crosses is a batch of bytes each way, which
// is why a value nobody could afford to render on can be followed frame by
// frame.
//
// THE CYCLE IS READ, COMPUTE, WRITE, and it is a pure function of the image,
// the engines and the instant: every input the host reported is LATCHED, the
// engines COMPUTE in a stated order over that one snapshot, and what they
// wrote is PUBLISHED in one go. Nothing an engine reads changes under it
// mid-cycle, and nothing it writes is seen until the cycle ends - which is
// what makes a run of them repeatable to the digit. See Core/Cycle.swift.

/// What one state holds on the image: numbers, one lane each, or text. This
/// library's own.
public enum StateCarried: Equatable, Sendable {
    /// Plain numbers, in a stated order - what almost everything is.
    case lanes([Double])

    /// Text, which has no lanes: it is dirty or it is not.
    case text(String)
}

/// A value that can ride a state - how it lies on the image, and back. This
/// library's own.
///
/// The image carries numbers and bytes, so whatever a state holds says how it is
/// one: a `Double` is a lane, a `Rect` is four of them in the order it names
/// its own fields, a `String` is its own bytes. A type of the application's
/// own joins by saying the same.
public protocol StateValue: Equatable, Sendable {
    /// The value, as the image holds it.
    var carried: StateCarried { get }

    /// The value that image stands for, or nil where it stands for none - a
    /// lane count that does not match, or text where numbers were expected.
    init?(carried: StateCarried)

    /// How many lanes one value takes; nought for text, and
    /// `StateValueLanes.own` for a value as wide as whatever is on the state.
    static var lanes: Int { get }

    /// Which of a view's values this one IS, where the property alone cannot
    /// say. MAUI has no equivalent: it is what `.motion(_:_:)` names.
    ///
    /// A colour is the case, and it is known from the value and from nothing
    /// else - which is what keeps a colour property added later in the right
    /// group the day it arrives, with no table to remember. Everything else
    /// answers nothing and takes the property's own group.
    static var moving: MotionValues { get }
}

extension StateValue {
    /// Nothing: the property this value drives says which group it is in.
    public static var moving: MotionValues { [] }
}

/// The lane counts that are not a count. This library's own.
enum StateValueLanes {
    /// A value whose width is ITS OWN - as many lanes as the image holds.
    ///
    /// A run of placements is one: how wide it is, is how many views it
    /// places, which nothing about the type can say. Everything that reads a
    /// value by its lane count asks the bytes instead.
    static let own = -1
}

extension Double: StateValue {
    /// One lane, which is the number itself.
    public var carried: StateCarried { .lanes([self]) }

    /// And back, unchanged.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = lanes[0]
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Int: StateValue {
    /// A whole number takes one lane, as itself.
    public var carried: StateCarried { .lanes([Double(self)]) }

    /// The nearest whole number to what the lane holds.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = Int(lanes[0].rounded())
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Bool: StateValue {
    /// Nought or one.
    public var carried: StateCarried { .lanes([self ? 1 : 0]) }

    /// Anything but nought is true.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = lanes[0] != 0
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Point: StateValue {
    /// Across, then down.
    public var carried: StateCarried { .lanes([x, y]) }

    /// A point from those two lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 2 else { return nil }

        self.init(x: lanes[0], y: lanes[1])
    }

    /// Two.
    public static var lanes: Int { 2 }
}

extension Rect: StateValue {
    /// Left, top, width, height - the order the type names its own fields in.
    public var carried: StateCarried { .lanes([x, y, width, height]) }

    /// A rectangle from those four lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Thickness: StateValue {
    /// Left, top, right, bottom.
    public var carried: StateCarried { .lanes([left, top, right, bottom]) }

    /// A thickness from those four lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Color: StateValue {
    /// Red, green, blue and alpha, each from nought to one - which is what a
    /// colour half way between two others is made of.
    ///
    /// A colour written with a DARK half is resolved by the tree, never here:
    /// what rides a state is one colour, the one on the screen, so this is the
    /// light half of a pair.
    public var carried: StateCarried {
        .lanes([
            Double(light.red) / 255,
            Double(light.green) / 255,
            Double(light.blue) / 255,
            Double(light.alpha) / 255,
        ])
    }

    /// A colour from those four lanes, each held to the range a channel has
    /// and rounded to the eight bits a channel is kept in.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        func channel(_ value: Double) -> UInt8 {
            UInt8(min(max((value * 255).rounded(), 0), 255))
        }

        self.init(
            red: channel(lanes[0]),
            green: channel(lanes[1]),
            blue: channel(lanes[2]),
            alpha: channel(lanes[3]))
    }

    /// Four.
    public static var lanes: Int { 4 }

    /// A colour, which is what only the value can say.
    public static var moving: MotionValues { .colour }
}

extension String: StateValue {
    /// Its own bytes.
    public var carried: StateCarried { .text(self) }

    /// The text, where that is what the image held.
    public init?(carried: StateCarried) {
        guard case .text(let text) = carried else { return nil }

        self = text
    }

    /// None: text is dirty or it is not.
    public static var lanes: Int { 0 }
}

/// A value a JOURNEY can be made of - one the host can WALK, lane by lane, from
/// where it is to where it is going. This library's own.
///
/// It is what an `AnimatedValue` is made of, so a value with no half-way in it -
/// text, a whole number, a truth value - is refused where the journey is
/// DECLARED rather than standing still at run time.
///
/// Text is the `StateValue` that is not one: letters have no half way, so
/// `String.lanes` is nought and there is nothing to walk. A whole number and a
/// truth value are out for the same reason read the other way - a journey
/// through a rounded whole is a stutter, and a truth has two places and no
/// distance between them. A `PlacedRun` is out because its width is its own
/// and it already carries a law for the whole run: a second journey over that
/// would be two laws for one picture.
public protocol Walked: StateValue {}

/// A value with a JOURNEY in it: where it is, where it is going, how fast, and
/// the law that closes the gap. This library's own.
///
/// `AnimatedValue` is the one. Two things stand on it: a declaration that
/// cannot carry a journey says so at the line that wrote it - `@State` being
/// the case, the tree having no frames to walk a value on - and a binding to
/// one offers the four lanes by name, which is what `$rotation.setPoint` is.
///
/// A PROTOCOL WITH REQUIREMENTS rather than a bare mark, because those four
/// have to be PROPERTIES: `Binding` resolves an unknown member through
/// `@dynamicMemberLookup`, which answers a `Binding` of the part and never
/// FAILS, so `$rotation.value = 4` would quietly be an assignment to the wrong
/// kind of thing. A real member shadows the subscript and the four read as
/// values.
public protocol Journeying {
    /// What kind of value is making the journey.
    associatedtype Moved: Walked

    /// Where the value IS - what is on the screen.
    var value: Moved { get set }

    /// Where it is GOING.
    var setPoint: Moved { get set }

    /// How fast it is going, per SECOND, lane by lane.
    var velocity: Moved { get set }

    /// The law that closes the gap.
    var motion: Motion { get set }
}

extension AnimatedValue: Journeying {
    /// The value this journey is made of.
    public typealias Moved = Value
}

extension Double: Walked {}
extension Point: Walked {}
extension Rect: Walked {}
extension Thickness: Walked {}
extension Color: Walked {}

/// How a value lies on the image, in bytes.
///
/// Little-endian bit patterns, eight bytes a lane, and text as its own length
/// and then its own UTF-8 - written by hand for the reason `Core/Wire.swift`
/// writes the wire by hand: this library imports no Foundation, and a number's
/// bytes are its own business either way.
enum StateImage {
    /// The bytes a value lies as.
    static func bytes(of carried: StateCarried) -> [UInt8] {
        switch carried {
        case .lanes(let lanes):
            var bytes: [UInt8] = []
            bytes.reserveCapacity(lanes.count * 8)

            for lane in lanes {
                let pattern = lane.bitPattern

                for shift in stride(from: 0, to: 64, by: 8) {
                    bytes.append(UInt8(truncatingIfNeeded: pattern >> UInt64(shift)))
                }
            }

            return bytes

        case .text(let text):
            let utf8 = Array(text.utf8)
            var bytes: [UInt8] = []
            bytes.reserveCapacity(utf8.count + 4)

            for shift in stride(from: 0, to: 32, by: 8) {
                bytes.append(UInt8(truncatingIfNeeded: UInt32(utf8.count) >> UInt32(shift)))
            }

            return bytes + utf8
        }
    }

    /// One lane of an image, by its index. Nought where the bytes stop short.
    static func lane(_ index: Int, of bytes: [UInt8]) -> Double {
        var pattern: UInt64 = 0

        for byte in 0..<8 where index * 8 + byte < bytes.count {
            pattern |= UInt64(bytes[index * 8 + byte]) << UInt64(byte * 8)
        }

        return Double(bitPattern: pattern)
    }

    /// Lays numbers over the lanes starting at `index`, leaving the rest as
    /// they were.
    static func lay(_ lanes: [Double], at index: Int, into bytes: inout [UInt8]) {
        let written = StateImage.bytes(of: .lanes(lanes))

        for byte in 0..<written.count where index * 8 + byte < bytes.count {
            bytes[index * 8 + byte] = written[byte]
        }
    }

    /// What those bytes stand for, read as `count` lanes or, where that is
    /// nought, as text.
    static func carried(of bytes: [UInt8], lanes count: Int) -> StateCarried {
        // ITS OWN WIDTH: as many lanes as there are eight-byte numbers.
        let count = count < 0 ? bytes.count / 8 : count

        guard count > 0 else {
            guard bytes.count >= 4 else { return .text("") }

            var length = 0

            for shift in stride(from: 0, to: 32, by: 8) {
                length |= Int(bytes[shift / 8]) << shift
            }

            let end = min(4 + length, bytes.count)

            return .text(String(decoding: bytes[4..<end], as: UTF8.self))
        }

        var lanes: [Double] = []
        lanes.reserveCapacity(count)

        for lane in 0..<count {
            var pattern: UInt64 = 0

            for byte in 0..<8 where lane * 8 + byte < bytes.count {
                pattern |= UInt64(bytes[lane * 8 + byte]) << UInt64(byte * 8)
            }

            lanes.append(Double(bitPattern: pattern))
        }

        return .lanes(lanes)
    }
}

/// Which way a state crosses at an attachment. This library's own.
///
/// Only where BOTH directions mean something: a placement is written and never
/// read, a frame is read and never written, and neither takes one.
public enum StateMode: Int32, Sendable {
    /// The host writes it; nothing this side writes reaches the control.
    case `in` = 0

    /// This side writes it; the host reads nothing back.
    case out = 1

    /// Both, which is what almost everything settable and readable is.
    case inOut = 2
}

/// What a registration is about - which of the host's own doors the value goes
/// through. This library's own. Declaration order is the number on the wire.
public enum StateKind: Int32, Sendable {
    /// An animated value driving one property of one control.
    case property = 0

    /// A run of placements driving a layout's children.
    case placement = 1

    /// Text going into a text property.
    case text = 2

    /// The host writes and this side reads: a scroller's offset, a drag, a
    /// frame the layout settled on.
    case feed = 3
}

/// One property of one element, driven to a state.
///
/// What the registration field carries: which number, which way it crosses, and
/// which of the host's doors the value goes through. The number rather than its
/// NUMBER, because a number is issued the first time anything asks and the
/// tree is written before the differ has seen it.
struct StateRegistration {
    /// Where the value lives - the image a number is issued against.
    let state: HostStorage

    /// Which way it crosses.
    let mode: StateMode

    /// Which door the value goes through.
    let kind: StateKind

    /// Which of the view's values this one is - the property's own group with
    /// whatever the VALUE adds to it, which is a colour and nothing else.
    ///
    /// What `.inherited` is resolved against: an element told
    /// `.motion(.spring(), .colour)` moves a driven colour on the spring, the
    /// same answer the tree-described colour beside it gets.
    let values: MotionValues
}

/// One registration as the WIRE carries it: the state by its number.
///
/// The number rather than the state, because this is what a render is compared
/// against - two renders naming the same state, mode and door said the same
/// thing, and nothing crosses.
struct StateEntry: Equatable {
    /// The number, by the number the host quotes it back by.
    let number: Int32

    /// Which way it crosses.
    let mode: StateMode

    /// Which of the host's doors the value goes through.
    let kind: StateKind
}

/// A value with a destination, a speed and a law - one property as the engine
/// sees it. This library's own.
///
///     @Bus private var fade = AnimatedValue(1.0)
///
///     Border { … }.opacity($fade)
///
///     fade.setPoint = 0.2    // travels there under `motion`
///     fade.value = 0.5       // snaps; any travel ends
///     fade.velocity = -3     // a kick: bends a travel, nudges a still value
///
/// WRITE `setPoint` ONCE PER DESTINATION and let the host carry the value
/// there; write `value` where the value is one somebody is MOVING - a finger,
/// a frame of arithmetic of your own - because a value written every frame has
/// no journey to make.
public struct AnimatedValue<Value: Walked>: StateValue {
    /// Where the value IS.
    ///
    /// The host writes it on every frame it moves, and mirrors into it
    /// whatever else aimed the property - a state change beside the value, a
    /// visual state - so `value == setPoint` always means "arrived".
    public var value: Value

    /// Where it is GOING. Written by you to send it somewhere; read back to
    /// find out where whatever aimed it last was sending it.
    public var setPoint: Value

    /// How fast it is going, per SECOND, lane by lane.
    ///
    /// Written by the host as the value moves and by a feed at the moment a
    /// finger lets go; written by YOU it is a kick - it bends a travel that is
    /// under way, and takes a still value out and back.
    public var velocity: Value

    /// The law a travel runs under. `.inherited` is the element's own, which
    /// this side resolves at the write.
    public var motion: Motion

    /// The negative id a waiter is registered under, or nought for nobody.
    ///
    /// Not the author's: `animateTo` puts it there and the host hands it back
    /// when the value arrives. See `Binding.animateTo(_:_:)`.
    var completion: Double = 0

    /// How many times a travel on this value has been STOPPED.
    ///
    /// A counter rather than a flag, so two stops in a row are two stops: the
    /// host acts on the lane having MOVED, which is what every other lane here
    /// means too.
    var stopped: Double = 0

    /// A value standing still where it says.
    ///
    /// - Parameters:
    ///   - value: where it starts, which is also where it is going.
    ///   - motion: the law a travel runs under. The element's own unless said.
    public init(_ value: Value, motion: Motion = .inherited) {
        self.value = value
        self.setPoint = value
        self.velocity = AnimatedValue.still
        self.motion = motion
    }

    /// A value of this type at nought - what a speed is before anything has
    /// moved.
    private static var still: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0)))) ?? value0
    }

    /// The stand-in for a type that has no numbers at all, which is text: a
    /// speed means nothing there, and nothing reads this.
    private static var value0: Value {
        Value(carried: .text(""))!
    }

    /// Every lane of it: where it is, where it is going, how fast, the law,
    /// the waiter and the stops.
    public var carried: StateCarried {
        .lanes(
            AnimatedValue.numbers(of: value)
                + AnimatedValue.numbers(of: setPoint)
                + AnimatedValue.numbers(of: velocity)
                + StateLaw.lanes(of: motion)
                + [completion, stopped])
    }

    /// And back, where the lane count is the one this type takes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == AnimatedValue.lanes else {
            return nil
        }

        let width = Value.lanes

        guard let value = Value(carried: .lanes(Array(lanes[0..<width]))),
              let setPoint = Value(carried: .lanes(Array(lanes[width..<(width * 2)]))),
              let velocity = Value(carried: .lanes(Array(lanes[(width * 2)..<(width * 3)])))
        else { return nil }

        self.value = value
        self.setPoint = setPoint
        self.velocity = velocity
        self.motion = StateLaw.motion(of: Array(lanes[(width * 3)..<(width * 3 + StateLaw.lanes)]))
        self.completion = lanes[width * 3 + StateLaw.lanes]
        self.stopped = lanes[width * 3 + StateLaw.lanes + 1]
    }

    /// Three of the value's own lanes, the law's, and one each for the waiter
    /// and the stops.
    public static var lanes: Int { Value.lanes * 3 + StateLaw.lanes + 2 }

    /// Whatever the value it carries is in - an animated colour is a colour.
    public static var moving: MotionValues { Value.moving }

    /// The plain numbers a value lies as, which for anything animated is what
    /// it lies as at all - a speed and a destination are numbers or they are
    /// nothing.
    private static func numbers(of value: Value) -> [Double] {
        guard case .lanes(let lanes) = value.carried else {
            return Array(repeating: 0, count: Value.lanes)
        }

        return lanes
    }

    /// Which lanes of an animated value one part sits in - what a write that
    /// must be SEEN as a change forces dirty, whatever the bytes say.
    static func mask(of part: AnimatedPart) -> UInt64 {
        let width = Value.lanes
        let range: Range<Int>

        switch part {
        case .value: range = 0..<width
        case .setPoint: range = width..<(width * 2)
        case .velocity: range = (width * 2)..<(width * 3)
        case .motion: range = (width * 3)..<(width * 3 + StateLaw.lanes)
        case .completion: range = (width * 3 + StateLaw.lanes)..<(width * 3 + StateLaw.lanes + 1)
        case .stopped: range = (width * 3 + StateLaw.lanes + 1)..<(width * 3 + StateLaw.lanes + 2)
        }

        return range.reduce(into: UInt64(0)) { $0 |= HostStorage.bit(of: $1) }
    }
}

/// Which part of an animated value a write is about.
enum AnimatedPart {
    case value
    case setPoint
    case velocity
    case motion
    case completion
    case stopped
}

/// How a law lies on the image.
///
/// THREE LANES, and the first says which of the four things a motion can be
/// this is - so `.none` and `.inherited` cross as themselves rather than as an
/// eased motion of no length, which is what they are made of on this side.
enum StateLaw {
    /// How many lanes a law takes.
    static let lanes = 3

    /// What the first lane says where the law is the ELEMENT's own.
    ///
    /// It crosses as itself and is resolved on the way out - see
    /// `HostStorage.crossing()` - so the image goes on saying what the author
    /// wrote.
    static let inherited: Double = 1

    /// Where a law lies in a value that goes through this door, or nil where
    /// the value carries none.
    ///
    /// An animated value is where it is, where it is going and how fast -
    /// three runs of the value's own width - and then the law, the waiter and
    /// the stops, so the law starts FIVE lanes from the end whatever the
    /// value's width is. A run of placements carries its law last. Text and a
    /// feed carry none at all.
    ///
    /// - Parameters:
    ///   - door: which of the host's doors the value goes through.
    ///   - lanes: how many lanes the value on the image has.
    /// - Returns: the first of the law's three lanes.
    static func within(_ door: StateKind, lanes: Int) -> Int? {
        switch door {
        case .property: return lanes >= 8 ? lanes - 5 : nil
        case .placement: return lanes >= StateLaw.lanes ? lanes - StateLaw.lanes : nil
        case .text, .feed: return nil
        }
    }

    /// A law as its lanes.
    static func lanes(of motion: Motion) -> [Double] {
        if motion.isInherited { return [StateLaw.inherited, 0, 0] }
        if motion.millis == 0 && motion.law == .eased { return [0, 0, 0] }

        return motion.law == .spring
            ? [3, Double(motion.millis), motion.factor]
            : [2, Double(motion.millis), Double(motion.curve.rawValue)]
    }

    /// And back.
    static func motion(of lanes: [Double]) -> Motion {
        switch lanes.first ?? 0 {
        case 1: return .inherited
        case 2: return .eased(UInt(max(lanes[1], 0)), Easing(rawValue: Int32(lanes[2])) ?? .cubicOut)
        case 3: return .spring(response: UInt(max(lanes[1], 0)), damping: lanes[2])
        default: return Motion.none
        }
    }
}

/// What a state's value IS, across every render - held as the bytes both sides
/// read.
///
/// A class for the same reason a `@State`'s storage is one: the wrapper is
/// rebuilt with its view on every render and adopts its predecessor's storage,
/// so this is the one object that means "this value" over time - and the one
/// the number is issued against.
///
/// THREE COPIES, and each answers a different question. `image` is what the
/// cycle running now is working on; `published` is the last COMPLETED cycle's,
/// which is what a handler or another board reads, so nothing outside ever
/// sees a half-finished picture; `pending` is a write made while no cycle was
/// running, waiting for the next one to latch it.
public final class HostStorage: @unchecked Sendable, NamedState {
    /// What the cycle running now is working on.
    var image: [UInt8]

    /// The last completed cycle's, which is what everything outside reads.
    var published: [UInt8]

    /// A write made outside a cycle, waiting to be latched.
    var pending: [UInt8]?

    /// Which of that write's lanes actually changed.
    var pendingMask: UInt64 = 0

    /// Which lanes have been written since whoever reads them last looked -
    /// bit n is lane n, and bit 63 means "and every lane past it", which is
    /// what a value of more than sixty-four lanes says.
    var dirty: UInt64 = 0

    /// How many times the value has been written.
    ///
    /// What "did anything I follow move?" is answered by, so it counts a write
    /// that put the same number back as well: an engine that follows a number a
    /// finger is holding still has been told about every report.
    var stamp: Int = 0

    /// The number the host quotes it back by, once anything has asked.
    var number: Int32?

    /// Which board's cycle owns it - one today, and the seam for a second.
    var board: Int = 0

    /// What the author calls it - the reflection walk's, as a state's is.
    nonisolated(unsafe) var origin: String?

    /// Which of the host's doors the value goes through, written at
    /// registration - and what says where its law lies.
    var door: StateKind?

    /// THE ELEMENT'S OWN LAW, which is what `.inherited` means.
    ///
    /// Written by the differ at registration, from the element's
    /// `.motion(_:_:)` resolved against the application's for the group the
    /// driven property is in. It has to be resolved on THIS side: what the
    /// host knows is what the application said, where an element's plan is a
    /// per-group answer only the tree can read - so a value written
    /// `.inherited` on an element that had said `.motion(.spring())` would
    /// otherwise travel the application's way.
    var inherited: Motion = .inherited

    /// Which element resolved that law, so a SECOND one resolving a different
    /// law on the same value is heard about rather than silently overwriting
    /// it.
    var inheritedBy: ElementId?

    init(_ bytes: [UInt8]) {
        image = bytes
        published = bytes
    }

    /// The published bytes as the HOST must read them: an `.inherited` law
    /// resolved into the element's own.
    ///
    /// The image itself goes on saying what the author wrote, because
    /// `.inherited` is a REQUEST and not a reading, and it is answered afresh
    /// on every crossing. That is what makes the answer keep up: a value is
    /// declared beside its view, which is BEFORE any element has driven it, so
    /// resolving once at the write would freeze whatever the application said
    /// at the moment of declaration onto a value the element goes on to claim.
    func crossing() -> [UInt8] {
        guard let door = door,
              let at = StateLaw.within(door, lanes: published.count / 8),
              StateImage.lane(at, of: published) == StateLaw.inherited
        else { return published }

        var bytes = published

        StateImage.lay(StateLaw.lanes(of: inherited), at: at, into: &bytes)

        return bytes
    }

    /// Lays a value into a slot lane by lane, answering which lanes changed.
    ///
    /// COMPARED BIT FOR BIT rather than by number: a number carries what a
    /// platform reported and what arithmetic worked out, where `-0.0` is not
    /// `0.0` and a NaN is itself. Both are answers a comparison by value gets
    /// wrong, and this is the comparison that decides whether anything
    /// crosses.
    static func lay(_ bytes: [UInt8], into slot: inout [UInt8]) -> UInt64 {
        if slot.count != bytes.count {
            slot = bytes
            return ~0
        }

        var moved: UInt64 = 0

        for lane in stride(from: 0, to: bytes.count, by: 8) {
            var same = true

            for byte in lane..<min(lane + 8, bytes.count) where slot[byte] != bytes[byte] {
                same = false
                slot[byte] = bytes[byte]
            }

            if !same {
                moved |= bit(of: lane / 8)
            }
        }

        return moved
    }

    /// Lays only the NAMED lanes of a value into a slot, answering which of
    /// them changed.
    ///
    /// What a report is: the host says where a value has got to and how fast
    /// it is going, and nothing at all about the law beside them - which this
    /// side may have written in the same breath.
    static func lay(_ bytes: [UInt8], into slot: inout [UInt8], only mask: UInt64) -> UInt64 {
        guard slot.count == bytes.count else {
            slot = bytes
            return mask
        }

        var moved: UInt64 = 0

        for lane in 0..<((bytes.count + 7) / 8) where mask & bit(of: lane) != 0 {
            var same = true

            for byte in (lane * 8)..<min(lane * 8 + 8, bytes.count) where slot[byte] != bytes[byte] {
                same = false
                slot[byte] = bytes[byte]
            }

            if !same {
                moved |= bit(of: lane)
            }
        }

        return moved
    }

    /// The dirty bit one lane sets: its own, or the last one where a value has
    /// more lanes than a word has bits.
    static func bit(of lane: Int) -> UInt64 { 1 << UInt64(min(lane, 63)) }
}

// ON THE BINDING, which is what `$fade` is: a handler written in a content
// getter must not capture `self`, so what it copies is the binding - the
// measured shape every composed view here uses, and the one place these are
// called from that a `State` cannot reach.
extension Binding where Value: Journeying {
    /// Where the value IS - what the screen is showing. Written, it SNAPS:
    /// whatever was carrying the property lets go and the value is simply
    /// there.
    ///
    ///     $rotation.value = 10        // on screen at once
    ///
    /// The plain name is the other one - `rotation = 10` says where it is
    /// GOING - and that is the spelling almost everything wants. This is the
    /// deliberate escape, and it is the same sentence a reading written back
    /// per report says.
    public var value: Value.Moved {
        get { wrappedValue.value }

        nonmutating set {
            var journey = wrappedValue

            journey.value = newValue

            wrappedValue = journey
        }
    }

    /// Where the value is GOING. The same thing the plain name reads and
    /// writes, said on a binding somebody was handed.
    public var setPoint: Value.Moved {
        get { wrappedValue.setPoint }

        nonmutating set {
            var journey = wrappedValue

            journey.setPoint = newValue

            wrappedValue = journey
        }
    }

    /// How fast it is going, per SECOND, lane by lane.
    ///
    /// Written, it is a KICK: it bends a travel already under way, and takes a
    /// value that was standing still out and lets the law bring it back.
    public var velocity: Value.Moved {
        get { wrappedValue.velocity }

        nonmutating set {
            var journey = wrappedValue

            journey.velocity = newValue

            wrappedValue = journey
        }
    }

    /// Puts the value THERE, with no journey at all: on the screen at once,
    /// going nowhere, and standing still.
    ///
    ///     $box.snap(to: measured)
    ///
    /// The one write that says all three - where it IS, where it is GOING, and
    /// that it is not moving. Writing `$box.value` alone moves only what is on
    /// the screen, so a set point left behind sends the host straight back;
    /// assigning the plain name is the opposite corner, a journey to somewhere
    /// new.
    ///
    /// **WHAT IT IS FOR: A VALUE THAT WAS WORKED OUT RATHER THAN CHOSEN.** A
    /// size taken from a measurement, a place read off a report, a reading
    /// written per frame - none of them is a destination, and carried as one
    /// they crawl after the thing that decided them.
    ///
    /// - Parameter value: where it now is, and stays.
    public func snap(to value: Value.Moved) {
        var journey = wrappedValue

        journey.value = value
        journey.setPoint = value

        if let still = Value.Moved(
            carried: .lanes(Array(repeating: 0, count: max(Value.Moved.lanes, 0)))) {
            journey.velocity = still
        }

        wrappedValue = journey
    }

    /// The law this value travels under, whoever is showing it.
    ///
    ///     $rotation.motion = .spring()
    ///
    /// ON THE VALUE rather than on the view, which is the difference between
    /// this and `.motion(_:)`: that one says how everything a given element
    /// does travels, and this says how THIS VALUE travels wherever it is shown.
    /// `.inherited`, the default, is a request rather than a reading - the
    /// element answers it afresh at every crossing.
    public var motion: Motion {
        get { wrappedValue.motion }

        nonmutating set {
            var journey = wrappedValue

            journey.motion = newValue

            wrappedValue = journey
        }
    }
}

extension Binding where Value: StateValue {
    /// Sends the value there under `motion`, and suspends until it ARRIVES.
    ///
    ///     try await $fade.animateTo(0.1, .eased(400, .cubicOut))
    ///
    /// TRUE means it got there. FALSE means something else ended the journey:
    /// a newer setpoint, a value written over it, a `stop()`, or the view
    /// leaving the tree. Where there is nothing to move - the value is already
    /// there, the reader asked for less movement, or no view on screen wears
    /// this state - it answers TRUE at once, the model being where it was going.
    ///
    /// **WRITTEN THE SAME WAY ON EITHER KIND OF STATE.** `$fade.animateTo(…)`
    /// is what an author writes over `@State private var fade = 1.0` and over
    /// `@Bus private var fade = AnimatedValue(1.0)` alike; which one it
    /// is decides which road the value takes, and nothing at the call site
    /// changes. An `AnimatedValue` held in a plain `@State` is the one pairing
    /// that cannot work - nothing carries the journey - and it is REFUSED OUT
    /// LOUD rather than answered with a true that nothing happened under.
    ///
    /// The write lands before the first suspension, so two of these started
    /// with `async let` from one handler are booked in the order they are
    /// written.
    ///
    /// - Parameters:
    ///   - target: where to send it.
    ///   - motion: the law to travel under. The element's own unless said.
    /// - Returns: whether it ran to the end.
    /// - Throws: whatever the host answers when it cannot carry the value at
    ///   all.
    @discardableResult
    public nonisolated(nonsending) func animateTo<Inner: StateValue>(
        _ target: Inner,
        _ motion: Motion = .inherited
    ) async throws -> Bool where Value == AnimatedValue<Inner> {
        guard let image = driving else {
            throw StateUIError(message: """
                This state holds an AnimatedValue and the TREE describes it, \
                so there is nothing to carry the journey. Declare it \
                `@Bus` and the host walks the value there.
                """)
        }

        let answer = try await Renderer.shared.answered { completion in
            let waiter = Renderer.shared.book(completion)
            var travelling = self.wrappedValue

            travelling.setPoint = target
            travelling.motion = motion
            travelling.completion = Double(waiter)

            // THE WAITER FORCES THE SETPOINT: sending a value where it is
            // already going is a fresh journey with somebody fresh waiting on
            // it, and lanes that did not move would cross as nothing at all.
            Renderer.shared.board(of: image).write(
                StateImage.bytes(of: travelling.carried),
                to: image,
                forcing: Value.mask(of: .setPoint) | Value.mask(of: .completion))
        }

        return answer.first?.bool ?? true
    }

    /// Stops a travel where it stands. Whoever is waiting on it hears that it
    /// did not run to the end.
    ///
    /// The value is left where it had got to and is on the image from the next
    /// cycle. A value that was not moving is unaffected.
    ///
    /// A state the TREE describes carries no journey to stop, and says so
    /// rather than doing nothing - the same answer `animateTo` gives, said the
    /// way a method that cannot throw has to.
    public func stop<Inner: StateValue>() where Value == AnimatedValue<Inner> {
        guard let image = driving else {
            complain("""
                stop() was given an AnimatedValue the tree describes, which \
                carries no journey to stop. Declare it `@Bus`.
                """)

            return
        }

        var standing = wrappedValue

        // The waiter's number is LEFT on the image: it is the host that ends
        // the travel, and it needs the number to answer.
        standing.stopped += 1

        Renderer.shared.board(of: image).write(
            StateImage.bytes(of: standing.carried),
            to: image,
            forcing: Value.mask(of: .stopped))
    }
}
