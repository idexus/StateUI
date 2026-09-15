// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// One property of one control, tied to a state.
/// </summary>
/// <remarks>
/// A walked value's lanes are read through <see cref="JourneyCodec"/>, the one
/// place this side lays them out.
/// </remarks>
internal sealed class StateAttachment
{
    /// <summary>The control this drives, held WEAKLY.</summary>
    /// <remarks>
    /// A control that leaves the tree is let go by its parent and by nothing
    /// else. The aiming maps hold weak references for that reason and the
    /// walker keys its trips off a weak table; held strongly here, every
    /// control ever driven would live as long as the process - measured on all
    /// three platforms as two or three kept per page visited, the page being
    /// rebuilt on every visit. An attachment whose control has gone does
    /// nothing and is dropped by the cycle's next sweep.
    /// </remarks>
    private readonly WeakReference<BindableObject> _view;
    private readonly MotionValue _shape;
    private readonly bool _fraction;

    /// <summary>The control, or null once it has gone.</summary>
    internal BindableObject? View => _view.TryGetTarget(out BindableObject? view) ? view : null;

    /// <summary>
    /// The number's channel, shared with every other control on the number -
    /// what a journey on this property is carried by. Set by the channel as the
    /// attachment joins it.
    /// </summary>
    internal StateChannel? Channel { get; set; }

    /// <summary>What the last text written onto the control was.</summary>
    /// <remarks>
    /// So a text state that was dirtied without its words changing writes
    /// nothing at all: a label re-measures whenever its text is set, whether
    /// or not the letters differ.
    /// </remarks>
    private string? _wrote;

    /// <summary>
    /// Sets a plain value on the property, boxed to the property's own type,
    /// and only where the control does not already show it: one lane is a
    /// flag from nought and one, a count from a whole number, a number as it
    /// is, or a member; three are a date (year, month, day) on a
    /// <c>DateTime</c> property and a time (hour, minute, second) on a
    /// <c>TimeSpan</c> one.
    /// </summary>
    /// <remarks>
    /// THE ASSIGNMENT RUNS UNDER <see cref="Walker.Writing"/>: the
    /// platform raises the property's changed notification synchronously
    /// inside it, and that notification is this side's own write coming
    /// round - refused as an event by the renderer and as a report by the
    /// cycle, so a value the tree wrote never reaches a handler or lands on
    /// the state a second time.
    /// </remarks>
    /// <param name="lanes">The value, lane by lane.</param>
    internal void Set(double[] lanes)
    {
        if (Property is null || View is not BindableObject view || lanes.Length == 0)
        {
            return;
        }

        // BRANCH BY BRANCH, not one conditional: a nested conditional over
        // int, long, float and double is typed DOUBLE as a whole, and a
        // whole number boxed as 2.0 is refused by an int property in silence.
        Type type = Nullable.GetUnderlyingType(Property.ReturnType) ?? Property.ReturnType;
        double value = lanes[0];
        object? boxed;

        if (type == typeof(DateTime) || type == typeof(TimeSpan))
        {
            // THREE LANES MAKE A DAY OR A TIME, composed the way the described
            // value is (Values.GetDate / GetTime) and refused the same
            // way: a day that does not exist sets nothing, so the picker goes
            // on showing the one it had.
            if (lanes.Length < 3)
            {
                return;
            }

            try
            {
                boxed = type == typeof(DateTime)
                    ? new DateTime((int)Math.Round(lanes[0]), (int)Math.Round(lanes[1]), (int)Math.Round(lanes[2]))
                    : new TimeSpan((int)Math.Round(lanes[0]), (int)Math.Round(lanes[1]), (int)Math.Round(lanes[2]));
            }
            catch (ArgumentOutOfRangeException)
            {
                return;
            }
        }
        else if (type == typeof(bool)) { boxed = value != 0; }
        else if (type == typeof(int)) { boxed = (int)Math.Round(value); }
        else if (type == typeof(long)) { boxed = (long)Math.Round(value); }
        else if (type == typeof(float)) { boxed = (float)value; }
        else if (type == typeof(double)) { boxed = value; }
        else
        {
            // A CHOICE - an alignment, a keyboard, a line break, a set of
            // flags - through the SAME table a described property goes
            // through, handed the member number the way the wire carries one.
            // So a channel understands every member the tree can describe,
            // and a member added later is understood the day it arrives.
            boxed = PropertyTable.Value(Property, Said(Key, (int)Math.Round(value)), Key);

            if (boxed is null)
            {
                return;
            }
        }

        // AGAINST THE CONTROL, not against the last lane: a value the platform
        // coerced away - a choice landed before its list - is set again the
        // next time the state says it, and one the control already shows is
        // not set twice.
        if (Equals(view.GetValue(Property), boxed))
        {
            return;
        }

        Walker.Writing++;

        try
        {
            view.SetValue(Property, boxed);
        }
        finally
        {
            Walker.Writing--;
        }
    }

