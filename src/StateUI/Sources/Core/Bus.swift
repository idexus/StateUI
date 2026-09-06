// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A BUS THE HOST CARRIES, and a LINK to it.
//
// Two types, and the difference between them is ownership. `Bus` is the
// declaration: it LAYS the bus - the image of lanes both sides rewrite between
// renders - registers it with the cycle and keeps it for as long as the view
// that declared it is described. `Link` is a connection to that bus, which
// anybody can hold: what `$x` gives, what every driven modifier, feed and
// engine takes, and what a view further down declares to reach the bus
// through. Both are two-way. There is no box behind either and no storage
// beside them: a read and a write go straight through the image, with nothing
// recorded and no view ever built for it.
//
// The names are the pair `@State`/`@Binding` makes: the owner names the THING
// (a state, a bus) and the borrower names the CONNECTION to it (a binding, a
// link) - a link rather than a tap, because a tap listens where a link
// carries both ways, and because in this library a tap is a gesture; and not
// a port, which is a class Foundation exports, so that in a file importing
// Foundation the name would be ambiguous.
//
// A DECLARATION OF ITS OWN rather than a kind of `State`, so that what the host
// offers is what the host can honour. The two riders a described state takes
// are both nonsense here - a cadence paces an ask the tree never hears, and a
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
/// scroller's offset, a finger's drag, a run of placements. See `.engine(following:)`.
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
/// `@Memory` - and the brackets are left to say what else is true of one, which
/// is a cadence or a persistent key. The constraint rides the generic
/// parameter, so a value the host can hold nothing of is refused at the
/// declaration. `$scrolled` is a `Link` - a connection to the bus, which is
/// what a view further down declares with `@Link` - and never a `Binding`.
///
/// THREAD-SAFE both ways: a write from a handler or a Task lands WHOLE and is
/// read by the next cycle, never half way through the one running.
@propertyWrapper
public final class Bus<Value: StateValue>: @unchecked Sendable {
    /// Where the value lives - an image of lanes the host rewrites between
    /// renders, rather than a box this side settles.
    ///
    /// The one thing this declaration stores, and the one thing adoption
    /// moves: the
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
    public convenience init(wrappedValue: Value) {
        self.init(carrying: wrappedValue)
    }

    /// The one body every spelling runs.
    ///
    /// - Parameter value: where the value stands before anything has moved it.
    init(carrying value: Value) {
        image = HostStorage(StateImage.bytes(of: value.carried))

        Renderer.shared.board(of: image).hold(image)
    }

    /// The value, read and written through the image the host holds.
    ///
    /// Neither half records anything: a read inside a body is not a dependency
    /// and a write asks for no render.
    public var wrappedValue: Value {
        get { Link<Value>.read(image) }
        set { Link<Value>.write(newValue, to: image) }
    }

    /// What `$scrolled` gives: this value AS IT IS ON THE BUS - for a modifier
    /// to drive a property from, an engine to follow, a scroller to report
    /// into, or a view further down the tree to be on (`@Link`).
    ///
    /// Never a `Binding`: a binding is the tree's borrowed state, and a bus
    /// shares no type with it, so the compiler tells `Slider($volume)` from
    /// `Slider($level)` by the declaration alone and a `@State` cannot be handed
    /// where a bus is wanted.
    public var projectedValue: Link<Value> { Link(image: image) }

    /// Reads the value, as the plain name does.
    ///
    ///     let scrolled = Bus(wrappedValue: 0.0)
    ///     Label("At \(scrolled.get())")
    ///
    /// For a bus laid WITHOUT the wrapper - at file scope, where Swift allows
    /// no property wrapper at all. On `@Bus private var scrolled = 0.0` the
    /// plain name reads the same value, and that is the spelling to use.
    public func get() -> Value { Link<Value>.read(image) }

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
        Link<Value>.write(transform(Link<Value>.read(image)), to: image)
    }

    /// The number the host quotes this state by, issued the first time anything
    /// asks. Every bus has one: the value is the host's by declaration.
    var number: Int32 { Renderer.shared.number(for: image) }
}

/// A LINK TO A BUS - a two-way connection to a value the host carries: what
/// `$scrolled` gives on a `@Bus`, and what a view that does not own the bus
/// declares to reach it through. This library's own.
///
///     struct Face: ContentView {
///         @Link var level: AnimatedValue<Double>
///
///         var content: Element { Slider($level) }
///     }
///
///     Face(level: $level)
///
/// The same image the owner writes, read and written the same way - `level`
/// is the value, `$level` is this again - so a bus is reached down the tree
/// through ONE type and one spelling, and a modifier, an engine or a scroller
/// asks for exactly that type. `@State` and `@Binding` are the tree's; a bus shares no
/// type with them, which is what lets the compiler refuse `.opacity($counter)`
/// and `following: $counter`.
///
/// **NO `init(wrappedValue:)`, ON PURPOSE.** A view cannot MAKE one of these
/// out of a value, only receive it - so the memberwise initializer of a view
/// declaring `@Link var level` takes a `Link`, and `Face(level: $level)`
/// hands over a link to the parent's bus exactly as `Menu(path: $path)` hands
/// over a binding. Nothing is adopted by path here, either: which bus this is comes
/// from whoever handed it in, every render, so a parent that switches buses
/// under a child is heard at once.
///
/// **A PART OF ONE IS A BINDING, NOT A LINK.** `$room.width` reads and writes
/// through the whole - the image IS the whole value, four lanes for a
/// rectangle - and there is no way to say on the wire that a property rides
/// one lane of it. So a derived part comes back as a described `Binding`,
/// which no driven modifier accepts, and the compiler says so.
@propertyWrapper
@dynamicMemberLookup
public struct Link<Value: StateValue>: @unchecked Sendable, Followable {
    /// Where the value lives - the image the host rewrites between renders.
    /// One per bus, however many views are on it.
    public let image: HostStorage

