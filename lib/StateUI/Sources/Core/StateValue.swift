// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What a value must be to cross to the host (`StateValue`), what it becomes there
// (`StateCarried`), which way and through which door it crosses, how an animated
// value lies (`JourneyLanes`), the journey an author reaches over a state
// (`Journey`), and where a carried value lives (`HostStorage`).
// Design: docs/design/core/state.md#carried-state

/// What one state holds on the image: numbers, one lane each, or text. This
/// library's own.
public enum StateCarried: Equatable, Sendable {
    /// Plain numbers, in a stated order - what almost everything is.
    case lanes([Double])

    /// Text, which has no lanes: it is dirty or it is not.
    case text(String)
}

/// A value that can ride a state - how it lies on the image, and back. This
/// library's own. A type of the application's own joins by saying the same: a
/// `Rect` is four lanes in the order it names its fields, a `String` its bytes.
public protocol StateValue: Equatable, Sendable {
    /// The value, as the image holds it.
    var carried: StateCarried { get }

    /// The value that image stands for, or nil where it stands for none - a
    /// lane count that does not match, or text where numbers were expected.
    init?(carried: StateCarried)

    /// How many lanes one value takes; nought for text, and
    /// `StateValueLanes.own` for a value as wide as whatever is on the state.
    static var lanes: Int { get }

    /// Which of a view's values this one is where the property alone cannot say - a
    /// colour. Everything else answers nothing.
    static var moving: MotionValues { get }
}

extension StateValue {
    /// Nothing: the property this value drives says which group it is in.
    public static var moving: MotionValues { [] }
}

/// The lane counts that are not a count. This library's own.
enum StateValueLanes {
    /// A value as wide as the image holds - a run of placements; readers ask the bytes.
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

extension Insets: StateValue {
    /// Left, top, right, bottom.
    public var carried: StateCarried { .lanes([left, top, right, bottom]) }

    /// Insets from those four lanes.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 4 else { return nil }

        self.init(lanes[0], lanes[1], lanes[2], lanes[3])
    }

    /// Four.
    public static var lanes: Int { 4 }
}

extension Color: StateValue {
    /// Red, green, blue and alpha, each from nought to one. A colour pair crosses as
    /// the half in force (`State.Storage.wearThemedPair()`).
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

        self.init(Rgba(
            red: channel(lanes[0]),
            green: channel(lanes[1]),
            blue: channel(lanes[2]),
            alpha: channel(lanes[3])))
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

/// A value a journey can be made of - one the host can animate lane by lane. This
/// library's own.
///
/// `$x.journey` exists on a binding to one, `@State(motion:)` is declared over
/// one, and a driven property animates one. Text, whole numbers and truth values
/// have no half way and are not `Walked`, so asking for their journey does not
/// compile.
public protocol Walked: StateValue {}

/// A choice the host can be handed as a channel: an alignment, a keyboard, a line
/// break, a set of flags. This library's own.
///
///     @State private var side = Alignment.start
///
///     Label("Where am I?").horizontalAlignment($side)
///
///     side = .center                  // the host moves it; nothing is rebuilt
///
/// One lane holding the member's number, resolved by the host as a described
/// property is. A choice has no half way, so it is set as it stands.
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
extension Insets: Walked {}
extension Color: Walked {}

/// How a value lies on the image: eight little-endian bytes a lane, or text as
/// its length and UTF-8.
/// Design: docs/design/core/cycle.md#the-state-batch
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

    /// Lays numbers over the lanes starting at `index`.
    static func lay(_ lanes: [Double], at index: Int, into bytes: inout [UInt8]) {
        let written = StateImage.bytes(of: .lanes(lanes))

        for byte in 0..<written.count where index * 8 + byte < bytes.count {
            bytes[index * 8 + byte] = written[byte]
        }
    }

    /// What those bytes stand for, as `count` lanes or, where that is nought, text.
    static func carried(of bytes: [UInt8], lanes count: Int) -> StateCarried {
        // Its own width: as many lanes as there are eight-byte numbers.
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

    /// Words written into a text property - out onto a caption, and both ways on a
    /// field the user types into, where the typed words land on the state whole.
    case text = 2

    /// The host writes and this side reads: the frame a layout settled on.
    case feed = 3

    /// A value the host sets as it stands - a flag, a count, a number that never
    /// animates - on its own frames. Both ways where the control reports one: a
    /// switch flipped, a choice made.
    case plain = 4
}

/// One property of one element, driven to a state: which state, which way, which
/// door. The state rather than its number, which is issued later.
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

