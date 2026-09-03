// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using Microsoft.Maui.Layouts;
using StateUI.Runtime.Protocol;

/// <summary>
/// A layout whose children TRAVEL to their new places instead of appearing
/// there.
/// </summary>
/// <remarks>
/// <para>
/// A layout's arrangement is the one thing about a view that is not a property:
/// where a child sits is worked out here, from what was measured, so nothing
/// describes it and nothing could move it. That is why a row that changes place
/// has always jumped there while every colour beside it could glide - and it is
/// the whole of what this fixes.
/// </para>
/// <para>
/// It wraps whatever manager the layout would have used, so the arithmetic is
/// untouched: a stack still stacks, a grid still measures its stars, a flex
/// still wraps. What changes is only WHERE each child is put once that
/// arithmetic has answered - at the place the engine has carried it to, rather
/// than at the answer itself. Add a card and the ones below it slide down;
/// widen a grid's column and every child crosses to its new width; swap what a
/// layout holds and everything settles into place.
/// </para>
/// <para>
/// A RESIZE SNAPS, and what tells one apart is whether a MESSAGE was applied
/// since the last arrangement. A message means the interface HOLDS something
/// different - a row inserted, a column widened - and the children travel to
/// their new places. None means the room itself is moving: a window dragged, a
/// keyboard rising, a scroller settling. Everything then tracks it exactly,
/// because a child that glides after a reader's own hand is late every frame.
/// </para>
/// </remarks>
internal sealed class MotionArranger : ILayoutManager
{
    /// <summary>What each child's place is filed under, per layout.</summary>
    private sealed class Seat
    {
        /// <summary>The child's place, as something the engine can move.</summary>
        internal required MotionFrame Frame { get; init; }

        /// <summary>Where it was last put - which is where it travels FROM.</summary>
        internal Rect Was { get; set; }
    }

    private readonly ILayoutManager _inner;
    private readonly Layout _layout;
    private readonly MotionEngine _engine;
    private readonly ConditionalWeakTable<IView, Seat> _seats = new();

    /// <summary>Whether each child's size is one somebody measures.</summary>
    /// <remarks>
    /// Answered by walking what a child holds, which is worth doing once: an
    /// arrangement is asked for whenever anything invalidates, and what a
    /// view holds changes only when a message says so. Cleared on every
    /// applied message for that reason.
    /// </remarks>
    private readonly ConditionalWeakTable<IView, object> _reads = new();

    /// <summary>Whether this layout has ever arranged its children.</summary>
    /// <remarks>
    /// The first arrangement of all is an arrival - every child is new, and a
    /// whole page fading into place is not what anyone asked for.
    /// </remarks>
    private bool _placed;

    private long _applied = -1;

    /// <summary>The clock instant the last arrangement was made at.</summary>
    private long _stamp;

    /// <summary>
    /// How many arrangements in a row have undone the inner manager without
    /// the clock moving on.
    /// </summary>
    private int _repeats;

    /// <summary>
    /// Whether a size ARRIVES here rather than travelling - what this layout
    /// was measured refusing to settle on. See <see cref="Refuse"/>.
    /// </summary>
    private bool _arrives;

    /// <summary>
    /// How many of those are allowed before the motions are landed.
    /// </summary>
    /// <remarks>
    /// <para>
    /// IT IS A COUNT OF PASSES because the thing it has to stay under is one:
    /// WinUI gives up on a layout that will not settle and takes the
    /// application down with a stowed exception, and what it counts is
    /// iterations of its own layout loop. A deadline in milliseconds was tried
    /// and is wrong for exactly that reason - the spin is FAST, a hundred
    /// passes inside a tenth of a second, so a quarter-second patience arrives
    /// long after WinUI has given up.
    /// </para>
    /// <para>
    /// BOTH BOUNDS ARE MEASURED. A page SETTLING after a message arranges
    /// itself several times over before the first frame of what it just
    /// started - six times on the gallery's three-column grid - and every one
    /// of those is an honest pass that ends; four was under that, which is why
    /// every motion on that page snapped. A window RESIZED while something is
    /// in flight is the other end: MoveWindow holds the thread that lays out,
    /// so no frame can be made, and the undo below keeps the pass dirty for as
    /// long as it is allowed to - 124 passes on the gallery's home page, and
    /// then the crash. This sits an order of magnitude clear of both.
    /// </para>
    /// </remarks>
    private const int Repeats = 24;

