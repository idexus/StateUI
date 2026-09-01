// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using Microsoft.Maui.Controls;
using Microsoft.Maui.Graphics;
using StateUI.Runtime.Interop;

/// <summary>
/// The channels: values the platform moves many times a second, and the
/// layouts that follow them - the one path that reaches the Swift side without
/// describing anything.
/// </summary>
/// <remarks>
/// <para>
/// A scroller's offset changes with every touch report. Held as state it is a
/// write, a render and a message each time; held here it is one number handed
/// to the author's own arithmetic, which answers where each view of a layout
/// goes, and those numbers are written straight onto the controls this side is
/// already holding. No tree is built, nothing is compared and no message is
/// packed.
/// </para>
/// <para>
/// The buffer is OURS and is reused, so a path taken on every frame allocates
/// on neither side of the boundary. The layouts are held WEAKLY: a follower
/// outlives nothing, and a page left takes its layouts with it.
/// </para>
/// </remarks>
internal sealed class Channels
{
    /// <summary>What carries the tree's own motions - asked before writing.</summary>
    private readonly MotionEngine _engine;

    /// <summary>The channels, and the engine whose flights they must not fight.</summary>
    /// <param name="engine">What carries the tree's own motions.</param>
    internal Channels(MotionEngine engine)
    {
        _engine = engine;
    }

    /// <summary>How many numbers one view's placement takes.</summary>
    /// <remarks>
    /// x, y, width, height, translationX, translationY, rotation, scaleX,
    /// scaleY, opacity, zIndex - the order <c>Core/Channel.swift</c> packs
    /// them in.
    /// </remarks>
    private const int Fields = 11;

    /// <summary>A size this close to the one a child has is the same size.</summary>
    private const double Same = 0.01;

    /// <summary>One layout following one value, and the arithmetic it follows it with.</summary>
    private sealed record Follower(WeakReference<Layout> Layout, int Rule);

    private readonly Dictionary<int, List<Follower>> _following = [];

    /// <summary>Where each value stands, as far as this side has been told.</summary>
    /// <remarks>
    /// Kept because a DRAG moves a value rather than setting it: a gesture
    /// reports how far it has come since it began, and where it began is
    /// wherever the value already stood.
    /// </remarks>
    private readonly Dictionary<int, double> _standing = [];

    private double[] _buffer = new double[Fields * 8];

    /// <summary>
    /// Says that a layout follows a continuous value, and with what.
    /// </summary>
    /// <param name="layout">The layout holding the placed views.</param>
    /// <param name="channels">The channels it follows - any of them moving is
    /// what asks for the arithmetic again.</param>
    /// <param name="rule">The arithmetic, by the id the message carried.</param>
    internal void Follows(Layout layout, double[] channels, int rule)
    {
        foreach (double number in channels)
        {
            Follows(layout, (int)number, rule);
        }
    }

    /// <summary>
    /// A followed layout has just been described - so this side's delta is
    /// spent, and the layout is aligned again once whatever the tree started
    /// has arrived.
    /// </summary>
    /// <remarks>
    /// EVERY APPLY, not only the ones that carry the properties: a message
    /// mentions a property only when it CHANGED, so a layout that goes on
    /// following the same channels under the same arithmetic says neither -
    /// and hooking the alignment to their arrival meant a change of shape
    /// aligned nothing at all, leaving every card standing where the reader's
    /// last movement had put it while the tree drew the new shape underneath.
    /// Measured on the placed gallery: move the run, change the shape, and the
    /// cards scatter until the next report puts them right.
    /// </remarks>
    /// <param name="layout">The layout that was described.</param>
    internal void Applied(Layout layout)
    {
        int rule = RuleOf(layout);

        if (rule == 0)
        {
            return;
        }

        // THE TREE HAS JUST SAID WHERE EVERYTHING IS, and what it said already
        // holds wherever the reader has moved the run to - the arithmetic
        // reads the channels. So this side's delta is spent.
        for (int index = 0; index < layout.Count; index++)
        {
            if (layout[index] is View child)
            {
                (double X, double Y) authored = AuthoredOf(child);

                child.TranslationX = authored.X;
                child.TranslationY = authored.Y;
            }
        }

        Aligned(layout, rule, waited: 0);
    }

