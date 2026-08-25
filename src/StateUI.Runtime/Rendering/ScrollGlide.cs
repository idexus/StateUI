// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

/// <summary>
/// How a scroller comes to rest on its grid: which of two movements takes it
/// there, and how long this side's own one lasts.
/// </summary>
/// <remarks>
/// <para>
/// THE PLATFORM'S OWN PREDICTED STOP DECIDES, and it decides one thing: how far
/// the release was going anyway, counted in points of the grid.
/// </para>
/// <para>
/// BEYOND ONE POINT the platform keeps its own curve and is simply sent to the
/// rounded point instead of its own. Nothing is stretched there worth seeing -
/// the movement was already crossing cards, and the rounding is a fraction of
/// it - so what the reader gets is the platform's own physics, which is what a
/// long throw should feel like.
/// </para>
/// <para>
/// WITHIN ONE POINT the movement is this side's own, and it is made of TWO
/// PARTS: a CROSSING, which is the distance still to go at a stated speed - one
/// point of the grid every <see cref="Crossing"/> seconds - and a LANDING of
/// <see cref="Landing"/> seconds, which is there whatever the distance was. A
/// whole point therefore takes half a second, half a point takes 350 ms rather
/// than a quarter of a second, and the smallest correction there is still takes
/// the landing.
/// </para>
/// <para>
/// BOTH PARTS ARE THE POINT. Without the crossing a short correction would take
/// as long as a long one, and the control would read as tired - which is what a
/// platform does when it is sent somewhere its own throw was not going: it
/// stretches its deceleration to arrive, and stretches it further the more
/// gently the reader let go. Without the landing a short correction would be
/// over before the easing could be seen, and the card would arrive with a snap.
/// THE SOFT STOP IS NOT SOMETHING A MOVEMENT EARNS BY BEING LONG ENOUGH.
/// </para>
/// <para>
/// Between them they give the behaviour the two parts are chosen for: STARTING
/// FURTHER MEANS STARTING FASTER, AND ARRIVING THE SAME WAY. The time grows
/// more slowly than the distance does - a tenth of a point takes 230 ms and a
/// whole one 500 - so the speed a movement leaves at climbs with how far it has
/// to go, while the last stretch of every one of them is the same.
/// </para>
/// <para>
/// A movement nobody threw - one an author ASKED for by assigning a position,
/// or a correction after a wheel - is the same movement, so a card assigned and
/// a card settled onto arrive alike.
/// </para>
/// </remarks>
internal static class ScrollGlide
{
    /// <summary>
    /// How long one point of the grid takes to CROSS, in seconds - the part of
    /// a movement that follows how far there is left to go.
    /// </summary>
    internal const double Crossing = 0.3;

    /// <summary>
    /// How long the LANDING takes, in seconds, however short the movement was.
    /// </summary>
    /// <remarks>
    /// Read together with the curve, which is <c>Easing.CubicOut</c>: a movement
    /// leaves at three times its average speed and eases to a stop, and this is
    /// what keeps enough of it back for that easing to be seen. A settle that
    /// arrives with a snap is what this exists to prevent, and the shortest
    /// correction there is needs it most.
    /// </remarks>
    internal const double Landing = 0.2;

    /// <summary>
    /// How many points of the grid a release may be going to cross and still be
    /// settled here rather than left to the platform.
    /// </summary>
    internal const int Reach = 1;

    /// <summary>The longest a movement may take, in milliseconds.</summary>
    /// <remarks>
    /// Above the longest settle there is - a point and a half of the grid, which
    /// is what a release from between two points can leave to cross - so no
    /// movement a reader makes is ever clipped by it. What it is for is a
    /// movement nobody threw: one an author asked for, across a run the stated
    /// speed would spend seconds crossing.
    /// </remarks>
    internal const double Most = 800;

    /// <summary>
    /// How fast the crossing is made, in device units a second: one point of the
    /// grid every <see cref="Crossing"/> seconds. Nothing, for a scroller with
    /// no grid to measure itself against.
    /// </summary>
    /// <param name="interval">How far apart the points of the grid are.</param>
    internal static double Speed(double interval) => interval > 0 ? interval / Crossing : 0;

