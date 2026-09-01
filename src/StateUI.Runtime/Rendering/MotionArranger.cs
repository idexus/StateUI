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
/// A RESIZE SNAPS. The rule is one line and it is the difference between a
/// layout that feels alive and one that lags: a change to the layout's own size
/// is a continuous driver - a window being dragged, a keyboard rising - and a
/// child that glides after it arrives late every frame. A change with the same
/// bounds is a change of CONTENT, which is what travels.
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

    private Size _measured = new(-1, -1);
    private long _applied = -1;

    /// <summary>
    /// Where a layout is told how its children travel.
    /// </summary>
    /// <remarks>
    /// Attached rather than held, because the arranger is made when the layout
    /// first measures - which is after the message that carried the motion has
    /// been applied.
    /// </remarks>
    /// <summary>
    /// Which parts of a child's place travel here - what
    /// `.motion(.none, .size)` on a layout comes to.
    /// </summary>
    internal static readonly BindableProperty LanesProperty =
        BindableProperty.CreateAttached(
            "StateUILanes",
            typeof(object),
            typeof(MotionArranger),
            defaultValue: null);

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
            _engine.Halt(gone, VisualElement.OpacityProperty, MotionEnd.Target);
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

        if (_layout.GetValue(Channels.FollowedProperty) is not true)
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
        bool first = _measured.Width < 0;

        // WHAT A VIEW HOLDS CHANGED, so what is measured under it may have
        // too - the one moment the kept answers stop being true.
        if (said)
        {
            _reads.Clear();
        }

        _applied = _engine.Applies;
        _measured = bounds.Size;

        // Whether anything in this layout is being measured - asked once, of
        // the whole layout, because one room is what they all share.
        SwiftMotionLanes sized = Measures() ? SwiftMotionLanes.All : 0;

        foreach (IView child in _layout)
        {
            Rect target = child.Frame;

            if (!_seats.TryGetValue(child, out Seat? seat))
            {
                // A child nobody has placed yet is already where it belongs:
                // the first thing anyone sees is the thing itself.
                _seats.Add(child, new Seat { Frame = new MotionFrame(child), Was = target });

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
                moving?.Moves.Write(moving.P);
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
            if (_layout.GetValue(Channels.FollowedProperty) is true
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
            // The PLACE still travels in every case: where a view sits is
            // the layout's answer and nobody stated it, so a view whose size
            // is settled still slides when the things around it change.
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

        return used;
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
    /// run of rooms nobody chose. So where any child is measured, none of
    /// them is carried through a size - and all of them still travel to
    /// their new places.
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
