// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using System.Diagnostics;
using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>Where a motion leaves the value it was carrying.</summary>
internal enum TripEnd : byte
{
    /// <summary>Exactly where it was going - what arriving means.</summary>
    Target = 0,

    /// <summary>Where it had got to, which a deliberate stop wants written.</summary>
    Here = 1,

    /// <summary>
    /// Nowhere - the value is not written at all, because something else has
    /// just written it. That is what a plain assignment over a moving value is:
    /// the author wrote it, and the motion must let go without a word.
    /// </summary>
    Nothing = 2,
}

/// <summary>One value on its way somewhere.</summary>
/// <remarks>
/// Everything about a motion in one place: where it started, how fast it was
/// going when it started, where it is going, under what law, and who is waiting
/// to hear that it arrived. The lanes are plain arrays because a trip is
/// stepped sixty times a second and the numbers are read in order.
/// </remarks>
internal sealed class Trip
{
    /// <summary>What this moves - and, in its owner and key, which value it is.</summary>
    internal required ITripTarget Moves { get; init; }

    /// <summary>Where the value is, this frame.</summary>
    internal required double[] P { get; init; }

    /// <summary>How fast each lane is going, per millisecond.</summary>
    internal required double[] V { get; init; }

    /// <summary>Where the current motion began.</summary>
    internal required double[] From { get; init; }

    /// <summary>How fast each lane was going when it began.</summary>
    internal required double[] StartV { get; init; }

    /// <summary>Where it is going.</summary>
    internal required double[] Target { get; init; }

    /// <summary>How it travels.</summary>
    internal HostMotion Motion { get; set; }

    /// <summary>When the current motion began, in stopwatch ticks.</summary>
    internal long T0 { get; set; }

    /// <summary>Whether the walker is stepping this right now.</summary>
    internal bool Moving { get; set; }

    /// <summary>
    /// How many setpoints THIS value has been given - the count an aim compares
    /// against to find out whether a newer one overtook it while it was telling
    /// the motion it replaces that it had ended. Per trip, because being
    /// told resumes a handler and a handler that renders aims every other
    /// trip that message touches: none of those is this value being sent
    /// somewhere new. See <see cref="Walker.Aim"/>.
    /// </summary>
    internal long Aims { get; set; }

    /// <summary>Told whether the motion ran to the end, once, when it stops.</summary>
    internal Action<bool>? Done { get; set; }

    /// <summary>Where the value was last actually written.</summary>
    internal double[]? Wrote { get; set; }

    /// <summary>Whether the value has been written since anything looked.</summary>
    /// <remarks>
    /// What a reader beside the walker asks instead of walking every trip:
    /// the walker sets it whenever it writes, and whoever reads the value
    /// clears it. Nothing here ever clears it, so a build with no such reader
    /// simply carries a flag that is set.
    /// </remarks>
    internal bool Observed { get; set; }
}

/// <summary>
/// What moves every value that is going somewhere, one frame at a time.
/// </summary>
/// <remarks>
/// <para>
/// The tree describes where the interface is GOING; this is how the screen
/// catches up. A setpoint arrives - from a journey the author sent, from a
/// property that simply changed, from a layout that put a child somewhere new -
/// and a CHANNEL carries the real value there, on the display's own rhythm,
/// carrying position AND speed so a target changed halfway bends the motion
/// instead of cutting it.
/// </para>
/// <para>
/// One walker per session, on the thread the platform draws on, with no locks
/// anywhere: every setpoint arrives from an apply and every frame arrives from
/// the platform's clock, and both of those are that thread.
/// </para>
/// <para>
/// It SLEEPS. The clock is started when the first trip begins to move and
/// stopped when the last one lands, so a still screen costs nothing at all.
/// </para>
/// </remarks>
internal sealed class Walker
{
    /// <summary>
    /// How deep inside a frame's own write to a control this thread is.
    /// </summary>
    /// <remarks>
    /// <para>
    /// WHAT TELLS AN ECHO FROM A READER. Setting a control's value raises the
    /// platform's own change notification synchronously - a Slider assigned
    /// five times raises five ValueChanged, measured - so a report arriving
    /// while this is above nought is the walker hearing itself, and is
    /// dropped. A report arriving while it is nought was made by somebody
    /// else, which on a control the reader can move means a finger: that one
    /// takes the value, ending whatever was carrying it.
    /// </para>
    /// <para>
    /// A COUNT rather than a flag, because a write can be heard by something
    /// that writes again, and static because there is one live session in a
    /// process and one thread that draws it.
    /// </para>
    /// </remarks>
    internal static int Writing;

