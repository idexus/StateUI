// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using System.ComponentModel;
using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// What the reader does to a value a state carries, onto the state: a finger
/// on a slider, a scroll, a switch flipped, a keystroke, a room that moved.
/// </summary>
/// <remarks>
/// A REPORT IS NOT AN ECHO: a platform raises its change notification while
/// the value is being assigned, and what arrives under
/// <see cref="Walker.Writing"/> is this side's own write coming round. What
/// is left lands on the state, every other control on the number is written
/// the reader's value, and the cycle runs INLINE, so the arithmetic that
/// follows moves on the reader's own frame.
/// </remarks>
internal sealed class CarriedReports
{
    private readonly Walker _walker;
    private readonly StateChannels _channels;
    private readonly DisplayCycle _cycle;
    private readonly Func<ICycleCrossing> _crossing;

    /// <summary>The reports onto one image's states.</summary>
    /// <param name="walker">What moves the values.</param>
    /// <param name="channels">The states the reports land on.</param>
    /// <param name="cycle">The cycle a report runs at once.</param>
    /// <param name="crossing">The far end of the image, as it stands.</param>
    internal CarriedReports(
        Walker walker, StateChannels channels, DisplayCycle cycle, Func<ICycleCrossing> crossing)
    {
        _walker = walker;
        _channels = channels;
        _cycle = cycle;
        _crossing = crossing;
    }

    /// <summary>
    /// Puts the room a view is given onto its state, from now on.
    /// </summary>
    /// <remarks>
    /// The frame's own parts rather than <c>SizeChanged</c> alone, because a
    /// view MOVED without being resized has a new room to place things in too -
    /// a run inside a page that scrolled, a pane the reader dragged wider.
    /// </remarks>
    /// <param name="view">The control whose room it is.</param>
    /// <param name="attachment">Where the room goes.</param>
    internal void Feed(VisualElement view, StateAttachment attachment)
    {
        // THE CLOSURES ARE MADE WHERE THE CONTROL IS NOT. Everything a feed
        // keeps - the handler, and the unsubscription the TIE holds - lives in
        // `Listen`, whose scope has the control only as a weak reference: the
        // cycle keeps attachments by number, so a closure of theirs that
        // captures the control roots it for the life of the process, and the
        // attachment's own weak reference can then never go null, which means
        // `Prune` never drops it either. The compiler decides what a closure
        // captures by SCOPE, so the control must not be in the scope that makes
        // them - not even as a variable the closures never read.
        //
        // MEASURED on the gallery, 2026-09-07, walking the whole of it: the
        // two samples that feed a frame - `PlacedLayout` and
        // `GalleryView` - left their whole subtree behind on every visit.
        Listen(new WeakReference<VisualElement>(view), attachment);

        // And the room it already stands in, so a layout registered onto a
        // page that has been laid out already is not waiting for a change.
        Reported(view, attachment);
    }

    /// <summary>
    /// Hears a control's own frame changing, and leaves the attachment a way to
    /// stop hearing it - both of them holding the control weakly.
    /// </summary>
    /// <param name="held">The control, weakly.</param>
    /// <param name="attachment">Where the room goes.</param>
    private void Listen(WeakReference<VisualElement> held, StateAttachment attachment)
    {
        void Moved(object? sender, PropertyChangedEventArgs args)
        {
            // THE SENDER, never a captured control: what a handler closes over
            // is what it keeps alive.
            if (args.PropertyName is nameof(VisualElement.X) or nameof(VisualElement.Y)
                or nameof(VisualElement.Width) or nameof(VisualElement.Height)
                or nameof(VisualElement.Frame)
                && sender is VisualElement moved)
            {
                Reported(moved, attachment);
            }
        }

        Hearing(held, Moved, hear: true);

        attachment.Released = () => Hearing(held, Moved, hear: false);
    }