    /// <summary>
    /// How many layouts are arranging right now - nought between passes.
    /// </summary>
    /// <remarks>
    /// Read by <see cref="MotionFrame"/> on Windows, where a place written
    /// between passes reaches nothing and one written inside a pass lands. A
    /// write already inside a pass therefore has nothing to ask for, and asking
    /// would only dirty the pass that is making it.
    /// </remarks>
    internal static int Arranging { get; private set; }

    /// <summary>
    /// Which parts of a child's place travel here - what
    /// <c>.motion(.none, .size)</c> on a layout comes to.
    /// </summary>
    /// <remarks>
    /// ATTACHED rather than held, as the one below is and for the same reason:
    /// the arranger is made when the layout first MEASURES, which is after the
    /// message that carried the motion was applied - so there is no arranger
    /// to tell when the answer arrives, and the layout has to keep it.
    /// </remarks>
    internal static readonly BindableProperty LanesProperty =
        BindableProperty.CreateAttached(
            "StateUILanes",
            typeof(object),
            typeof(MotionArranger),
            defaultValue: null);

    /// <summary>
    /// How this layout's children travel - the law the element said, or
    /// nothing at all where it inherits the application's.
    /// </summary>
    internal static readonly BindableProperty TravelProperty =
        BindableProperty.CreateAttached(
            "StateUITravel",
            typeof(object),
            typeof(MotionArranger),
            defaultValue: null);

    /// <summary>Wraps a layout's own manager.</summary>
    /// <param name="layout">The layout.</param>
    /// <param name="inner">What works out where the children go.</param>
    /// <param name="engine">What carries them there.</param>
    internal MotionArranger(Layout layout, ILayoutManager inner, MotionEngine engine)
    {
        _layout = layout;
        _inner = inner;
        _engine = engine;

        // A CHILD THAT LEAVES STOPS TRAVELLING. Nothing can see it any more, so
        // there is nothing left to draw - and a motion still under way would go
        // on arranging a view that is no longer in the tree, and hold it while
        // it did.
        //
        // A REORDER IS A REMOVAL TOO: bringing a list into the order a message
        // asked for takes a child out and puts it back. So where the motion had
        // reached is written into the seat before it is stopped, and the
        // arrangement that follows carries on from there rather than jumping
        // back to the place it was last aimed at. A fade is LANDED instead:
        // nothing would ever start it again, and a view left half there is
        // worse than one that simply finished arriving.
        _layout.ChildRemoved += (_, e) =>
        {
            if (e.Element is not IView gone)
            {
                return;
            }

            if (_engine.Moving(gone, MotionFrame.Place) is MotionChannel channel
                && _seats.TryGetValue(gone, out Seat? seat))
            {
                seat.Was = new Rect(channel.P[0], channel.P[1], channel.P[2], channel.P[3]);
            }

            _engine.Halt(gone, MotionFrame.Place, MotionEnd.Nothing);

            // Unless somebody else has the opacity: a fade this layout never
            // started is not this layout's to land.
            if (_engine.Driven?.Invoke(gone, VisualElement.OpacityProperty) != true)
            {
                _engine.Halt(gone, VisualElement.OpacityProperty, MotionEnd.Target);
            }
        };
    }