    /// Which of the view's values this is - the property's group, plus a colour's -
    /// what `.inherited` is resolved against.
    let values: MotionValues
}

/// One registration as the wire carries it: the state by its number, which is
/// what a render compares.
struct StateEntry: Equatable {
    /// The state, by the number the host quotes it back by.
    let number: Int32

    /// Which way it crosses.
    let mode: StateMode

    /// Which of the host's doors the value goes through.
    let kind: StateKind
}

/// How a value the host animates lies on the image - one state channel on the
/// host however many controls wear it. Internal: an author reaches `Journey`.
/// Design: docs/design/core/journeys.md#the-journey-lanes
struct JourneyLanes<Value: Walked>: StateValue {
    /// Where the value is; the host writes it every frame it moves.
    var value: Value

    /// Where it is going - the state's own value.
    var destination: Value

    /// How fast it is going, per second, lane by lane.
    var velocity: Value

    /// The law an animation runs under (`StateLaw`).
    var motion: Motion

    /// The negative id a waiter is registered under, or nought for nobody.
    var completion: Double = 0

    /// How many times an animation on this value stopped - a counter, so two stops
    /// are two changes.
    var stopped: Double = 0

    /// A value standing still where it says, under the element's law unless said.
    init(_ value: Value, motion: Motion = .inherited) {
        self.value = value
        self.destination = value
        self.velocity = JourneyLanes.still
        self.motion = motion
    }

    /// A value of this type at nought - a speed before anything moved.
    static var still: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0)))) ?? value0
    }

    /// The stand-in for text, which has no numbers; nothing reads it.
    private static var value0: Value {
        Value(carried: .text(""))!
    }

    /// Every lane: value, destination, velocity, law, waiter, stops.
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

    /// Three of the value's widths, the law's three, and the waiter and the stops.
    static var lanes: Int { Value.lanes * 3 + StateLaw.lanes + 2 }

    /// Whatever the value it carries is in - an animated colour is a colour.
    static var moving: MotionValues { Value.moving }

    /// The numbers a value lies as - an animated value's lanes.
    private static func numbers(of value: Value) -> [Double] {
        guard case .lanes(let lanes) = value.carried else {
            return Array(repeating: 0, count: Value.lanes)
        }

        return lanes
    }

    /// Which lanes one part sits in - what a write that must be seen forces dirty.
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


/// How a law lies on the image: three lanes, the first saying which kind.
/// Design: docs/design/core/journeys.md#the-law-on-the-image
enum StateLaw {
    /// How many lanes a law takes.
    static let lanes = 3

    /// The first lane of the element's own law, resolved as the host reads it.
    static let inherited: Double = 1

    /// The first lane where an engine on this side animates the value; the host never
    /// sees it.
    static let custom: Double = 4

    /// Where a law's three lanes start for a value going through this door: five
    /// lanes from the end of a journey, last in a placement run, nowhere for text, a
    /// feed or a plain value.
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

// Design: docs/design/core/cycle.md#three-copies-of-a-value
/// What a carried state's value is, across every render - the bytes both sides
/// read, kept as three copies: the image the running cycle works on, the last
/// completed cycle's, and a write waiting to be latched.
public final class HostStorage: @unchecked Sendable, NamedState {
    /// What the cycle running now is working on.
    var image: [UInt8]

    /// The last completed cycle's, which is what everything outside reads.
    var published: [UInt8]

    /// A write made outside a cycle, waiting to be latched.
    var pending: [UInt8]?

    /// Which of that write's lanes actually changed.
    var pendingMask: UInt64 = 0

    /// Which lanes were written since they were last read - bit n is lane n, bit 63
    /// every lane from 63 on.
    var dirty: UInt64 = 0

