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
//   the CHANNEL  a `@Channel`. The host owns what it currently is and pushes
//                it in; nothing here asks for a render when it moves.
//   the RULE     the author's arithmetic, in Swift, which the host CALLS when
//                a channel moves and gets numbers back - where each child of
//                a layout goes, and how it is turned.
//
// The host then writes those numbers onto the controls it already has. No
// build, no diff, no message: the only thing crossing is one number in and a
// packed answer out, which is why a value nobody could afford to render on can
// be followed frame by frame.
//
// IT IS THE SAME ARITHMETIC EITHER WAY. The closure is the one an author wrote
// for `PlacedLayout`, reading the channels by their own names - reading one
// records nothing - so a render still describes the cards exactly where the
// rule would put them, and the rule is what keeps them there between renders.
// Nothing is authored twice.

/// A value that can ride a channel - what it is as the number that crosses,
/// and back. This library's own.
///
/// The boundary carries numbers, so whatever a channel holds says how it is
/// one: a `Double` is itself, an `Int` is the nearest whole one, a `Bool` is
/// nought or one. A type of the application's own joins by saying the same.
public protocol ChannelValue {
    /// The value, as the number that crosses the boundary.
    var crossing: Double { get }

    /// The value the crossed number stands for.
    init(crossing: Double)
}

extension Double: ChannelValue {
    /// The number is the value.
    public var crossing: Double { self }

    /// And back, unchanged.
    public init(crossing: Double) { self = crossing }
}

extension Int: ChannelValue {
    /// A whole number crosses as itself.
    public var crossing: Double { Double(self) }

    /// The nearest whole number to what crossed.
    public init(crossing: Double) { self = Int(crossing.rounded()) }
}

extension Bool: ChannelValue {
    /// Nought or one.
    public var crossing: Double { self ? 1 : 0 }

    /// Anything but nought is true.
    public init(crossing: Double) { self = crossing != 0 }
}

/// What a channel's value IS, across every render.
///
/// A class for the same reason a `@State`'s storage is one: the wrapper is
/// rebuilt with its view on every render and adopts its predecessor's storage,
/// so this is the one object that means "this value" over time - and the one
/// the channel number is issued against. It holds the CROSSING rather than the
/// typed value, because the host writes numbers and does not know types.
final class ChannelStorage: @unchecked Sendable, NamedState {
    /// Where it stands, as the number that crosses. Written by the host as the
    /// platform reports, and read by whatever asks where things are.
    ///
    /// Unlocked on purpose: it is one number, written by the thread that
    /// renders and reports, and a reader that catches the previous one is a
    /// reader one report behind - which is what every reader of a moving value
    /// is anyway.
    nonisolated(unsafe) var crossing: Double

    /// The number the host quotes it back by, once anything has asked.
    nonisolated(unsafe) var channel: Int32?

    /// What the author calls it - the reflection walk's, as a state's is.
    nonisolated(unsafe) var origin: String?

    init(_ crossing: Double) {
        self.crossing = crossing
    }
}

/// A channel, whatever value rides it - what a layout FOLLOWS, however each
/// of the values it follows is typed. This library's own.
///
/// The typed face is `Channel<Value>`; this is the part of one that the
/// mechanism needs - which channel it is - and it is what a signature takes
/// where any channel will do:
///
///     PlacedLayout(cards, id: \.name, following: $scrolled, $dragged, at: place) { … }
public class HostChannel {
    /// The value, across every render.
    ///
    /// A VAR because a wrapper rebuilt with its view ADOPTS its predecessor's
    /// storage, and this is the one place that storage is kept: the number the
    /// host quotes the value by is issued against it, so a wrapper holding the
    /// storage it was BUILT with would be given a new number every render -
    /// and the host would then be moving a value nothing reads.
    fileprivate(set) var held: ChannelStorage

    /// The number this channel rides on, issued the first time anything asks.
    var channel: Int32 { Renderer.shared.channel(for: held) }

    init(_ storage: ChannelStorage) {
        held = storage
    }
}

