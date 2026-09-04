// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A value the HOST moves, and the question a binding to one answers.
//
// `@DrivenState` is a `State` with the host's image behind it: the same box,
// the same storage, the same adoption across a render - and a value read and
// written through lanes the host writes between renders, with nothing recorded
// and no view ever built for it. A SUBCLASS rather than a word in `@State`'s
// brackets, so that the wrapper's NAME says what kind of state it is and the
// brackets are left for what else is true of one, and so that the constraint
// rides the generic parameter: a value the host can hold nothing of is refused
// at the declaration rather than at a member.

/// State the HOST moves, which the tree is never told about.
///
///     @DrivenState private var scrolled = 0.0
///
///     ScrollReader(across: 540) { … }.scrollX($scrolled)
///
/// Declared and kept like any other state - the same value is here across every
/// render, found by the property's own name - but read and written with nothing
/// recorded, so no view is ever built for it. What such a value is for is
/// arithmetic the HOST runs, frame by frame, with no tree in between: a
/// scroller's offset, a finger's drag, a run of placements. See
/// `.engine(following:)`.
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
/// A STATE RATHER THAN A WORD IN `@State`'s BRACKETS, and it stands beside
/// `@EngineState` for the same reason: the wrapper's NAME says what kind of
/// state it is, and the brackets are left to say what else is true of one -
/// a cadence, a persistent key. The constraint rides the generic parameter, so
/// a value the host can hold nothing of is refused at the declaration.
///
/// THREAD-SAFE both ways: a write from a handler or a Task lands WHOLE and is
/// read by the next cycle, never half way through the one running.
@propertyWrapper
public final class DrivenState<Value: StateValue>: State<Value>, @unchecked Sendable {
    /// State the host moves, holding `wrappedValue` until it does.
    ///
    /// EAGER where a `@State`'s expression is lazy: the image the host writes
    /// into is made OF the value, so there is nothing left to defer.
    ///
    /// - Parameter wrappedValue: where the value stands before anything has
    ///   moved it.
    public init(wrappedValue: Value) {
        super.init(making: { wrappedValue })

        drive(from: wrappedValue)
    }

    /// The value, read and written through the image the host holds.
    ///
    /// Declared here and not merely inherited because `@propertyWrapper` takes
    /// no inherited `wrappedValue` - *"property wrapper type 'DrivenState' does
    /// not contain a non-static property named 'wrappedValue'"*.
    public override var wrappedValue: Value {
        get { super.wrappedValue }
        set { super.wrappedValue = newValue }
    }

    /// What `$scrolled` gives: this state, for a modifier to drive a property
    /// from or an engine to follow.
    public override var projectedValue: Binding<Value> { super.projectedValue }
}

extension State where Value: StateValue {
    /// Puts this state where the HOST can move it, which is what a
    /// `@DrivenState` arms itself with.
    ///
    /// On `State` rather than on `DrivenState`, because everything it writes -
    /// the image, and the two closures that read and write through it - is
    /// machinery the base class already owns. What the subclass adds is the
    /// constraint and the name.
    ///
    /// - Parameter value: where the value stands before anything moves it.
    fileprivate func drive(from value: Value) {
        let image = HostStorage(StateImage.bytes(of: value.carried))

        Renderer.shared.board(of: image).hold(image)

        host = image
        reads { image in
            Value(carried: Renderer.shared.board(of: image).read(image, lanes: Value.lanes))
                ?? State.nothing
        }
        writes { image, value in
            Renderer.shared.board(of: image).write(StateImage.bytes(of: value.carried), to: image)
        }
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

/// What an engine can be told to FOLLOW. This library's own.
///
/// What `$scrolled` answers to when it is handed to `.engine(following:)` or to
/// a scroller to report into. A binding to state the tree describes conforms
/// too and answers nothing, which is what lets a modifier say so rather than
/// fail to compile against a distinction the author cannot see.
///
/// Named for the one place it is written - `following:` - because the name
/// `DrivenState` belongs to the declaration an author writes, and one word
/// cannot be both a wrapper and the question asked about a binding to it.
public protocol Followable {
    /// Where the state lives when the host moves it, and nothing otherwise.
    var driving: HostStorage? { get }
}

extension Binding: Followable {
    /// Where the borrowed state lives when the HOST is what moves it, and
    /// nothing where the tree describes it.
    ///
    /// What every modifier driven by state asks first: a property can only be
    /// driven by a value the host can write into, which is the image behind
    /// `@DrivenState`.
    public var driving: HostStorage? { lender as? HostStorage }

    /// The number the host quotes that state by, where there is one.
    var number: Int32? { driving.map { Renderer.shared.number(for: $0) } }
}