    /// The readings asked for of this value, by the state each is read into - known
    /// weakly, since a reading belongs to the element that asked for it.
    /// Design: docs/design/core/journeys.md#readings
    var samplings: [ObjectIdentifier: WeakSampling] = [:]

    /// How many times the value was written, equal bytes included - what an engine
    /// following it compares.
    var stamp: Int = 0

    /// The number the host quotes it back by, once anything has asked.
    var number: Int32?

    /// Which board's cycle owns it.
    var board: Int = 0

    /// What the author calls it - the reflection walk's, as a state's is.
    nonisolated(unsafe) var origin: String?

    /// Which of the host's doors the value goes through, which says where its law lies.
    var door: StateKind?

    /// The element's own law - what `.inherited` means here - resolved by the differ.
    /// Design: docs/design/core/identity-and-diffing.md#driven-properties
    var inherited: Motion = .inherited

    /// Which element resolved that law, so a second answering differently is heard.
    var inheritedBy: ElementId?

    /// What runs after the host wrote this value, handed the lanes it wrote - the
    /// state's own ask for a render.
    nonisolated(unsafe) var told: ((UInt64) -> Void)?

    /// Whether any build read the journey off this image.
    /// Design: docs/design/core/journeys.md#two-reader-sets
    nonisolated(unsafe) var readAtBuild = false

    init(_ bytes: [UInt8]) {
        image = bytes
        published = bytes
    }

    /// The published bytes as the host must read them: an inherited law resolved, and
    /// a `.custom` value handed over as its own destination.
    /// Design: docs/design/core/journeys.md#the-law-on-the-image
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
            // Under `.custom` the engine's value is the host's destination, under no law.
            let width = (published.count / 8 - StateLaw.lanes - 2) / 3
            var bytes = published

            StateImage.lay((0..<width).map { StateImage.lane($0, of: published) }, at: width, into: &bytes)
            StateImage.lay(StateLaw.lanes(of: Motion.none), at: at, into: &bytes)

            return bytes

        default:
            return published
        }
    }

    /// Lays a value into a slot lane by lane, answering which lanes changed - bit for
    /// bit, so -0.0 and a NaN are what they are.
    /// Design: docs/design/core/cycle.md#where-a-write-lands
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

    /// Lays only the named lanes, answering which of them changed - what a host's
    /// report is.
    static func lay(_ bytes: [UInt8], into slot: inout [UInt8], only mask: UInt64) -> UInt64 {
        // A report speaks about lanes, never about shape: what it does not name stands.
        // Design: docs/design/core/cycle.md#what-the-host-reports
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

    /// The dirty bit of one lane: its own, or the last for lanes past 63.
    static func bit(of lane: Int) -> UInt64 { 1 << UInt64(min(lane, 63)) }
}

// MARK: - The journey

// Design: docs/design/core/journeys.md#who-animates-it
/// The journey a state is on: where the value is, where it is going, how fast,
/// and under what law - reached as `$fade.journey`. This library's own.
///
///     @State private var fade = 1.0
///
///     ColorBox().opacity($fade)
///
///     fade = 0.2                                         // the destination: the box animates there
///     try await $fade.journey.move(to: 0.2, .eased(400, .cubicOut))   // the same, awaited
///     $fade.journey.value                                // where it has got to this frame
///     $fade.journey.velocity                             // and how fast
///     $fade.journey.stop()                               // leaves it where it is
///
/// The state's own value is the destination: reading it answers where the value
/// is going, writing it sends it there. The host animates a state handed to a
/// driven modifier, a two-way control or a scroller; an engine of your own
/// animates one declared `@State(motion: .custom)`; a state nobody wears lands
/// where it is sent. A part of a state and a binding made from closures stand at
/// their value.
public struct Journey<Value: Walked> {
    /// The state this is the journey of.
    private let state: Binding<Value>

    /// The storage behind the state; nothing for a part of one or a closure binding.
    var storage: State<Value>.Storage? { state.described }

    /// The journey of a state, reached as `$fade.journey`.
    init(of state: Binding<Value>) { self.state = state }

    /// The lanes as they stand, with the read recorded against the image.
    /// Design: docs/design/core/journeys.md#two-reader-sets
    private func lanes() -> JourneyLanes<Value>? {
        guard let (_, image, lanes) = walking() else { return nil }

        if Renderer.shared.stateRead(image) { image.readAtBuild = true }

        return lanes
    }