    /// <summary>
    /// How long a movement takes, in milliseconds: the distance STILL TO GO at
    /// <see cref="Speed"/>, plus the <see cref="Landing"/> every movement ends
    /// with.
    /// </summary>
    /// <param name="distance">
    /// How far there is left to go, in device units - not the size of the step
    /// being landed on.
    /// </param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    internal static double Length(double distance, double interval)
    {
        double speed = Speed(interval);

        return speed <= 0
            ? Most
            : Math.Min((Math.Abs(distance) / speed * 1000) + (Landing * 1000), Most);
    }

    /// <summary>
    /// An offset brought back to the furthest point of the grid a release
    /// starting at <paramref name="from"/> is allowed to reach.
    /// </summary>
    /// <remarks>
    /// The limit is counted in POINTS rather than in distance, and from where
    /// the release STARTED - which for a finger is where it landed, not where it
    /// let go. A reader who drags most of the way to the next point and then
    /// throws has already spent the movement, so counting only the throw would
    /// let a drag and a throw add up to two points where one was asked for.
    /// </remarks>
    /// <param name="to">Where it was going, which is on the grid.</param>
    /// <param name="from">Where the release started, which need not be.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    /// <param name="origin">Where the grid starts.</param>
    /// <param name="most">
    /// The most points it may cross. Zero, or less, is no limit.
    /// </param>
    internal static double Held(double to, double from, double interval, double origin, int most)
    {
        if (most <= 0 || interval <= 0)
        {
            return to;
        }

        double started = Math.Round((from - origin) / interval);
        double wanted = Math.Round((to - origin) / interval);

        return origin + (Math.Clamp(wanted, started - most, started + most) * interval);
    }

    /// <summary>
    /// Where a WHEEL NOTCH takes a scroller that has a grid: the offset the
    /// platform was taking it to, rounded to the grid - and never the point it
    /// is already on or already going to.
    /// </summary>
    /// <remarks>
    /// A notch is a STEP, not a throw, so it is not shortened by momentum and
    /// it always moves: one notch is worth a fraction of a card, and rounding
    /// that alone would leave a carousel refusing to turn however long the
    /// reader spun the wheel. Where the notch is worth more than a point - a
    /// list of rows, say - the rounding is the whole of it, so the wheel keeps
    /// the platform's own idea of how far a notch goes.
    /// </remarks>
    /// <param name="going">Where the platform was taking it.</param>
    /// <param name="aim">
    /// Where it is going already - the point the notch before it was aimed at,
    /// or where the scroller stands when this is the first.
    /// </param>
    /// <param name="at">
    /// Where the scroller stands now, which is what says WHICH WAY the notch
    /// turned: the platform works its own destination out from where the
    /// content has got to, so a notch answered by a longer movement of ours
    /// announces a destination BEHIND that movement's, and reading the
    /// direction off <paramref name="aim"/> would take it for a notch the other
    /// way.
    /// </param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    /// <param name="origin">Where the grid starts.</param>
    /// <param name="least">
    /// How far the scroller must have been carried before the turn counts as
    /// one at all. Under it the nearest point wins, which is where it started;
    /// over it the movement is at least a whole point. One notch of the wheel
    /// for a burst that followed the reader's fingers, and a pixel's worth for
    /// a single notch, which is deliberate by construction.
    /// </param>
    internal static double Step(
        double going, double aim, double at, double interval, double origin, double least)
    {
        if (interval <= 0)
        {
            return going;
        }

        double here = origin + (Math.Round((aim - origin) / interval) * interval);
        double rounded = origin + (Math.Round((going - origin) / interval) * interval);

        if (Math.Abs(going - at) < least)
        {
            return rounded;
        }

        return going > at
            ? Math.Max(rounded, here + interval)
            : Math.Min(rounded, here - interval);
    }

    /// <summary>
    /// How many points of the grid lie between two offsets - the same rounding
    /// that names which point a scroller is nearest, so this counts in the very
    /// terms a reader sees.
    /// </summary>
    /// <param name="from">Where it is now, which need not be on the grid.</param>
    /// <param name="to">Where it is going, which is.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    /// <param name="origin">Where the grid starts.</param>
    internal static int Cells(double from, double to, double interval, double origin)
    {
        if (interval <= 0)
        {
            return 0;
        }

        double here = Math.Round((from - origin) / interval);
        double there = Math.Round((to - origin) / interval);

        return (int)Math.Min(int.MaxValue, Math.Abs(there - here));
    }
}
