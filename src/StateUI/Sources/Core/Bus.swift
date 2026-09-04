// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A value the HOST moves, and the question a binding to one answers.
//
// A bus holds ONE thing: the image of lanes both sides rewrite between renders.
// There is no box behind it and no storage beside it - a read and a write go
// straight through the image, with nothing recorded and no view ever built for
// it.
//
// A DECLARATION OF ITS OWN rather than a kind of `State`, so that what a bus
// offers is what a bus can honour. The two riders a described state takes are
// both nonsense here - a cadence paces an ask the tree never hears, and a
// persistent key writes down a value the host owns - and there is no second
// storage beside the image for a member to write into by mistake.

/// State the HOST moves, which the tree is never told about.
///
///     @Bus private var scrolled = 0.0
///
///     ScrollReader(across: 540) { … }.scrollX($scrolled)
///
/// Declared and kept like any other state - the same value is here across every
/// render, found by the property's own name - but read and written with nothing
/// recorded, so no view is ever built for it. What such a value is for is
/// arithmetic the HOST runs, frame by frame, with no tree in between: a
/// scroller's offset, a finger's drag, a run of placements. See `.engine(in:)`.
///
/// **THE TRADE IS THAT MOVING ONE ASKS FOR NO RENDER.** A body may read one and
/// print what it holds - `Label("\(scrolled)")` compiles and shows the value it
/// had at that build. What the value MOVING does not do is ask for that view to
/// be described again, so the number on screen is refreshed only when the view
/// happens to be described for some OTHER reason - which makes it ARBITRARY,
/// not frozen. To show one AS IT MOVES, DRIVE the property instead:
/// `Label().text($caption)` is the letters written by the host on its own
/// frames, and it costs no render at all.
///
/// A DECLARATION OF ITS OWN, not a word in `@State`'s brackets: what a value is
/// held BY is said by the name it is declared with - `@State`, `@Bus`,
/// `@Phase` - and the brackets are left to say what else is true of one, which
/// is a cadence or a persistent key. The constraint rides the generic
/// parameter, so a value the host can hold nothing of is refused at the
/// declaration.
///
/// THREAD-SAFE both ways: a write from a handler or a Task lands WHOLE and is
/// read by the next cycle, never half way through the one running.
@propertyWrapper
public final class Bus<Value: StateValue>: @unchecked Sendable {
    /// Where the value lives - an image of lanes the host rewrites between
    /// renders, rather than a box this side settles.
    ///
    /// The one thing a bus stores, and the one thing adoption moves: the
    /// number the host quotes the value by is issued against the image, so a
    /// box that kept the one it was BUILT with would be given a new number
    /// every render and the host would be moving a value nothing reads.
    private(set) var image: HostStorage

    /// State the host moves, holding `wrappedValue` until it does.
    ///
    /// EAGER where a `@State`'s expression is lazy: the image the host writes
    /// into is made OF the value, so there is nothing left to defer.
    ///
    /// - Parameter wrappedValue: where the value stands before anything has
    ///   moved it.
    public init(wrappedValue: Value) {
        image = HostStorage(StateImage.bytes(of: wrappedValue.carried))

        Renderer.shared.board(of: image).hold(image)
    }

    /// The value, read and written through the image the host holds.
    ///
    /// Neither half records anything: a read inside a body is not a dependency
    /// and a write asks for no render.
    public var wrappedValue: Value {
        get { Bus.read(image) }
        set { Bus.write(newValue, to: image) }
    }

    /// What `$scrolled` gives: this state, for a modifier to drive a property
    /// from or an engine to follow.
    ///
    /// The image is what the binding says it borrows from, which is what
    /// `Binding.driving` answers with and what tells a driven property from a
    /// described one.
    public var projectedValue: Binding<Value> {
        let image = image

        return Binding(
            read: { Bus.read(image) },
            write: { Bus.write($0, to: image) },
            lender: image,
            lent: nil)
    }

    /// Reads the value, as the plain name does.
    ///
    ///     let scrolled = Bus(wrappedValue: 0.0)
    ///     Label("At \(scrolled.get())")
    ///
    /// For a bus held WITHOUT the wrapper - at file scope, where Swift allows
    /// no property wrapper at all. On `@Bus private var scrolled = 0.0` the
    /// plain name reads the same value, and that is the spelling to use.
    public func get() -> Value { Bus.read(image) }

    /// Writes the value worked out from the one the image holds.
    ///
    ///     scrolled.update { $0 + 40 }
    ///
    /// A READ AND THEN A WRITE, and not a hold: the host rewrites this image on
    /// its own frames and nothing on this side can bracket that, so what stands
    /// between the two is whatever the last cycle left. It is the same pair
    /// `scrolled += 40` is, spelled where the box is what one has - through the
    /// wrapper (`_scrolled.update`) or on a bus held at file scope.
    ///
    /// - Parameter transform: given the value as it stands, answers the new one.
    public func update(_ transform: (Value) -> Value) {
        Bus.write(transform(Bus.read(image)), to: image)
    }