    /// <summary>
    /// A member number as a NODE says it - what the conversion table reads.
    /// </summary>
    /// <param name="key">Which property it is about.</param>
    /// <param name="member">The member's number, this library's own.</param>
    /// <returns>A node carrying that one value under that one key.</returns>
    private static HostPatch Said(HostPropKey key, int member)
    {
        var said = new HostPatch();

        if (key.Name is string own)
        {
            said.OwnProps = new Dictionary<string, HostValue> { [own] = HostValue.OfMember(member) };
        }
        else
        {
            said.Props = new Dictionary<HostProp, HostValue> { [key.Prop] = HostValue.OfMember(member) };
        }

        return said;
    }

    /// <summary>
    /// Remembers the words the READER typed, so the state's echo of them on
    /// the next cycle is not set back onto the field under the caret.
    /// </summary>
    /// <param name="words">What was typed.</param>
    internal void Remember(string words) => _wrote = words;

    /// <summary>
    /// Writes words onto the control where they differ from the last ones
    /// written - what a text state's cycle does, and what a typed report does
    /// to every OTHER field the same state drives.
    /// </summary>
    /// <remarks>
    /// Under <see cref="Walker.Writing"/>, for the reason
    /// <see cref="Set(double[])"/> gives: the field's own changed notification
    /// is this side's write coming round.
    /// </remarks>
    /// <param name="words">The text.</param>
    internal void Wear(string words)
    {
        if (words == _wrote || Property is null)
        {
            return;
        }

        _wrote = words;

        Walker.Writing++;

        try
        {
            View?.SetValue(Property, words);
        }
        finally
        {
            Walker.Writing--;
        }
    }

    private StateAttachment(
        BindableObject view,
        HostStateBinding entry,
        BindableProperty? property,
        MotionValue shape)
    {
        _view = new WeakReference<BindableObject>(view);
        _shape = shape;
        _fraction = property == VisualElement.OpacityProperty;
        Key = entry.Key;
        Number = entry.Number;
        Mode = entry.Mode;
        Kind = entry.Kind;
        Property = property;
    }

    /// <summary>Which property, as a key that reads either bag.</summary>
    internal HostPropKey Key { get; }

    /// <summary>The number the value rides on.</summary>
    internal int Number { get; }

    /// <summary>Which way it crosses.</summary>
    internal HostStateMode Mode { get; }

    /// <summary>Which of this side's doors the value goes through.</summary>
    internal HostStateKind Kind { get; }

    /// <summary>The property itself, or null for a kind that is not one.</summary>
    internal BindableProperty? Property { get; }

    /// <summary>What a feed unsubscribes when the control is described away.</summary>
    internal Action? Released { get; set; }

    /// <summary>The room this feed last put on the state.</summary>
    /// <remarks>
    /// A pass reports each part of a frame separately, so the same room
    /// arrives four times; only a room that actually moved is worth a cycle.
    /// </remarks>
    internal Rect Fed { get; set; } = new(0, 0, -1, -1);