    /// <summary>The layouts whose size is already watched, so the hook is made once.</summary>
    private readonly HashSet<Layout> _watched = [];

    /// <summary>What the TREE last wrote as each placed view's translation.</summary>
    /// <remarks>
    /// The ground a channel's write stands on. A move is written as a
    /// translation on top of whatever the author's own transform said, so the
    /// two must not be confused: read back from the control they would
    /// compound, and a render that does not mention the property at all - an
    /// unchanged value - would leave this side's delta standing under the
    /// tree's new bounds and count the reader's movement twice. Measured on
    /// the placed gallery: scroll, then change the shape, and every card
    /// stood a run's worth away from where it belonged.
    /// </remarks>
    private readonly Dictionary<View, (double X, double Y)> _authored = [];

    /// <summary>
    /// Records what the tree wrote as a view's translation, as it writes it.
    /// </summary>
    /// <param name="view">The view being described.</param>
    /// <param name="x">What the tree said sideways, where it said one.</param>
    /// <param name="y">What it said downwards, where it said one.</param>
    internal void Authored(View view, double? x = null, double? y = null)
    {
        _authored.TryGetValue(view, out (double X, double Y) held);
        _authored[view] = (x ?? held.X, y ?? held.Y);
    }

    /// <summary>What the tree wrote, or nothing at all where it never did.</summary>
    private (double X, double Y) AuthoredOf(View view) =>
        _authored.TryGetValue(view, out (double X, double Y) held) ? held : (0, 0);

    /// <summary>
    /// Whether a layout is placed by a rule the host runs - set here, read by
    /// the arranger's measure.
    /// </summary>
    /// <remarks>
    /// A followed layout's children stand where ARITHMETIC over the room puts
    /// them, so they say nothing about how big the layout should be - and a
    /// layout that answered with their reach fed its own measure: the room
    /// grew or shrank with the placements, the placements with the room, and
    /// the pass oscillated for ever at a whole core. Measured on Mac Catalyst
    /// at launch, and as a run drawn off its own centre on Android.
    /// </remarks>
    internal static readonly BindableProperty FollowedProperty =
        BindableProperty.CreateAttached(
            "StateUIFollowed",
            typeof(bool),
            typeof(Channels),
            defaultValue: false);

    /// <summary>One layout following one of the values it follows.</summary>
    private void Follows(Layout layout, int channel, int rule)
    {
        layout.SetValue(FollowedProperty, true);

        // THE CHANNELS WRITE BEHIND THE TREE'S BACK, so the tree cannot put
        // these properties right: a render diffs against what IT last said,
        // and a translation this side wrote reads as unchanged and is never
        // sent again. The answer is that a followed layout is RE-PLACED after
        // anything that could have moved the ground under it - this apply,
        // once the pass has laid the layout out, and every later change of
        // its size (a turned phone, a resized window).
        if (_watched.Add(layout))
        {
            layout.SizeChanged += (_, _) => Resized(layout);
        }

        if (!_following.TryGetValue(channel, out List<Follower>? followers))
        {
            _following[channel] = followers = [];
        }

        for (int index = 0; index < followers.Count; index++)
        {
            if (!followers[index].Layout.TryGetTarget(out Layout? held))
            {
                continue;
            }

            if (ReferenceEquals(held, layout))
            {
                // The same layout, told a new rule: a render re-registers what
                // it already had, and the id is the one thing that can move.
                if (followers[index].Rule == rule)
                {
                    return;
                }

                followers.RemoveAt(index);
                break;
            }
        }

        followers.Add(new Follower(new WeakReference<Layout>(layout), rule));
    }