    /// <summary>How much room the layout wants - the inner manager's answer.</summary>
    /// <param name="widthConstraint">How wide it may be.</param>
    /// <param name="heightConstraint">How tall it may be.</param>
    /// <returns>What it asks for.</returns>
    public Size Measure(double widthConstraint, double heightConstraint)
    {
        // Still taken, whatever is answered below: measuring the children is
        // what gives each of them a size to be arranged at.
        Size wanted = _inner.Measure(widthConstraint, heightConstraint);

        if (_layout.GetValue(MotionPlacement.PlacedProperty) is not true)
        {
            return wanted;
        }

        // A FOLLOWED LAYOUT IS THE SIZE IT IS GIVEN. Its children stand where
        // arithmetic over the room puts them - free to reach outside it - so
        // their union says nothing about how big the layout should be, and a
        // layout that answered with it fed its own measure: the room grew or
        // shrank with the placements, the placements with the room, and the
        // pass oscillated for ever at a whole core. The constraint is the one
        // answer that cannot feed back; a side nothing constrains keeps the
        // children's, there being nothing else to say.
        return new Size(
            double.IsFinite(widthConstraint) ? widthConstraint : wanted.Width,
            double.IsFinite(heightConstraint) ? heightConstraint : wanted.Height);
    }

    /// <summary>
    /// Puts the children where the layout says - or starts them travelling
    /// there.
    /// </summary>
    /// <param name="bounds">The room the layout has.</param>
    /// <returns>What it used.</returns>
    public Size ArrangeChildren(Rect bounds)
    {
        // A PASS IS UNDER WAY, which is the one thing a place written from here
        // can rely on - see MotionFrame.Write.
        Arranging++;

        try
        {
            return Place(bounds);
        }
        finally
        {
            Arranging--;
        }
    }