    /// <summary>How many lanes the value takes.</summary>
    internal int Lanes => _shape switch
    {
        MotionValue.Number or MotionValue.Whole or MotionValue.Single => 1,
        MotionValue.Offset => 2,
        _ => 4,
    };

    /// <summary>
    /// The attachment a registration asks for, or null where this side cannot
    /// make one.
    /// </summary>
    /// <remarks>
    /// A property nothing declares, or one of a value nothing can carry, is
    /// not tied at all - and says so by being absent rather than by throwing:
    /// a message from a newer Swift half is a message this one reads as far as
    /// it can.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="entry">What the message said.</param>
    /// <param name="type">The element's type, which resolves a shared property.</param>
    /// <param name="typeName">
    /// Its name, which resolves a property of a control an application
    /// registered.
    /// </param>
    /// <returns>The attachment, or null.</returns>
    internal static StateAttachment? Of(
        BindableObject view,
        HostStateBinding entry,
        HostNodeType type,
        string typeName)
    {
        // A PLACEMENT IS ABOUT THE LAYOUT'S CHILDREN, and a FEED is the
        // platform's own answer about the control - a room, an offset, a drag.
        // Neither is a property of anything, so neither is looked up as one.
        if (entry.Kind == HostStateKind.Placement)
        {
            return view is Microsoft.Maui.Controls.Layout
                ? new StateAttachment(view, entry, null, MotionValue.Number)
                : null;
        }

        if (entry.Kind == HostStateKind.Feed)
        {
            return new StateAttachment(view, entry, null, MotionValue.Number);
        }

        // A SCROLLER'S OFFSET IS ONE POINT AND HAS NO SETTABLE PROPERTY: the
        // platform declares ScrollX and ScrollY read-only, so this attachment
        // carries no property at all and aims at the scroller itself, which the
        // walker moves as a two-lane target. See ScrollMovement.Walked.
        if (entry.Key.Prop == HostProp.ScrollOffset)
        {
            return view is ScrollView ? new StateAttachment(view, entry, null, MotionValue.Offset) : null;
        }

        if (PropertyTable.Property(type, typeName, entry.Key) is not BindableProperty property)
        {
            return null;
        }

        // TEXT HAS NO LANES: it is dirty or it is not, and nothing walks it -
        // out onto a label's caption, and both ways on a field the reader
        // types into, where the typed words cross back whole.
        if (entry.Kind == HostStateKind.Text)
        {
            return new StateAttachment(view, entry, property, MotionValue.Number);
        }

        // A PLAIN value is one lane set as it stands - a flag, a count, a
        // number that never travels - on whatever property it names.
        if (entry.Kind == HostStateKind.Plain)
        {
            return new StateAttachment(view, entry, property, MotionValue.Number);
        }

        if (Shape(property) is not MotionValue shape)
        {
            return null;
        }

        return new StateAttachment(view, entry, property, shape);
    }

    /// <summary>What a property's value is made of, or null for one nothing carries.</summary>
    private static MotionValue? Shape(BindableProperty property) =>
        property.ReturnType == typeof(double) ? MotionValue.Number
        : property.ReturnType == typeof(Color) ? MotionValue.Colour
        : property.ReturnType == typeof(Thickness) ? MotionValue.Edges
        : property.ReturnType == typeof(Rect) ? MotionValue.Bounds
        : property.ReturnType == typeof(CornerRadius) ? MotionValue.Corners
        : property.ReturnType == typeof(int) ? MotionValue.Whole
        : property.ReturnType == typeof(float) ? MotionValue.Single
        : null;

