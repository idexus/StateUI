// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>Which law a channel travels under.</summary>
internal enum MotionKind : byte
{
    /// <summary>A stated length on a stated curve.</summary>
    Eased = 0,

    /// <summary>A mass on a spring, stated as a response and a damping.</summary>
    Spring = 1,
}

/// <summary>
/// What a motion is, as the numbers that describe it: everything the engine
/// needs to know beyond where the value is going.
/// </summary>
/// <remarks>
/// A value type with no state of its own, so the same spec can start any number
/// of channels. Which fields mean anything depends on <see cref="Kind"/>, and
/// the three factories below are the only way one is meant to be built.
/// </remarks>
internal readonly struct MotionSpec
{
    /// <summary>The law this motion travels under.</summary>
    internal MotionKind Kind { get; private init; }

    /// <summary>How long an eased motion takes, in milliseconds.</summary>
    internal double Length { get; private init; }

    /// <summary>The curve an eased motion follows, as its wire member.</summary>
    internal int Curve { get; private init; }

    /// <summary>A spring's period, in milliseconds - how quickly it answers.</summary>
    internal double Response { get; private init; }

    /// <summary>
    /// A spring's damping: 1 comes to rest without overshooting, below 1
    /// overshoots and rings, above 1 crawls in.
    /// </summary>
    internal double Damping { get; private init; }

    /// <summary>A stated length on a stated curve.</summary>
    /// <param name="length">How long it takes, in milliseconds.</param>
    /// <param name="curve">The curve, as its <c>SwiftEasing</c> member.</param>
    internal static MotionSpec Eased(double length, int curve) => new()
    {
        Kind = MotionKind.Eased,
        Length = Math.Max(length, 0),
        Curve = curve,
    };

    /// <summary>A mass on a spring.</summary>
    /// <param name="response">The period, in milliseconds.</param>
    /// <param name="damping">1 for a spring that does not overshoot.</param>
    internal static MotionSpec Spring(double response, double damping) => new()
    {
        Kind = MotionKind.Spring,
        Response = Math.Max(response, 1),
        Damping = Math.Max(damping, 0.01),
    };

    /// <summary>Whether this motion is no motion at all - land at once.</summary>
    internal bool Instant => Kind == MotionKind.Eased && Length <= 0;
}

/// <summary>
/// Where a value is at a given moment of its motion, and how fast it is going
/// there.
/// </summary>
/// <remarks>
/// <para>
/// Every law here is CLOSED FORM in the time since the motion began: nothing is
/// integrated frame by frame, so a run of frames answers the same numbers
/// whatever the frames were - which is what makes a trajectory a pure function
/// of <c>t</c>, testable against a hand-written clock, and unharmed by a
/// suspended application (it slews to the end rather than resuming mid-air).
/// </para>
/// <para>
/// Velocity is the law's own derivative, never a difference between two
/// samples. That is what a retarget needs: the motion that replaces this one
/// starts from the speed this one had, so the value bends instead of being cut.
/// </para>
/// </remarks>
internal static class MotionCurve
{
    /// <summary>
    /// A spring is at rest when it is this close to its target and this slow -
    /// in the value's own units, and per millisecond for the speed.
    /// </summary>
    /// <remarks>
    /// One number for every lane, which is why lanes are kept in the units a
    /// reader sees: a colour channel is 0-1, a coordinate is a unit on screen.
    /// A thousandth of either is under any screen's resolution.
    /// </remarks>
    internal const double Still = 0.001;

    /// <summary>
    /// However slow it gets, a spring - the one law with no stated end - is
    /// over after this many milliseconds, so nothing can hold the frame clock
    /// awake for ever.
    /// </summary>
    internal const double Longest = 10_000;

    /// <summary>
    /// Puts the value and its speed at <paramref name="t"/> into
    /// <paramref name="p"/> and <paramref name="v"/>.
    /// </summary>
    /// <param name="channel">The channel, holding where it started and where it is going.</param>
    /// <param name="t">Milliseconds since the motion began.</param>
    /// <param name="p">Filled with the value at that moment.</param>
    /// <param name="v">Filled with how fast each lane is moving, per millisecond.</param>
    /// <returns>Whether the motion is over.</returns>
    internal static bool At(MotionChannel channel, double t, double[] p, double[] v)
    {
        return channel.Spec.Kind switch
        {
            MotionKind.Spring => Spring(channel, t, p, v),
            _ => Eased(channel, t, p, v),
        };
    }

