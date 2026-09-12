// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// WHAT A VALUE MUST BE TO CROSS TO THE HOST, AND WHERE IT LIVES ONCE IT HAS -
// both of them outside the path that describes the interface.
//
// A scroller's offset changes with every touch report. Read in a body, each
// report is a write that renders that body - which for a run of cards placed
// by arithmetic is the whole example, forty times per movement of a finger.
//
// So a state HANDED ON - `$x` to a driven modifier, a feed or a two-way
// control - reads nothing at build and carries no tree at all:
//
//   the STATE   `@State`, the one declaration (Core/State.swift), carried by
//               the host because of where it is used. A value both sides
//               hold, in one IMAGE of plain bytes, moved by the host on the
//               display's own frames and by arithmetic that runs inside them.
//               A move renders only a body that read the state.
//
//               THIS FILE IS THE LAYER UNDER IT: what a value must be to cross
//               (`StateValue`), what it turns into (`StateCarried`), which way
//               and through which door (`StateMode`, `StateKind`), the shape
//               a value the host walks lies in (`JourneyLanes`), the journey
//               an author reaches over any such state (`Journey`), and
//               `HostStorage`, which is where one lives.
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
    /// One colour: a PAIR crosses as the half in force, the theme read without
    /// recording - laying a value is no reason to build anything. The state
    /// holding it keeps the pair, and the element handing that state on is
    /// what reads the theme, so a theme change lays the other half
    /// (`State.Storage.wearThemedPair()`).
    public var carried: StateCarried {
        let half = dark.flatMap { StandardEnvironment.app.$requestedTheme.standing == .dark ? $0 : nil } ?? light

        return .lanes([
            Double(half.red) / 255,
            Double(half.green) / 255,
            Double(half.blue) / 255,
            Double(half.alpha) / 255,
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
/// It is what has a JOURNEY: `$x.journey` exists on a binding to one,
/// `@State(motion:)` is declared over one, and a driven property WALKS one -
/// any other `StateValue` it sets as it stands -
/// so a value with no half-way in it - text, a whole number, a truth value -
/// is refused at the line that asks for the journey rather than standing still
/// at run time.
///
/// Text is the `StateValue` that is not one: letters have no half way, so
/// `String.lanes` is nought and there is nothing to walk. A whole number and a
/// truth value are out for the same reason read the other way - a journey
/// through a rounded whole is a stutter, and a truth has two places and no
/// distance between them. A `PlacedRun` is out because its width is its own
/// and it already carries a law for the whole run: a second journey over that
/// would be two laws for one picture.
public protocol Walked: StateValue {}

/// A CHOICE the host can be handed as a channel: an alignment, a keyboard, a
/// line break, a set of flags. This library's own.
///
///     @State private var side = LayoutOptions.start
///
///     Label("Where am I?").horizontalOptions($side)
///
///     side = .center                  // the host moves it; nothing is rebuilt
///
/// One lane, holding the MEMBER'S NUMBER - this library's own numbering, the
/// same one the tree describes a member with - and the host resolves it back
/// into the platform's own member through the very table a described property
/// goes through. So every member the tree can say, a channel can say too.
///
/// Nothing here TRAVELS: a choice has no half-way, so the host sets it as it
/// stands. Conformance is one line per type, beside the type itself.
public protocol StateChoice: StateValue, RawRepresentable where RawValue == Int32 {}

extension StateChoice {
    /// The member's number, as its one lane.
    public var carried: StateCarried { .lanes([Double(rawValue)]) }

    /// And back - or nothing, where those bytes name no member of this type.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried,
              let first = lanes.first,
              let made = Self(rawValue: Int32(first.rounded()))
        else { return nil }

        self = made
    }

    /// One.
    public static var lanes: Int { 1 }

    /// A choice is in no group of values a motion can be about: it has no
    /// half-way to be caught at.
    public static var moving: MotionValues { [] }
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
/// Every registration carries one. A placement and a caption's text are
/// `.out`, a feed `.in`; a walked property, a field's text and a value a
/// control reports are `.inOut`.
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

    /// Words written into a text property - out onto a caption, and both
    /// ways on a field the reader types into, where the typed words land on
    /// the state whole.
    case text = 2

    /// The host writes and this side reads: the frame a layout settled on.
    case feed = 3

    /// A value the host SETS as it stands - a flag, a count, a number that
    /// never travels - on its own frames, with nothing walking it. Both ways
    /// where the control reports one: a switch flipped, a choice made.
    case plain = 4
}

/// One property of one element, driven to a state.
///
/// What the registration field carries: which number, which way it crosses, and
/// which of the host's doors the value goes through. The STATE rather than its
/// number, because a number is issued the first time anything asks and the
/// tree is written before the differ has seen it.
struct StateRegistration {
    /// Where the value lives - the image a number is issued against.
    let state: HostStorage

    /// The conversion the state is the derived side of, if it is one - what
    /// the differ arms engines for on the element wearing it.
    var conversion: Conversion? = nil

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
    /// The state, by the number the host quotes it back by.
    let number: Int32

    /// Which way it crosses.
    let mode: StateMode

    /// Which of the host's doors the value goes through.
    let kind: StateKind
}

/// How a value the host walks lies on the image: where it is, where it is
/// going, how fast, the law that closes the gap, and two lanes of
/// bookkeeping - the shape `$fade.journey` reads and writes, and the one the
/// host's `MotionChannel` is fed from.
///
/// ONE OF THESE IS ONE CHANNEL ON THE HOST, however many controls are handed
/// `$fade`: each holds a HANDLE on the one value, written from the same lanes
/// on the same frame, so two controls on one state can never stand in two
/// places, and a control handed the state while it travels joins it where it
/// is. The host calls its half a `MotionChannel`, that side counting channels
/// where this one describes the trip.
///
/// Internal on purpose: what an author reaches is the `Journey` over the
/// state, and what a converter is handed is that same journey. The lanes are
/// the wire's business.
struct JourneyLanes<Value: Walked>: StateValue {
    /// Where the value IS.
    ///
    /// The host writes it on every frame it moves, and mirrors into it
    /// whatever else aimed the property - a state change beside the value, a
    /// visual state - so `value == destination` always means "arrived".
    var value: Value

    /// Where it is GOING - the state's own value, as this side wrote it or as
    /// a report landed it.
    var destination: Value

    /// How fast it is going, per SECOND, lane by lane.
    ///
    /// Written by the host as the value moves - a finger's report puts it at
    /// nought - and by this side as a kick: it bends a travel that is under
    /// way, and takes a still value out and back.
    var velocity: Value

    /// The law a travel runs under. `.inherited` is the element's own, which
    /// this side resolves at the crossing - see `HostStorage.crossing()` - and
    /// `.custom` crosses as `.none` over the value an engine here wrote.
    var motion: Motion

    /// The negative id a waiter is registered under, or nought for nobody.
    ///
    /// `Journey.move(to:_:)` puts it there and the host hands it back when the
    /// value arrives.
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
    init(_ value: Value, motion: Motion = .inherited) {
        self.value = value
        self.destination = value
        self.velocity = JourneyLanes.still
        self.motion = motion
    }

    /// A value of this type at nought - what a speed is before anything has
    /// moved.
    static var still: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0)))) ?? value0
    }

    /// The stand-in for a type that has no numbers at all, which is text: a
    /// speed means nothing there, and nothing reads this.
    private static var value0: Value {
        Value(carried: .text(""))!
    }

    /// Every lane of it: where it is, where it is going, how fast, the law,
    /// the waiter and the stops.
    var carried: StateCarried {
        .lanes(
            JourneyLanes.numbers(of: value)
                + JourneyLanes.numbers(of: destination)
                + JourneyLanes.numbers(of: velocity)
                + StateLaw.lanes(of: motion)
                + [completion, stopped])
    }

    /// And back, where the lane count is the one this type takes.
    init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == JourneyLanes.lanes else {
            return nil
        }

        let width = Value.lanes

        guard let value = Value(carried: .lanes(Array(lanes[0..<width]))),
              let destination = Value(carried: .lanes(Array(lanes[width..<(width * 2)]))),
              let velocity = Value(carried: .lanes(Array(lanes[(width * 2)..<(width * 3)])))
        else { return nil }

        self.value = value
        self.destination = destination
        self.velocity = velocity
        self.motion = StateLaw.motion(of: Array(lanes[(width * 3)..<(width * 3 + StateLaw.lanes)]))
        self.completion = lanes[width * 3 + StateLaw.lanes]
        self.stopped = lanes[width * 3 + StateLaw.lanes + 1]
    }

    /// Three of the value's own lanes, the law's, and one each for the waiter
    /// and the stops.
    static var lanes: Int { Value.lanes * 3 + StateLaw.lanes + 2 }

    /// Whatever the value it carries is in - an animated colour is a colour.
    static var moving: MotionValues { Value.moving }

    /// The plain numbers a value lies as, which for anything animated is what
    /// it lies as at all - a speed and a destination are numbers or they are
    /// nothing.
    private static func numbers(of value: Value) -> [Double] {
        guard case .lanes(let lanes) = value.carried else {
            return Array(repeating: 0, count: Value.lanes)
        }

        return lanes
    }

    /// Which lanes of a walked value one part sits in - what a write that
    /// must be SEEN as a change forces dirty, whatever the bytes say.
    static func mask(of part: JourneyPart) -> UInt64 {
        let width = Value.lanes
        let range: Range<Int>

        switch part {
        case .value: range = 0..<width
        case .destination: range = width..<(width * 2)
        case .velocity: range = (width * 2)..<(width * 3)
        case .motion: range = (width * 3)..<(width * 3 + StateLaw.lanes)
        case .completion: range = (width * 3 + StateLaw.lanes)..<(width * 3 + StateLaw.lanes + 1)
        case .stopped: range = (width * 3 + StateLaw.lanes + 1)..<(width * 3 + StateLaw.lanes + 2)
        }

        return range.reduce(into: UInt64(0)) { $0 |= HostStorage.bit(of: $1) }
    }
}

