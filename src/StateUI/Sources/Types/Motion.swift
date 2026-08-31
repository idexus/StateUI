// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// HOW A VALUE MOVES WHEN IT CHANGES.
//
// The tree describes where the interface is GOING; the host's engine is how the
// screen catches up. This is the whole of what an author says about that
// catching up - one vocabulary, used in three places and meaning the same thing
// in all of them:
//
//     Application.motion            what everything moves at, by default
//     .motion(.none)                what THIS element does instead
//     $fade.animateTo(0.1, .spring())   what THIS write does instead
//
// Nothing about a motion rides the wire except the resolved numbers: a length
// and a curve, or a spring's two, or a friction. The frames themselves are the
// host's and never cross - that is not the wire's work.
//
// The three laws are the three shapes a movement can have. A LENGTH is a
// movement that takes as long as it is told, whatever the distance. A SPRING is
// a movement with no length at all: it answers as quickly as its response says
// and settles when it is done, which is what makes an interrupted one carry on
// rather than start over. A DECAY is speed alone, bled off - a throw, with no
// destination but the one it runs out at.

/// How a value moves when it changes. This library's own.
///
/// A change is a MOTION by default - assign a state and the control travels
/// there - and this is what says how:
///
///     VStack { … }.motion(.spring(response: 260))
///
///     try await $fade.animateTo(0.1, .eased(400, .cubicOut))
///
/// `.none` is how something snaps: the value is written and the screen is
/// already showing it. Every other case names a law and the numbers it needs.
public struct Motion: Equatable, Sendable {
    /// Which law a movement travels under, as the wire carries it.
    ///
    /// The numbers are this library's own, as every closed vocabulary's on this
    /// wire are: declaration order from 0, fixed forever. See Types/Easing.swift
    /// for why nothing here is ever a platform's own numbering.
    enum Law: Int32, Sendable {
        /// A stated length on a stated curve.
        case eased = 0

        /// A mass on a spring - no length, only a response.
        case spring = 1

        /// Speed alone, bled off at a stated friction.
        case decay = 2
    }

    /// The law this motion travels under.
    let law: Law

    /// Milliseconds: how long an eased motion takes, or a spring's response.
    let millis: UInt32

    /// The curve an eased motion follows.
    let curve: Easing

    /// A spring's damping, or a throw's friction - whichever its law needs.
    let factor: Double

    /// Whether this motion is the one its element resolves to rather than one
    /// of its own.
    let isInherited: Bool

    /// Whatever the element this is written on resolves to - the element's own
    /// motion, or the application's, or this library's.
    ///
    /// What a write means when it says nothing about how to travel, which is
    /// what makes `.animateTo(x)` and a plain assignment agree about the
    /// motion and differ only in being awaited.
    public static let inherited = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: true)

    /// No motion: the value is written and the screen is already showing it.
    ///
    /// The escape from everything here, and it costs nothing at all - a value
    /// that snaps is a value with no motion beside it on the wire.
    public static let none = Motion(
        law: .eased, millis: 0, curve: .cubicOut, factor: 0, isInherited: false)

    /// A movement of a stated length on a stated curve.
    ///
    ///     .motion(.eased(400, .cubicOut))
    ///
    /// It takes as long as it is told however far it has to go, which is what
    /// makes it the right law for something whose distance the author knows -
    /// a fade, a page that slides in, a card that turns over.
    ///
    /// - Parameters:
    ///   - length: how long it takes, in milliseconds.
    ///   - curve: how it spends that time. `.cubicOut` arrives gently, which is
    ///     what almost everything on screen wants.
    /// - Returns: the motion.
    public static func eased(_ length: UInt, _ curve: Easing = .cubicOut) -> Motion {
        Motion(
            law: .eased,
            millis: UInt32(truncatingIfNeeded: length),
            curve: curve,
            factor: 0,
            isInherited: false)
    }

    /// A mass on a spring, which answers a change rather than timing it.
    ///
    ///     .motion(.spring(response: 260))
    ///
    /// It has no length: a spring settles when it is done, and one whose target
    /// moves mid-flight simply carries on from the speed it had. That is what
    /// makes it right for anything a reader can interrupt - a card being
    /// dragged, a value they are still choosing.
    ///
    /// - Parameters:
    ///   - response: how quickly it answers, in milliseconds. Smaller is
    ///     snappier.
    ///   - damping: 1 comes to rest without overshooting. Below 1 overshoots
    ///     and rings, which is a deliberate purchase and never a default: half
    ///     a card's worth of wobble is what a reader reads as a mistake.
    /// - Returns: the motion.
    public static func spring(response: UInt = 300, damping: Double = 1) -> Motion {
        Motion(
            law: .spring,
            millis: UInt32(truncatingIfNeeded: max(response, 1)),
            curve: .linear,
            factor: max(damping, 0.05),
            isInherited: false)
    }

    /// Speed alone, bled off - a throw with no destination but the one it runs
    /// out at.
    ///
    ///     .motion(.decay(friction: 0.006))
    ///
    /// The value it is given is where it starts, not where it ends: a decay
    /// carries whatever speed the movement before it had and comes to rest
    /// wherever that speed takes it.
    ///
    /// - Parameter friction: how fast the speed bleeds away, per millisecond.
    ///   Larger stops sooner.
    /// - Returns: the motion.
    public static func decay(friction: Double = 0.004) -> Motion {
        Motion(
            law: .decay,
            millis: 0,
            curve: .linear,
            factor: max(friction, 0.0001),
            isInherited: false)
    }

    /// Whether this motion moves nothing - the value simply arrives.
    var isNothing: Bool {
        !isInherited && law == .eased && millis == 0
    }

    /// This motion, or `fallback` where this is the inherited one.
    func resolved(against fallback: Motion) -> Motion {
        isInherited ? fallback : self
    }

    /// What everything moves at unless something says otherwise.
    ///
    /// Two hundred milliseconds is the one soft-stop this library already has -
    /// the landing every scroller makes - so there is ONE number for the whole
    /// system rather than a second one to explain beside it.
    public static let standard = Motion.eased(200, .cubicOut)
}
