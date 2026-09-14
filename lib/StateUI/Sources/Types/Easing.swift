// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// How an animation spends its time.
//
// The numbers are this library's own, as every closed vocabulary's on this wire
// are: declaration order from 0, written out, fixed forever. A host maps each
// case onto the curve it names, and no toolkit's numbering reaches the wire.
// Appending a case is free; inserting or reordering one is not - a moved number
// is read as a different curve, with nothing failing anywhere.
//
// An easing is a curve from 0 to 1: given how far through the animation is, it
// says how far through the CHANGE should be. Linear is the straight line, and
// every other one here is worth having only because it is not.

/// The curve an animation follows.
///
/// Half of an eased law - the other half being how long it takes:
///
///     @State private var fade = 1.0
///     …
///     Border { … }.opacity($fade)
///     …
///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
///
/// The numbers are this library's own, as they are everywhere else on this
/// wire. `In` accelerates from a standstill, `Out` decelerates into one, and
/// `InOut` does both - which is why `.cubicOut` is the one to reach for when
/// something arrives on screen, and `.cubicIn` when it leaves.
public enum Easing: Int32, Sendable {
    /// A straight line: the same speed from beginning to end.
    case linear = 0

    /// Slow at the end, following a sine curve.
    case sineOut = 1

    /// Slow at the start, following a sine curve.
    case sineIn = 2

    /// Slow at both ends, following a sine curve.
    case sineInOut = 3

    /// Slow at the start, and more pronounced than `.sineIn`.
    case cubicIn = 4

    /// Slow at the end, and more pronounced than `.sineOut`. The usual choice for
    /// something appearing.
    case cubicOut = 5

    /// Slow at both ends, and more pronounced than `.sineInOut`.
    case cubicInOut = 6

    /// Overshoots at the end and settles back, twice.
    case bounceOut = 7

    /// Bounces before it sets off.
    case bounceIn = 8

    /// Pulls back before it sets off, the way a spring loads.
    case springIn = 9

    /// Overshoots the target and comes back to it.
    case springOut = 10

    var propValue: PropValue { .enumeration(rawValue) }
}
