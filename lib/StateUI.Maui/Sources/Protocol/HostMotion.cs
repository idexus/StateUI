// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Protocol;

/// <summary>
/// How a value travels: the law and the numbers it needs, as Swift's
/// <c>Motion</c> crosses the wire.
/// </summary>
/// <remarks>
/// The numbers are the wire's as they arrive. <c>MotionLaw</c> reads them the
/// way the core's <c>HostMotionLaw</c> does, holding a spring's response to a
/// millisecond and its damping off nought there and nowhere else.
/// </remarks>
internal readonly struct HostMotion
{
    /// <summary>Which law a movement follows: Swift's <c>Motion.Law</c>, by its wire number.</summary>
    internal enum Law
    {
        /// <summary>A stated length on a stated curve.</summary>
        Eased = 0,

        /// <summary>A mass on a spring - no length, only a response.</summary>
        Spring = 1,
    }

    /// <summary>The law this motion travels under.</summary>
    internal Law Kind { get; private init; }

    /// <summary>Milliseconds: how long an eased motion takes, or a spring's response.</summary>
    internal uint Millis { get; private init; }

    /// <summary>The curve an eased motion follows.</summary>
    internal HostEasing Curve { get; private init; }

    /// <summary>A spring's damping. Nought where the law has no use for one.</summary>
    internal double Factor { get; private init; }

    /// <summary>Whether this motion moves nothing - the value simply arrives.</summary>
    internal bool Instant => Kind == Law.Eased && Millis == 0;

    /// <summary>A stated length on a stated curve.</summary>
    /// <param name="millis">How long it takes, in milliseconds.</param>
    /// <param name="curve">The curve it follows.</param>
    internal static HostMotion Eased(uint millis, HostEasing curve) =>
        new() { Kind = Law.Eased, Millis = millis, Curve = curve };

    /// <summary>A mass on a spring.</summary>
    /// <param name="response">The period, in milliseconds.</param>
    /// <param name="damping">1 for a spring that does not overshoot.</param>
    internal static HostMotion Spring(uint response, double damping) =>
        new() { Kind = Law.Spring, Millis = response, Factor = damping };

    /// <summary>A motion from the four numbers the wire carries for one.</summary>
    /// <remarks>
    /// A law this side does not know is the eased one, so a motion from a newer
    /// Swift side still arrives in the time it states.
    /// </remarks>
    /// <param name="law">The law, as its <see cref="Law"/> number.</param>
    /// <param name="millis">The length, or the response.</param>
    /// <param name="curve">The curve, as its <see cref="HostEasing"/> number.</param>
    /// <param name="factor">The damping.</param>
    internal static HostMotion Of(int law, uint millis, int curve, double factor) =>
        (Law)law switch
        {
            Law.Spring => Spring(millis, factor),
            _ => Eased(millis, (HostEasing)curve),
        };
}
