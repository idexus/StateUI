// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Diagnostics;
using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;

/// <summary>Where a motion leaves the value it was carrying.</summary>
internal enum MotionEnd : byte
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
/// to hear that it arrived. The lanes are plain arrays because a channel is
/// stepped sixty times a second and the numbers are read in order.
/// </remarks>
internal sealed class MotionChannel
{
    /// <summary>What this moves - and, in its owner and key, which value it is.</summary>
    internal required IMotionTarget Moves { get; init; }

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

    /// <summary>The law it travels under.</summary>
    internal MotionSpec Spec { get; set; }

    /// <summary>When the current motion began, in stopwatch ticks.</summary>
    internal long T0 { get; set; }

    /// <summary>Whether the engine is stepping this right now.</summary>
    internal bool Moving { get; set; }

    /// <summary>Told whether the motion ran to the end, once, when it stops.</summary>
    internal Action<bool>? Done { get; set; }

    /// <summary>Where a sample of the motion goes, or null when nobody watches.</summary>
    internal Action<double[]>? Sample { get; set; }

    /// <summary>How many milliseconds of the motion between samples.</summary>
    internal uint Every { get; set; }

    /// <summary>How far into the motion the last sample was taken.</summary>
    internal double SampledAt { get; set; }

    /// <summary>Where the value was last actually written.</summary>
    internal double[]? Wrote { get; set; }
}

/// <summary>
/// What moves every value that is going somewhere, one frame at a time.
/// </summary>
/// <remarks>
/// <para>
/// The tree describes where the interface is GOING; this is how the screen
/// catches up. A setpoint arrives - from a flight the author started, from a
/// property that simply changed, from a layout that put a child somewhere new -
/// and a CHANNEL carries the real value there, on the display's own rhythm,
/// carrying position AND speed so a target changed halfway bends the motion
/// instead of cutting it.
/// </para>
/// <para>
/// One engine per session, on the thread the platform draws on, with no locks
/// anywhere: every setpoint arrives from an apply and every frame arrives from
/// the platform's clock, and both of those are that thread.
/// </para>
/// <para>
/// It SLEEPS. The clock is started when the first channel begins to move and
/// stopped when the last one lands, so a still screen costs nothing at all.
/// </para>
/// </remarks>
internal sealed class MotionEngine
{
    /// <summary>
    /// Every channel, by what it moves - the control, then which of its values.
    /// </summary>
    /// <remarks>
    /// Weak in the owner, so a control that has left the tree is not held by
    /// the fact that something once moved it. A channel is removed the moment
    /// it lands, which is what makes the next setpoint on the same value read
    /// where the platform actually has it: a reader's drag, a visual state, a
    /// layout pass - anything may have written it while nothing was moving.
    /// </remarks>
    private readonly ConditionalWeakTable<object, Dictionary<object, MotionChannel>> _table = new();

    /// <summary>The channels that are moving, which is what a frame steps.</summary>
    private readonly List<MotionChannel> _moving = [];

    /// <summary>The moving channels, copied for the length of one frame.</summary>
    /// <remarks>
    /// A write can be heard - a slider raises a change, a layout re-arranges -
    /// and what hears it may render, which may start or stop channels. So a
    /// frame steps a COPY and skips whatever stopped moving while it ran.
    /// </remarks>
    private readonly List<MotionChannel> _frame = [];

    /// <summary>What landed during a frame, told after it rather than inside it.</summary>
    private readonly List<(MotionChannel Channel, bool Whole)> _landed = [];

    /// <summary>
    /// How many setpoints have been given - the count a call compares against
    /// to find out whether a newer one overtook it. See <see cref="Aim"/>.
    /// </summary>
    private long _aims;

    private IMotionClock? _clock;
    private bool _asked;
    private bool _stepping;
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
    /// frame. See <c>MotionArranger</c>.
    /// </remarks>
    internal long Applies { get; private set; }

    /// <summary>Counts one message applied.</summary>
    internal void Said() => Applies++;

    /// <summary>The instant the last frame was worked out at.</summary>
    /// <remarks>
    /// The clock runs on the thread that lays out, so this number standing
    /// still across two arrangements says the same thing twice over: no frame
    /// has been made, and none can be until the pass that is asking lets the
    /// thread go. Read by <c>MotionArranger</c>, which is the one place a
    /// motion is written from inside a layout pass. Nought while nothing
    /// moves.
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
    internal MotionSpec Travel { get; set; } = MotionSpec.Eased(0, 0);

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
    /// What says when to draw - the platform's own frame signal, or one a test
    /// winds by hand.
    /// </summary>
    /// <remarks>
    /// Asked for once, the first time anything moves. A build with no clock -
    /// the headless tests, unless they bring one - lands every setpoint at once,
    /// which is the honest answer where there is no screen to move across.
    /// </remarks>
    internal IMotionClock? Clock
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

    private void Attach(IMotionClock? clock)
    {
        if (ReferenceEquals(_clock, clock))
        {
            return;
        }

        if (_clock is not null)
        {
            _clock.Frame -= Step;
            _clock.Stop();
        }

        _clock = clock;

        if (_clock is not null)
        {
            _clock.Frame += Step;
        }
    }

