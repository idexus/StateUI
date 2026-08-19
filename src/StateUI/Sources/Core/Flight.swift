// ANIMATION IS STATE, not a command.
//
// A modifier written from a BINDING rather than from a value ARMS the property
// it sets - it writes the value and, beside it, a note of whose state that was.
// Flying that state is then what animates every control armed with it:
//
//     @State private var fade = 1.0
//
//     Border { … }.opacity($fade)
//
//     Button("Fade").onClicked {
//         try await $fade.animateTo(0.1, length: 400, easing: .cubicOut)
//     }
//
// `fade = 0.1` snaps; `$fade.animateTo(0.1, …)` walks there. The same modifier
// does both, arming being nothing more than which of the two it was handed.
//
// THE STATE IS GIVEN THE TARGET AT ONCE and the HOST walks the control. So the
// tree always describes where a value is GOING: a render in the middle of a
// walk re-reads the target, finds it unchanged, says nothing, and the walk goes
// on. Nothing has to be put back afterwards, and nothing has to be guarded
// against an unrelated rebuild.
//
// The corollary is the one trap here: assigning an armed property ENDS the walk
// on it, so never write the state and then fly it to what was just written -
// the flight would have nothing left to do. `stop()` is the deliberate form of
// the same thing, and it writes back where the control had got to.
//
// THE WALK RIDES BESIDE THE PROPERTY, never inside its value. It is a
// transitions FIELD of its own carrying four things - how long, on what curve,
// which completion is waiting, how often to report - because a wrapped value
// answers nil from every typed accessor on the far side and would simply not
// be written, silently. `Renderer.settle` resolves a flight no property
// claimed.
//
// WHAT MATCHES THE TWO HALVES UP is `FlightKey`, below: `$fade` builds a new
// binding every time it is written, so the one that armed a property and the
// one a handler flies with are two values that have never met.

/// Which piece of state a flight is about.
///
/// The lender's ADDRESS and, when the binding is one property of what it
/// borrows, which property - so `$profile.opacity` and `$profile.scale` are
/// two flights and not one. Both halves come from the binding, which is what
/// lets the modifier that armed a property and the handler that flies it
/// recognize each other without ever having met.
///
/// `@unchecked` for the second half, which is whatever the spelling that made
/// the binding had to hand - a key path for `$profile.opacity`, an index for
/// `$hops[2]` - and which nothing here can write to.
struct FlightKey: Hashable, @unchecked Sendable {
    let lender: ObjectIdentifier
    let lent: AnyHashable?
}

/// A flight an author has started that no message has carried yet.
///
/// It lives for one render: the walk that follows finds the properties armed
/// on this state among the ones that CHANGED, writes a transition beside each,
/// and the flight becomes the host's business. One that no property claimed is
/// resolved on the spot - see `Renderer.settle`.
struct PendingFlight {
    /// How long the walk is to take, in milliseconds.
    let length: UInt32

    /// The curve it walks on.
    let easing: Easing

    /// The completion the handler that started this is suspended on - one of
    /// the negative ids every act answers on, quoted back when the last
    /// property flown on it has landed.
    let channel: Int32

    /// How many milliseconds apart the host is to say where the walk has got
    /// to, or 0 when nobody asked. See `Binding.animateTo(_:reporting:every:)`.
    let report: UInt32

    /// Held, and held STRONGLY, because `FlightKey` is an address: a lender
    /// released while its flight is pending would let the next object at that
    /// address be flown by mistake. Invalidation can afford to err toward
    /// rebuilding; this cannot.
    let lender: AnyObject
}

extension Binding {
    /// The key a flight on this binding is filed under - nil for a binding
    /// made from closures, which borrows from nobody nameable.
    var flightKey: FlightKey? {
        lender.map { FlightKey(lender: ObjectIdentifier($0), lent: lent) }
    }

