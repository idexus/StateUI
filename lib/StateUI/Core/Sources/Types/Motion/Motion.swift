// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How a value animates when it changes: one vocabulary for the application, an
// element, a state and a single write.
// Design: docs/design/types/motion.md#one-vocabulary-in-four-places

/// How a value animates when it changes.
///
/// A change animates by default - assign a state and the control animates to
/// the new value - and a motion says how:
///
///     VStack { … }.motion(.spring(response: .milliseconds(260)))
///
///     $fade.journey.move(to: 0.1, .eased(.milliseconds(400), .cubicOut))
///
/// `.none` applies a change at once. `.custom` hands the animation to an
/// engine of your own. `.eased` and `.spring` name a timing law and its
/// numbers.
///
/// Design: docs/design/types/motion.md#two-laws
public struct Motion: Equatable, Sendable {
    /// What a motion is, each kind with only its own numbers.
    /// Design: docs/design/types/motion.md#two-laws
    @_spi(Host) public enum Kind: Equatable, Sendable {
        /// The element's motion, else the application's, else `standard`.
        case inherited

        /// No animation.
        case none

        /// An engine of the application's animates the value.
        case custom

        /// A stated duration, in milliseconds, on a stated curve.
        case eased(milliseconds: UInt32, curve: Easing)

        /// A spring's response, in milliseconds, and its damping.
        case spring(milliseconds: UInt32, damping: Double)

        /// A glide setting out at the value's speed, in milliseconds the longest it takes.
        case glide(milliseconds: UInt32)
    }

    /// What this motion is.
    @_spi(Host) public let kind: Kind

    /// An eased motion's length or a spring's response, in milliseconds; nought for a motion the host does not
    /// time.
    @_spi(Host) public var milliseconds: UInt32 {
        switch kind {
        case .eased(let milliseconds, _), .spring(let milliseconds, _), .glide(let milliseconds): milliseconds
        case .inherited, .none, .custom: 0
        }
    }

    /// Whether the host animates a change under this motion: an eased or a spring one - never `none`, an engine's
    /// own, or the inherited one before it is resolved.
    @_spi(Host) public var animates: Bool {
        switch kind {
        case .eased, .spring, .glide: true
        case .inherited, .none, .custom: false
        }
    }

    /// The motion the element resolves to: its own, else the application's,
    /// else `standard`.
    ///
    /// What a write means when it names no motion, so a plain assignment and
    /// `move(to:)` agree about the motion and differ only in `move(to:)`
    /// answering an `Arrival` whose `arrived()` waits.
    public static let inherited = Motion(kind: .inherited)

    /// No animation: the change is applied at once.
    public static let none = Motion(kind: .none)

    /// The animation is yours: a write moves only the destination, the host
    /// animates nothing, and an engine of your own writes where the value is
    /// and how fast it is going, frame by frame, reading the destination back.
    ///
    ///     @State(motion: .custom) private var ball = 0.0
    ///
    ///     Rectangle()
    ///         .translationY($ball)
    ///         .engine(tracking: $ball) { cycle in
    ///             let journey = $ball.journey
    ///             let seconds = cycle.elapsed / 1000
    ///             // A spring towards the destination, damped by the speed.
    ///             let pull = (journey.destination - journey.value) * 180 - journey.velocity * 24
    ///             journey.velocity += pull * seconds
    ///             journey.value += journey.velocity * seconds
    ///             let resting = abs(journey.destination - journey.value) < 0.5 && abs(journey.velocity) < 1
    ///             guard resting else { return .again }
    ///             journey.value = journey.destination
    ///             journey.velocity = 0
    ///             return .wait
    ///         }
    ///
    /// Unlike `.none`, a write changes only where the value is going; where it
    /// is stays put until the engine moves it. Declare it on the state, since
    /// which side animates a state is fixed when the state first reaches the
    /// host.
    ///
    /// Design: docs/design/types/motion.md#custom-animates-in-an-engine
    public static let custom = Motion(kind: .custom)

    /// An animation of a stated duration on a stated curve.
    ///
    ///     .motion(.eased(.milliseconds(400), .cubicOut))
    ///
    /// It takes the stated time whatever the distance: right for something
    /// whose distance is known, such as a fade, a page sliding in, or a card
    /// turning over. One that takes no time is `none`.
    ///
    /// - Parameters:
    ///   - length: how long it takes, to the millisecond.
    ///   - curve: how it spends that time. `.cubicOut` arrives gently, which is
    ///     what almost everything on screen wants.
    /// - Returns: the motion.
    public static func eased(_ length: Duration, _ curve: Easing = .cubicOut) -> Motion {
        let milliseconds = Motion.milliseconds(of: length)

        return milliseconds == 0 ? .none : Motion(kind: .eased(milliseconds: milliseconds, curve: curve))
    }

    /// A glide: the value sets out at the speed it has and slows onto its destination on `cubicOut`, as long as that
    /// speed takes there - never shorter than `HostMotionLaw.shortestGlide`, nor longer than `longest`.
    /// Design: docs/design/types/motion.md#a-glide
    static func glide(within longest: Duration) -> Motion {
        let milliseconds = Motion.milliseconds(of: longest)

        return milliseconds == 0 ? .none : Motion(kind: .glide(milliseconds: milliseconds))
    }

    /// A mass on a spring, which answers a change rather than timing it.
    ///
    ///     .motion(.spring(response: .milliseconds(260)))
    ///
    /// It has no duration: a spring settles when it is done, and one whose
    /// destination changes mid-animation carries on from the speed it had.
    /// That makes it right for anything the user can interrupt - a card being
    /// dragged, a value still being chosen.
    ///
    /// - Parameters:
    ///   - response: how quickly it answers, to the millisecond. Smaller is
    ///     snappier.
    ///   - damping: 1 comes to rest without overshooting; below 1 overshoots
    ///     and oscillates, which is rarely what a user expects. A damping that
    ///     is no number is 1.
    /// - Returns: the motion.
    public static func spring(response: Duration = .milliseconds(300), damping: Double = 1) -> Motion {
        Motion(kind: .spring(
            milliseconds: max(Motion.milliseconds(of: response), 1),
            damping: damping.isFinite ? max(damping, 0.05) : 1))
    }

    /// This motion, or `fallback` where this is the inherited one.
    func resolved(against fallback: Motion) -> Motion {
        kind == .inherited ? fallback : self
    }

    /// The default motion: 200 milliseconds on `.cubicOut`, for ordinary
    /// changes and a scroller's landing.
    public static let standard = Motion.eased(.milliseconds(200), .cubicOut)

    /// A length in whole milliseconds, nought for one before none, rounded to the nearest.
    static func milliseconds(of length: Duration) -> UInt32 {
        let (seconds, attoseconds) = length.components
        let whole = Double(seconds) * 1_000 + Double(attoseconds) / 1e15

        return UInt32(min(max(whole.rounded(), 0), Double(UInt32.max)))
    }
}