    /// <summary>Starts or stops hearing a control that may already be gone.</summary>
    /// <param name="held">The control, weakly.</param>
    /// <param name="handler">What hears it.</param>
    /// <param name="hear">Whether to start or to stop.</param>
    private static void Hearing(
        WeakReference<VisualElement> held, PropertyChangedEventHandler handler, bool hear)
    {
        if (!held.TryGetTarget(out VisualElement? view))
        {
            return;
        }

        if (hear)
        {
            view.PropertyChanged += handler;
        }
        else
        {
            view.PropertyChanged -= handler;
        }
    }

    /// <summary>
    /// The room, onto the state, and a cycle at once.
    /// </summary>
    /// <remarks>
    /// <para>
    /// INSIDE THE PLATFORM'S OWN LAYOUT PASS, deliberately. What this room
    /// places has to be where it belongs before the pass paints, and a turn's
    /// wait is a run of cards a frame behind the hand - worse than that on a
    /// Mac, where a window drag is tracked in a run loop mode that drains no
    /// dispatcher at all: measured, a queued turn ran 590 ms after the report
    /// that asked for it, having swallowed eleven reports on the way.
    /// </para>
    /// <para>
    /// What a cycle running there may NOT do is write a rectangle, which
    /// invalidates the very measure being taken. Those are left owing and
    /// written on the turn after - see <see cref="MotionPlacement.Wear"/>.
    /// </para>
    /// </remarks>
    /// <param name="view">The control whose room it is.</param>
    /// <param name="attachment">Where the room goes.</param>
    private void Reported(VisualElement view, StateAttachment attachment)
    {
        Rect frame = view.Frame;

        if (attachment.Fed == frame)
        {
            return;
        }

        attachment.Fed = frame;
        Told(attachment.Number, [frame.X, frame.Y, frame.Width, frame.Height], 0b1111);

        MotionPlacement.InPass++;

        try
        {
            _cycle.Run(CycleReason.Told);
        }
        finally
        {
            MotionPlacement.InPass--;
        }
    }

    /// <summary>
    /// A value the READER moved, onto the state driving it - and whether there
    /// was a state to move.
    /// </summary>
    /// <remarks>
    /// <para>
    /// THE REPORT THAT IS NOT AN ECHO. Every platform raises its change
    /// notification while the value is being assigned, so the walker's own
    /// frames come back as reports; those are dropped, by
    /// <see cref="Walker.Writing"/>. What is left was made by somebody
    /// else, and on a Slider or a Stepper that is a finger.
    /// </para>
    /// <para>
    /// A FINGER TAKES THE VALUE. Whatever was carrying it ends where it stands
    /// and whoever was waiting hears that it did not arrive - which is the
    /// only honest reading: the reader has just put the thumb somewhere, and a
    /// motion that went on would drag it out from under them. Then the value
    /// AND where it is going are written, so nothing aims it back.
    /// </para>
    /// </remarks>
    /// <param name="view">The control the reader moved.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="value">Where they left it.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Reader(BindableObject view, BindableProperty property, double value) =>
        Reader(view, property, [value]);