    /// <summary>Works out where each child goes, and starts it on its way.</summary>
    /// <param name="bounds">The room the layout has.</param>
    /// <returns>What it used.</returns>
    private Size Place(Rect bounds)
    {
        Size used = _inner.ArrangeChildren(bounds);

        // The layout's own answer where it has one, the application's where it
        // does not - which is what almost every layout there is uses, and what
        // keeps the common case off the wire entirely.
        MotionSpec spec = _layout.GetValue(TravelProperty) is MotionSpec placement
            ? placement
            : _engine.Travel;

        // Which parts of a place travel at all. A layout told `.motion(.none,
        // .size)` puts its children in their new places and gives them their
        // new size at once - a view growing out of nothing is the one movement
        // a reader reads as a fault, and a view sliding is not.
        SwiftMotionLanes lanes = _layout.GetValue(LanesProperty) is SwiftMotionLanes told
            ? told
            : SwiftMotionLanes.All;

        if (lanes == 0)
        {
            spec = MotionSpec.Eased(0, 0);
        }

        // WHY this arrangement is happening, which is the one thing it does not
        // say about itself: a message applied since the last one means the
        // interface HOLDS something different - a row inserted, a card grown -
        // and the children travel. Nothing applied means the room itself is
        // moving: a window dragged, a keyboard rising, a scroller settling.
        // Everything then tracks it exactly, because a child that glides after
        // a reader's own hand is late every frame.
        bool said = _applied != _engine.Applies;
        bool first = !_placed;

        // A MOTION CANNOT OUTLIVE A PASS THAT WILL NOT END. A place is walked
        // by the frame clock, and that clock runs on the thread that lays out
        // - so a platform repeating one layout pass, as UIKit does while it
        // rotates a window, holds the thread the motion needs. The arranger's
        // own undo below is what keeps the pass dirty, and the value it writes
        // cannot change while the pass owns the thread: the two spin, at a
        // whole core, until the reader kills the application.
        //
        // Measured on an iPhone, portrait to landscape: one three-row Grid
        // measured and arranged for ever, its last row frozen part-way from
        // the place it had to the place it was going.
        //
        // So a place undone `Repeats` times with no frame made in between has
        // to give something up: its SIZE first, which is what a pass actually
        // fails to settle on, and the place itself where even that does not
        // help. The children are then where the tree says, the pass has nothing
        // left to redo, and what the reader sees is the platform's own rotation
        // rather than ours on top of it. See `Refuse`.
        bool advanced = _stamp != _engine.At;
        _stamp = _engine.At;

        if (advanced)
        {
            _repeats = 0;
        }

        bool starved = !advanced && _repeats >= Repeats;
        bool undid = false;

        // Whether the sizes were ALREADY given up here - read before the loop,
        // because a refusal found on one child is a refusal for every child
        // beside it, and reading it as it goes would land all the others.
        bool gaveUp = _arrives;

        // WHAT A VIEW HOLDS CHANGED, so what is measured under it may have
        // too - the one moment the kept answers stop being true.
        if (said)
        {
            _reads.Clear();
        }

        _applied = _engine.Applies;
        _placed = true;

        // Whether anything in this layout is being measured - asked once, of
        // the whole layout, because one room is what they all share.
        //
        // ALL FOUR LANES, THE PLACE INCLUDED. Holding the two SIZE lanes and
        // letting the place travel is what this reads like it should be, and
        // it is measured to be wrong: on Android, with the size lanes alone
        // held, a swipe of two cards left the gallery's whole run resting a
        // card's width right of centre and nothing put it back. A measured
        // page is also, in every case this library has, a page that FOLLOWS a
        // channel - and a place in the air is a place two writers are aiming
        // at, since `Channels.Place` drops every report while any child of the
        // layout is flying.
        //
        // So a page that measures is a page that places AT ONCE, and the cost
        // is the honest one to pay: rows on such a page arrive rather than
        // slide. A size the child ASKED for is the narrower rule and keeps its
        // place travelling - see `Asked`.
        SwiftMotionLanes sized = Measures() ? SwiftMotionLanes.All : 0;

        // AND A SIZE THIS LAYOUT WAS MEASURED REFUSING TO SETTLE ON - see the
        // starved branch below, which is where that is found out.
        if (_arrives)
        {
            sized |= SwiftMotionLanes.Width | SwiftMotionLanes.Height;
        }

        foreach (IView child in _layout)
        {
            Rect target = child.Frame;

            if (!_seats.TryGetValue(child, out Seat? seat))
            {
                // A child nobody has placed yet is already where it belongs:
                // the first thing anyone sees is the thing itself.
                _seats.Add(child, new Seat { Frame = new MotionFrame(child, _layout), Was = target });

                if (!first && said && !spec.Instant)
                {
                    Arrive(child, spec);
                }

                continue;
            }

            MotionChannel? moving = _engine.Moving(child, MotionFrame.Place);

            if (!Real(seat.Was) || !Real(target))
            {
                // THERE IS NO HALF-WAY BETWEEN NOWHERE AND SOMEWHERE. A child
                // MAUI has not laid out yet wears (0, 0, -1, -1) and one a
                // layout gave nothing wears a side of nothing; a view being
                // placed for the first time - a tab just chosen, a page just
                // pushed - is coming from neither.
                //
                // Measured on the gallery: switching to a sample's code tab
                // flew the whole listing up out of (0, 0, -1, -1), which is a
                // size grown out of nothing and the one movement a reader
                // reads as a fault. The view still FADES in - appearing is
                // what it is doing - it simply appears at its own size.
                if (moving is not null)
                {
                    _engine.Halt(child, MotionFrame.Place, MotionEnd.Nothing);
                }

                seat.Was = target;
                continue;
            }

            if (seat.Was == target)
            {
                // THE PLAN HAS NOT CHANGED. An arrangement is asked for
                // whenever anything anywhere invalidates - a label remeasured,
                // a scroll settled, a motion of ours writing a frame - and a
                // motion re-aimed on every one of those would never arrive: its
                // clock would start again each time, and the value would creep
                // at the head of a curve it never finishes.
                //
                // What the inner manager just did still has to be undone: it
                // put the child AT the target, and the motion is not there yet.
                if (moving is not null)
                {
                    if (starved)
                    {
                        Refuse(child, seat, target, spec, moving, gaveUp);
                        continue;
                    }

                    undid = true;
                    moving.Moves.Write(moving.P);
                }

                continue;
            }

            if (!said || spec.Instant)
            {
                if (moving is not null)
                {
                    _engine.Halt(child, MotionFrame.Place, MotionEnd.Nothing);
                }

                seat.Was = target;
                continue;
            }

            // The inner manager has already put the child AT the target, so
            // the frame can no longer say where it is travelling from: that is
            // the place it was last put, or - where a motion is still under
            // way - wherever that motion has reached.
            Rect was = seat.Was;
            seat.Was = target;

            // A FOLLOWED CHILD IS WHERE THE CHANNEL PUT IT, not where this
            // pass last arranged it. Its movement is written as a translation
            // between layout passes, so the seat is a whole swipe out of date
            // - and a message arriving mid-swipe would fly the card in from
            // wherever it stood when the layout last ran. Measured on the
            // gallery as a card vanishing and arriving again from somewhere
            // else. The place it travels FROM is the one it is showing.
            if (_layout.GetValue(MotionPlacement.PlacedProperty) is true
                && child is VisualElement moved)
            {
                was = new Rect(
                    was.X + moved.TranslationX,
                    was.Y + moved.TranslationY,
                    was.Width,
                    was.Height);
            }

            // A SIZE SOMEBODY IS MEASURING IS ARRIVED AT, never travelled
            // to. A frame that is WATCHED is a number an application reads
            // and works its interface out from, so every step of a walk to
            // it is a whole page laid out at a size nobody chose - and where
            // what is read back decides the very room being walked, the two
            // chase each other down. Measured on the gallery: the box the
            // home page measures its room with was carried 342 -> 369 -> 377
            // -> 379 while the run it sizes went 400 -> 383 -> 303 -> 236 ->
            // 246 -> 262, the cards were placed afresh at every one of them,
            // and the words underneath rode the lot.
            //
            // AND IT IS THE WHOLE LAYOUT'S ANSWER, not the watched child's:
            // what a measurement reports is what the views BESIDE it leave
            // it, so a sibling walked through a size moves the very number
            // being read. The gallery's own run and its scroller are exactly
            // that - siblings of the box that measures the room they stand
            // in.
            //
            // The same holds for a size the child ASKED for: a request is a
            // value somebody worked out, most sharply where they worked it
            // out from a measurement.
            //
            // A size the child stated is the one case where the PLACE still
            // travels: `Asked` names the two size lanes and no more, so a view
            // that fixed its own height still slides when the things around it
            // change. Where a MEASUREMENT is what is being taken, `Measures`
            // holds every lane - see above.
            SwiftMotionLanes travels = lanes & ~(sized | Asked(child));

            // A lane that does not travel starts where it is going, which is
            // the whole of what holding one still means to a channel.
            double[] start =
            [
                travels.HasFlag(SwiftMotionLanes.X) ? was.X : target.X,
                travels.HasFlag(SwiftMotionLanes.Y) ? was.Y : target.Y,
                travels.HasFlag(SwiftMotionLanes.Width) ? was.Width : target.Width,
                travels.HasFlag(SwiftMotionLanes.Height) ? was.Height : target.Height,
            ];

            _engine.Aim(
                seat.Frame,
                [target.X, target.Y, target.Width, target.Height],
                spec,
                from: moving is null ? start : null);
        }

        // One more pass that had to undo the inner manager without a frame
        // being made - and `Repeats` of those is a pass that is not ending.
        if (undid)
        {
            _repeats++;
        }

        if (MotionTrace.Watching && (undid || starved))
        {
            MotionTrace.Say(
                $"arrange {_layout.GetType().Name} {bounds.Width:F0}x{bounds.Height:F0} "
                + $"said={said} advanced={advanced} repeats={_repeats} starved={starved}");
        }

        return used;
    }