    /// <summary>
    /// The value the state stands at, written onto the control at once - what a
    /// registration owes before anything is drawn.
    /// </summary>
    /// <param name="bytes">The state, whole.</param>
    /// <param name="walker">What moves the values.</param>
    internal void Landed(byte[] bytes, Walker walker)
    {
        if (Kind == HostStateKind.Plain)
        {
            Wear(bytes, ~0UL, walker, static (_, _) => { });
            return;
        }

        if (Kind == HostStateKind.Placement)
        {
            // WHOLE, because nothing has been placed yet - and every one of
            // them arrives rather than travelling, a view nobody has placed
            // having nowhere to travel from.
            Placed(bytes, All, walker);
            return;
        }

        if (Kind == HostStateKind.Text)
        {
            Wear(bytes, 1, walker, static (_, _) => { });
            return;
        }

        if (Mode == HostStateMode.In || Channel is not StateChannel channel)
        {
            return;
        }

        // WHATEVER THIS CONTROL'S OWN WAS DOING TO THE PROPERTY lets go - the
        // tree stating a value beside the registration, most often - and the
        // control joins the number's channel where the value is.
        if (Property is BindableProperty own && View is BindableObject told)
        {
            walker.Halt(told, own, TripEnd.Nothing);
        }

        channel.Join(this, bytes);
    }

    /// <summary>
    /// Sends this control's value where the state is GOING, under a law of
    /// somebody else's - what a host writer settling a resting value does
    /// instead of settling one of its own.
    /// </summary>
    /// <remarks>
    /// On the control's OWN trip, from wherever the writer left it - a
    /// visual state leaving has the control at the state's colour, not the
    /// number's - and the number's channel leaves the control alone until that
    /// lands. The destination is where the number is bound: its channel's
    /// target while it travels, the image's setpoint while it stands.
    /// </remarks>
    /// <param name="bytes">The state, whole.</param>
    /// <param name="walker">What moves the values.</param>
    /// <param name="spec">The law the writer was going to use.</param>
    internal void Resting(byte[] bytes, Walker walker, in HostMotion spec)
    {
        if (Property is null
            || Kind != HostStateKind.Property
            || Mode == HostStateMode.In
            || View is not BindableObject view
            || Channel is not StateChannel channel)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
        int width = Lanes;

        if (lanes.Length < JourneyCodec.Count(width))
        {
            return;
        }

        double[] destination = channel.Moving is Trip carrying
            ? (double[])carrying.Target.Clone()
            : JourneyCodec.DestinationOf(lanes, width);

        walker.Aim(new MotionProperty(view, Property, _shape, _fraction), destination, spec);
    }

    /// <summary>
    /// What a cycle wrote, onto the control.
    /// </summary>
    /// <remarks>
    /// THE BITS OF ONE MASK APPLY IN ONE ORDER: stop, then the value, then
    /// where it is going, then how fast, then the law. So a handler that stops
    /// a movement and starts another in the same breath ends the first and
    /// gets a fresh one, rather than the other way round.
    /// </remarks>
    /// <param name="bytes">The state, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="walker">What moves the values.</param>
    /// <param name="land">Told a completion is done, and whether it finished.</param>
    internal void Wear(byte[] bytes, ulong mask, Walker walker, Action<int, bool> land)
    {
        if (Kind == HostStateKind.Placement)
        {
            Placed(bytes, mask, walker);
            return;
        }

        if (Property is null)
        {
            return;
        }

        if (Kind == HostStateKind.Text)
        {
            Wear(StateBatch.Text(bytes));
            return;
        }

        if (Kind == HostStateKind.Plain)
        {
            Set(StateBatch.Lanes(bytes));
        }

        // A JOURNEY IS NOT WORN HERE: it rides the number's channel, once for
        // every control on the number - see StateChannel.Wear.
    }

    /// <summary>Every lane, for a run nothing has been told about yet.</summary>
    private const ulong All = ~0UL;

    /// <summary>Where each placed view's journey is kept.</summary>
    /// <remarks>
    /// WEAK, because these outlive nothing: a view taken out of the run is a
    /// view this must let go of, and the attachment belongs to a layout that
    /// belongs to a page.
    /// </remarks>
    private readonly ConditionalWeakTable<View, MotionPlacement> _seats = new();