    /// <summary>
    /// The same for a value of more than one lane - a scroller's offset, which
    /// is one point the reader moves with a finger.
    /// </summary>
    /// <remarks>
    /// A REPORT IS ABOUT LANES, so a value of any width comes back the same
    /// way: the finger takes it, whatever carried it ends where it stands, and
    /// the value AND its destination are written together, lane for lane. Only
    /// a report as wide as the value is heard - one of another width is a value
    /// of another shape, and laying it would leave the image half of each.
    /// </remarks>
    /// <param name="view">The control the reader moved.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="lanes">Where they left it, lane by lane.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Reader(BindableObject view, BindableProperty property, double[] lanes)
    {
        double value = lanes.Length > 0 ? lanes[0] : 0;

        if (MotionTrace.Watching)
        {
            // The one line that says why a finger was or was not heard: the
            // attachment the control has, and whether a frame was being
            // written.
            MotionTrace.Say(_channels.Sink(view, property) is StateAttachment heard
                ? $"reader {view.GetType().Name}.{property.PropertyName} = {value:0.###}  attachment {heard.Number} kind={heard.Kind} mode={heard.Mode} lanes={heard.Lanes} writing={Walker.Writing}"
                : $"reader {view.GetType().Name}.{property.PropertyName} = {value:0.###}  no attachment ({_channels.Count} numbers)");
        }

        if (_channels.Count == 0
            || _channels.Sink(view, property) is not StateAttachment attachment
            || attachment.Kind != HostStateKind.Property
            || attachment.Mode == HostStateMode.Out
            || attachment.Lanes != lanes.Length)
        {
            return false;
        }

        if (Walker.Writing > 0)
        {
            return true;
        }

        return Landed(view, attachment, lanes);
    }

    /// <summary>
    /// A reader's own movement onto the attachment carrying it, whatever found
    /// the attachment - a property that reported, or a scroller, which has
    /// none.
    /// </summary>
    /// <param name="view">The control the reader moved.</param>
    /// <param name="attachment">The attachment the value is carried on.</param>
    /// <param name="lanes">Where they left it, lane by lane.</param>
    /// <returns>Whether the cycle has work to do.</returns>
    private bool Landed(BindableObject view, StateAttachment attachment, double[] lanes)
    {
        // THE VALUE IS THE READER'S NOW, on every control that shows it: the
        // state's channel lets go, and every other control on the number is
        // written the reader's own number - before the cycle, and whether or
        // not there is one, since a control is not going to hear it any other
        // way and it needs no arithmetic to hear it.
        attachment.Channel?.Taken(attachment, lanes);

        // Where it is, where it is going, and standing still: three lanes, and
        // the law, the waiter and the stop counter left as they were.
        //
        // WRITTEN INTO AN ARRAY OF THE VALUE'S WHOLE SHAPE, because a report
        // is about LANES and never about shape: the other side lays the named
        // lanes into the image it has, and a report of a different length is a
        // value of a different shape. Sent short, it replaced the journey's
        // image with three lanes - the law, the waiter and the stop counter
        // gone with it - and every write after that crossed as a whole new
        // value, which the branch below reads as a snap. Measured on the
        // gallery: a slider travelled to every value until it was touched
        // once, and jumped for the rest of the session.
        double[] said = new double[JourneyCodec.Count(attachment.Lanes)];

        for (int lane = 0; lane < attachment.Lanes; lane++)
        {
            said[lane] = lanes[lane];
            said[JourneyCodec.Destination(attachment.Lanes) + lane] = lanes[lane];
        }

        // WHERE IT IS AND WHERE IT IS GOING, both, and standing still - three
        // groups of `Lanes`, which for one number is the three slots this
        // always named and for a point is six.
        Told(attachment.Number, said, (1UL << JourneyCodec.LawAt(attachment.Lanes)) - 1);

        return Cycled();
    }

    /// <summary>
    /// Where the reader has scrolled to, onto the state carrying the offset.
    /// </summary>
    /// <remarks>
    /// A scroller has no settable property for this side to hear, so the
    /// report comes from the scroller's movement - the one place that tells a
    /// reader's report from a relayout's clamp and from the frames of a travel
    /// the application wrote - and lands here by KEY instead. Both lanes
    /// always, the offset being one point.
    /// </remarks>
    /// <param name="view">The scroller.</param>
    /// <param name="lanes">Where it stands, across then down.</param>
    /// <returns>Whether a state carries it.</returns>
    internal bool Slid(BindableObject view, double[] lanes)
    {
        if (_channels.Count == 0
            || _channels.Sink(view, HostProp.ScrollOffset) is not StateAttachment attachment
            || attachment.Mode == HostStateMode.Out
            || attachment.Lanes != lanes.Length)
        {
            return false;
        }

        return Walker.Writing > 0 || Landed(view, attachment, lanes);
    }