    /// The storage, its journey image - made now if nothing has yet - and the lanes
    /// as they stand, read without recording: what every write starts from.
    private func walking() -> (State<Value>.Storage, HostStorage, JourneyLanes<Value>)? {
        guard let storage, let image = storage.walkedImage(), let lanes = storage.journeyLanes else {
            return nil
        }

        return (storage, image, lanes)
    }

    /// Where the value is - what the screen shows this frame.
    ///
    /// Read in a body, it rebuilds the body every frame the value moves; `.samples`
    /// reads it at a slower rate, and `convert(_:)` works words out on the host's
    /// frames with no render. Written, it moves only what is shown and leaves the
    /// destination, so the host goes straight back; `snap(to:)` sets all three.
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

    /// How fast it is going, per second, lane by lane - nought where nothing animates
    /// it. Written, it is a kick: it bends an animation under way, or takes a still
    /// value out and lets the law bring it back.
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

    /// The law this value animates under, wherever it is shown.
    ///
    ///     $rotation.journey.motion = .spring()
    ///
    /// On the value rather than the view: `.motion(_:)` says how an element animates,
    /// this says how this value does. `.inherited` is the element's own. `.custom` is
    /// not set here: who animates a value is settled at its declaration.
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

    /// Puts the value there at once: shown there, going nowhere, standing still.
    ///
    ///     $box.journey.snap(to: measured)
    ///
    /// For a value worked out rather than chosen - a size from a measurement, a place
    /// from a report - which, animated as a destination, would crawl after what
    /// decided it. Synchronous: nothing is booked and nobody waits.
    ///
    /// - Parameter value: where it now is, and stays.
    public func snap(to value: Value) {
        state.land(value)
    }

    /// Sends the value there under `motion`, and suspends until it arrives.
    ///
    ///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
    ///
    /// True means it got there; false means something else ended the journey - a
    /// newer destination, a value written over it, or `stop()`. With nothing to
    /// animate - already there, the user asked for less motion, or nothing wears the
    /// state yet - it answers true at once. A law given here stays on the value;
    /// without one, the value's own law stands.
    ///
    /// - Parameters:
    ///   - target: where to send it.
    ///   - motion: the law to animate under, or nothing for the value's own.
    /// - Returns: whether it ran to the end.
    /// - Throws: whatever the host answers when it cannot carry the value at all.
    @discardableResult
    public nonisolated(nonsending) func move(to target: Value, _ motion: Motion? = nil) async throws -> Bool {
        guard let (storage, image, lanes) = walking() else {
            complain("`move` was called on a part of a state, a binding made from closures, "
                + "or a state the host carries as the value itself, none of which it can "
                + "walk. Move the whole state, handed to something that walks it.")
            return false
        }

        // Nothing animates it, or an engine does: the destination is written through the
        // state and the answer is at once.
        // Design: docs/design/core/journeys.md#moving-and-waiting
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

            // The waiter forces the destination: a fresh journey even to where it is going.
            Renderer.shared.board(of: image).write(
                StateImage.bytes(of: travelling.carried),
                to: image,
                forcing: JourneyLanes<Value>.mask(of: .destination) | JourneyLanes<Value>.mask(of: .completion))

            storage.noteDestination(target)
        }

        return answer.first?.bool ?? true
    }

    /// Stops an animation where it stands; whoever waits on it hears it did not run
    /// to the end. A value that was not moving is unaffected.
    public func stop() {
        guard let (_, image, standing) = walking() else {
            complain("`stop` was called on a part of a state, a binding made from closures, "
                + "or a state the host carries as the value itself, none of which it walks.")
            return
        }

        var stopping = standing

        // The waiter's id stays on the image: the host needs it to answer.
        stopping.stopped += 1

        Renderer.shared.board(of: image).write(
            StateImage.bytes(of: stopping.carried),
            to: image,
            forcing: JourneyLanes<Value>.mask(of: .stopped))
    }
}

/// `Sendable` for the reason `Binding` is.
/// Design: docs/design/core/state.md#sendable-promises
extension Journey: Sendable {}
