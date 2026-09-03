// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A VALUE THE HOST MOVES MANY TIMES A SECOND, AND THE ARITHMETIC THAT FOLLOWS
// IT - both of them outside the path that describes the interface.
//
// A scroller's offset changes with every touch report. Held as `@State` it is
// correct and expensive: each report is a write, a write is a render, and a
// render describes every view that read the value - which for a run of cards
// placed by arithmetic is the whole example, forty times per movement of a
// finger. Measured on a phone: 3.5 ms describing, 2.2 ms applying and a whole
// platform relayout, per report, against a frame budget of 11.
//
// So there is a second path, and it carries no tree at all:
//
//   the BUS     a `@Bus`. A value both sides hold, in one IMAGE of plain
//               bytes, moved by the host on the display's own frames and by
//               arithmetic that runs inside them. Nothing here asks for a
//               render when it moves.
//   the ENGINE  the author's arithmetic, in Swift, run on every cycle in which
//               something it follows was written - where each child of a
//               layout goes, what a caption says, where a thrown object is.
//
// The host then writes what came back onto the controls it already has. No
// build, no diff, no message: what crosses is a batch of bytes each way, which
// is why a value nobody could afford to render on can be followed frame by
// frame.
//
// THE CYCLE IS A PURE FUNCTION of the image, the engines and the instant:
// every input is latched, the engines run in a stated order, and what they
// wrote is published in one go. See Core/Cycle.swift.

/// What one bus holds on the image: numbers, one lane each, or text. This
/// library's own.
public enum BusCarried: Equatable, Sendable {
    /// Plain numbers, in a stated order - what almost everything is.
    case lanes([Double])

    /// Text, which has no lanes: it is dirty or it is not.
    case text(String)
}

/// A value that can ride a bus - how it lies on the image, and back. This
/// library's own.
///
/// The image carries numbers and bytes, so whatever a bus holds says how it is
/// one: a `Double` is a lane, a `Rect` is four of them in the order it names
/// its own fields, a `String` is its own bytes. A type of the application's
/// own joins by saying the same.
public protocol BusValue: Equatable, Sendable {
    /// The value, as the image holds it.
    var carried: BusCarried { get }

    /// The value that image stands for, or nil where it stands for none - a
    /// lane count that does not match, or text where numbers were expected.
    init?(carried: BusCarried)

    /// How many lanes one value takes; nought for text, and
    /// `BusValueLanes.own` for a value as wide as whatever is on the bus.
    static var lanes: Int { get }
}

/// The lane counts that are not a count. This library's own.
enum BusValueLanes {
    /// A value whose width is ITS OWN - as many lanes as the image holds.
    ///
    /// A run of placements is one: how wide it is, is how many views it
    /// places, which nothing about the type can say. Everything that reads a
    /// value by its lane count asks the bytes instead.
    static let own = -1
}

extension Double: BusValue {
    /// One lane, which is the number itself.
    public var carried: BusCarried { .lanes([self]) }

