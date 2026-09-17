// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// Where a value is at a given moment of its motion, and how fast it is going
/// there - and the curves an eased motion follows.
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
/// A curve's SLOPE is a central difference on the CURVE - a pure function of
/// how far through the motion is - and not a difference between two frames, so
/// it answers the same number in every run and every process, at any frame
/// rate, including none at all.
/// </para>
/// <para>
/// The laws and their curves are the core's: a line-by-line copy of the Swift
/// <c>HostMotionLaw</c>, in the same arithmetic order, which every runtime
/// walks with - a value walked on <c>cubicOut</c> here is the sequence of
/// numbers every other runtime walks. <c>motion-laws.txt</c>, the core's
/// trajectory table, is what proves the copy (<c>MotionLawTests</c>).
/// </para>
/// </remarks>
internal static class MotionLaw
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

    /// <summary>Whether two runs of lanes stand at the same place, to <see cref="Still"/>.</summary>
    /// <param name="left">One run.</param>
    /// <param name="right">The other, as long.</param>
    /// <returns>Whether every lane agrees.</returns>
    internal static bool Same(double[] left, double[] right)
    {
        for (int lane = 0; lane < left.Length; lane++)
        {
            if (Math.Abs(left[lane] - right[lane]) >= Still)
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Puts the value and its speed at <paramref name="t"/> into
    /// <paramref name="p"/> and <paramref name="v"/>.
    /// </summary>
    /// <remarks>
    /// The motion's numbers are read as the wire carries them, a spring's
    /// response held to a millisecond and its damping off nought here, as the
    /// core's law holds them.
    /// </remarks>
    /// <param name="trip">The trip, holding where it started, where it is going and how.</param>
    /// <param name="t">Milliseconds since the motion began.</param>
    /// <param name="p">Filled with the value at that moment.</param>
    /// <param name="v">Filled with how fast each lane is moving, per millisecond.</param>
    /// <returns>Whether the motion is over.</returns>
    internal static bool Sample(Trip trip, double t, double[] p, double[] v)
    {
        HostMotion motion = trip.Motion;

        return motion.Kind switch
        {
            HostMotion.Law.Spring => Spring(
                trip, Math.Max(motion.Millis, 1u), Math.Max(motion.Factor, 0.01), t, p, v),
            _ => Eased(trip, motion.Millis, motion.Curve, t, p, v),
        };
    }

    /// <summary>How far along a curve is at <paramref name="s"/>, from 0 to 1.</summary>
    /// <remarks>
    /// A number the wire does not name is the straight line.
    /// </remarks>
    /// <param name="curve">The curve.</param>
    /// <param name="s">How far through the motion is, from 0 to 1.</param>
    /// <returns>The fraction of the distance covered - which the bouncing and
    /// springing curves deliberately take past 1 and back.</returns>
    internal static double Ease(HostEasing curve, double s)
    {
        double x = Math.Clamp(s, 0, 1);

        switch (curve)
        {
            case HostEasing.SineOut:
                return Math.Sin(x * Math.PI / 2);

            case HostEasing.SineIn:
                return 1 - Math.Cos(x * Math.PI / 2);

            case HostEasing.SineInOut:
                return (1 - Math.Cos(x * Math.PI)) / 2;

            case HostEasing.CubicIn:
                return x * x * x;

            case HostEasing.CubicOut:
            {
                double shifted = x - 1;
                return (shifted * shifted * shifted) + 1;
            }

            case HostEasing.CubicInOut:
            {
                if (x < 0.5)
                {
                    return 4 * x * x * x;
                }

                double shifted = (2 * x) - 2;
                return (shifted * shifted * shifted / 2) + 1;
            }

            case HostEasing.BounceOut:
                return BounceOut(x);

            case HostEasing.BounceIn:
                return 1 - BounceOut(1 - x);

            case HostEasing.SpringIn:
                return x * x * ((2.70158 * x) - 1.70158);

            case HostEasing.SpringOut:
            {
                double shifted = x - 1;
                return (shifted * shifted * ((2.70158 * shifted) + 1.70158)) + 1;
            }

            default:
                return x;
        }
    }

    /// <summary>How steeply the curve is rising at <paramref name="s"/>.</summary>
    /// <remarks>
    /// Per unit of <c>s</c>, so a caller divides by the motion's length to get
    /// a speed. The step is small enough to be exact for every curve here and
    /// wide enough that no curve's own arithmetic shows through it; at the ends
    /// the difference is one-sided, since there is no curve outside 0 to 1.
    /// </remarks>
    /// <param name="curve">The curve.</param>
    /// <param name="s">How far through the motion is, from 0 to 1.</param>
    /// <returns>The curve's rate of climb there.</returns>
    internal static double Slope(HostEasing curve, double s)
    {
        const double step = 1e-4;

        double from = Math.Clamp(s - step, 0, 1);
        double to = Math.Clamp(s + step, 0, 1);

        if (to - from <= 0)
        {
            return 0;
        }

        return (Ease(curve, to) - Ease(curve, from)) / (to - from);
    }

    /// <summary>
    /// A stated length on a stated curve - or, where the motion it replaced
    /// left speed behind, the cubic that carries that speed into it.
    /// </summary>
    /// <remarks>
    /// FROM REST it is exactly the curve the author asked for, evaluated as
    /// the core evaluates it. With speed at the start it is a Hermite:
    /// the same duration, beginning at the value and the speed the previous
    /// motion had reached, ending at the target at a standstill. So a target
    /// changed mid-walk bends the motion rather than cutting it, and a motion
    /// that nothing interrupted is unchanged.
    /// </remarks>
    private static bool Eased(
        Trip trip, double length, HostEasing curve, double t, double[] p, double[] v)
    {
        if (length <= 0 || t >= length)
        {
            trip.Target.CopyTo(p, 0);
            Array.Clear(v);
            return true;
        }

        double s = t / length;
        double eased = Ease(curve, s);
        double slope = Slope(curve, s);

        // The Hermite basis, which only the lanes that carry speed need.
        double h00 = ((2 * s) - 3) * s * s + 1;
        double h10 = ((s - 2) * s + 1) * s;
        double h01 = (3 - (2 * s)) * s * s;
        double d00 = (6 * s * s) - (6 * s);
        double d10 = (3 * s * s) - (4 * s) + 1;
        double d01 = (6 * s) - (6 * s * s);

        for (int lane = 0; lane < p.Length; lane++)
        {
            double from = trip.From[lane];
            double to = trip.Target[lane];
            double speed = trip.StartV[lane];

            if (speed == 0)
            {
                p[lane] = from + ((to - from) * eased);
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
    private static bool Spring(
        Trip trip, double response, double damping, double t, double[] p, double[] v)
    {
        double w = 2 * Math.PI / response;
        double zeta = damping;
        bool rested = t >= Longest;

        for (int lane = 0; lane < p.Length; lane++)
        {
            double to = trip.Target[lane];
            double x0 = trip.From[lane] - to;
            double v0 = trip.StartV[lane];
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
            // whole trip is: a spring on four lanes settles them one by one.
            p[lane] = to;
            v[lane] = 0;
        }

        if (!rested)
        {
            rested = true;

            for (int lane = 0; lane < p.Length && rested; lane++)
            {
                rested = v[lane] == 0 && p[lane] == trip.Target[lane];
            }
        }

        if (rested)
        {
            trip.Target.CopyTo(p, 0);
            Array.Clear(v);
        }

        return rested;
    }

    /// <summary>The bounce that settles into its end, four arcs smaller each time.</summary>
    private static double BounceOut(double x)
    {
        if (x < 1 / 2.75)
        {
            return 7.5625 * x * x;
        }

        if (x < 2 / 2.75)
        {
            double shifted = x - (1.5 / 2.75);
            return (7.5625 * shifted * shifted) + 0.75;
        }

        if (x < 2.5 / 2.75)
        {
            double shifted = x - (2.25 / 2.75);
            return (7.5625 * shifted * shifted) + 0.9375;
        }

        double last = x - (2.625 / 2.75);
        return (7.5625 * last * last) + 0.984375;
    }
}