/// A value the host moves and this side never re-describes for. This library's
/// own.
///
///     @Channel private var scrolled = 0.0
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
/// nothing tells the tree the value moved. What a channel is for is arithmetic
/// the HOST runs - `PlacedLayout(…, following:)` - where the answer is written
/// straight onto the controls, frame by frame, with no tree in between. A
/// value a view must SHOW is `@State`.
///
/// What rides it is any `ChannelValue` - a `Double` today for an offset and a
/// drag, an `Int` or a `Bool` the day something reports one.
@propertyWrapper
public final class Channel<Value: ChannelValue>: HostChannel, @unchecked Sendable {
    /// A channel, starting where it says.
    ///
    /// - Parameter wrappedValue: where it stands before anything has moved it.
    public init(wrappedValue: Value) {
        super.init(ChannelStorage(wrappedValue.crossing))
    }

    /// Where the value stands.
    ///
    /// Reading it records NOTHING, so a view that reads it is not rebuilt when
    /// it moves - which is the point, and the trap: a view cannot show one.
    public var wrappedValue: Value {
        get { Value(crossing: held.crossing) }
        set { held.crossing = newValue.crossing }
    }

    /// What `$scrolled` gives: the channel itself, for a scroller to report
    /// into and for a layout to follow.
    public var projectedValue: Channel<Value> { self }
}

extension Channel: StateBox {
    /// Takes over the other wrapper's storage, so the two are one value from
    /// here on - and the number the host is already quoting goes on meaning the
    /// same thing across a rebuild.
    func adopt(from other: AnyObject) {
        guard let other = other as? Channel<Value>, other !== self else { return }

        held = other.held
    }

    /// Tells the value what the author calls it, as a state is told.
    func named(_ path: String) {
        held.origin = BuildScope.readable(path)
    }
}

/// Where one view goes, packed as plain numbers for the host to write.
///
/// ELEVEN DOUBLES A VIEW, in the order below. A packed answer rather than a
/// message because this crosses on the platform's own frames: there is no
/// identity to carry, no property to name and nothing to diff - the host holds
/// the controls already and writes what arrives onto the child in that
/// position.
enum PackedPlacement {
    /// How many numbers one view takes.
    static let fields = 12

    /// The shade of a layout that has none, which is what tells the host to
    /// look for no shade view under the placed one.
    ///
    /// A layout WITH a shade answers 0 for a view that wears none of it, and
    /// nought is a shade like any other - so the absence needs a number no
    /// opacity can be. See `PlacedLayout.shade(_:)`.
    static let unshaded = -1.0

    /// Writes one placement into a buffer.
    ///
    /// - Parameters:
    ///   - placement: where the view goes and how it is turned.
    ///   - buffer: where to write.
    ///   - offset: the first number to write.
    static func write(
        _ placement: Placement,
        into buffer: UnsafeMutablePointer<Double>,
        at offset: Int
    ) {
        let transform = placement.transform

        buffer[offset + 0] = placement.bounds.x
        buffer[offset + 1] = placement.bounds.y
        buffer[offset + 2] = placement.bounds.width
        buffer[offset + 3] = placement.bounds.height
        buffer[offset + 4] = transform.x
        buffer[offset + 5] = transform.y
        buffer[offset + 6] = transform.rotation
        buffer[offset + 7] = transform.width
        buffer[offset + 8] = transform.height
        buffer[offset + 9] = placement.opacity
        buffer[offset + 10] = Double(placement.zIndex)
        buffer[offset + 11] = placement.shade
    }
}

/// The arithmetic a layout is placed by: which view this is, how many there
/// are, and the room.
///
/// THE SAME CLOSURE EITHER WAY, and that is the design: a channel is READ
/// rather than handed over, and reading one records nothing - so the
/// arithmetic an author writes for a render is the arithmetic the host calls
/// between renders, with no second signature, no arity to grow as a second and
/// third channel join, and nothing written twice.
typealias PlacementRule = (Int, Int, Rect) -> Placement

/// A layout, told what to follow between renders.
///
/// What the message carries is NUMBERS: the channels the values ride on and
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
    _ values: [HostChannel],
    _ rule: PlacementRule?
) -> Node {
    var node = layout.body

    if let rule = rule, !values.isEmpty {
        node.props[.channels] = .numbers(values.map { Double($0.channel) })
        node.placing = rule
    }

    return node
}