    /// <summary>Whether a turn is already booked to write the sizes owing.</summary>
    private bool _settling;

    /// <summary>
    /// A run of placements, worn by the layout's children.
    /// </summary>
    /// <remarks>
    /// <para>
    /// ONE JOURNEY PER VIEW. The law is the RUN's - written by whoever worked
    /// the placements out, so the same arithmetic lands at once while a hand
    /// is moving it and travels when the shape of the layout changes - and a
    /// run written during a journey BENDS it rather than starting it again,
    /// which is what lets a finger go on moving cards that are crossing.
    /// </para>
    /// <para>
    /// A run shorter than the views leaves the rest where they are; one longer
    /// is read as far as there are views to wear it. Neither is a fault: the
    /// tree and the state are written by different halves at different moments,
    /// and the next cycle settles it.
    /// </para>
    /// </remarks>
    /// <param name="bytes">The run, whole.</param>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="walker">What moves the values.</param>
    private void Placed(byte[] bytes, ulong mask, Walker walker)
    {
        if (View is not Microsoft.Maui.Controls.Layout layout)
        {
            return;
        }

        double[] lanes = StateBatch.Lanes(bytes);
        int width = MotionPlacement.Fields;
        int run = Math.Min((lanes.Length - JourneyCodec.LawLanes) / width, layout.Count);

        if (run <= 0)
        {
            return;
        }

        HostMotion spec = LawAt(lanes, lanes.Length - JourneyCodec.LawLanes, walker);
        bool owing = false;

        for (int index = 0; index < run; index++)
        {
            if (layout[index] is not View child || !Moved(mask, index, width))
            {
                continue;
            }

            Array.Copy(lanes, index * width, _place, 0, width);

            MotionPlacement seat = _seats.GetValue(child, static held => new MotionPlacement(held));

            if (seat.Wearing(_place))
            {
                continue;
            }

            seat.Holding(_place);

            if (spec.Instant)
            {
                // AT ONCE, and whatever was carrying this view lets go: the
                // arithmetic has just said where the view is, which is not a
                // destination but a fact.
                walker.Halt(child, MotionPlacement.Seat, TripEnd.Nothing);
                seat.Write(_place);
            }
            else
            {
                walker.Aim(seat, _place, spec);
            }

            owing |= seat.Owing;
        }

        if (owing)
        {
            Settle(layout);
        }
    }

    /// <summary>One view's twelve lanes, kept rather than made per frame.</summary>
    private readonly double[] _place = new double[MotionPlacement.Fields];