    /// Starts a flight and suspends until it lands.
    ///
    /// The state is given the TARGET at once - a read anywhere answers where
    /// the value is going, not where it is - and what glides is the control.
    /// `reporting` is where the host writes what the control is SHOWING, every
    /// `interval` milliseconds of the walk; nil asks for no reports at all, and
    /// the walk then crosses the boundary exactly twice.
    nonisolated(nonsending) func fly(
        to target: Value,
        length: UInt,
        easing: Easing,
        every interval: UInt = 0,
        reporting: ((PropValue) -> Void)? = nil
    ) async throws -> Bool {
        guard let key = flightKey else {
            throw StateUIError(message: """
                This binding has nothing behind it to fly: it was made with \
                Binding(get:set:), which borrows from a pair of closures. \
                Only a binding to @State, or to one of its properties, can be \
                animated - a flight is the state moving.
                """)
        }

        let values = try await Renderer.shared.fly(
            key,
            length: UInt32(length),
            easing: easing,
            every: reporting == nil ? 0 : UInt32(max(interval, 1)),
            reporting: reporting,
            lender: lender!,
            commit: { wrappedValue = target })

        return values.first?.bool == true
    }
}

extension Binding {
    /// Whether a flight owns this state right now - the host walking a control
    /// some property armed with it.
    ///
    /// What it is for: a TWO-WAY input reports the very property it is bound
    /// to, and the platform raises that report for a value it is itself walking
    /// as readily as for a finger. Measured on a MAUI `Slider`: five
    /// assignments to `Value`, five `ValueChanged`. Writing those back would be
    /// an assignment to an armed property, which is what ENDS a walk - so the
    /// flight would die on its own first frame, having asked for a render on
    /// the way, and every frame after it until it did.
    ///
    /// There is also nothing an intermediate report could correctly say: while
    /// a flight is on, the state already holds the TARGET - that is the whole
    /// model - so a report of where the control has GOT to would contradict it.
    /// An author who wants the sweep asks for it with
    /// `animateTo(_:reporting:every:)`, into a SECOND piece of state.
    ///
    /// A drag the reader makes mid-flight is ignored with them: the flight is
    /// what the application asked for last, and `stop()` is how it gives the
    /// control back.
    var isFlying: Bool {
        guard let key = flightKey else { return false }
        return Renderer.shared.flownChannel(for: key) != nil
    }

    /// Stops the walk this state is on, and answers where it had got to - or
    /// nothing at all when nothing was flying.
    ///
    /// The state is written with the answer, which is what keeps the tree and
    /// the control saying the same thing: a walk that was stopped halfway has
    /// left the control somewhere the tree never named, and this is how the
    /// tree learns it. The flight itself resolves false, the way anything that
    /// did not run to the end does.
    nonisolated(nonsending) func stopped() async throws -> [PropValue] {
        guard let key = flightKey, let channel = Renderer.shared.flownChannel(for: key) else {
            return []
        }

        return try await Renderer.shared.call(.stopFlight, [.number(Double(channel))])
    }
}