    /// <summary>
    /// A stated length on a stated curve - or, where the motion it replaced
    /// left speed behind, the cubic that carries that speed into it.
    /// </summary>
    /// <remarks>
    /// FROM REST it is exactly the curve the author asked for, evaluated the
    /// way it always was. With speed at the start it is a Hermite: the same
    /// duration, beginning at the value and the speed the previous motion had
    /// reached, ending at the target at a standstill. So a target changed
    /// mid-flight bends the motion rather than cutting it, and a motion that
    /// nothing interrupted is unchanged.
    /// </remarks>
    private static bool Eased(MotionChannel channel, double t, double[] p, double[] v)
    {
        double length = channel.Spec.Length;

        if (length <= 0 || t >= length)
        {
            channel.Target.CopyTo(p, 0);
            Array.Clear(v);
            return true;
        }

        double s = t / length;
        double curve = MotionEasing.At(channel.Spec.Curve, s);
        double slope = MotionEasing.Slope(channel.Spec.Curve, s);

        // The Hermite basis, which only the lanes that carry speed need.
        double h00 = ((2 * s) - 3) * s * s + 1;
        double h10 = ((s - 2) * s + 1) * s;
        double h01 = (3 - (2 * s)) * s * s;
        double d00 = (6 * s * s) - (6 * s);
        double d10 = (3 * s * s) - (4 * s) + 1;
        double d01 = (6 * s) - (6 * s * s);

        for (int lane = 0; lane < p.Length; lane++)
        {
            double from = channel.From[lane];
            double to = channel.Target[lane];
            double speed = channel.StartV[lane];

            if (speed == 0)
            {
                p[lane] = from + ((to - from) * curve);
                v[lane] = (to - from) * slope / length;
                continue;
            }

            p[lane] = (h00 * from) + (h10 * length * speed) + (h01 * to);
            v[lane] = ((d00 * from) + (d10 * length * speed) + (d01 * to)) / length;
        }

        return false;
    }

    /// <summary>
    /// A mass on a spring, in closed form - critically damped unless the author
    /// bought the overshoot.
    /// </summary>
    /// <remarks>
    /// Written about the DISTANCE LEFT rather than the value, which is what
    /// makes the three damping cases the textbook ones and keeps the target out
    /// of the exponentials.
    /// </remarks>
    private static bool Spring(MotionChannel channel, double t, double[] p, double[] v)
    {
        double w = 2 * Math.PI / channel.Spec.Response;
        double zeta = channel.Spec.Damping;
        bool rested = t >= Longest;

        for (int lane = 0; lane < p.Length; lane++)
        {
            double to = channel.Target[lane];
            double x0 = channel.From[lane] - to;
            double v0 = channel.StartV[lane];
            double x, dx;

            if (Math.Abs(zeta - 1) < 1e-6)
            {
                double b = v0 + (w * x0);
                double decay = Math.Exp(-w * t);

                x = (x0 + (b * t)) * decay;
                dx = (b - (w * (x0 + (b * t)))) * decay;
            }
            else if (zeta < 1)
            {
                double wd = w * Math.Sqrt(1 - (zeta * zeta));
                double a = x0;
                double b = (v0 + (zeta * w * x0)) / wd;
                double decay = Math.Exp(-zeta * w * t);
                double cos = Math.Cos(wd * t);
                double sin = Math.Sin(wd * t);

                x = decay * ((a * cos) + (b * sin));
                dx = decay * ((-zeta * w * ((a * cos) + (b * sin)))
                    + (wd * ((b * cos) - (a * sin))));
            }
            else
            {
                double root = w * Math.Sqrt((zeta * zeta) - 1);
                double r1 = -(w * zeta) + root;
                double r2 = -(w * zeta) - root;
                double c1 = (v0 - (r2 * x0)) / (r1 - r2);
                double c2 = x0 - c1;

                x = (c1 * Math.Exp(r1 * t)) + (c2 * Math.Exp(r2 * t));
                dx = (c1 * r1 * Math.Exp(r1 * t)) + (c2 * r2 * Math.Exp(r2 * t));
            }

            p[lane] = to + x;
            v[lane] = dx;

            if (Math.Abs(x) > Still || Math.Abs(dx) > Still)
            {
                continue;
            }

            // Near enough to be over, and every lane has to agree before the
            // whole channel is: a spring on four lanes settles them one by one.
            p[lane] = to;
            v[lane] = 0;
        }

        if (!rested)
        {
            rested = true;

            for (int lane = 0; lane < p.Length && rested; lane++)
            {
                rested = v[lane] == 0 && p[lane] == channel.Target[lane];
            }
        }

        if (rested)
        {
            channel.Target.CopyTo(p, 0);
            Array.Clear(v);
        }

        return rested;
    }
}