    /// <summary>Whether any of one view's lanes is named by the mask.</summary>
    /// <remarks>
    /// A DIRTY MASK IS A WORD OF BITS and a run is twelve lanes a view, so
    /// past lane 62 there is no bit left to name one: every lane from there on
    /// shares the highest, and the views they belong to are all told together.
    /// Which costs the platform nothing - a view given the place it already
    /// has is skipped here, before any write is made.
    /// </remarks>
    /// <param name="mask">Which lanes moved.</param>
    /// <param name="index">Which view.</param>
    /// <param name="width">How many lanes one view takes.</param>
    /// <returns>Whether this view has anything to hear.</returns>
    private static bool Moved(ulong mask, int index, int width)
    {
        for (int lane = index * width; lane < (index + 1) * width; lane++)
        {
            if ((mask & (1UL << Math.Min(lane, 63))) != 0)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Writes the sizes a layout pass would not take, on the turn after it.
    /// </summary>
    /// <remarks>
    /// One turn per layout at a time: every view that could not have its
    /// rectangle written is waiting for the same moment, which is the first
    /// one outside the pass. See <see cref="MotionPlacement.Wear"/>.
    /// </remarks>
    /// <param name="layout">The layout whose children are owed a size.</param>
    private void Settle(Microsoft.Maui.Controls.Layout layout)
    {
        if (_settling)
        {
            return;
        }

        _settling = true;

        layout.Dispatcher.Dispatch(() =>
        {
            _settling = false;

            for (int index = 0; index < layout.Count; index++)
            {
                if (layout[index] is View child && _seats.TryGetValue(child, out MotionPlacement? seat))
                {
                    seat.Settle();
                }
            }
        });
    }

    /// <summary>
    /// The offset's own target, for a scroller - the platform keeps the offset
    /// read-only and the scroller's movement writes it, see
    /// <see cref="ScrollMovement.Walked"/>.
    /// </summary>
    private ITripTarget? Sliding =>
        View is ScrollView scroll && Property is null
            && scroll.GetValue(StateUIRenderer.ScrollMovementProperty) is ScrollMovement movement
            ? movement.Walked
            : null;

    /// <summary>
    /// Puts the value onto this control - the property, composed to its own
    /// type, or the scroller's offset.
    /// </summary>
    /// <remarks>
    /// What the number's channel does to every control on the number, each
    /// frame, and what a report or a joining does to one. Not under the
    /// writing marker itself: the walker raises it around a frame, and the
    /// state channel around its own writes.
    /// </remarks>
    /// <param name="lanes">The value, lane by lane.</param>
    internal void Write(double[] lanes)
    {
        if (Property is BindableProperty property)
        {
            View?.SetValue(property, MotionProperty.Compose(_shape, _fraction, lanes));
            return;
        }

        Sliding?.Write(lanes);
    }

    /// <summary>Reads where this control has the value.</summary>
    /// <param name="into">Filled with the value's lanes.</param>
    /// <returns>Whether there was anything to read.</returns>
    internal bool Read(double[] into)
    {
        if (Property is BindableProperty property)
        {
            return View is BindableObject view && MotionProperty.Split(view.GetValue(property), _shape, into);
        }

        return Sliding?.Read(into) ?? false;
    }

    /// <summary>The value these lanes stand for, in the control's own type.</summary>
    /// <param name="lanes">The lanes.</param>
    /// <returns>The value, or null where this control has none.</returns>
    internal object? Compose(double[] lanes) =>
        Property is not null
            ? MotionProperty.Compose(_shape, _fraction, lanes)
            : Sliding?.Compose(lanes);

    /// <summary>
    /// The law the lanes name.
    /// </summary>
    /// <remarks>
    /// Kind 0 is no motion at all, 2 is a stated length on a stated curve, and
    /// 3 is a spring. Kind 1 is a value that asked for the law of whatever
    /// element drives it and is driven by NONE - Swift resolves an element's
    /// own law into these lanes as the value crosses, being the only side that
    /// can read a per-value motion plan - so the application's answer is the
    /// right one for a value no element has claimed.
    /// </remarks>
    internal static HostMotion Law(double[] lanes, int width, Walker walker) =>
        LawAt(lanes, JourneyCodec.LawAt(width), walker);

    /// <summary>The law the three lanes at <paramref name="at"/> name.</summary>
    /// <param name="lanes">The whole value.</param>
    /// <param name="at">The first of the law's three lanes.</param>
    /// <param name="walker">What moves the values, for the element's own law.</param>
    /// <returns>The law.</returns>
    private static HostMotion LawAt(double[] lanes, int at, Walker walker) =>
        JourneyCodec.MotionAt(lanes, at) switch
        {
            (JourneyCodec.Law.Inherited, _) => walker.Travel,
            (_, HostMotion motion) => motion,
        };

    /// <summary>Whether two runs of lanes hold the same numbers.</summary>
    internal static bool Same(double[] left, double[] right)
    {
        for (int lane = 0; lane < left.Length; lane++)
        {
            if (Math.Abs(left[lane] - right[lane]) >= MotionLaw.Still)
            {
                return false;
            }
        }

        return true;
    }
}