    /// And back, unchanged.
    public init?(carried: BusCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = lanes[0]
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Int: BusValue {
    /// A whole number takes one lane, as itself.
    public var carried: BusCarried { .lanes([Double(self)]) }

    /// The nearest whole number to what the lane holds.
    public init?(carried: BusCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = Int(lanes[0].rounded())
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Bool: BusValue {
    /// Nought or one.
    public var carried: BusCarried { .lanes([self ? 1 : 0]) }

    /// Anything but nought is true.
    public init?(carried: BusCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 1 else { return nil }

        self = lanes[0] != 0
    }

    /// One.
    public static var lanes: Int { 1 }
}

extension Point: BusValue {
    /// Across, then down.
    public var carried: BusCarried { .lanes([x, y]) }

    /// A point from those two lanes.
    public init?(carried: BusCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 2 else { return nil }

        self.init(x: lanes[0], y: lanes[1])
    }

    /// Two.
    public static var lanes: Int { 2 }
}

extension Rect: BusValue {
    /// Left, top, width, height - the order the type names its own fields in.
    public var carried: BusCarried { .lanes([x, y, width, height]) }

    /// A rectangle from those four lanes.
    public init?(carried: BusCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Thickness: BusValue {
    /// Left, top, right, bottom.
    public var carried: BusCarried { .lanes([left, top, right, bottom]) }

    /// A thickness from those four lanes.
    public init?(carried: BusCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Color: BusValue {
    /// Red, green, blue and alpha, each from nought to one - which is what a
    /// colour half way between two others is made of.
    ///
    /// A colour written with a DARK half is resolved by the tree, never here:
    /// what rides a bus is one colour, the one on the screen, so this is the
    /// light half of a pair.
    public var carried: BusCarried {
        .lanes([
            Double(light.red) / 255,
            Double(light.green) / 255,
            Double(light.blue) / 255,
            Double(light.alpha) / 255,
        ])
    }

    /// A colour from those four lanes, each held to the range a channel has
    /// and rounded to the eight bits a channel is kept in.
    public init?(carried: BusCarried) {
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
}

extension String: BusValue {
    /// Its own bytes.
    public var carried: BusCarried { .text(self) }

    /// The text, where that is what the image held.
    public init?(carried: BusCarried) {
        guard case .text(let text) = carried else { return nil }

        self = text
    }

    /// None: text is dirty or it is not.
    public static var lanes: Int { 0 }
}

/// How a value lies on the image, in bytes.
///
/// Little-endian bit patterns, eight bytes a lane, and text as its own length
/// and then its own UTF-8 - written by hand for the reason `Core/Wire.swift`
/// writes the wire by hand: this library imports no Foundation, and a number's
/// bytes are its own business either way.
enum BusImage {
    /// The bytes a value lies as.
    static func bytes(of carried: BusCarried) -> [UInt8] {
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

    /// What those bytes stand for, read as `count` lanes or, where that is
    /// nought, as text.
    static func carried(of bytes: [UInt8], lanes count: Int) -> BusCarried {
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

/// Which way a bus crosses at an attachment. This library's own.
///
/// Only where BOTH directions mean something: a placement is written and never
/// read, a frame is read and never written, and neither takes one.
public enum BusMode: Int32, Sendable {
    /// The host writes it; nothing this side writes reaches the control.
    case `in` = 0

    /// This side writes it; the host reads nothing back.
    case out = 1

    /// Both, which is what almost everything settable and readable is.
    case inOut = 2
}

/// What a registration is about - which of the host's own doors the value goes
/// through. This library's own. Declaration order is the number on the wire.
public enum BusKind: Int32, Sendable {
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

/// One property of one element, tied to a bus.
///
/// What the registration field carries: which bus, which way it crosses, and
/// which of the host's doors the value goes through. The bus rather than its
/// NUMBER, because a number is issued the first time anything asks and the
/// tree is written before the differ has seen it.
struct BusRegistration {
    /// The bus itself.
    let bus: HostBus

    /// Which way it crosses.
    let mode: BusMode

    /// Which door the value goes through.
    let kind: BusKind
}

/// One registration as the WIRE carries it: the bus by its number.
///
/// The number rather than the bus, because this is what a render is compared
/// against - two renders naming the same bus, mode and door said the same
/// thing, and nothing crosses.
struct BusEntry: Equatable {
    /// The bus, by the number the host quotes it back by.
    let bus: Int32

    /// Which way it crosses.
    let mode: BusMode

    /// Which of the host's doors the value goes through.
    let kind: BusKind
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
/// there; write `value` where the number is one somebody is MOVING - a finger,
/// a frame of arithmetic of your own - because a value written every frame has
/// no journey to make.
public struct AnimatedValue<Value: BusValue>: BusValue {
    /// Where the value IS.
    ///
    /// The host writes it on every frame it moves, and mirrors into it
    /// whatever else aimed the property - a state change beside the bus, a
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
    /// when the value arrives. See `Bus.animateTo(_:_:)`.
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
    public var carried: BusCarried {
        .lanes(
            AnimatedValue.numbers(of: value)
                + AnimatedValue.numbers(of: setPoint)
                + AnimatedValue.numbers(of: velocity)
                + BusLaw.lanes(of: motion)
                + [completion, stopped])
    }

    /// And back, where the lane count is the one this type takes.
    public init?(carried: BusCarried) {
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
        self.motion = BusLaw.motion(of: Array(lanes[(width * 3)..<(width * 3 + BusLaw.lanes)]))
        self.completion = lanes[width * 3 + BusLaw.lanes]
        self.stopped = lanes[width * 3 + BusLaw.lanes + 1]
    }

    /// Three of the value's own lanes, the law's, and one each for the waiter
    /// and the stops.
    public static var lanes: Int { Value.lanes * 3 + BusLaw.lanes + 2 }

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
        case .motion: range = (width * 3)..<(width * 3 + BusLaw.lanes)
        case .completion: range = (width * 3 + BusLaw.lanes)..<(width * 3 + BusLaw.lanes + 1)
        case .stopped: range = (width * 3 + BusLaw.lanes + 1)..<(width * 3 + BusLaw.lanes + 2)
        }

        return range.reduce(into: UInt64(0)) { $0 |= BusStorage.bit(of: $1) }
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
enum BusLaw {
    /// How many lanes a law takes.
    static let lanes = 3

    /// A law as its lanes.
    static func lanes(of motion: Motion) -> [Double] {
        if motion.isInherited { return [1, 0, 0] }
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

/// What a bus's value IS, across every render - held as the bytes both sides
/// read.
///
/// A class for the same reason a `@State`'s storage is one: the wrapper is
/// rebuilt with its view on every render and adopts its predecessor's storage,
/// so this is the one object that means "this value" over time - and the one
/// the bus number is issued against.
///
/// THREE COPIES, and each answers a different question. `image` is what the
/// cycle running now is working on; `published` is the last COMPLETED cycle's,
/// which is what a handler or another board reads, so nothing outside ever
/// sees a half-finished picture; `pending` is a write made while no cycle was
/// running, waiting for the next one to latch it.
final class BusStorage: @unchecked Sendable, NamedState {
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
    /// that put the same number back as well: an engine that follows a bus a
    /// finger is holding still has been told about every report.
    var stamp: Int = 0

    /// The number the host quotes it back by, once anything has asked.
    var bus: Int32?

    /// Which board's cycle owns it - one today, and the seam for a second.
    var board: Int = 0

    /// What the author calls it - the reflection walk's, as a state's is.
    nonisolated(unsafe) var origin: String?

    init(_ bytes: [UInt8]) {
        image = bytes
        published = bytes
    }

    /// Lays a value into a slot lane by lane, answering which lanes changed.
    ///
    /// COMPARED BIT FOR BIT rather than by number: a bus carries what a
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

/// A bus, whatever value rides it - what an engine FOLLOWS, however each of
/// the values it follows is typed. This library's own.
///
/// The typed face is `Bus<Value>`; this is the part of one that the mechanism
/// needs - which bus it is - and it is what a signature takes where any bus
/// will do:
///
///     PlacedLayout(cards, id: \.name, following: $scrolled, $dragged, at: place) { … }
public class HostBus {
    /// The value, across every render.
    ///
    /// A VAR because a wrapper rebuilt with its view ADOPTS its predecessor's
    /// storage, and this is the one place that storage is kept: the number the
    /// host quotes the value by is issued against it, so a wrapper holding the
    /// storage it was BUILT with would be given a new number every render -
    /// and the host would then be moving a value nothing reads.
    fileprivate(set) var held: BusStorage

    /// The number this bus rides on, issued the first time anything asks.
    var bus: Int32 { Renderer.shared.bus(for: held) }

    init(_ storage: BusStorage) {
        held = storage
    }
}

/// A value the host moves and this side never re-describes for. This library's
/// own.
///
///     @Bus private var scrolled = 0.0
///
///     ScrollReader(across: 540) { … }.scrollX($scrolled)
///
/// Declared like `@State` and kept like it - the same value is here across
/// every render, found by the property's own name - but read and written
/// without the interface being described again: nothing records a dependency
/// on it, and writing it asks for no render.
///
/// That is the whole of the difference, and it is a trade: a view CANNOT show
/// one. A `Label("\(scrolled)")` would be built once and never again, because
/// nothing tells the tree the value moved. What a bus is for is arithmetic the
/// HOST runs - an `.engine`, or a layout that follows one - where the answer
/// is written straight onto the controls, frame by frame, with no tree in
/// between. A value a view must SHOW is `@State`.
///
/// THREAD-SAFE like `@State`: a write from a handler or a Task lands WHOLE and
/// is read by the next cycle, never half way through the one running.
@propertyWrapper
public final class Bus<Value: BusValue>: HostBus, @unchecked Sendable {
    /// A bus, starting where it says.
    ///
    /// - Parameter wrappedValue: where it stands before anything has moved it.
    public init(wrappedValue: Value) {
        super.init(BusStorage(BusImage.bytes(of: wrappedValue.carried)))
        Renderer.shared.board(of: held).hold(held)
    }

    /// Where the value stands.
    ///
    /// Reading it records NOTHING, so a view that reads it is not rebuilt when
    /// it moves - which is the point, and the trap: a view cannot show one.
    /// Inside a cycle it answers what that cycle is working on; anywhere else,
    /// the last cycle to finish.
    public var wrappedValue: Value {
        get {
            Value(carried: Renderer.shared.board(of: held).read(held, lanes: Value.lanes))
                ?? Self.nothing
        }
        set {
            Renderer.shared.board(of: held).write(BusImage.bytes(of: newValue.carried), to: held)
        }
    }

    /// What `$scrolled` gives: the bus itself, for a scroller to report into
    /// and for an engine to follow.
    public var projectedValue: Bus<Value> { self }

    /// What a bus answers where its bytes stand for no value of this type -
    /// every lane at nought, or empty text.
    ///
    /// Nothing on this side can bring it about, the setter writing the type's
    /// own bytes; a HOST that wrote the wrong lane count could, and a picture
    /// frozen for a frame is the right answer to that where a trap would take
    /// the application down.
    private static var nothing: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0))))
            ?? Value(carried: .text(""))!
    }
}

extension Bus: StateBox {
    /// Takes over the other wrapper's storage, so the two are one value from
    /// here on - and the number the host is already quoting goes on meaning the
    /// same thing across a rebuild.
    func adopt(from other: AnyObject) {
        guard let other = other as? Bus<Value>, other !== self else { return }

        held = other.held
    }

    /// Tells the value what the author calls it, as a state is told.
    func named(_ path: String) {
        held.origin = BuildScope.readable(path)
    }
}

extension Bus {
    /// Sends the value there under `motion`, and suspends until it ARRIVES.
    ///
    ///     try await $fade.animateTo(0.1, .eased(400, .cubicOut))
    ///
    /// TRUE means it got there. FALSE means something else ended the journey:
    /// a newer setpoint, a value written over it, a `stop()`, or the view
    /// leaving the tree. Where there is nothing to move - the value is already
    /// there, the reader asked for less movement, or no view on screen wears
    /// this bus - it answers TRUE at once, the model being where it was going.
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
    public nonisolated(nonsending) func animateTo<Inner: BusValue>(
        _ target: Inner,
        _ motion: Motion = .inherited
    ) async throws -> Bool where Value == AnimatedValue<Inner> {
        let answer = try await Renderer.shared.answered { completion in
            let waiter = Renderer.shared.book(completion)
            var travelling = self.wrappedValue

            travelling.setPoint = target
            travelling.motion = motion
            travelling.completion = Double(waiter)

            // THE WAITER FORCES THE SETPOINT: sending a value where it is
            // already going is a fresh journey with somebody fresh waiting on
            // it, and lanes that did not move would cross as nothing at all.
            Renderer.shared.board(of: self.held).write(
                BusImage.bytes(of: travelling.carried),
                to: self.held,
                forcing: Value.mask(of: .setPoint) | Value.mask(of: .completion))
        }

        return answer.first?.bool ?? true
    }

    /// Stops a travel where it stands. Whoever is waiting on it hears that it
    /// did not run to the end.
    ///
    /// The value is left where it had got to and is on the bus from the next
    /// cycle. A value that was not moving is unaffected.
    public func stop<Inner: BusValue>() where Value == AnimatedValue<Inner> {
        var standing = wrappedValue

        // The waiter's number is LEFT on the image: it is the host that ends
        // the travel, and it needs the number to answer.
        standing.stopped += 1

        Renderer.shared.board(of: held).write(
            BusImage.bytes(of: standing.carried),
            to: held,
            forcing: Value.mask(of: .stopped))
    }
}

/// The arithmetic a layout is placed by: which view this is, how many there
/// are, and the room.
///
/// THE SAME CLOSURE EITHER WAY, and that is the design: a bus is READ
/// rather than handed over, and reading one records nothing - so the
/// arithmetic an author writes for a render is the arithmetic the host calls
/// between renders, with no second signature, no arity to grow as a second and
/// third bus join, and nothing written twice.
typealias PlacementRule = (Int, Int, Rect) -> Placement

/// A layout, told what to follow between renders.
///
/// What the message carries is NUMBERS: the buses the values ride on and
/// the id the differ registered the arithmetic under - the closure itself
/// never leaves this side, and the id is the differ's because only the differ
/// knows which element is which across a render.
///
/// - Parameters:
///   - layout: the layout holding the placed views.
///   - values: what to follow. Empty where the tree's own placement stands.
///   - rule: the arithmetic to follow it with.
/// - Returns: the layout's node, saying what it follows.
func following(
    _ layout: any Element,
    _ values: [HostBus],
    _ rule: PlacementRule?
) -> Node {
    var node = layout.body

    if let rule = rule, !values.isEmpty {
        node.props[.channels] = .numbers(values.map { Double($0.bus) })
        node.placing = rule
    }

    return node
}