    /// <summary>
    /// A PLAIN value the reader moved - a switch flipped, a choice made - onto
    /// the state driving it, and whether there was one.
    /// </summary>
    /// <remarks>
    /// The one lane crosses as the host's own write, so the state hears it
    /// exactly as it hears a slider's thumb: a reader of the state renders,
    /// nobody else does. The state's echo of the value is not set on the
    /// control again because <see cref="StateAttachment.Set(double[])"/>
    /// compares against what the control already shows, and a write this side
    /// makes comes round under <see cref="Walker.Writing"/> and is dropped.
    /// Every other control the same state drives is set here too, the cycle's
    /// read-back naming only what this side has not yet been told.
    /// </remarks>
    /// <param name="view">The control that reported.</param>
    /// <param name="property">Which of its properties moved.</param>
    /// <param name="value">Where the reader left it, as one lane.</param>
    /// <returns>Whether a plain state drives it both ways.</returns>
    internal bool Reported(BindableObject view, BindableProperty property, double value) =>
        Reported(view, property, [value]);

    /// <summary>
    /// The same, for a plain value of more than one lane - a date as year,
    /// month and day, a time as hour, minute and second.
    /// </summary>
    /// <remarks>
    /// A STATE'S OWN WRITE IS NOT A REPORT: the platform raises its changed
    /// notification synchronously inside the assignment
    /// <see cref="StateAttachment.Set(double[])"/> makes, and that assignment
    /// runs under <see cref="Walker.Writing"/>, so what arrives here while that
    /// counter is up is this side's own value coming round and is dropped -
    /// answered as handled, so the renderer raises no event for it either.
    /// </remarks>
    /// <param name="view">The control that reported.</param>
    /// <param name="property">Which of its properties moved.</param>
    /// <param name="lanes">Where the reader left it, lane by lane.</param>
    /// <returns>Whether a plain state drives it both ways.</returns>
    internal bool Reported(BindableObject view, BindableProperty property, double[] lanes)
    {
        if (_channels.Count == 0
            || _channels.Sink(view, property) is not StateAttachment attachment
            || attachment.Kind != HostStateKind.Plain
            || attachment.Mode != HostStateMode.InOut)
        {
            return false;
        }

        if (Walker.Writing > 0)
        {
            return true;
        }

        Told(attachment.Number, lanes, lanes.Length >= 64 ? ~0UL : (1UL << lanes.Length) - 1);

        if (attachment.Channel is StateChannel channel)
        {
            foreach (StateAttachment other in channel.Attachments)
            {
                if (!ReferenceEquals(other, attachment) && other.Kind == HostStateKind.Plain)
                {
                    other.Set(lanes);
                }
            }
        }

        return Cycled();
    }

    /// <summary>
    /// The words the reader typed into a field, onto the text state driving
    /// it both ways, and whether there was one.
    /// </summary>
    /// <remarks>
    /// The text crosses WHOLE - its length and its letters - as the host's own
    /// write, so the state hears a keystroke exactly as it hears a switch
    /// flipped: a reader of the state renders, nobody else does. The attachment
    /// remembers the words, so the state's echo of them on the next cycle is
    /// not set back onto the field under the reader's caret; every other field
    /// the same state drives is set here. A write this side made comes round
    /// as a platform notification under <see cref="Walker.Writing"/> and
    /// is dropped, as <see cref="Reported(BindableObject, BindableProperty, double[])"/>
    /// drops it.
    /// </remarks>
    /// <param name="view">The field that reported.</param>
    /// <param name="property">Its text property.</param>
    /// <param name="words">What the reader typed.</param>
    /// <returns>Whether a text state drives it both ways.</returns>
    internal bool Typed(BindableObject view, BindableProperty property, string words)
    {
        if (_channels.Count == 0
            || _channels.Sink(view, property) is not StateAttachment attachment
            || attachment.Kind != HostStateKind.Text
            || attachment.Mode != HostStateMode.InOut)
        {
            return false;
        }

        if (Walker.Writing > 0)
        {
            return true;
        }

        attachment.Remember(words);
        Told(attachment.Number, StateBatch.Words(words), ~0UL);

        if (attachment.Channel is StateChannel channel)
        {
            foreach (StateAttachment other in channel.Attachments)
            {
                if (!ReferenceEquals(other, attachment) && other.Kind == HostStateKind.Text)
                {
                    other.Wear(words);
                }
            }
        }

        return Cycled();
    }