extension Binding where Value == Double {
    /// Walks the properties armed with this state to `target`, and answers
    /// when they get there.
    ///
    ///     @State private var fade = 1.0
    ///
    ///     Border { … }.opacity($fade)
    ///
    ///     Button("Fade").onClicked { try await $fade.animateTo(0.1, length: 400) }
    ///
    /// The STATE is given the target immediately - reading `fade` on the line
    /// after this one answers 0.1, not what is on the screen - and the walk
    /// is the control's. Assigning `fade` instead of flying it snaps, which is
    /// the difference between the two spellings and the whole of it.
    ///
    /// - Parameters:
    ///   - target: where the value is going.
    ///   - length: how long the walk takes, in milliseconds.
    ///   - easing: the curve it walks on.
    ///   - reporting: a SECOND piece of state, written with what the control
    ///     is showing as it walks. The flying state stands at the target the
    ///     whole way - that is the model - so a reading that must SWEEP takes
    ///     this. Nil, the default, asks for nothing and the walk crosses the
    ///     boundary exactly twice. Never pass the state that is flying: an
    ///     assignment to an armed property is what ENDS a walk.
    ///   - every: how many milliseconds of the walk between reports, counted
    ///     on the walk's own clock rather than the wall's. The default of 100
    ///     is ten readings a second, which is what a number on screen needs;
    ///     the host's frames are its own and are never what crosses. Ignored
    ///     when nothing is being reported.
    /// - Returns: whether it ran to the end - false when another flight took
    ///   its place, or the app went away before it landed.
    /// - Throws: `StateUIError` when the binding has no state behind it.
    @discardableResult
    public nonisolated(nonsending) func animateTo(
        _ target: Double,
        length: UInt = 250,
        easing: Easing = .linear,
        reporting: Binding<Double>? = nil,
        every: UInt = 100
    ) async throws -> Bool {
        let watch: ((PropValue) -> Void)? = reporting.map { shown in
            { value in
                if let number = value.number { shown.wrappedValue = number }
            }
        }

        let landed = try await fly(
            to: target, length: length, easing: easing, every: every, reporting: watch)

        // A sample is a sample; the END is known exactly, and only a walk that
        // reached it may say so.
        if landed, let reporting = reporting { reporting.wrappedValue = target }

        return landed
    }

    /// Stops the walk this state is on, where it stands, and writes what the
    /// control had reached into the state.
    ///
    ///     Button("Stop").onClicked { try await $fade.stop() }
    ///
    /// Nothing happens when nothing is flying. The flight that was stopped
    /// answers false, and the state now holds what is on the screen - so the
    /// tree and the control agree again, which a walk abandoned halfway would
    /// otherwise have broken.
    ///
    /// - Throws: `StateUIError` when the host could not be asked.
    public nonisolated(nonsending) func stop() async throws {
        if let reached = try await stopped().first?.number {
            wrappedValue = reached
        }
    }

}

extension Binding where Value == Color {
    /// Walks the properties armed with this state to `target`, and answers
    /// when they get there.
    ///
    ///     @State private var tint = Color("#3B82F6")
    ///
    ///     Border { … }.backgroundColor($tint)
    ///
    ///     Button("Warn").onClicked {
    ///         try await $tint.animateTo(Color("#EF4444"), length: 300)
    ///     }
    ///
    /// A `Color(light:dark:)` is resolved as the target is written, exactly as
    /// it would be if the value were assigned - so a flight walks to the half
    /// the theme is showing now.
    ///
    /// - Parameters:
    ///   - target: where the colour is going.
    ///   - length: how long the walk takes, in milliseconds.
    ///   - easing: the curve it walks on.
    ///   - reporting: a SECOND piece of state, written with what the control
    ///     is showing as it walks. The flying state stands at the target the
    ///     whole way - that is the model - so a reading that must SWEEP takes
    ///     this. Nil, the default, asks for nothing and the walk crosses the
    ///     boundary exactly twice. Never pass the state that is flying: an
    ///     assignment to an armed property is what ENDS a walk.
    ///   - every: how many milliseconds of the walk between reports, counted
    ///     on the walk's own clock rather than the wall's. The default of 100
    ///     is ten readings a second, which is what a number on screen needs;
    ///     the host's frames are its own and are never what crosses. Ignored
    ///     when nothing is being reported.
    /// - Returns: whether it ran to the end - false when another flight took
    ///   its place, or the app went away before it landed.
    /// - Throws: `StateUIError` when the binding has no state behind it.
    @discardableResult
    public nonisolated(nonsending) func animateTo(
        _ target: Color,
        length: UInt = 250,
        easing: Easing = .linear,
        reporting: Binding<Color>? = nil,
        every: UInt = 100
    ) async throws -> Bool {
        let watch: ((PropValue) -> Void)? = reporting.map { shown in
            { value in
                guard let channels = value.color else { return }

                shown.wrappedValue = Color(
                    red: channels.red,
                    green: channels.green,
                    blue: channels.blue,
                    alpha: channels.alpha)
            }
        }

        let landed = try await fly(
            to: target, length: length, easing: easing, every: every, reporting: watch)

        if landed, let reporting = reporting { reporting.wrappedValue = target }

        return landed
    }