    /// <summary>
    /// The pass will not settle, so the place gives up the one part of itself
    /// that a layout can refuse to settle on: its SIZE.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A SIZE BEING WALKED IS WHAT A PASS FAILS TO CONVERGE ON, measured on
    /// Windows and measured both ways. The gallery's three-column grid,
    /// changing its columns' widths, re-arranged every 0.45 ms for as long as
    /// it was allowed to - the thread never yielding, so no frame could be
    /// composed, so the motion never moved and the whole thing snapped - while
    /// the same page's rows, which change only their PLACE, travelled
    /// perfectly. Holding the two size lanes made the same grid converge at one
    /// arrangement a frame and travel.
    /// </para>
    /// <para>
    /// So the size is given up rather than the motion: the child takes its new
    /// size at once and goes on travelling to its new place, which is what
    /// <c>.motion(.none, .size)</c> asks for in so many words. And the layout
    /// keeps the answer, because whatever about it would not settle is still
    /// true of it next time.
    /// </para>
    /// <para>
    /// A layout that will not settle EVEN THEN is the one this cannot help -
    /// UIKit repeating a pass through a whole rotation is that - and there the
    /// place arrives, which is where this branch started.
    /// </para>
    /// </remarks>
    /// <param name="child">The child being placed.</param>
    /// <param name="seat">Where it sits.</param>
    /// <param name="target">Where the layout says it belongs.</param>
    /// <param name="spec">The law it travels under.</param>
    /// <param name="moving">The motion carrying it.</param>
    /// <param name="gaveUp">Whether the sizes were given up before this pass.</param>
    private void Refuse(
        IView child,
        Seat seat,
        Rect target,
        in MotionSpec spec,
        MotionChannel moving,
        bool gaveUp)
    {
        // A SIZE THAT IS NOT IN THE AIR IS NOT WHAT THIS PASS IS STUCK ON, so
        // there is nothing to give up and the place arrives - which is the
        // rotation case, where a row travels without changing size at all.
        bool sizing =
            Math.Abs(moving.P[2] - moving.Target[2]) >= MotionCurve.Still
            || Math.Abs(moving.P[3] - moving.Target[3]) >= MotionCurve.Still;

        if (gaveUp || !sizing)
        {
            _engine.Halt(child, MotionFrame.Place, MotionEnd.Target);
            return;
        }

        _arrives = true;
        _repeats = 0;

        // Where it stands, at the size it is going to. Started again rather
        // than bent, because a motion already under way keeps the lanes it has
        // and the size is the whole of what has to change.
        double[] from = [moving.P[0], moving.P[1], target.Width, target.Height];

        _engine.Halt(child, MotionFrame.Place, MotionEnd.Nothing);

        _engine.Aim(
            seat.Frame,
            [target.X, target.Y, target.Width, target.Height],
            spec,
            from: from);
    }