/// Which part of a walked value a write is about.
enum JourneyPart {
    case value
    case destination
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

    /// What the first lane says where the walk is an ENGINE's on this side.
    ///
    /// Never seen by the host: the crossing sends `.none` over the value the
    /// engine wrote, so the host wears each frame as it comes and walks
    /// nothing - see `HostStorage.crossing()`.
    static let custom: Double = 4

    /// Where a law lies in a value that goes through this door, or nil where
    /// the value carries none.
    ///
    /// An animated value is where it is, where it is going and how fast -
    /// three runs of the value's own width - and then the law, the waiter and
    /// the stops, so the law starts FIVE lanes from the end whatever the
    /// value's width is. A run of placements carries its law last. Text, a
    /// feed and a plain value carry none at all.
    ///
    /// - Parameters:
    ///   - door: which of the host's doors the value goes through.
    ///   - lanes: how many lanes the value on the image has.
    /// - Returns: the first of the law's three lanes.
    static func within(_ door: StateKind, lanes: Int) -> Int? {
        switch door {
        case .property: return lanes >= 8 ? lanes - 5 : nil
        case .placement: return lanes >= StateLaw.lanes ? lanes - StateLaw.lanes : nil
        case .text, .feed, .plain: return nil
        }
    }

    /// A law as its lanes.
    static func lanes(of motion: Motion) -> [Double] {
        if motion.isInherited { return [StateLaw.inherited, 0, 0] }
        if motion.isCustom { return [StateLaw.custom, 0, 0] }
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
        case 4: return .custom
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
/// cycle running now is working on; `published` is the last COMPLETED cycle's
/// - what a read outside a cycle answers where no write is waiting - so
/// nothing outside ever sees a half-finished picture; `pending` is a write
/// made while no cycle was running, waiting for the next one to latch it.
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

    /// The readings `.samples(_:into:_:)` asked for of this value, by the
    /// identity of the state each one is read INTO - so a view describing
    /// itself again replaces its own reading rather than adding a second.
    ///
    /// On the HOST's storage rather than the state's, because a reading is
    /// about the host's writes and nothing else: see Core/Sampling.swift.
    ///
    /// **KNOWN WEAKLY, BECAUSE A READING BELONGS TO THE ELEMENT THAT ASKED FOR
    /// IT.** A reading reads this value and writes another, so it holds both -
    /// and this image is the state's own. Kept here strongly, the four make a
    /// ring: the state holds the image, the image the reading, the reading its
    /// closure, and the closure the state. No state of that view is ever freed,
    /// every visit to the page leaves another set behind, and the board walks
    /// all of them on every frame it runs. So the ELEMENT holds it
    /// (`RenderedNode.readings`) and this is a way to find it, which ends when
    /// the element does. `StateTests.testAReadingEndsWithTheViewThatAskedForIt`.
    var samplings: [ObjectIdentifier: WeakSampling] = [:]

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

    /// What runs after the HOST has written this value, handed which lanes it
    /// wrote - the state's own ask for a render, installed by
    /// `State.Storage.carry()` or `carryAsJourney()`. The state decides: nothing where no build ever
    /// read it, which is one load, and otherwise its readers. So a value the
    /// host moves sixty times a second costs a render only where a body prints
    /// it.
    nonisolated(unsafe) var told: ((UInt64) -> Void)?

    /// Whether any BUILD has ever read the JOURNEY off this image - where the
    /// value is, how fast - as against the state, whose own flag is
    /// `State.Storage.readAtBuild`. Set by `Journey`'s reads, never cleared,
    /// and what `askJourneyReaders()` consults: a frame of a walk asks the
    /// bodies that read the journey and nobody else.
    nonisolated(unsafe) var readAtBuild = false

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
              let at = StateLaw.within(door, lanes: published.count / 8)
        else { return published }

        switch StateImage.lane(at, of: published) {
        case StateLaw.inherited:
            var bytes = published

            StateImage.lay(StateLaw.lanes(of: inherited), at: at, into: &bytes)

            return bytes

        case StateLaw.custom where door == .property:
            // THE ENGINE'S VALUE IS THE HOST'S DESTINATION. Under `.custom`
            // the host walks nothing: it is handed `.none` and a destination
            // that is wherever this side's engine has written the value, so a
            // frame the engine wrote is worn as it comes and a destination
            // the author wrote - which the engine reads off the image, and
            // the host never sees - sends the host nowhere. What the host
            // reports back is where it was put, which is what it was told.
            let width = (published.count / 8 - StateLaw.lanes - 2) / 3
            var bytes = published

            StateImage.lay((0..<width).map { StateImage.lane($0, of: published) }, at: width, into: &bytes)
            StateImage.lay(StateLaw.lanes(of: Motion.none), at: at, into: &bytes)

            return bytes

        default:
            return published
        }
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
        // A REPORT SPEAKS ABOUT LANES AND NEVER ABOUT SHAPE. What shape a
        // value has is its declaration's, so what is laid here is the named
        // lanes both sides have and nothing else - a report longer or shorter
        // than the image leaves the rest of it standing. Replacing the image
        // instead would throw away every lane the report says nothing about -
        // a journey's law, its waiter and its stop counter - and every later
        // write would cross as a whole new value, which the host reads as a
        // snap.
        let reach = min(slot.count, bytes.count)
        var moved: UInt64 = 0

        for lane in 0..<((reach + 7) / 8) where mask & bit(of: lane) != 0 {
            var same = true

            for byte in (lane * 8)..<min(lane * 8 + 8, reach) where slot[byte] != bytes[byte] {
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

// MARK: - The journey

/// The journey a state is on: where the value IS, where it is GOING, how fast,
/// and under what law - reached through the state's binding, `$fade.journey`.
/// This library's own.
///
///     @State private var fade = 1.0
///
///     BoxView().opacity($fade)
///
///     fade = 0.2                                         // the destination: the host walks the box there
///     try await $fade.journey.move(to: 0.2, .eased(400, .cubicOut))   // the same, awaited
///     $fade.journey.value                                // where it has got to this frame
///     $fade.journey.velocity                             // and how fast
///     $fade.journey.stop()                               // leaves it where it is
///
/// **A STATE IS DISCRETE, AND ITS JOURNEY IS A PART OF IT.** The state's own
/// value - `fade` - is the DESTINATION, at once and from this side: reading
/// it answers where the value is going, writing it sends it there. The journey
/// is what happens between two destinations, and this is the road to it.
/// Every state over a value the host can walk (`Walked`) has one, and nothing
/// is declared for it.
///
/// **WHO WALKS IT is decided by where the state is used.** Handed to a driven
/// modifier, a two-way control or a scroller, the HOST walks the value and
/// writes `value` and `velocity` back every frame - for a body that reads
/// them (a build per frame), a reading (`.samples`), an engine, or a
/// conversion (`convert(_:)`). A state nobody wears has nobody to walk it:
/// there the value lands where it is sent, and a `move` answers at once.
/// Under `@State(motion: .custom)` an engine of your own is the walker, and
/// writes `value` and `velocity` here.
///
/// A value type over the state's binding, as `Binding` itself is: every write
/// through it reaches the one storage, so a handler holding a copy writes where
/// the body reads. A part of a state (`$room.width`) and a binding made from
/// closures have no storage the host could walk, so their journey stands at the
/// value and `move` says so.
public struct Journey<Value: Walked> {
    /// The state this is the journey of.
    private let state: Binding<Value>

    /// The storage behind the state - nothing for a part of one or a binding
    /// made from closures, which no host walks.
    var storage: State<Value>.Storage? { state.described }

    /// The journey of a state, reached as `$fade.journey`.
    init(of state: Binding<Value>) { self.state = state }

    /// The lanes as they stand, with the read RECORDED where a build is
    /// running - against the image the host walks the value on, which is a
    /// second reader set beside the state's own: a frame of the walk asks the
    /// bodies that read the journey and none that read the destination alone.
    /// See `State.Storage.askJourneyReaders()`. Nothing where the host walks
    /// the state in no shape a journey can be read off.
    private func lanes() -> JourneyLanes<Value>? {
        guard let (_, image, lanes) = walking() else { return nil }

        if Renderer.shared.stateRead(image) { image.readAtBuild = true }

        return lanes
    }

    /// The storage, the image the host walks it on - made now if nothing has
    /// yet - and the lanes as they stand, read WITHOUT recording. What every
    /// write starts from. Nothing for a part of a state, a closure binding,
    /// or a state the host carries as the value itself.
    private func walking() -> (State<Value>.Storage, HostStorage, JourneyLanes<Value>)? {
        guard let storage, let image = storage.walkedImage(), let lanes = storage.journeyLanes else {
            return nil
        }

        return (storage, image, lanes)
    }

    /// Where the value IS - what the screen is showing this frame.
    ///
    /// Read in a body it is a build PER FRAME for as long as the value moves,
    /// which is the honest cost of printing a moving number; `.samples` is
    /// the road where ten a second will do, and `convert(_:)` the one where
    /// the words can be worked out on the host's frames and cost no render.
    ///
    /// Written, it is a SNAP on a value the host walks - whatever was carrying
    /// it lets go, and the destination is left where it was, so a set point
    /// left behind sends the host straight back - and it is the engine's own
    /// frame under `.custom`. `snap(to:)` is the write that says all three.
    public var value: Value {
        get { lanes()?.value ?? state.wrappedValue }

        nonmutating set {
            guard let (storage, _, standing) = walking() else {
                state.wrappedValue = newValue
                return
            }

            var lanes = standing

            lanes.value = newValue
            storage.lay(lanes)
            storage.askJourneyReaders()
        }
    }

    /// Where it is GOING - the state's own value, read and written here so a
    /// journey says both of its ends. `fade` and `$fade.journey.destination`
    /// are one thing.
    public var destination: Value {
        get { state.wrappedValue }

        nonmutating set { state.wrappedValue = newValue }
    }

    /// How fast it is going, per SECOND, lane by lane - nought where nothing
    /// walks.
    ///
    /// Written, it is a KICK: it bends a travel already under way, and takes a
    /// value that was standing still out and lets the law bring it back. Under
    /// `.custom` it is the engine's own to keep between frames.
    public var velocity: Value {
        get { lanes()?.velocity ?? JourneyLanes<Value>.still }

        nonmutating set {
            guard let (storage, _, standing) = walking() else { return }

            var lanes = standing

            lanes.velocity = newValue
            storage.lay(lanes)
            storage.askJourneyReaders()
        }
    }

    /// The law this value travels under, wherever it is shown.
    ///
    ///     $rotation.journey.motion = .spring()
    ///
    /// ON THE VALUE rather than on the view, which is the difference between
    /// this and `.motion(_:)`: that one says how everything a given element
    /// does travels, and this says how THIS VALUE travels wherever it is shown.
    /// `.inherited`, the default, is a request rather than a reading - the
    /// element answers it afresh at every crossing. Said at the declaration it
    /// is `@State(motion:)`, and on the image from the first frame.
    ///
    /// `.custom` is not written here, and a value declared `.custom` is not
    /// given another law: WHO WALKS the value is decided where it is declared,
    /// because the host is told at the first crossing and cannot be told again.
    public var motion: Motion {
        get { lanes()?.motion ?? storage?.law ?? .inherited }

        nonmutating set {
            guard let storage else { return }

            guard let (_, _, standing) = walking() else {
                storage.law = newValue
                return
            }

            var lanes = standing

            guard !newValue.isCustom, !lanes.motion.isCustom else {
                complain("`\(storage.origin ?? "a state")` was given a law after it was declared "
                    + "that would change who walks it. `.custom` is said at the declaration - "
                    + "`@State(motion: .custom)` - and a value declared so keeps it.")
                return
            }

            lanes.motion = newValue
            storage.lay(lanes)
            storage.askJourneyReaders()
        }
    }

    /// Puts the value THERE, with no journey at all: on the screen at once,
    /// going nowhere, and standing still.
    ///
    ///     $box.journey.snap(to: measured)
    ///
    /// The one write that says all three - where it IS, where it is GOING, and
    /// that it is not moving. Writing `value` alone moves only what is on the
    /// screen, so a destination left behind sends the host straight back;
    /// assigning the state is the opposite corner, a journey to somewhere new.
    /// Synchronous, unlike `move(to:_:)` under `.none`: nothing is booked and
    /// nobody is awaited, which is what a value written per report wants.
    ///
    /// **WHAT IT IS FOR: A VALUE THAT WAS WORKED OUT RATHER THAN CHOSEN.** A
    /// size taken from a measurement, a place read off a report, a reading
    /// written per frame - none of them is a destination, and carried as one
    /// they crawl after the thing that decided them.
    ///
    /// - Parameter value: where it now is, and stays.
    public func snap(to value: Value) {
        state.land(value)
    }

    /// Sends the value there under `motion`, and suspends until it ARRIVES.
    ///
    ///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
    ///
    /// TRUE means it got there. FALSE means something else ended the journey:
    /// a newer destination, a value written over it, or a `stop()`. Where
    /// there is nothing to move - the value is already there, or the reader
    /// asked for less movement - it answers TRUE at once, the value being where
    /// it was going.
    ///
    /// **A STATE NOTHING WEARS LANDS AT ONCE.** A number is issued when an
    /// element registers the state, so a state without one has nobody to walk
    /// it, and a waiter booked on it would wait for good: the value lands at
    /// the target, the answer is that it arrived, and a view described later
    /// shows the target from its first frame. Under `.custom` the destination
    /// is written and the answer is TRUE at once too - the walk is the
    /// engine's, and the engine is the only one that knows when it is done.
    ///
    /// **THE LAW STAYS ON THE VALUE.** Given one, the value goes on travelling
    /// under it: a plain assignment after `move(to: 0, .eased(2000))` takes
    /// two seconds too. Given none, the value's own law stands - the element's,
    /// unless `@State(motion:)` or `motion` said otherwise.
    ///
    /// The write lands before the first suspension, so two of these started
    /// with `async let` from one handler are booked in the order they are
    /// written.
    ///
    /// - Parameters:
    ///   - target: where to send it.
    ///   - motion: the law to travel under, or nothing for the value's own.
    /// - Returns: whether it ran to the end.
    /// - Throws: whatever the host answers when it cannot carry the value at
    ///   all.
    @discardableResult
    public nonisolated(nonsending) func move(to target: Value, _ motion: Motion? = nil) async throws -> Bool {
        guard let (storage, image, lanes) = walking() else {
            complain("`move` was called on a part of a state, a binding made from closures, "
                + "or a state the host carries as the value itself, none of which it can "
                + "walk. Move the whole state, handed to something that walks it.")
            return false
        }

        // NOBODY TO WALK IT, or the walk is an engine's own: the destination
        // is written - through the state, so its readers and its save hear -
        // and the answer is at once.
        if image.number == nil || lanes.motion.isCustom {
            state.wrappedValue = target
            return true
        }

        let answer = try await Renderer.shared.answered { completion in
            let waiter = Renderer.shared.book(completion)
            var travelling = lanes

            travelling.destination = target
            travelling.completion = Double(waiter)

            if let motion { travelling.motion = motion }

            // THE WAITER FORCES THE DESTINATION: sending a value where it is
            // already going is a fresh journey with somebody fresh waiting on
            // it, and lanes that did not move would cross as nothing at all.
            Renderer.shared.board(of: image).write(
                StateImage.bytes(of: travelling.carried),
                to: image,
                forcing: JourneyLanes<Value>.mask(of: .destination) | JourneyLanes<Value>.mask(of: .completion))

            storage.noteDestination(target)
        }

        return answer.first?.bool ?? true
    }

    /// Stops a travel where it stands. Whoever is waiting on it hears that it
    /// did not run to the end.
    ///
    /// The value is left where it had got to and is on the image from the next
    /// cycle. A value that was not moving is unaffected.
    public func stop() {
        guard let (_, image, standing) = walking() else {
            complain("`stop` was called on a part of a state, a binding made from closures, "
                + "or a state the host carries as the value itself, none of which it walks.")
            return
        }

        var stopping = standing

        // The waiter's number is LEFT on the image: it is the host that ends
        // the travel, and it needs the number to answer.
        stopping.stopped += 1

        Renderer.shared.board(of: image).write(
            StateImage.bytes(of: stopping.carried),
            to: image,
            forcing: JourneyLanes<Value>.mask(of: .stopped))
    }
}

/// `Sendable` for the reason `Binding` is: what a handler on another executor
/// holds is the one storage's road, and the storage keeps its own lock.
extension Journey: Sendable {}
