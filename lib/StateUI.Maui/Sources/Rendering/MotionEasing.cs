// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// The curves, and how steeply each of them is rising.
/// </summary>
/// <remarks>
/// <para>
/// The curves are the core's own: a line-by-line copy of the Swift
/// <c>HostMotionLaw.ease</c>, in the same arithmetic order, so a value walked
/// on <c>cubicOut</c> here is the sequence of numbers every other runtime
/// walks. <c>motion-laws.txt</c>, the core's trajectory table, is what proves
/// the copy (<c>MotionLawTests</c>).
/// </para>
/// <para>
/// The SLOPE is what a retarget needs: how fast the
/// value was moving when the target changed. It is a central difference on the
/// CURVE - a pure function of how far through the motion is - and not a
/// difference between two frames, so it answers the same number in every run
/// and every process, at any frame rate, including none at all.
/// </para>
/// </remarks>
internal static class MotionEasing
{
    /// <summary>How far along a curve is at <paramref name="s"/>, from 0 to 1.</summary>
    /// <remarks>
    /// A number the wire does not name is the straight line.
    /// </remarks>
    /// <param name="curve">The curve, as its <c>SwiftEasing</c> member.</param>
    /// <param name="s">How far through the motion is, from 0 to 1.</param>
    /// <returns>The fraction of the distance covered - which the bouncing and
    /// springing curves deliberately take past 1 and back.</returns>
    internal static double At(int curve, double s)
    {
        double x = Math.Clamp(s, 0, 1);

        switch ((SwiftEasing)curve)
        {
            case SwiftEasing.SineOut:
                return Math.Sin(x * Math.PI / 2);

            case SwiftEasing.SineIn:
                return 1 - Math.Cos(x * Math.PI / 2);

            case SwiftEasing.SineInOut:
                return (1 - Math.Cos(x * Math.PI)) / 2;

            case SwiftEasing.CubicIn:
                return x * x * x;

            case SwiftEasing.CubicOut:
            {
                double shifted = x - 1;
                return (shifted * shifted * shifted) + 1;
            }

            case SwiftEasing.CubicInOut:
            {
                if (x < 0.5)
                {
                    return 4 * x * x * x;
                }

                double shifted = (2 * x) - 2;
                return (shifted * shifted * shifted / 2) + 1;
            }

            case SwiftEasing.BounceOut:
                return BounceOut(x);

            case SwiftEasing.BounceIn:
                return 1 - BounceOut(1 - x);

            case SwiftEasing.SpringIn:
                return x * x * ((2.70158 * x) - 1.70158);

            case SwiftEasing.SpringOut:
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
    /// <param name="curve">The curve, as its <c>SwiftEasing</c> member.</param>
    /// <param name="s">How far through the motion is, from 0 to 1.</param>
    /// <returns>The curve's rate of climb there.</returns>
    internal static double Slope(int curve, double s)
    {
        const double step = 1e-4;

        double from = Math.Clamp(s - step, 0, 1);
        double to = Math.Clamp(s + step, 0, 1);

        if (to - from <= 0)
        {
            return 0;
        }

        return (At(curve, to) - At(curve, from)) / (to - from);
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