    /// <summary>
    /// Fades a child in as it joins a layout that was already standing.
    /// </summary>
    /// <remarks>
    /// <para>
    /// A view APPEARING is the other half of a view moving: an `if` that turns
    /// true, a row inserted, a card dealt. Everything around it slides to make
    /// room - that is the arrangement above - and this is the view itself
    /// arriving rather than being suddenly there.
    /// </para>
    /// <para>
    /// Not on the layout's FIRST arrangement, where every child is new and the
    /// whole page fading in is not what anyone asked for; and not under a
    /// layout that places its children at once, which is what this library's
    /// own list says of its rows - a row entering the window is a row that was
    /// always there.
    /// </para>
    /// </remarks>
    private void Arrive(IView child, in MotionSpec spec)
    {
        if (child is not VisualElement view)
        {
            return;
        }

        // A VIEW ALREADY CROSSING IS NOT ALSO FADED IN. Showing and hiding is
        // a crossing of this same value, decided by what the TREE said - so a
        // row inserted into a live layout and described as hidden is on its
        // way OUT, and a fade in over the top of it would replace that motion,
        // tell it that it did not finish, and leave the view standing there.
        if (_engine.Moving(view, VisualElement.OpacityProperty) is not null)
        {
            return;
        }

        // NOR ONE SOMEBODY ELSE OWNS. A child whose opacity is on a bus wears
        // whatever the bus says from the frame it arrives, and a fade in over
        // the top of that would be a second writer on one value.
        if (_engine.Driven?.Invoke(view, VisualElement.OpacityProperty) == true)
        {
            return;
        }

        _engine.Aim(
            new MotionProperty(view, VisualElement.OpacityProperty, MotionValue.Number, true),
            [view.Opacity],
            spec,
            from: [0]);
    }

