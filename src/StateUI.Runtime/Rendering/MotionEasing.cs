// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// The curves, and how steeply each of them is rising.
/// </summary>
/// <remarks>
/// <para>
/// The curves themselves are MAUI's own - <see cref="SwiftTransitions.Read"/> is
/// the one table that turns a wire member into one - so a motion from rest
/// draws exactly the shape it has always drawn, and a value walked on
/// <c>cubicOut</c> is the same sequence of numbers it was before there was an
/// engine to produce them.
/// </para>
/// <para>
/// The SLOPE is what is new, and it is what a retarget needs: how fast the
/// value was moving when the target changed. It is a central difference on the
/// CURVE - a pure function of how far through the motion is - and not a
/// difference between two frames, so it answers the same number in every run
/// and every process, at any frame rate, including none at all.
/// </para>
/// </remarks>
internal static class MotionEasing
{
    /// <summary>How far along a curve is at <paramref name="s"/>, from 0 to 1.</summary>
    /// <param name="curve">The curve, as its <c>SwiftEasing</c> member.</param>
    /// <param name="s">How far through the motion is, from 0 to 1.</param>
    /// <returns>The fraction of the distance covered - which the bouncing and
    /// springing curves deliberately take past 1 and back.</returns>
    internal static double At(int curve, double s) =>
        SwiftTransitions.Read(curve).Ease(Math.Clamp(s, 0, 1));

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
}