    /// <summary>
    /// Runs the cycle a report owes and answers true - what every report path
    /// ends with. <see cref="MotionPlacement.InPass"/> is raised around it
    /// because some reports arrive from inside a layout pass (a frame feed),
    /// and it is harmless where they do not (a keystroke, a pick).
    /// </summary>
    private bool Cycled()
    {
        if (StateUISession.RegisterApp is null)
        {
            return true;
        }

        MotionPlacement.InPass++;

        try
        {
            _cycle.Run(CycleReason.Told);
        }
        finally
        {
            MotionPlacement.InPass--;
        }

        return true;
    }

    /// <summary>
    /// Where a value the platform reports stands, as far as this side has been
    /// told.
    /// </summary>
    /// <remarks>
    /// Kept here as well as on the state so a gesture can count on from where the
    /// value stood without reading back across the boundary: a drag writes the
    /// base plus its own delta, and it is asked once per report.
    /// </remarks>
    private readonly Dictionary<int, double> _standing = [];

    /// <summary>Where a reported value stands.</summary>
    /// <param name="number">The value being asked about.</param>
    /// <returns>Where it stands, or nought where nothing has said.</returns>
    internal double Standing(int number) =>
        _standing.TryGetValue(number, out double value) ? value : 0;

    /// <summary>Says where a value the platform moves now stands.</summary>
    /// <remarks>
    /// A ONE-LANE WRITE AND A CYCLE, in that order: the arithmetic that follows
    /// this value READS it, so it has to be where the platform says before any
    /// engine runs - and the cycle is run INLINE, on the platform's own report,
    /// because a run of cards that waited for the next frame would be a card
    /// behind the hand. Where it stands is recorded either way; with no Swift
    /// side registered nothing crosses and no cycle runs - a test host's
    /// controls have no library behind them.
    /// </remarks>
    /// <param name="number">The value that moved.</param>
    /// <param name="value">Where it now stands.</param>
    internal void Moved(int number, double value)
    {
        _standing[number] = value;

        if (StateUISession.RegisterApp is null)
        {
            return;
        }

        Told(number, [value], 1);
        Cycled();
    }

    /// <summary>Where a value the platform reports goes.</summary>
    /// <remarks>
    /// Written straight into the image and the clock STARTED if it was
    /// stopped: a report on a still page has to reach whatever follows it
    /// within a frame, and nothing else is about to ask for one.
    /// </remarks>
    /// <param name="number">Which number.</param>
    /// <param name="lanes">The value, lane by lane.</param>
    /// <param name="mask">Which lanes are being reported.</param>
    internal void Told(int number, double[] lanes, ulong mask)
    {
        _crossing().Write(StateBatch.Bytes([(number, mask, lanes)]));
        _walker.Clock?.Start();
    }

    /// <summary>
    /// The same, for a value with no lanes - a text, whole.
    /// </summary>
    /// <param name="number">Which number.</param>
    /// <param name="bytes">The value's own bytes.</param>
    /// <param name="mask">Which lanes are being reported - all of them, for a text.</param>
    internal void Told(int number, byte[] bytes, ulong mask)
    {
        _crossing().Write(StateBatch.Bytes([(number, mask, bytes)]));
        _walker.Clock?.Start();
    }
}