    /// <summary>
    /// Which sides of its place a child stated for itself, and which
    /// therefore arrive rather than travel.
    /// </summary>
    /// <remarks>
    /// A request is a size somebody worked out - most sharply where they
    /// worked it out from a measurement, which is a number the platform said
    /// and has nothing to animate between. What a layout DECIDES for a child
    /// is the other half, and that still travels.
    /// </remarks>
    /// <param name="child">The child being placed.</param>
    /// <returns>The lanes it asked for, none where it asked for nothing.</returns>
    private static SwiftMotionLanes Asked(IView child)
    {
        if (child is not VisualElement view)
        {
            return 0;
        }

        SwiftMotionLanes asked = 0;

        if (view.WidthRequest >= 0) { asked |= SwiftMotionLanes.Width; }
        if (view.HeightRequest >= 0) { asked |= SwiftMotionLanes.Height; }

        return asked;
    }

    /// <summary>Whether anything this layout arranges is being measured.</summary>
    /// <remarks>
    /// Asked of the layout rather than of each child, because what a
    /// measurement reports is what the views BESIDE it leave it: a sibling
    /// carried through a size moves the very number being read, and an
    /// application that works its interface out from that number is handed a
    /// run of rooms nobody chose. So where any child is measured, ALL FOUR
    /// LANES are held - the place with the size - and the layout's children
    /// arrive rather than travel. Only a size the child ASKED for goes on
    /// travelling; see <see cref="Asked"/>, and the comment at the call site
    /// for what a place left in the air was measured doing on Android.
    /// </remarks>
    private bool Measures()
    {
        // The layout's OWN frame first: a view that reports how big it is
        // reports what it holds arranged in that size, so carrying its
        // children through a size is the same run of answers from inside.
        if (StateUIRenderer.Watched(_layout))
        {
            return true;
        }

        foreach (IView child in _layout)
        {
            if (child is VisualElement view && Reads(view))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Whether this view's size is one somebody is measuring - its own frame
    /// watched, or anything it holds.
    /// </summary>
    /// <remarks>
    /// A watched frame is whatever the views around it leave it, so carrying
    /// any of them through a size hands the watcher a run of rooms nobody
    /// chose. The answer is kept per view: the tree a view holds changes only
    /// when a message says so, and an arrangement is asked for far more often
    /// than that.
    /// </remarks>
    /// <param name="view">The root of the subtree.</param>
    /// <returns>True where anything under it is measured.</returns>
    private bool Reads(VisualElement view)
    {
        if (_reads.TryGetValue(view, out object? known))
        {
            return known is true;
        }

        bool reads = Measured(view);

        _reads.Add(view, reads);

        return reads;
    }

    /// <summary>Whether a watched frame is anywhere in this subtree.</summary>
    private static bool Measured(VisualElement view)
    {
        if (StateUIRenderer.Watched(view))
        {
            return true;
        }

        foreach (IVisualTreeElement child in ((IVisualTreeElement)view).GetVisualChildren())
        {
            if (child is VisualElement below && Measured(below))
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Whether a rectangle is somewhere a view can actually be seen.
    /// </summary>
    /// <remarks>
    /// A child MAUI has not laid out yet wears <c>(0, 0, -1, -1)</c>, and one a
    /// layout gave nothing wears a side of nothing. Neither is a place, so
    /// neither is one a view travels from or to.
    /// </remarks>
    private static bool Real(Rect rect) => rect.Width > 0 && rect.Height > 0;
}