    /// <summary>
    /// Every trip, by what it moves - the control, then which of its values.
    /// </summary>
    /// <remarks>
    /// Weak in the owner, so a control that has left the tree is not held by
    /// the fact that something once moved it. A trip is removed the moment
    /// it lands, which is what makes the next setpoint on the same value read
    /// where the platform actually has it: a reader's drag, a visual state, a
    /// layout pass - anything may have written it while nothing was moving.
    /// </remarks>
    private readonly ConditionalWeakTable<object, Dictionary<object, Trip>> _table = new();

    /// <summary>The trips that are moving, which is what a frame steps.</summary>
    private readonly List<Trip> _moving = [];

    /// <summary>How many motions this walker is carrying - the tally's own.</summary>
    internal int Carrying => _moving.Count;

    /// <summary>The moving trips, copied for the length of one frame.</summary>
    /// <remarks>
    /// A write can be heard - a slider raises a change, a layout re-arranges -
    /// and what hears it may render, which may start or stop trips. So a
    /// frame steps a COPY and skips whatever stopped moving while it ran.
    /// </remarks>
    private readonly List<Trip> _frame = [];

    /// <summary>What landed during a frame, told after it rather than inside it.</summary>
    private readonly List<(Trip Trip, bool Whole)> _landed = [];

    private IFrameClock? _clock;
    private bool _asked;
    private bool _stepping;
    private bool _inFrame;
    private long _at;

    /// <summary>
    /// How many messages have been applied.
    /// </summary>
    /// <remarks>
    /// What tells a layout WHY it is being arranged, which is the one thing an
    /// arrangement does not say about itself. A layout pass with a message
    /// behind it is a change to what the interface HOLDS - a row inserted, a
    /// card grown - and its children travel to their new places. One with no
    /// message behind it is the room itself moving: a window dragged, a
    /// keyboard rising, a scroller settling. Everything then tracks it exactly,
    /// because a child that glides after a reader's own hand is late every
    /// frame. See <c>LayoutMotion</c>.
    /// </remarks>
    internal long Applies { get; private set; }

    /// <summary>Counts one message applied.</summary>
    internal void Said() => Applies++;

    /// <summary>The instant the last frame was worked out at.</summary>
    /// <remarks>
    /// The clock runs on the thread that lays out, so this number standing
    /// still across two arrangements says the same thing twice over: no frame
    /// has been made, and none can be until the pass that is asking lets the
    /// thread go. Read by <c>LayoutMotion</c>, which is the one place a
    /// motion is written from inside a layout pass. Nought until the first
    /// frame is made; afterwards it holds the last frame's instant, and a
    /// number that does not move is the whole signal.
    /// </remarks>
    internal long At => _at;

    /// <summary>
    /// How the children of a layout that says nothing of its own travel - the
    /// APPLICATION's answer, which is what almost every layout uses.
    /// </summary>
    /// <remarks>
    /// Held here rather than on each layout so that a whole application's
    /// motion is one number: nothing per layout is on the wire, and changing
    /// the application's answer changes every layout that inherits it without
    /// a single one of them being told.
    /// </remarks>
    internal HostMotion Travel { get; set; } = HostMotion.Eased(0, HostEasing.Linear);

