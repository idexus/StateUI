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
/// WITHIN ONE POINT the movement is this side's own, at a stated speed - one
/// point of the grid every <see cref="Cell"/> seconds. It has to be, because a
/// platform sent somewhere its own throw was not going stretches its
/// deceleration to arrive there, and the more gently the reader let go the
/// further it stretches: the same half-card takes a fraction of a second after
/// a flick and the better part of a second after a nudge, which is a crawl and
/// reads as the control being tired. A stated speed cannot do that. Being a
/// speed and not a time, half a card also takes half as long as a whole one, so
/// the shortest corrections stay the quickest.
/// </para>
/// <para>
/// BEYOND ONE POINT the platform keeps its own curve and is simply sent to the
/// rounded point instead of its own. Nothing is stretched there worth seeing -
/// the movement was already crossing cards, and the rounding is a fraction of
/// it - so what the reader gets is the platform's own physics, which is what a
/// long throw should feel like.
/// </para>
/// <para>
/// A movement nobody threw - one an author ASKED for by assigning a position,
/// or a correction after a wheel - is the first kind, so a card assigned and a
/// card settled onto move alike.
/// </para>
/// </remarks>
internal static class ScrollGlide
{
    /// <summary>
    /// How long one point of the grid takes, in seconds, in a movement of this
    /// side's own.
    /// </summary>
    internal const double Cell = 0.3;

    /// <summary>
    /// How many points of the grid a release may be going to cross and still be
    /// settled here rather than left to the platform.
    /// </summary>
    internal const int Reach = 1;

    /// <summary>The shortest a movement may take, in milliseconds.</summary>
    /// <remarks>
    /// A correction of a few units would otherwise be a single frame, which
    /// reads as the offset jumping rather than as the scroller settling.
    /// </remarks>
    internal const double Least = 90;

    /// <summary>The longest a movement may take, in milliseconds.</summary>
    /// <remarks>
    /// Only a movement nobody threw can reach it - one an author asked for,
    /// across a run the stated speed would spend seconds crossing.
    /// </remarks>
    internal const double Most = 420;

    /// <summary>
    /// The speed a movement of this side's own is made at, in device units a
    /// second: one point of the grid every <see cref="Cell"/> seconds. Nothing,
    /// for a scroller with no grid to measure itself against.
    /// </summary>
    /// <param name="interval">How far apart the points of the grid are.</param>
    internal static double Speed(double interval) => interval > 0 ? interval / Cell : 0;

    /// <summary>
    /// How long a movement of this length takes, in milliseconds - its distance
    /// at <see cref="Speed"/>, held inside <see cref="Least"/> to
    /// <see cref="Most"/>.
    /// </summary>
    /// <param name="distance">How far there is to go, in device units.</param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    internal static double Length(double distance, double interval)
    {
        double speed = Speed(interval);

        return speed <= 0
            ? Most
            : Math.Clamp(Math.Abs(distance) / speed * 1000, Least, Most);
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