    /// <summary>The layouts whose re-place is already queued for a later turn.</summary>
    private readonly HashSet<Layout> _replacing = [];

    /// <summary>The layouts being placed right now, so a report cannot recurse.</summary>
    private readonly HashSet<Layout> _placing = [];

    /// <summary>
    /// The layout was given a new size, so its arithmetic has a new answer.
    /// </summary>
    /// <remarks>
    /// <para>
    /// AT ONCE, on the platform's own report. A window being dragged is a
    /// continuous driver, and every turn of waiting is a run of cards a frame
    /// behind the hand - but the wait is worse than that on a Mac, where the
    /// resize is tracked in a run loop mode that drains no dispatcher at all:
    /// measured, the queued turn ran 590 ms after the report that asked for
    /// it, having swallowed eleven reports on the way, so the cards stood
    /// still for the whole drag and jumped when it stopped.
    /// </para>
    /// <para>
    /// WHAT IS PLACED HERE IS THE MOVE ALONE. A move is a TRANSLATION and
    /// invalidates nothing, so it is safe inside the platform's own layout
    /// pass; a change of SIZE is the one write that invalidates the measure,
    /// and written from inside the pass that reported the room it invalidates
    /// that very pass. Where the room is worked out from the children's own
    /// size - a run of cards fitted to the box a page gives it - the two then
    /// chase each other for ever: measured on the gallery at launch, the
    /// layout alternated between 277.4 and 329.9 points 31,520 times each. So
    /// a size is left OWING and `Later` writes it, outside the pass.
    /// </para>
    /// <para>
    /// The re-entrant case is guarded rather than assumed: a report arriving
    /// while this is placing is taken on a later turn too.
    /// </para>
    /// </remarks>
    /// <param name="layout">The layout whose size moved.</param>
    private void Resized(Layout layout)
    {
        if (_placing.Contains(layout))
        {
            Later(layout);
            return;
        }

        _placing.Add(layout);

        try
        {
            int rule = RuleOf(layout);

            if (Flying(layout))
            {
                Aligned(layout, rule, waited: 0);
                return;
            }

            // MOVES ONLY, and a size change owed to a later turn - see Place.
            if (Place(layout, rule, moving: true))
            {
                Later(layout);
            }
        }
        finally
        {
            _placing.Remove(layout);
        }
    }

    /// <summary>
    /// Puts the layout right on a later turn - what a place made inside the
    /// platform's own layout pass leaves owing.
    /// </summary>
    /// <remarks>
    /// It runs OUTSIDE the pass, so this is the full write: the sizes a resize
    /// could not say are written here, where invalidating the measure is
    /// ordinary rather than a pass invalidating itself. One queued turn per
    /// layout at a time - every report while one is waiting asks for the same
    /// arithmetic over the same size, which the one turn reads for itself when
    /// it runs.
    /// </remarks>
    /// <param name="layout">The layout to put right.</param>
    private void Later(Layout layout)
    {
        if (!_replacing.Add(layout))
        {
            return;
        }

        layout.Dispatcher.Dispatch(() =>
        {
            _replacing.Remove(layout);

            int rule = RuleOf(layout);

            if (Flying(layout))
            {
                Aligned(layout, rule, waited: 0);
                return;
            }

            Place(layout, rule);
        });
    }

