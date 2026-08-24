namespace StateUI.Runtime.Rendering;

/// <summary>
/// How far a released scroller travels, how long it takes getting there, and
/// on what curve - the whole of what a settle LOOKS like, in arithmetic no
/// platform takes part in.
/// </summary>
/// <remarks>
/// <para>
/// A platform is asked for ONE number and nothing else: how fast the scroller
/// was going as the finger left it. A speed is a physical quantity and means
/// the same on every screen, which is what makes it the only thing worth taking
/// from a platform - the DISTANCE and the TIME are worked out here, from that
/// one number, and are therefore the same everywhere.
/// </para>
/// <para>
/// There are two settles, and which one it is depends on the throw rather than
/// on the platform:
/// </para>
/// <para>
/// A release too slow to be a throw - under <see cref="Slowest"/>, which is ONE
/// POINT OF THE GRID every <see cref="Cell"/> seconds - is a nudge, and it is
/// tidied up to the nearest point AT that speed. Being a speed and not a time,
/// half a card takes half as long as a whole one, and the shortest corrections
/// are the quickest, which is what a correction should be.
/// </para>
/// <para>
/// A release above it is a THROW, and it is carried out over
/// <see cref="Throw"/> milliseconds whatever it crosses, on a curve that
/// overshoots slightly and comes back. A firm flick asks to be somewhere else
/// now; springing into place says that, and it is the answer to the one thing
/// this replaces - an arrival that gets slower the further it has to go.
/// </para>
/// <para>
/// WHAT THIS REPLACES is each platform deciding both for itself, and they do
/// not agree. UIKit stretches its own deceleration to reach wherever it is
/// told, so a gentle release takes the better part of a second to cross half a
/// card - a crawl, and the slower the release the worse it gets. Android's
/// smooth scroll is a flat 250 ms whatever the distance, and skips outright
/// when two land within that of each other. WinUI runs a curve of its own. The
/// reader sees one control, so the control has to move one way.
/// </para>
/// <para>
/// THE FLOOR IS THE GRID'S OWN, not a number of device units, which is what
/// makes it need no tuning per screen: a phone's card and a desktop's card are
/// each crossed in the same time, so the settle reads the same size on both.
/// </para>
/// </remarks>
internal static class ScrollGlide
{
    /// <summary>
    /// How long one point of the grid takes at the slowest a settle may go, in
    /// seconds.
    /// </summary>
    internal const double Cell = 0.3;

    /// <summary>
    /// How long a throw keeps travelling, in seconds - the whole of the
    /// distance model.
    /// </summary>
    /// <remarks>
    /// A scroller let go of at 2000 units a second travels 800 of them, which
    /// is two cards of a phone-width carousel and reads as a firm flick. What
    /// scales it per scroller is <c>scrollMomentum</c>, so a carousel asking
    /// for half the throw is asking for half of this.
    /// </remarks>
    internal const double Carry = 0.4;

    /// <summary>
    /// How long a thrown settle takes, in milliseconds, whatever it crosses.
    /// </summary>
    internal const double Throw = 320;

    /// <summary>The shortest a movement may take, in milliseconds.</summary>
    /// <remarks>
    /// A correction of a few units would otherwise be a single frame, which
    /// reads as the offset jumping rather than as the scroller settling.
    /// </remarks>
    internal const double Least = 90;

    /// <summary>The longest a movement may take, in milliseconds.</summary>
    /// <remarks>
    /// Only a movement nobody threw can reach it - one an author ASKED for,
    /// across a run the floor speed would spend seconds crossing.
    /// </remarks>
    internal const double Most = 420;

    /// <summary>
    /// The slowest a settle may go, in device units a second: one point of the
    /// grid every <see cref="Cell"/> seconds. Nothing, for a scroller with no
    /// grid to measure itself against.
    /// </summary>
    /// <param name="interval">How far apart the points of the grid are.</param>
    internal static double Slowest(double interval) => interval > 0 ? interval / Cell : 0;

    /// <summary>
    /// Where a throw at this speed ends up, before the grid is applied.
    /// </summary>
    /// <param name="offset">Where the scroller is as the finger leaves it.</param>
    /// <param name="velocity">How fast it is going, in device units a second.</param>
    /// <param name="momentum">What fraction of the throw this scroller keeps.</param>
    internal static double Thrown(double offset, double velocity, double momentum) =>
        offset + (velocity * Carry * Math.Max(0, momentum));

    /// <summary>
    /// How long a movement takes and whether it springs into place - the two
    /// halves of what it looks like, decided together because it is one
    /// decision: whether a throw is being carried out or a nudge tidied up.
    /// </summary>
    /// <param name="distance">How far there is to go, in device units.</param>
    /// <param name="speed">
    /// How fast the scroller was going as it was let go of. Zero for a movement
    /// no throw is behind - one somebody ASKED for - which is therefore made at
    /// the floor speed, and so looks like the settle a reader gets for free.
    /// </param>
    /// <param name="interval">How far apart the points of the grid are.</param>
    /// <returns>How many milliseconds it takes, and whether it overshoots.</returns>
    internal static (double Length, bool Springs) Movement(double distance, double speed, double interval)
    {
        double slowest = Slowest(interval);

        if (slowest <= 0 || Math.Abs(speed) > slowest)
        {
            return (Throw, true);
        }

        return (Math.Clamp(Math.Abs(distance) / slowest * 1000, Least, Most), false);
    }
}
