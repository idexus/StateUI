// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A value the HOST WALKS, and the plain name is where it is going.
//
// The fourth declaration, and the only one whose bare name is not where the
// value IS. That is deliberate and it is the rest of this library's rule said
// once more: a value that changes is a SETPOINT - the tree says where it is
// going and the host takes the control there - so `rotation = 10` means "go to
// 10" here exactly as it does on a `@State` that some element is showing.
// `$rotation.value` is the deliberate escape to what is on the screen.
//
// It holds ONE thing, the image, and stores nothing beside it - a declaration
// of its own rather than a kind of `Bus`, so that what it offers is what it can
// honour. A bus carries a value of ANY shape the host can hold, a raw run of
// numbers included, and offers no journey; this carries a journey and takes
// only what can be walked.

/// State the HOST WALKS: where the value is going, where it has got to, and how
/// fast.
///
///     @Animated private var rotation = 0.0
///
///     Image("dial").rotation($rotation)
///
///     rotation = 10                    // travels there
///     $rotation.value = 10             // snaps; any travel ends
///     $rotation.velocity               // how fast it is going, per second
///     try await $rotation.animateTo(10, .spring())
///
/// **THE PLAIN NAME IS THE TARGET, both read and written.** Reading `rotation`
/// on the line after `rotation = 10` answers 10, not what is on the screen -
/// the state stands at the destination the whole way, which is what lets a
/// render in the middle of a travel say nothing and lets the travel go on. What
/// is ON THE SCREEN is `$rotation.value`, and writing that one SNAPS.
///
/// Declared and kept like any other state - the same value is here across every
/// render, found by the property's own name - but read and written with nothing
/// recorded, so no view is ever built for it and a travel costs no render at
/// all. To SHOW one as it moves, drive the letters: `Label().text($caption)`
/// off a `@Bus`.
///
/// **WHAT IT TAKES IS WHAT CAN BE WALKED** - `Walked`, on the generic
/// parameter, so a value with no half way is refused at the declaration rather
/// than standing still at run time. Text, a whole number and a truth value are
/// out; they are `@Bus`'s, which offers no journey and takes any shape the host
/// can hold.
@propertyWrapper
public final class Animated<Value: Walked>: @unchecked Sendable {
    /// Where the journey lives - an image of lanes the host rewrites between
    /// renders, rather than a box this side settles.
    ///
    /// The one thing it stores, and the one thing adoption moves: the number
    /// the host quotes the value by is issued against the image, so a box that
    /// kept the one it was BUILT with would be given a new number every render
    /// and the host would be walking a value nothing reads.
    private(set) var image: HostStorage

    /// A value standing still where it says, travelling the way the element
    /// showing it does.
    ///
    /// EAGER where a `@State`'s expression is lazy: the image the host walks is
    /// made OF the value, so there is nothing left to defer.
    ///
    /// - Parameter wrappedValue: where the value stands, which is also where it
    ///   is going until something moves it.
    public convenience init(wrappedValue: Value) {
        self.init(wrappedValue: wrappedValue, motion: .inherited)
    }

    /// A value with a law of ITS OWN, whoever shows it.
    ///
    ///     @Animated(motion: .spring()) private var position = 0.0
    ///
    /// **THE VALUE'S LAW BEATS THE ELEMENT'S, and only for this property.** An
    /// element's `.motion(_:)` says how everything that element does travels;
    /// this says how this one value travels wherever it is shown - so a colour
    /// driven from one state can travel the application's way while a
    /// coordinate driven from another, on the same element, travels its own.
    ///
    /// Said HERE rather than written afterwards because a law written outside a
    /// cycle waits for the next one to be latched: at the declaration it is on
    /// the image from the first frame, which is the one an entrance is seen on.
    ///
    /// - Parameters:
    ///   - wrappedValue: where the value stands, which is also where it is
    ///     going until something moves it.
    ///   - motion: the law it travels under. `.inherited` - which is what
    ///     leaving this out means - asks the element showing it, afresh at
    ///     every crossing.
    public init(wrappedValue: Value, motion: Motion) {
        image = HostStorage(
            StateImage.bytes(of: AnimatedValue(wrappedValue, motion: motion).carried))

        Renderer.shared.board(of: image).hold(image)
    }

    /// Where the value is GOING. Written, it is sent there under the law the
    /// element resolves; read, it answers the destination and not the screen.
    ///
    /// Neither half records anything: a read inside a body is not a dependency
    /// and a write asks for no render.
    public var wrappedValue: Value {
        get { Animated.read(image).setPoint }

        set {
            var journey = Animated.read(image)

            journey.setPoint = newValue

            Animated.write(journey, to: image)
        }
    }

    /// What `$rotation` gives: the whole journey, for a modifier to drive a
    /// property from, an engine to follow, or `animateTo` to send.
    ///
    /// A `Binding` of the same type a driven modifier has always taken, which
    /// is what lets `.opacity($fade)` and `try await $fade.animateTo(…)` mean
    /// here exactly what they meant before this declaration existed.
    public var projectedValue: Binding<AnimatedValue<Value>> {
        let image = image

        return Binding(
            read: { Animated.read(image) },
            write: { Animated.write($0, to: image) },
            lender: image,
            lent: nil)
    }

    /// Reads the target, as the plain name does.
    ///
    /// For a value held WITHOUT the wrapper - at file scope, where Swift allows
    /// no property wrapper at all. On `@Animated private var rotation = 0.0`
    /// the plain name reads the same thing, and that is the spelling to use.
    public func get() -> Value { Animated.read(image).setPoint }

    /// The number the host quotes this state by, issued the first time anything
    /// asks.
    var number: Int32 { Renderer.shared.number(for: image) }

    /// The journey as the lanes stand, or one standing still at nought where
    /// those bytes stand for no value of this type.
    private static func read(_ image: HostStorage) -> AnimatedValue<Value> {
        AnimatedValue<Value>(
            carried: Renderer.shared.board(of: image).read(
                image, lanes: AnimatedValue<Value>.lanes))
            ?? nothing
    }

    /// The journey written into the lanes, whole.
    private static func write(_ journey: AnimatedValue<Value>, to image: HostStorage) {
        Renderer.shared.board(of: image).write(
            StateImage.bytes(of: journey.carried), to: image)
    }

    /// What this answers where its bytes stand for no journey of this type -
    /// every lane at nought.
    ///
    /// Nothing on this side can bring it about, the setter writing the type's
    /// own bytes; a HOST that wrote the wrong lane count could, and a picture
    /// frozen for a frame is the right answer to that where a trap would take
    /// the application down.
    private static var nothing: AnimatedValue<Value> {
        AnimatedValue<Value>(
            carried: .lanes(Array(repeating: 0, count: max(AnimatedValue<Value>.lanes, 0))))
            ?? AnimatedValue(Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0))))!)
    }
}

extension Animated: StateBox {
    /// Takes over the other box's image, so the two are one piece of state from
    /// here on - which is how an `@Animated` on a view survives the view being
    /// a value rebuilt every render.
    func adopt(from other: AnyObject) {
        guard let other = other as? Animated<Value>, other !== self else { return }

        image = other.image
    }

    /// Tells the image what the author calls it, so a render explained in names
    /// has one for this state.
    func named(_ path: String) {
        image.origin = BuildScope.readable(path)
    }
}