    /// The number the host quotes this state by, issued the first time anything
    /// asks. Every bus has one: the value is the host's by declaration.
    var number: Int32 { Renderer.shared.number(for: image) }

    /// The value as the lanes stand, or `nothing` where those bytes stand for
    /// no value of this type.
    private static func read(_ image: HostStorage) -> Value {
        Value(carried: Renderer.shared.board(of: image).read(image, lanes: Value.lanes))
            ?? nothing
    }

    /// The value written into the lanes, whole.
    private static func write(_ value: Value, to image: HostStorage) {
        Renderer.shared.board(of: image).write(StateImage.bytes(of: value.carried), to: image)
    }

    /// What a value answers where its bytes stand for none of this type -
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
    /// Takes over the other box's image, so the two are one piece of state
    /// from here on - which is how a `@Bus` on a view survives the view being
    /// a value rebuilt every render.
    func adopt(from other: AnyObject) {
        guard let other = other as? Bus<Value>, other !== self else { return }

        image = other.image
    }

    /// Tells the image what the author calls it, so a render explained in
    /// names has one for this state.
    func named(_ path: String) {
        image.origin = BuildScope.readable(path)
    }
}

/// What an engine can be told to follow. This library's own.
///
/// What `$scrolled` answers to when it is handed to `.engine(in:)` or to a
/// scroller to report into. A binding to state the tree describes conforms too
/// and answers nothing, which is what lets a modifier say so rather than fail
/// to compile against a distinction the author cannot see.
///
/// Named for what an engine DOES with one, because what a binding answers here
/// is not a KIND of thing but a question about one, and the names that describe
/// the thing are taken: `Bus` is the declaration and `HostStorage` is where its
/// value lies.
public protocol Followable {
    /// Where the state lives when the host moves it, and nothing otherwise.
    var driving: HostStorage? { get }
}

extension Binding: Followable {
    /// Where the borrowed state lives when the HOST is what moves it, and
    /// nothing where the tree describes it.
    ///
    /// What every modifier driven by a bus asks first: a property can only be
    /// driven by a value the host can write into, which is the image behind
    /// `@Bus`.
    ///
    /// **A PART OF ONE ANSWERS NOTHING.** `$room.width` reads and writes
    /// through the bus perfectly well, but the image IS the whole value - four
    /// lanes for a rectangle - and there is no way to say on the wire that a
    /// property is driven by one lane of it. So a derived binding takes the
    /// described road, where the whole is read and written by this side, rather
    /// than registering the whole image as if it were the part.
    public var driving: HostStorage? { lent == nil ? lender as? HostStorage : nil }

    /// The number the host quotes that state by, where there is one.
    var number: Int32? { driving.map { Renderer.shared.number(for: $0) } }
}

// MARK: - The value only a bus can carry

// An `AnimatedValue` says where a value IS and where it is GOING, and what
// closes that gap is the host walking it frame by frame. A `@State` has no
// frames: the tree describes where the value is going and the number beside it
// never moves, so the two halves stand apart for good. These two declarations
// say that at the line that caused it, as Core/Observable.swift does for a
// model whose writes reach nobody.
//
// A warning rather than a refusal, because the value is still a value and both
// halves can be read and written by hand; what it cannot be is animated. The
// binding's own `animateTo` traps beside it, for a journey that arrives by some
// other road - a binding made from closures has no declaration to warn at.

/// A value with a JOURNEY in it: where it is, where it is going, and a host
/// closing the gap. This library's own.
///
/// `AnimatedValue` is the one, and this is what lets a declaration that cannot
/// carry a journey say so at the line that wrote it - `@State` being the case,
/// the tree having no frames to walk a value on.
public protocol Journeying {}

extension AnimatedValue: Journeying {}

extension State where Value: Journeying {
    /// Holds a value with a journey in it, and says that the tree cannot move
    /// one - see the note above for the two spellings that do.
    ///
    /// - Parameter wrappedValue: the value this state holds.
    @available(*, deprecated, message: """
        An AnimatedValue is carried by a @Bus and by nothing else: the host \
        walks it frame by frame, and the tree has no frames to walk it on. \
        Declare it `@Bus private var fade = AnimatedValue(1.0)` - or hold the \
        plain number in @State and fly it with `$fade.animateTo(...)`.
        """)
    public convenience init(wrappedValue: Value) {
        self.init(holding: wrappedValue)
    }

    /// Holds one at file scope, and says the same thing `init(wrappedValue:)`
    /// above does.
    ///
    /// - Parameter initialValue: the value this state holds.
    @available(*, deprecated, message: """
        An AnimatedValue is carried by a @Bus and by nothing else: the host \
        walks it frame by frame, and the tree has no frames to walk it on. \
        Declare it `@Bus private var fade = AnimatedValue(1.0)` - or hold the \
        plain number in @State and fly it with `$fade.animateTo(...)`.
        """)
    public convenience init(_ initialValue: Value) {
        self.init(holding: initialValue)
    }
}