    /// <summary>Whether the tree's engine is carrying any of the layout's children.</summary>
    private bool Flying(Layout layout)
    {
        for (int index = 0; index < layout.Count; index++)
        {
            if (layout[index] is View child
                && _engine.Moving(child, MotionFrame.Place) is not null)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>How long one wait for the tree's flights is, in milliseconds.</summary>
    private const int Wait = 90;

    /// <summary>How many waits are worth taking before letting it lie.</summary>
    private const int Waits = 40;

    /// <summary>
    /// Puts the layout where its arithmetic says, once the tree is done moving
    /// it - the alignment a render owes, because the tree cannot put right the
    /// properties this side wrote behind its back.
    /// </summary>
    /// <remarks>
    /// DELAYED EVEN WHEN NOTHING FLIES, deliberately: this runs from an apply,
    /// and the walks that apply described arm at the ARRANGE that follows it -
    /// asked at once, the engine still answers "nothing is moving" and the
    /// write would land in the middle of the very flight it was told to keep
    /// out of. One wait later the walks are armed and the answer is real.
    /// </remarks>
    /// <param name="layout">The layout to align.</param>
    /// <param name="rule">The arithmetic, by the id the message carried.</param>
    /// <param name="waited">How many waits this alignment has already taken.</param>
    private void Aligned(Layout layout, int rule, int waited)
    {
        if (rule == 0 || waited > Waits)
        {
            return;
        }

        layout.Dispatcher.DispatchDelayed(TimeSpan.FromMilliseconds(Wait), () =>
        {
            if (Flying(layout))
            {
                Aligned(layout, rule, waited + 1);
                return;
            }

            Place(layout, rule);
        });
    }

    /// <summary>The rule a layout is currently registered under, or zero.</summary>
    private int RuleOf(Layout layout)
    {
        foreach (List<Follower> followers in _following.Values)
        {
            foreach (Follower follower in followers)
            {
                if (follower.Layout.TryGetTarget(out Layout? held)
                    && ReferenceEquals(held, layout))
                {
                    return follower.Rule;
                }
            }
        }

        return 0;
    }

    /// <summary>Where a value stands, as far as this side has been told.</summary>
    /// <remarks>
    /// The value is pushed across even when nothing follows it, because the
    /// Swift side holds it too: a render that happens later describes the views
    /// where the reader left them, rather than where they were when the tree
    /// was last built.
    /// </remarks>
    /// <param name="channel">The value being asked about.</param>
    /// <returns>Where it stands.</returns>
    internal double Standing(int channel) =>
        _standing.TryGetValue(channel, out double value) ? value : 0;

    /// <summary>
    /// Says where a continuous value now stands, and puts every layout
    /// following it where its arithmetic says.
    /// </summary>
    /// <param name="channel">The value that moved.</param>
    /// <param name="value">Where it now stands.</param>
    internal void Moved(int channel, double value)
    {
        _standing[channel] = value;

        // NO MODULE, NOTHING TO ASK: a host with no Swift side registered is a
        // test host, whose controls are real MAUI objects with no library
        // behind them - the same thing that keeps a session from being claimed
        // there. A report then goes nowhere, which is what it means.
        if (StateUISession.RegisterApp is null)
        {
            return;
        }

        // ALWAYS, and before anything is placed: the arithmetic READS the
        // values it follows, so every one of them has to be where the platform
        // says before any of it runs - and a value nobody follows is still one
        // the next render describes from.
        NativeMethods.ChannelMoved(channel, value);

        if (!_following.TryGetValue(channel, out List<Follower>? followers))
        {
            return;
        }

        for (int index = followers.Count - 1; index >= 0; index--)
        {
            if (!followers[index].Layout.TryGetTarget(out Layout? layout))
            {
                followers.RemoveAt(index);
                continue;
            }

            Place(layout, followers[index].Rule);
        }
    }

    /// <summary>
    /// Asks the arithmetic where every view of one layout goes, and writes the
    /// answer onto them.
    /// </summary>
    /// <param name="layout">The layout to place.</param>
    /// <param name="rule">The arithmetic, by the id the message carried.</param>
    /// <param name="moving">
    /// Whether to write MOVES alone and leave any change of SIZE for a later
    /// turn - what a place running inside the platform's own layout pass asks
    /// for.
    /// </param>
    /// <returns>Whether a size was left owing.</returns>
    private unsafe bool Place(Layout layout, int rule, bool moving = false)
    {
        int count = layout.Count;

        if (count == 0 || rule == 0 || StateUISession.RegisterApp is null)
        {
            return false;
        }

        // A LAYOUT THE TREE IS MOVING IS THE TREE'S: a change of shape flies
        // every child to its new place, and a write landing mid-flight snaps
        // the very journey the tree described. A REPORT dropped here is not
        // owed a retry - the next one is a frame away - and the after-a-render
        // alignment retries through Aligned until the flights are over.
        if (Flying(layout))
        {
            return false;
        }

        int needed = count * Fields;

        if (_buffer.Length < needed)
        {
            _buffer = new double[needed];
        }

        int written;

        fixed (double* into = _buffer)
        {
            written = NativeMethods.Place(
                rule,
                count,
                layout.Width,
                layout.Height,
                into,
                _buffer.Length);
        }

        // Nothing holds that arithmetic any more - the layout was described
        // away, and the next render is what settles where its views are.
        if (written < needed)
        {
            return false;
        }

        bool owing = false;

        for (int index = 0; index < count; index++)
        {
            if (layout[index] is View child)
            {
                owing |= Wear(child, _buffer.AsSpan(index * Fields, Fields), moving);
            }
        }

        return owing;
    }

    /// <summary>
    /// One view, wearing one placement.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A MOVE IS A TRANSLATION, never a new rectangle. Writing a child's
    /// <c>LayoutBounds</c> invalidates the layout's measure, which on Android
    /// is a real <c>requestLayout</c> and costs a whole-hierarchy measure and
    /// layout pass - measured at 3.4 ms a report on a phone whose frame is
    /// 11.1. The picture is the same either way: a translation is applied
    /// outside the pivot-centred turn and scale on every platform here, which
    /// is exactly what moving the rectangle does.
    /// </para>
    /// <para>
    /// A SIZE is the one part that cannot be said that way, so a placement
    /// whose width or height moved does write the rectangle - and a layout
    /// whose views change size while a finger is down pays for it, which is
    /// the honest cost of asking for it.
    /// </para>
    /// <para>
    /// AND IT IS THE ONE WRITE A LAYOUT PASS MUST NOT SEE. <c>SetLayoutBounds</c>
    /// invalidates the measure, so a size written from inside the pass that
    /// reported the room invalidates that very pass - and where the room is
    /// worked out from the children's own size, the two chase each other for
    /// ever. Measured on the gallery: a run alternating between 277.4 and
    /// 329.9 points, one card size feeding the next, thousands of times a
    /// second. So a place made from a resize writes the MOVES and says a size
    /// is owing; the turn that follows the pass writes it.
    /// </para>
    /// </remarks>
    /// <param name="child">The view being placed.</param>
    /// <param name="placement">Where the arithmetic put it.</param>
    /// <param name="moving">Whether to leave a change of size for a later turn.</param>
    /// <returns>Whether a size was left unwritten.</returns>
    private static bool Wear(View child, ReadOnlySpan<double> placement, bool moving)
    {
        Rect bounds = AbsoluteLayout.GetLayoutBounds(child);

        double x = placement[0];
        double y = placement[1];
        double width = placement[2];
        double height = placement[3];

        bool owing = false;

        if (Math.Abs(width - bounds.Width) > Same || Math.Abs(height - bounds.Height) > Same)
        {
            if (moving)
            {
                owing = true;
            }
            else
            {
                bounds = new Rect(x, y, width, height);
                AbsoluteLayout.SetLayoutBounds(child, bounds);
            }
        }

        // WORKED OUT AFRESH, never read back: the placement carries the
        // author's own translation and the rectangle says the rest, so writing
        // this twice writes the same thing - which is what lets a report be
        // dropped without owing a correction.
        child.TranslationX = placement[4] + (x - bounds.X);
        child.TranslationY = placement[5] + (y - bounds.Y);
        child.Rotation = placement[6];
        child.ScaleX = placement[7];
        child.ScaleY = placement[8];
        child.Opacity = placement[9];
        child.ZIndex = (int)placement[10];

        return owing;
    }
}