    /// Stops the walk this state is on, where it stands, and writes the colour
    /// the control had reached into the state.
    ///
    /// Nothing happens when nothing is flying. What comes back is the colour ON
    /// SCREEN, so a state written with a `Color(light:dark:)` holds a plain one
    /// afterwards - the half that was showing, which is the only thing a
    /// stopped walk can honestly say.
    ///
    /// - Throws: `StateUIError` when the host could not be asked.
    public nonisolated(nonsending) func stop() async throws {
        guard let channels = try await stopped().first?.color else { return }

        wrappedValue = Color(
            red: channels.red,
            green: channels.green,
            blue: channels.blue,
            alpha: channels.alpha)
    }

}

extension Binding where Value == Thickness {
    /// Walks the properties armed with this state to `target`, and answers
    /// when they get there.
    ///
    ///     @State private var inset = Thickness(8)
    ///
    ///     VStack { … }.padding($inset)
    ///
    ///     Button("Open up").onClicked {
    ///         try await $inset.animateTo(Thickness(24), length: 200)
    ///     }
    ///
    /// Each edge walks on its own, so a flight from `Thickness(8)` to
    /// `Thickness(24, 8)` moves two of the four and leaves the rest.
    ///
    /// - Parameters:
    ///   - target: where the thickness is going.
    ///   - length: how long the walk takes, in milliseconds.
    ///   - easing: the curve it walks on.
    ///   - reporting: a SECOND piece of state, written with what the control
    ///     is showing as it walks. The flying state stands at the target the
    ///     whole way - that is the model - so a reading that must SWEEP takes
    ///     this. Nil, the default, asks for nothing and the walk crosses the
    ///     boundary exactly twice. Never pass the state that is flying: an
    ///     assignment to an armed property is what ENDS a walk.
    ///   - every: how many milliseconds of the walk between reports, counted
    ///     on the walk's own clock rather than the wall's. The default of 100
    ///     is ten readings a second, which is what a number on screen needs;
    ///     the host's frames are its own and are never what crosses. Ignored
    ///     when nothing is being reported.
    /// - Returns: whether it ran to the end - false when another flight took
    ///   its place, or the app went away before it landed.
    /// - Throws: `StateUIError` when the binding has no state behind it.
    @discardableResult
    public nonisolated(nonsending) func animateTo(
        _ target: Thickness,
        length: UInt = 250,
        easing: Easing = .linear,
        reporting: Binding<Thickness>? = nil,
        every: UInt = 100
    ) async throws -> Bool {
        let watch: ((PropValue) -> Void)? = reporting.map { shown in
            { value in
                guard let edges = value.numbers, edges.count == 4 else { return }

                shown.wrappedValue = Thickness(edges[0], edges[1], edges[2], edges[3])
            }
        }

        let landed = try await fly(
            to: target, length: length, easing: easing, every: every, reporting: watch)

        if landed, let reporting = reporting { reporting.wrappedValue = target }

        return landed
    }

    /// Stops the walk this state is on, where it stands, and writes the
    /// thickness the control had reached into the state - so the tree and the
    /// control agree again.
    ///
    /// Nothing happens when nothing is flying. The flight that was stopped
    /// answers false, the way anything that did not run to the end does.
    ///
    /// - Throws: `StateUIError` when the host could not be asked.
    public nonisolated(nonsending) func stop() async throws {
        guard let edges = try await stopped().first?.numbers, edges.count == 4 else { return }

        wrappedValue = Thickness(edges[0], edges[1], edges[2], edges[3])
    }

}