    /// <summary>The platform's clock, or nothing when it cannot be had.</summary>
    private static IMotionClock? Made()
    {
        try
        {
            return MotionClock.Create();
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
    /// <param name="sample">Where readings of the motion go, or null for none.</param>
    /// <param name="every">Milliseconds of the motion between readings.</param>
    /// <param name="from">
    /// Where the motion starts, for a caller that knows better than the value
    /// itself does - a layout has already put its child at the target by the
    /// time it asks, so the place it came from is the layout's to say. Ignored
    /// while a motion is already under way, which starts from where that one
    /// has reached.
    /// </param>
    /// <returns>The channel, or null when the value landed at once.</returns>
    internal MotionChannel? Aim(
        IMotionTarget moves,
        double[] to,
        in MotionSpec spec,
        Action<bool>? done = null,
        Action<double[]>? sample = null,
        uint every = 0,
        double[]? from = null)
    {
        // Every setpoint is counted, so a call can find out whether a newer one
        // overtook it while it was telling somebody their motion had ended.
        long spoke = ++_aims;

        Dictionary<object, MotionChannel> owned = _table.GetValue(moves.Owner, static _ => []);
        bool had = owned.TryGetValue(moves.Key, out MotionChannel? channel);

        if (had && channel!.Moving)
        {
            // Whatever was waiting on the motion being replaced hears first,
            // and hears that it did not finish - the same answer a second
            // animation of one property has always given the first.
            Action<bool>? waiting = channel.Done;
            channel.Done = null;

            if (waiting is not null)
            {
                // Being told resumes a handler, which may write state, render,
                // and send this very value somewhere else - all before this
                // call has finished arming it. The NEWER setpoint is the one
                // that stands, so a call that was overtaken while it spoke
                // gives up its turn rather than writing over the answer.
                waiting(false);

                if (spoke != _aims)
                {
                    return Moving(moves.Owner, moves.Key);
                }
            }
        }

        if (channel is null)
        {
            channel = new MotionChannel
            {
                Moves = moves,
                P = new double[moves.Lanes],
                V = new double[moves.Lanes],
                From = new double[moves.Lanes],
                StartV = new double[moves.Lanes],
                Target = new double[moves.Lanes],
            };

            owned[moves.Key] = channel;
        }

        if (channel.Moving)
        {
            channel.P.CopyTo(channel.From, 0);
            channel.V.CopyTo(channel.StartV, 0);
        }
        else if (from is not null)
        {
            Array.Clear(channel.StartV);
            from.CopyTo(channel.From, 0);
        }
        else
        {
            Array.Clear(channel.StartV);

            if (!channel.Moves.Read(channel.From))
            {
                // Nothing there to move from - a property of a shape that has
                // no half-way, or a child no layout has placed yet. It goes to
                // where it was told and says so.
                to.CopyTo(channel.From, 0);
            }
        }

        to.CopyTo(channel.Target, 0);
        channel.Spec = spec;
        channel.Done = done;
        channel.Sample = sample;
        channel.Every = every;
        channel.SampledAt = double.NegativeInfinity;

        // A SETPOINT WHERE THE VALUE ALREADY IS is an arrival. Nothing else
        // would be drawn - a motion of no distance writes the same number for
        // a fifth of a second - and it is not a rare case: a visual state
        // settles every value it touches on every apply, and almost all of
        // them are already where they belong.
        //
        // Nothing moves either for a reader who asked for less movement. Both
        // answer TRUE to whoever awaited the motion: the target was reached,
        // which is the whole of what they asked about.
        if (spec.Instant || There(channel) || MotionMood.Reduced || Clock is null)
        {
            Land(channel, whole: true);
            return null;
        }

        channel.From.CopyTo(channel.P, 0);
        channel.StartV.CopyTo(channel.V, 0);
        channel.T0 = Clock?.Now ?? Stopwatch.GetTimestamp();

        if (!channel.Moving)
        {
            channel.Moving = true;
            _moving.Add(channel);
        }

        // Written at once, so the value is where the motion says it is from
        // the frame it starts on - which is what lets a layout hand its child
        // over having already put it at the target.
        Put(channel);
        Watch(channel, 0);
        Clock?.Start();

        return channel;
    }

    /// <summary>Whether the value is already where it is being sent.</summary>
    private static bool There(MotionChannel channel)
    {
        for (int lane = 0; lane < channel.From.Length; lane++)
        {
            if (Math.Abs(channel.From[lane] - channel.Target[lane]) >= MotionCurve.Still)
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
        if (_moving.Count == 0 || !_table.TryGetValue(owner, out Dictionary<object, MotionChannel>? owned))
        {
            return false;
        }

        foreach (MotionChannel channel in owned.Values)
        {
            if (channel.Moving)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>Where a value has got to, whether or not it is still moving.</summary>
    /// <param name="owner">The control.</param>
    /// <param name="key">Which of its values.</param>
    /// <returns>The channel carrying it, or null when nothing is.</returns>
    internal MotionChannel? Moving(object owner, object key) =>
        _table.TryGetValue(owner, out Dictionary<object, MotionChannel>? owned)
        && owned.TryGetValue(key, out MotionChannel? channel)
        && channel.Moving
            ? channel
            : null;

    /// <summary>
    /// Stops a motion. Whoever was waiting hears that it did not run to the
    /// end.
    /// </summary>
    /// <param name="owner">The control.</param>
    /// <param name="key">Which of its values.</param>
    /// <param name="end">Where to leave the value.</param>
    /// <returns>Whether anything was moving.</returns>
    internal bool Halt(object owner, object key, MotionEnd end = MotionEnd.Here)
    {
        if (Moving(owner, key) is not MotionChannel channel)
        {
            return false;
        }

        Land(channel, whole: false, end);
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
    /// in the TREE is never restated, and a channel left short of it would
    /// keep a control turned, scaled or faded wrongly for the rest of the
    /// session. Measured on Android, in a layout of seven cards changing
    /// shape: some cards kept the previous shape's rotation for good.
    /// </para>
    /// </remarks>
    /// <param name="owner">The control.</param>
    internal void Arrive(object owner)
    {
        if (_moving.Count == 0
            || !_table.TryGetValue(owner, out Dictionary<object, MotionChannel>? owned))
        {
            return;
        }

        foreach (MotionChannel channel in owned.Values.ToArray())
        {
            if (channel.Moving)
            {
                Land(channel, whole: false);
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

    /// <summary>One frame: every channel advanced, written, and asked whether it is there.</summary>
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
            foreach (MotionChannel channel in _frame)
            {
                if (!channel.Moving)
                {
                    continue;
                }

                double t = (now - channel.T0) * 1000.0 / Stopwatch.Frequency;
                bool rested = MotionCurve.At(channel, t, channel.P, channel.V);

                if (rested)
                {
                    _landed.Add((channel, true));
                    continue;
                }

                Put(channel);
                Watch(channel, t);
            }
        }
        finally
        {
            _stepping = false;
        }

        // TAKEN AND EMPTIED IN ONE GO. A platform write can throw - a mapper,
        // a native property - and the list is the ENGINE's rather than this
        // frame's, so one left holding a landing would land it again on the
        // next frame, against a channel that has since been aimed somewhere
        // else.
        (MotionChannel Channel, bool Whole)[] landed = [.. _landed];

        _landed.Clear();

        foreach ((MotionChannel channel, bool whole) in landed)
        {
            if (channel.Moving)
            {
                Land(channel, whole);
            }
        }

        if (_moving.Count == 0)
        {
            _clock?.Stop();
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
    private static void Put(MotionChannel channel)
    {
        double[]? wrote = channel.Wrote;

        if (wrote is not null)
        {
            bool same = true;

            for (int lane = 0; lane < wrote.Length && same; lane++)
            {
                same = Math.Abs(wrote[lane] - channel.P[lane]) < MotionCurve.Still;
            }

            if (same)
            {
                return;
            }
        }
        else
        {
            wrote = new double[channel.P.Length];
            channel.Wrote = wrote;
        }

        channel.P.CopyTo(wrote, 0);
        channel.Moves.Write(channel.P);

        if (MotionTrace.Watching)
        {
            MotionTrace.Wrote(channel);
        }
    }

    /// <summary>Passes a reading on when one is due.</summary>
    private static void Watch(MotionChannel channel, double t)
    {
        if (channel.Sample is null || !SwiftFlights.Due(t, channel.SampledAt, channel.Every))
        {
            return;
        }

        channel.SampledAt = t;
        channel.Sample(channel.P);
    }

    /// <summary>
    /// Ends a motion: the value put exactly where it was going, the channel
    /// forgotten, and whoever was waiting told.
    /// </summary>
    /// <remarks>
    /// The LAST write is the target itself and not the last thing the curve
    /// worked out, because a value that stops a thousandth short has stopped
    /// somewhere nobody described. The channel is then dropped, so the next
    /// setpoint on this value reads the platform afresh.
    /// </remarks>
    /// <param name="channel">The motion.</param>
    /// <param name="whole">Whether it ran to the end.</param>
    /// <param name="end">Where the value is left.</param>
    private void Land(MotionChannel channel, bool whole, MotionEnd end = MotionEnd.Target)
    {
        if (end == MotionEnd.Target)
        {
            channel.Target.CopyTo(channel.P, 0);
        }

        Array.Clear(channel.V);

        if (end != MotionEnd.Nothing)
        {
            channel.Moves.Write(channel.P);
        }

        channel.Wrote = null;

        if (channel.Moving)
        {
            channel.Moving = false;
            _moving.Remove(channel);
        }

        if (_table.TryGetValue(channel.Moves.Owner, out Dictionary<object, MotionChannel>? owned))
        {
            owned.Remove(channel.Moves.Key);
        }

        if (channel.Sample is not null && whole)
        {
            channel.Sample(channel.P);
        }

        Action<bool>? waiting = channel.Done;
        channel.Done = null;
        waiting?.Invoke(whole);

        if (_moving.Count == 0)
        {
            _clock?.Stop();
        }
    }
}
