// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Protocol;

/// <summary>
/// How a walked value lies in its lanes, as the core's <c>JourneyLanes</c> lays
/// it: where the value is, where it is going and how fast - three runs of the
/// value's own width - then the law's three lanes, the waiter and the stops.
/// </summary>
/// <remarks>
/// <para>
/// THE LAYOUT IS HERE AND NOWHERE ELSE on this side, and
/// <c>journey-lanes.txt</c>, written by the core from its own lanes, holds it
/// to the other (<c>JourneyCodecTests</c>).
/// </para>
/// <para>
/// The speed crosses per SECOND, which is what an author writes and reads; the
/// walker keeps it per millisecond. A law's first lane says which of five
/// things it is. The element's own crosses as itself, carrying no numbers, and
/// is the application's here: a value no element claims has nobody else's to
/// follow.
/// </para>
/// </remarks>
internal static class JourneyCodec
{
    /// <summary>What a law's first lane says it is.</summary>
    internal enum Law
    {
        /// <summary>No motion: the value arrives.</summary>
        None = 0,

        /// <summary>The element's own, which carries no numbers.</summary>
        Inherited = 1,

        /// <summary>A stated length on a stated curve.</summary>
        Eased = 2,

        /// <summary>A mass on a spring.</summary>
        Spring = 3,

        /// <summary>An application engine's walk, which the core never hands a host.</summary>
        Custom = 4,
    }

    /// <summary>How many lanes a law takes.</summary>
    internal const int LawLanes = 3;

    /// <summary>How many lanes a walked value takes.</summary>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static int Count(int width) => (width * 3) + LawLanes + 2;

    /// <summary>The first lane of where the value is going.</summary>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static int Destination(int width) => width;

    /// <summary>The first lane of how fast it is going.</summary>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static int Velocity(int width) => width * 2;

    /// <summary>The first of the law's lanes.</summary>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static int LawAt(int width) => width * 3;

    /// <summary>The lane of whoever is waiting for the value to arrive.</summary>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static int Waiter(int width) => (width * 3) + LawLanes;

    /// <summary>The lane counting the times a travel on the value was stopped.</summary>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static int Stops(int width) => (width * 3) + LawLanes + 1;

    /// <summary>Where the value is.</summary>
    /// <param name="lanes">The whole value.</param>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static double[] ValueOf(double[] lanes, int width) => lanes[..width];

    /// <summary>Where the value is going.</summary>
    /// <param name="lanes">The whole value.</param>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static double[] DestinationOf(double[] lanes, int width) =>
        lanes[Destination(width)..Velocity(width)];

    /// <summary>How fast the value is going, per second.</summary>
    /// <param name="lanes">The whole value.</param>
    /// <param name="width">How many lanes the value itself takes.</param>
    internal static double[] VelocityOf(double[] lanes, int width) =>
        lanes[Velocity(width)..LawAt(width)];

    /// <summary>The law the three lanes at <paramref name="at"/> name, and the motion it walks by.</summary>
    /// <remarks>
    /// No law and an engine's walk move nothing. The element's own carries no
    /// numbers, so its motion here moves nothing either: the caller's answer is
    /// the one it follows.
    /// </remarks>
    /// <param name="lanes">The lanes holding the law.</param>
    /// <param name="at">The first of the law's three lanes.</param>
    /// <returns>What the law is, and the motion it walks by.</returns>
    internal static (Law Kind, HostMotion Motion) MotionAt(double[] lanes, int at) =>
        (Law)(int)lanes[at] switch
        {
            Law.Inherited => (Law.Inherited, Arrives),
            Law.Eased => (Law.Eased, HostMotion.Eased(Millis(lanes[at + 1]), (HostEasing)(int)lanes[at + 2])),
            Law.Spring => (Law.Spring, HostMotion.Spring(Millis(lanes[at + 1]), lanes[at + 2])),
            Law.Custom => (Law.Custom, Arrives),
            _ => (Law.None, Arrives),
        };

    /// <summary>A speed per millisecond, as the walker keeps one, from per-second lanes.</summary>
    /// <param name="perSecond">The speed as it crosses.</param>
    /// <returns>The same speed, per millisecond.</returns>
    internal static double[] PerMillisecond(double[] perSecond)
    {
        double[] perMillisecond = new double[perSecond.Length];

        for (int lane = 0; lane < perSecond.Length; lane++)
        {
            perMillisecond[lane] = perSecond[lane] / 1000;
        }

        return perMillisecond;
    }

    /// <summary>A speed as it crosses, per second, from the walker's per millisecond.</summary>
    /// <param name="perMillisecond">The walker's speed.</param>
    /// <returns>The same speed, per second.</returns>
    internal static double PerSecond(double perMillisecond) => perMillisecond * 1000;

    /// <summary>A motion that moves nothing.</summary>
    private static HostMotion Arrives => HostMotion.Eased(0, HostEasing.Linear);

    /// <summary>A lane's milliseconds, as the whole number a motion carries.</summary>
    private static uint Millis(double lane) => (uint)Math.Max(lane, 0);
}