    /// <summary>
    /// The law three lanes of a state name: a walked value's own, or
    /// <see cref="Travel"/> where they name the element's.
    /// </summary>
    /// <remarks>
    /// Kind 0 is no motion at all, 2 is a stated length on a stated curve, and
    /// 3 is a spring. Kind 1 is a value that asked for the law of whatever
    /// element drives it and is driven by NONE - Swift resolves an element's
    /// own law into these lanes as the value crosses, being the only side that
    /// can read a per-value motion plan - so the application's answer is the
    /// right one for a value no element has claimed.
    /// </remarks>
    /// <param name="lanes">The state's lanes.</param>
    /// <param name="at">The first of the law's three.</param>
    /// <returns>The law.</returns>
    internal HostMotion Law(double[] lanes, int at) =>
        JourneyCodec.MotionAt(lanes, at) switch
        {
            (JourneyCodec.Law.Inherited, _) => Travel,
            (_, HostMotion motion) => motion,
        };

    /// <summary>
    /// Whether the frame is to be skipped - asked once per frame.
    /// </summary>
    /// <remarks>
    /// Set by the renderer to its own "a message is being applied": writing a
    /// property inside an apply is what makes a render inside an apply, which
    /// is a resync, which describes the moving property as a plain value and
    /// ends the very motion that caused it. One frame deferred is invisible.
    /// </remarks>
    internal Func<bool>? Held { get; set; }

    /// <summary>
    /// Whether there is nothing BEYOND the moving values to make frames for -
    /// asked once the frame is over, before the clock is stopped.
    /// </summary>
    /// <remarks>
    /// The walker's own reason to be awake is a value under way, and when the
    /// last one lands there is nothing left to draw. Anything else that rides
    /// the display's rhythm has reasons of its own - a value written from a
    /// handler, arithmetic that says it has not finished - and none of those is
    /// a trip, so they are asked about here. Null is a build where nothing
    /// else is awake, which is every build until something claims it.
    /// </remarks>
    internal Func<bool>? Idle { get; set; }

    /// <summary>
    /// What else the frame is for, run once every value that moves has been
    /// written.
    /// </summary>
    /// <remarks>
    /// The one seam for whatever else rides the display's own rhythm. It runs
    /// INSIDE the frame and after the writes, so that what it reads is the
    /// picture this frame drew rather than the last one's. Null while nothing
    /// has claimed it.
    /// </remarks>
    internal Action? Cycle { get; set; }

    /// <summary>
    /// Whether a value is being driven from OUTSIDE the walker, or null where
    /// nothing else drives anything.
    /// </summary>
    /// <remarks>
    /// The one question every host writer asks before it decides a resting
    /// value of its own. A visual state leaving, a view shown again, a
    /// property the tree stopped describing and a fade over an inserted child
    /// each land what they believe the value should be at rest - and where
    /// something else owns it, what they believe is out of date the moment
    /// they write it. Null is a build where nothing owns anything, which is
    /// every build until something claims it.
    /// </remarks>
    internal Func<object, object, bool>? Driven { get; set; }

    /// <summary>
    /// Told where a value is going, whenever that is decided - or null where
    /// nobody is watching.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Twice per motion and not once per frame: when a setpoint arms a motion,
    /// and when one stops somewhere the value is actually written. Frame by
    /// frame there is <see cref="Trip.Observed"/>, which a reader
    /// polls; what this answers is the two moments a poll CANNOT see - a
    /// destination that changed without the value having moved yet, and a
    /// landing, after which the trip is gone from the table and there is
    /// nothing left to poll.
    /// </para>
    /// <para>
    /// The flag says which of the two it is: true while the value is on its
    /// way somewhere, false where it has stopped - and a value that has
    /// stopped is going nowhere, whatever the trip it left behind still
    /// says about where it was sent.
    /// </para>
    /// </remarks>
    internal Action<Trip, bool>? Aimed { get; set; }

    /// <summary>
    /// What says when to draw - the platform's own frame signal, or one a test
    /// winds by hand.
    /// </summary>
    /// <remarks>
    /// Asked for once, the first time anything moves. A build with no clock -
    /// the headless tests, unless they bring one - lands every setpoint at once,
    /// which is the honest answer where there is no screen to move across.
    /// </remarks>
    internal IFrameClock? Clock
    {
        get
        {
            if (!_asked)
            {
                _asked = true;
                Attach(Made());
            }

            return _clock;
        }

        set
        {
            _asked = true;
            Attach(value);
        }
    }