    /// On the bus behind that image.
    ///
    /// - Parameter image: the bus's image.
    init(image: HostStorage) {
        self.image = image
    }

    /// The value, read and written through the image the host holds.
    ///
    /// Neither half records anything: a read inside a body is not a
    /// dependency and a write asks for no render - the host hears it on its
    /// own frames.
    public var wrappedValue: Value {
        get { Link.read(image) }
        nonmutating set { Link.write(newValue, to: image) }
    }

    /// What `$level` gives inside a view that is on the bus: this again, to
    /// hand further down or to a modifier.
    public var projectedValue: Link<Value> { self }

    /// The number the host quotes this bus by, issued the first time anything
    /// asks.
    var number: Int32 { Renderer.shared.number(for: image) }

    /// A part of the value, as described state: read and written through the
    /// whole, driven by nothing.
    ///
    /// - Parameter keyPath: which part.
    /// - Returns: a binding to that part, taking the described road.
    public subscript<Subject>(
        dynamicMember keyPath: WritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding<Subject>(
            read: { wrappedValue[keyPath: keyPath] },
            write: { newValue in
                var whole = wrappedValue
                whole[keyPath: keyPath] = newValue
                wrappedValue = whole
            },
            lender: nil,
            lent: keyPath)
    }

    /// The value as the lanes stand, or `nothing` where those bytes stand for
    /// no value of this type.
    static func read(_ image: HostStorage) -> Value {
        Value(carried: Renderer.shared.board(of: image).read(image, lanes: Value.lanes))
            ?? nothing
    }

    /// The value written into the lanes, whole.
    static func write(_ value: Value, to image: HostStorage) {
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

/// A value on the bus, as `.engine(following:)` takes any number of them.
/// This library's own.
///
/// `Link` is the one thing that conforms, so "followable" and "on the bus" are
/// one set; the protocol exists because the engine's plain form has to take
/// buses of DIFFERENT values in one list. A parameter pack says that too, and
/// the form that answers an `EngineAnswer` uses one - but Swift cannot rank two
/// pack overloads against each other for a multi-statement closure, and it
/// cannot rank two existential ones for a closure over two buses (both
/// measured as "ambiguous use of 'engine'"). One of each is what it resolves,
/// every time, so that is the shape.
public protocol Followable {
    /// Where the value lives - the image the host rewrites on its own frames.
    var image: HostStorage { get }
}

// MARK: - The value the tree cannot carry

// An `AnimatedValue` says where a value IS and where it is GOING, and what
// closes that gap is the host walking it frame by frame. A `@State` has no
// frames: the tree describes where the value is going and the number beside it
// never moves, so the two halves stand apart for good. The declaration says
// that at the line that caused it, as Core/Observable.swift does for a model
// whose writes reach nobody.
//
// A warning rather than a refusal, because the value is still a value and both
// halves can be read and written by hand; what it cannot be is animated. A
// `Binding` has no `animateTo` at all - the journey's calls are on `Link` - so
// a journey reached by the described road has nothing to call.
//
// A `@Bus` carrying one is the ORDINARY spelling and warns about nothing: a
// journey is a value the host can hold, which is the whole of what a bus takes.

extension State where Value: Journeying {
    /// Holds a value with a journey in it, and says that the tree cannot move
    /// one - see the note above for the spelling that can.
    ///
    /// - Parameter wrappedValue: the value this state holds.
    @available(*, deprecated, message: """
        An AnimatedValue is carried by a @Bus and by nothing else: what \
        closes the gap between where a value is and where it is going is the \
        host walking it frame by frame, and the tree has no frames to walk one \
        on. Declare it `@Bus private var fade = AnimatedValue(1.0)` - or hold \
        the plain value in @State, where an assignment travels because the \
        differ says so.
        """)
    public convenience init(wrappedValue: Value) {
        self.init(holding: wrappedValue)
    }

    /// Holds one at file scope, and says the same thing `init(wrappedValue:)`
    /// above does.
    ///
    /// - Parameter initialValue: the value this state holds.
    @available(*, deprecated, message: """
        An AnimatedValue is carried by a @Bus and by nothing else: what \
        closes the gap between where a value is and where it is going is the \
        host walking it frame by frame, and the tree has no frames to walk one \
        on. Declare it `@Bus private var fade = AnimatedValue(1.0)` - or hold \
        the plain value in @State, where an assignment travels because the \
        differ says so.
        """)
    public convenience init(_ initialValue: Value) {
        self.init(holding: initialValue)
    }
}
