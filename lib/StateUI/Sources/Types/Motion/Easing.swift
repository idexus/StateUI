// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Easing curves: a closed vocabulary, numbered by StateUI.
// Design: docs/design/types/motion.md#easing-curves

/// The curve an animation follows; with a duration, it makes an eased motion.
///
///     @State private var fade = 1.0
///     …
///     VStack { … }.opacity($fade)
///     …
///     try await $fade.journey.move(to: 0.1, .eased(400, .cubicOut))
///
/// `In` curves start slowly, `Out` curves end slowly, and `InOut` curves do
/// both: `.cubicOut` suits something arriving on screen, `.cubicIn` something
/// leaving it.
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