    private void Attach(IFrameClock? clock)
    {
        if (ReferenceEquals(_clock, clock))
        {
            return;
        }

        if (_clock is not null)
        {
            _clock.Frame -= Frame;
            _clock.Stop();
        }

        _clock = clock;

        if (_clock is not null)
        {
            _clock.Frame += Frame;
        }
    }

    /// <summary>The platform's clock, or nothing when it cannot be had.</summary>
    private static IFrameClock? Made()
    {
        try
        {
            return FrameClock.Create();
        }
        catch (Exception)
        {
            // A platform that cannot answer a clock - asked from the wrong
            // thread, or a head with no display at all - is a platform where
            // every setpoint lands at once. That is a degraded interface and
            // never a broken one, so it must not be a throw.
            return null;
        }
    }

    /// <summary>Sends a value somewhere.</summary>
    /// <remarks>
    /// <para>
    /// A setpoint on a value that is ALREADY moving bends it: the new motion
    /// starts from where the value is and how fast it is going, so nothing is
    /// cut. One on a value that is still starts from wherever the platform
    /// actually has it, which is the only honest reading - anything at all may
    /// have written it while nothing was moving.
    /// </para>
    /// <para>
    /// Whoever was waiting on the motion this replaces is told at once that it
    /// did not run to the end.
    /// </para>
    /// </remarks>
    /// <param name="moves">What to move, and which value of it.</param>
    /// <param name="to">Where it is going, lane by lane.</param>
    /// <param name="spec">The law to travel under.</param>
    /// <param name="done">Told whether it ran to the end, or null when nobody waits.</param>
    /// <param name="from">
    /// Where the motion starts, for a caller that knows better than the value
    /// itself does - a layout has already put its child at the target by the
    /// time it asks, so the place it came from is the layout's to say. Ignored
    /// while a motion is already under way, which starts from where that one
    /// has reached.
    /// </param>
    /// <param name="velocity">
    /// How fast each lane is going as this motion begins, per millisecond, for
    /// a caller that knows a speed the value itself cannot say - a reader's
    /// hand let go of it, or arithmetic beside the walker handed it over. It
    /// stands in for the speed a motion being replaced would have lent, so a
    /// value handed over is never cut. A speed given where the value is already
    /// at its target is a NUDGE: the value leaves and comes back, which a
    /// motion of no distance otherwise would not do.
    /// </param>
    /// <returns>The trip, or null when the value landed at once.</returns>
    internal Trip? Aim(
        ITripTarget moves,
        double[] to,
        in HostMotion spec,
        Action<bool>? done = null,
        double[]? from = null,
        double[]? velocity = null)
    {
        Dictionary<object, Trip> owned = _table.GetValue(moves.Owner, static _ => []);
        bool had = owned.TryGetValue(moves.Key, out Trip? trip);

        // Every setpoint given to THIS value is counted, so a call can find out
        // whether a newer one overtook it while it was telling somebody their
        // motion had ended.
        long spoke = had ? ++trip!.Aims : 0;

        if (had && trip!.Moving)
        {
            // Whatever was waiting on the motion being replaced hears first,
            // and hears that it did not finish - the same answer a second
            // animation of one property has always given the first.
            Action<bool>? waiting = trip.Done;
            trip.Done = null;

            if (waiting is not null)
            {
                // Being told resumes a handler, which may write state, render,
                // and send this very value somewhere else - all before this
                // call has finished arming it. The NEWER setpoint is the one
                // that stands, so a call that was overtaken while it spoke
                // gives up its turn rather than writing over the answer.
                waiting(false);

                if (spoke != trip.Aims)
                {
                    // Somebody sent THIS value somewhere else while we spoke,
                    // and theirs is the setpoint that stands. Whoever awaited
                    // ours hears that it did not arrive - dropped, the await
                    // would never return.
                    done?.Invoke(false);

                    return Moving(moves.Owner, moves.Key);
                }
            }
        }

        if (trip is null)
        {
            trip = new Trip
            {
                Moves = moves,
                P = new double[moves.Lanes],
                V = new double[moves.Lanes],
                From = new double[moves.Lanes],
                StartV = new double[moves.Lanes],
                Target = new double[moves.Lanes],
            };

            owned[moves.Key] = trip;
        }

        if (trip.Moving)
        {
            trip.P.CopyTo(trip.From, 0);
            trip.V.CopyTo(trip.StartV, 0);
        }
        else if (from is not null)
        {
            Array.Clear(trip.StartV);
            from.CopyTo(trip.From, 0);
        }
        else
        {
            Array.Clear(trip.StartV);

            if (!trip.Moves.Read(trip.From))
            {
                // Nothing there to move from - a property of a shape that has
                // no half-way, or a child no layout has placed yet. It goes to
                // where it was told and says so.
                to.CopyTo(trip.From, 0);
            }
        }

        if (velocity is not null)
        {
            // A speed the CALLER knows outranks the one the trip would have
            // lent: it is the speed the value is actually going at, from a hand
            // that has just let go or arithmetic that has just handed over.
            velocity.CopyTo(trip.StartV, 0);
        }

        to.CopyTo(trip.Target, 0);
        trip.Motion = spec;
        trip.Done = done;

        // A SETPOINT WHERE THE VALUE ALREADY IS is an arrival. Nothing else
        // would be drawn - a motion of no distance writes the same number for
        // a fifth of a second - and it is not a rare case: a visual state
        // settles every value it touches on every apply, and almost all of
        // them are already where they belong.
        //
        // Nothing moves either for a reader who asked for less movement. Both
        // answer TRUE to whoever awaited the motion: the target was reached,
        // which is the whole of what they asked about.
        if (spec.Instant || There(trip) || MotionMood.Reduced || Clock is null)
        {
            Land(trip, whole: true);
            return null;
        }

        trip.From.CopyTo(trip.P, 0);
        trip.StartV.CopyTo(trip.V, 0);
        trip.T0 = Clock?.Now ?? Stopwatch.GetTimestamp();

        if (!trip.Moving)
        {
            trip.Moving = true;
            _moving.Add(trip);
        }

        // Written at once, so the value is where the motion says it is from
        // the frame it starts on - which is what lets a layout hand its child
        // over having already put it at the target.
        Put(trip);
        Clock?.Start();
        Aimed?.Invoke(trip, true);

        return trip;
    }

    /// <summary>Whether the value is already where it is being sent, and still.</summary>
    /// <remarks>
    /// The speed is half the question. A value at its target that is GOING
    /// somewhere has a motion to draw - it leaves and comes back - so a
    /// distance of nothing is an arrival only from a standstill.
    /// </remarks>
    private static bool There(Trip trip)
    {
        for (int lane = 0; lane < trip.From.Length; lane++)
        {
            if (Math.Abs(trip.From[lane] - trip.Target[lane]) >= MotionLaw.Still
                || trip.StartV[lane] != 0)
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Whether anything at all on this control is moving - the cheap question,
    /// asked before every apply so a still interface pays a comparison.
    /// </summary>
    /// <param name="owner">The control.</param>
    /// <returns>True when at least one of its values is under way.</returns>
    internal bool Stirring(object owner)
    {
        if (_moving.Count == 0 || !_table.TryGetValue(owner, out Dictionary<object, Trip>? owned))
        {
            return false;
        }

        foreach (Trip trip in owned.Values)
        {
            if (trip.Moving)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>Where a value has got to, whether or not it is still moving.</summary>
    /// <param name="owner">The control.</param>
    /// <param name="key">Which of its values.</param>
    /// <returns>The trip carrying it, or null when nothing is.</returns>
    internal Trip? Moving(object owner, object key) =>
        _table.TryGetValue(owner, out Dictionary<object, Trip>? owned)
        && owned.TryGetValue(key, out Trip? trip)
        && trip.Moving
            ? trip
            : null;

    /// <summary>
    /// Stops a motion. Whoever was waiting hears that it did not run to the
    /// end.
    /// </summary>
    /// <param name="owner">The control.</param>
    /// <param name="key">Which of its values.</param>
    /// <param name="end">Where to leave the value.</param>
    /// <returns>Whether anything was moving.</returns>
    internal bool Halt(object owner, object key, TripEnd end = TripEnd.Here)
    {
        if (Moving(owner, key) is not Trip trip)
        {
            return false;
        }

        Land(trip, whole: false, end);
        return true;
    }

    /// <summary>
    /// Ends every motion this control owns, leaving each value where it was
    /// going.
    /// </summary>
    /// <remarks>
    /// <para>
    /// What a control TOLD NOT TO TRAVEL needs. A law is per node and arrives
    /// with the message, so it can arrive while a value of that control is
    /// still on its way somewhere: the tree says the control does not travel,
    /// and the control is half way across. Landing it is the only reading of
    /// that message which leaves the two agreeing.
    /// </para>
    /// <para>
    /// It matters because a value that stalls is a value nothing puts right:
    /// an absent field means unchanged, so a property that reached its target
    /// in the TREE is never restated, and a trip left short of it would
    /// keep a control turned, scaled or faded wrongly for the rest of the
    /// session. Measured on Android, in a layout of seven cards changing
    /// shape: some cards kept the previous shape's rotation for good.
    /// </para>
    /// </remarks>
    /// <param name="owner">The control.</param>
    internal void Arrive(object owner)
    {
        if (_moving.Count == 0
            || !_table.TryGetValue(owner, out Dictionary<object, Trip>? owned))
        {
            return;
        }

        foreach (Trip trip in owned.Values.ToArray())
        {
            if (trip.Moving)
            {
                Land(trip, whole: false);
            }
        }
    }

    /// <summary>
    /// Ends every motion in a subtree, leaving each value where it was going.
    /// </summary>
    /// <remarks>
    /// What a control being put away needs: a row going into a pool must not go
    /// on moving, and the value it was moving to is the one the tree last said -
    /// so landing there rather than stopping short is what keeps the two in
    /// agreement. Whoever was waiting hears that it did not run to the end.
    /// </remarks>
    /// <param name="view">The root of the subtree.</param>
    internal void Settle(IView view)
    {
        if (_moving.Count == 0)
        {
            return;
        }

        Arrive(view);

        if (view is not IVisualTreeElement element)
        {
            return;
        }

        foreach (IVisualTreeElement child in element.GetVisualChildren())
        {
            if (child is IView below)
            {
                Settle(below);
            }
        }
    }

    /// <summary>
    /// Ends every motion in a subtree WITHOUT WRITING ANYTHING - what a control
    /// leaving the tree needs.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A trip holds its control for as long as it moves, so a view the tree
    /// has stopped describing goes on being stepped and goes on being written
    /// to. On Apple that is fatal rather than merely wrong: a place lands by
    /// ARRANGING, arranging reads the platform view's superview, and reading it
    /// asks the runtime to marshal a native <c>LayoutView</c> whose managed
    /// side has been collected - *"Failed to marshal the Objective-C object ...
    /// nor was it possible to create a new managed instance"*, and the
    /// application is gone. Measured on Mac Catalyst by scrolling a recycling
    /// list whose rows travel: dead within four sweeps.
    /// </para>
    /// <para>
    /// So the trip is ended with <see cref="TripEnd.Nothing"/> - no write
    /// of any kind, the value left wherever it stood, which is nobody's picture
    /// because the control is not on the screen - and whoever awaited it hears
    /// that it did not run to the end. Where a control is being PUT AWAY rather
    /// than dropped, <see cref="Settle"/> is the other answer: it lands, which
    /// is safe because the row is still in the tree and still has its peer.
    /// </para>
    /// </remarks>
    /// <param name="view">The root of the subtree that is leaving.</param>
    internal void Drop(IView view)
    {
        if (_moving.Count == 0)
        {
            return;
        }

        if (_table.TryGetValue(view, out Dictionary<object, Trip>? owned))
        {
            foreach (Trip trip in owned.Values.ToArray())
            {
                if (trip.Moving)
                {
                    Land(trip, whole: false, TripEnd.Nothing);
                }
            }
        }

        if (view is not IVisualTreeElement element)
        {
            return;
        }

        foreach (IVisualTreeElement child in element.GetVisualChildren())
        {
            if (child is IView below)
            {
                Drop(below);
            }
        }
    }

    /// <summary>
    /// One frame, whole: every value that moves stepped and written, then
    /// whatever else the frame is for, then the clock stopped if that was the
    /// last of it.
    /// </summary>
    /// <remarks>
    /// <para>
    /// THE CLOCK IS STOPPED HERE, once the whole frame is over, and that is
    /// what makes the question answerable: everything that could have started
    /// something has run. A stop from inside the stepping is a stop inside the
    /// platform's own callback, and whatever runs next in that same callback
    /// may start it again - which on a platform asked for one frame at a time
    /// leaves two signals in flight, for ever.
    /// </para>
    /// <para>
    /// What the clock signals is bound to: the platform's frame, or a test's
    /// own winding.
    /// </para>
    /// </remarks>
    internal void Frame()
    {
        _inFrame = true;

        try
        {
            Step();
            Cycle?.Invoke();
        }
        finally
        {
            _inFrame = false;
        }

        Sleep();
    }

    /// <summary>Stops the clock where there is nothing left to draw.</summary>
    /// <remarks>
    /// Never from inside a frame, which <see cref="Frame"/> ends by asking
    /// this itself.
    /// </remarks>
    private void Sleep()
    {
        if (_inFrame || _moving.Count != 0 || Idle?.Invoke() == false)
        {
            return;
        }

        _clock?.Stop();
    }

    /// <summary>One frame: every trip advanced, written, and asked whether it is there.</summary>
    private void Step()
    {
        if (_stepping || _moving.Count == 0)
        {
            return;
        }

        if (Held?.Invoke() == true)
        {
            return;
        }

        long now = _clock?.Now ?? Stopwatch.GetTimestamp();

        if (now == _at)
        {
            // Two clocks on one thread, or a signal delivered twice for one
            // instant: a frame that takes no time moves nothing.
            return;
        }

        _at = now;
        _stepping = true;

        _frame.Clear();
        _frame.AddRange(_moving);

        try
        {
            foreach (Trip trip in _frame)
            {
                if (!trip.Moving)
                {
                    continue;
                }

                double t = (now - trip.T0) * 1000.0 / Stopwatch.Frequency;
                bool rested = MotionLaw.Sample(trip, t, trip.P, trip.V);

                if (rested)
                {
                    _landed.Add((trip, true));
                    continue;
                }

                Put(trip);
            }
        }
        finally
        {
            _stepping = false;
        }

        // TAKEN AND EMPTIED IN ONE GO. A platform write can throw - a mapper,
        // a native property - and the list is the WALKER's rather than this
        // frame's, so one left holding a landing would land it again on the
        // next frame, against a trip that has since been aimed somewhere
        // else.
        (Trip Trip, bool Whole)[] landed = [.. _landed];

        _landed.Clear();

        foreach ((Trip trip, bool whole) in landed)
        {
            if (trip.Moving)
            {
                Land(trip, whole);
            }
        }
    }


    /// <summary>
    /// Writes where the value has got to, unless it is already there.
    /// </summary>
    /// <remarks>
    /// A platform write is the expensive half of a frame - a mapper, a native
    /// property, sometimes a re-layout - and a motion that has slowed to less
    /// than a screen can show has nothing to say. The comparison is against
    /// what was WRITTEN, never against the platform's own reading, so nothing
    /// here can be talked out of a write by a control that rounds.
    /// </remarks>
    private static void Put(Trip trip)
    {
        double[]? wrote = trip.Wrote;

        if (wrote is not null)
        {
            bool same = true;

            for (int lane = 0; lane < wrote.Length && same; lane++)
            {
                same = Math.Abs(wrote[lane] - trip.P[lane]) < MotionLaw.Still;
            }

            if (same)
            {
                return;
            }
        }
        else
        {
            wrote = new double[trip.P.Length];
            trip.Wrote = wrote;
        }

        trip.P.CopyTo(wrote, 0);
        trip.Observed = true;

        Writing++;

        try
        {
            trip.Moves.Write(trip.P);
        }
        finally
        {
            Writing--;
        }

        if (MotionTrace.Watching)
        {
            MotionTrace.Wrote(trip);
        }
    }

    /// <summary>
    /// Ends a motion: the value put exactly where it was going, the trip
    /// forgotten, and whoever was waiting told.
    /// </summary>
    /// <remarks>
    /// The LAST write is the target itself and not the last thing the curve
    /// worked out, because a value that stops a thousandth short has stopped
    /// somewhere nobody described. The trip is then dropped, so the next
    /// setpoint on this value reads the platform afresh.
    /// </remarks>
    /// <param name="trip">The motion.</param>
    /// <param name="whole">Whether it ran to the end.</param>
    /// <param name="end">Where the value is left.</param>
    private void Land(Trip trip, bool whole, TripEnd end = TripEnd.Target)
    {
        if (end == TripEnd.Target)
        {
            trip.Target.CopyTo(trip.P, 0);
        }

        Array.Clear(trip.V);

        if (end != TripEnd.Nothing)
        {
            trip.Observed = true;

            // INSIDE the marker, as a frame's write is, and for a sharper
            // reason: a landing writes the control, the platform raises its
            // change for that write, and a report believed there re-enters as
            // a finger and halts the very landing making it. What tells STATE
            // about the arrival is `Aimed` below, which is this side's own
            // road and needs no report at all.
            Writing++;

            try
            {
                trip.Moves.Write(trip.P);
            }
            finally
            {
                Writing--;
            }

#if ANDROID
            // A SIZE THAT LANDS INSIDE A FRAME IS A SIZE NOBODY MEASURES.
            // Android coalesces `requestLayout`: one asked for while the
            // platform is in its own layout or draw phase - which is where the
            // frame clock runs - is served on the NEXT frame, and a landing has
            // no next frame, the clock stopping with it. So the child keeps the
            // desired size it was last measured at, which is a value from the
            // MIDDLE of the journey, and nothing ever puts it right: measured
            // on the gallery's *Motion* sample as a panel drawn 138 wide and 62
            // tall while its WidthRequest stood at 300, unchanged by ten idle
            // seconds or by a scroll. Asked again a turn later, outside the
            // frame, the measure happens. Only a SIZE needs it - every other
            // property this walker carries is drawn from the value itself.
            if (trip.Moves.Owner is VisualElement sized
                && trip.Moves.Key is BindableProperty property
                && (property == VisualElement.WidthRequestProperty
                    || property == VisualElement.HeightRequestProperty))
            {
                sized.Dispatcher.Dispatch(sized.InvalidateMeasure);
            }
            else if (trip.Moves is StateChannel channel)
            {
                // A size on a STATE is worn by every control on the number.
                channel.Remeasure();
            }
#endif
        }

        trip.Wrote = null;

        if (trip.Moving)
        {
            trip.Moving = false;
            _moving.Remove(trip);
        }

        if (_table.TryGetValue(trip.Moves.Owner, out Dictionary<object, Trip>? owned))
        {
            owned.Remove(trip.Moves.Key);
        }

        // BEFORE the waiter, which resumes a handler that may write this very
        // value somewhere else: where it stopped is older news than whatever
        // that handler asks for next.
        if (end != TripEnd.Nothing)
        {
            Aimed?.Invoke(trip, false);
        }

        Action<bool>? waiting = trip.Done;
        trip.Done = null;
        waiting?.Invoke(whole);

        Sleep();
    }
}
