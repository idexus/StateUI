// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using System.Runtime.CompilerServices;
using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// Every state a control on this side wears, one channel per number, and
/// which control's properties are attached to which.
/// </summary>
/// <remarks>
/// A property with a state behind it is moved by the SAME walker that moves
/// everything else here, on a channel that is the STATE's - one per number,
/// written onto every control attached to it, see <see cref="StateChannel"/> -
/// so a state is one value however many controls wear it, and every guard the
/// walker already has sees a state's motion as it sees any other.
/// </remarks>
internal sealed class StateChannels
{
    private readonly Walker _walker;
    private readonly Func<ICycleCrossing> _crossing;
    private readonly Action<int, bool> _land;

    /// <summary>How much room a read is given before it asks for more.</summary>
    private const int Room = 4096;

    /// <summary>
    /// Every number with a control on it - one state may drive several, and
    /// they share one channel.
    /// </summary>
    private readonly Dictionary<int, StateChannel> _byNumber = [];

    /// <summary>And by the control, which is how a host writer asks about one.</summary>
    private readonly ConditionalWeakTable<BindableObject, Dictionary<HostPropKey, StateAttachment>> _byView = new();

    /// <summary>What a cycle reads into, kept rather than made per frame.</summary>
    private byte[] _buffer = new byte[Room];

    /// <summary>The state channels over one image.</summary>
    /// <param name="walker">What moves the values.</param>
    /// <param name="crossing">The far end of the image, as it stands.</param>
    /// <param name="land">Told a completion is done, and whether it finished.</param>
    internal StateChannels(Walker walker, Func<ICycleCrossing> crossing, Action<int, bool> land)
    {
        _walker = walker;
        _crossing = crossing;
        _land = land;
    }

    /// <summary>Arms the frame feed a control registers - the carried reports' own.</summary>
    internal Action<VisualElement, FeedAttachment>? Feeding { get; set; }

    /// <summary>How many numbers have a control on them.</summary>
    internal int Count => _byNumber.Count;

    /// <summary>
    /// Attaches this control's properties to their states, forgetting whatever
    /// it was tied to before.
    /// </summary>
    /// <remarks>
    /// THE VALUE IS LANDED AT ONCE, before anything is drawn: the state is read
    /// whole - where the value is AND where it is going - and the property
    /// snapped to where the value stands, so a control born under a state is
    /// already showing what the state says rather than what its default was.
    /// A setpoint that differs is then aimed at in the ordinary way.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="node">
    /// The element as the message describes it - its registrations, and the
    /// type that resolves each property the way a style setter is resolved.
    /// </param>
    internal void Register(BindableObject view, HostPatch node)
    {
        Detach(view);

        if (node.States is not { Count: > 0 } entries)
        {
            return;
        }

        Dictionary<HostPropKey, StateAttachment> tied = [];
        bool fed = false;

        foreach (HostStateBinding entry in entries)
        {
            if (StateAttachment.Of(view, entry, node.Type, node.TypeName) is not StateAttachment attachment)
            {
                continue;
            }

            tied[entry.Key] = attachment;

            if (!_byNumber.TryGetValue(entry.Number, out StateChannel? channel))
            {
                _byNumber[entry.Number] = channel = new StateChannel(entry.Number, _walker);
            }

            channel.Add(attachment);

            // AND THE LAYOUT IS TOLD IT IS PLACED, before anything measures
            // it: its children stand where arithmetic over the room puts them,
            // so their reach says nothing about how big it should be.
            if (attachment is PlacementAttachment)
            {
                view.SetValue(MotionPlacement.PlacedProperty, true);
            }

            if (attachment is FeedAttachment feed
                && entry.Key.Prop == HostProp.Frame
                && view is VisualElement reporting)
            {
                Feeding?.Invoke(reporting, feed);
                fed = true;
                continue;
            }

            // READ WHOLE, and landed before anything is drawn: the value AND
            // where it is going, so a control born under a state shows what the
            // number says rather than what its own default was.
            int read = _crossing().Read(entry.Number, _buffer);

            if (read > 0 && StateBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
            {
                attachment.Landed(bytes, _walker);
            }
        }

        // A ROOM A LAYOUT PLACES ITS OWN CHILDREN FROM IS A ROOM THAT DOES NOT
        // TRAVEL, and that is the same mark a WATCHED frame sets, for the same
        // reason: what is reported there decides where those children GO, so
        // they must ARRIVE at the answer rather than walk to it through the
        // very measurement that made it. See LayoutMotion.Measures.
        //
        // Asked here rather than where the feed is armed, because the two
        // entries arrive in whatever order the message lays them out - and
        // BOTH are needed: a view that merely reports its room, with nothing
        // placed from it, is an ordinary view whose children go on travelling.
        //
        // Measured on Linux, where a page's first arrangement gives a layout
        // one unit square: the room crossed as 1x1, the arithmetic put every
        // card of `PlacedLayout` in a rectangle half a point wide, and
        // when the real room arrived the cards were left travelling from there
        // - which on a page that then stopped arranging is a ring of cards
        // frozen a fifth of a percent from the corner.
        if (fed && view.GetValue(MotionPlacement.PlacedProperty) is true)
        {
            view.SetValue(StateUIRenderer.WatchedProperty, true);
        }

        if (tied.Count > 0)
        {
            _byView.AddOrUpdate(view, tied);
        }
    }

    /// <summary>What this control's properties are tied to, if anything.</summary>
    /// <param name="view">The control.</param>
    /// <returns>The attachments, by property.</returns>
    internal IReadOnlyDictionary<HostPropKey, StateAttachment> Registered(BindableObject view) =>
        _byView.TryGetValue(view, out Dictionary<HostPropKey, StateAttachment>? tied)
            ? tied
            : new Dictionary<HostPropKey, StateAttachment>();

    /// <summary>
    /// The attachment carrying one named value on a control, or null - the
    /// lookup for a value the platform declares no settable property for.
    /// </summary>
    /// <param name="view">The control.</param>
    /// <param name="named">Which value.</param>
    /// <returns>The attachment, or null where no state carries it.</returns>
    internal StateAttachment? Sink(BindableObject view, HostProp named)
    {
        if (!_byView.TryGetValue(view, out Dictionary<HostPropKey, StateAttachment>? tied))
        {
            return null;
        }

        foreach (StateAttachment attachment in tied.Values)
        {
            if (attachment.Key.Prop == named)
            {
                return attachment;
            }
        }

        return null;
    }

    /// <summary>
    /// The attachment one property of one control has, or null where it has
    /// none.
    /// </summary>
    /// <remarks>
    /// The one question every host writer asks before it decides a resting
    /// value for itself: a property a state is driving has its resting value on
    /// the state, and a visual state leaving, a hidden view coming back or a
    /// cleared property must land THAT rather than what the tree last said.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <returns>The attachment, or null.</returns>
    internal StateAttachment? Sink(BindableObject view, BindableProperty property)
    {
        if (!_byView.TryGetValue(view, out Dictionary<HostPropKey, StateAttachment>? tied))
        {
            return null;
        }

        foreach (StateAttachment attachment in tied.Values)
        {
            if (attachment.Property == property)
            {
                return attachment;
            }
        }

        return null;
    }

    /// <summary>
    /// Whether a state is driving this value - what every host writer asks
    /// before it decides a resting value of its own.
    /// </summary>
    /// <remarks>
    /// A state whose writes never reach the control drives nothing: an
    /// <c>.in</c> registration is the host TELLING the state where a value got
    /// to, so every writer there goes on as it always did.
    /// </remarks>
    /// <param name="owner">The control.</param>
    /// <param name="key">Which of its values - a property, for a state.</param>
    /// <returns>Whether a state owns it.</returns>
    internal bool Drives(object owner, object key) =>
        owner is BindableObject view
        && key is BindableProperty property
        && Sink(view, property) is StateAttachment attachment
        && attachment is PropertyAttachment or TextAttachment or PlainAttachment
        && attachment.Mode != HostStateMode.In;

    /// <summary>
    /// Puts a state-driven property back where its state says it belongs, and
    /// answers whether there was a state at all.
    /// </summary>
    /// <remarks>
    /// What the host's own writers do INSTEAD of landing a resting value they
    /// worked out for themselves. The state is read whole, so the property is
    /// snapped to where the value stands and aimed at where it is going -
    /// which is the same landing a registration makes, and the only reading of
    /// "at rest" that a value something else is carrying can have.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Reland(BindableObject view, BindableProperty property)
    {
        if (!Drives(view, property) || Sink(view, property) is not StateAttachment attachment)
        {
            return false;
        }

        int read = _crossing().Read(attachment.Number, _buffer);

        if (read > 0 && StateBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
        {
            attachment.Landed(bytes, _walker);
        }

        return true;
    }

    /// <summary>
    /// Sends a state-driven property to where its state is going, under the law
    /// the caller was going to use - and answers whether there was a state.
    /// </summary>
    /// <remarks>
    /// The other half of <see cref="Reland"/>, for a writer that was about to
    /// send the value somewhere rather than put it there: a visual state
    /// leaving settles every value it touched, and where a state has one the
    /// destination is the state's rather than the tree's.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="property">Which of its properties.</param>
    /// <param name="spec">The law the caller was going to use.</param>
    /// <returns>Whether a state drives it.</returns>
    internal bool Restate(BindableObject view, BindableProperty property, in HostMotion spec)
    {
        if (!Drives(view, property) || Sink(view, property) is not StateAttachment attachment)
        {
            return false;
        }

        int read = _crossing().Read(attachment.Number, _buffer);

        if (read > 0 && StateBatch.Read(_buffer.AsSpan(0, read)) is [(_, _, byte[] bytes)])
        {
            (attachment as PropertyAttachment)?.Resting(bytes, _walker, spec);
        }

        return true;
    }

    /// <summary>
    /// Tells a state where its value is going, whenever its own trip is
    /// aimed or lands.
    /// </summary>
    /// <remarks>
    /// <para>
    /// WHAT KEEPS A DRIVEN STATE HONEST. A setpoint the state itself wrote is
    /// already on the image; what is not is where the value actually started
    /// from and how fast it set off, and - the half no poll can see - where it
    /// LANDED: the trip is taken out of the table as it lands, so nothing
    /// is left to read the value it finished at. Written here, where the
    /// value is and where it is going agree and the speed is nought, which is
    /// what an engine reads as "arrived".
    /// </para>
    /// <para>
    /// A CHANNEL OF ONE CONTROL'S OWN IS NOT THE STATE'S NEWS. A visual state
    /// dimming a button, or the tree stating a value beside the registration,
    /// aims that control's own (control, property) trip, and the value on
    /// the number is unchanged by it - every other control on the number is
    /// still showing the state. See <see cref="StateChannel"/>.
    /// </para>
    /// </remarks>
    /// <param name="trip">The motion.</param>
    /// <param name="going">Whether the value is on its way rather than stopped.</param>
    internal void Mirror(Trip trip, bool going)
    {
        if (trip.Moves is not StateChannel channel
            || !channel.Reports
            || channel.Mirror(trip, going) is not (ulong mask, double[] lanes))
        {
            return;
        }

        _crossing().Write(StateBatch.Bytes([(channel.Number, mask, lanes)]));
    }

    /// <summary>
    /// Drops every attachment whose control has been collected, and every
    /// number left with none.
    /// </summary>
    /// <remarks>
    /// The other half of holding a control weakly: an attachment is harmless
    /// once its view has gone - it writes nothing and aims nothing - but the
    /// list it sits in would grow for ever. Run at the head of a cycle, which
    /// is the one moment the map is walked anyway.
    /// </remarks>
    internal void Prune()
    {
        List<int>? empty = null;

        foreach ((int number, StateChannel channel) in _byNumber)
        {
            // A NUMBER WITH NOTHING LEFT ON IT GOES - once its trip has
            // landed. One still moving runs to the end and tells the state
            // where the value got to, which is the truth about the value
            // whether or not anything is there to show it.
            if (channel.Prune() == 0 && channel.Moving is null)
            {
                (empty ??= []).Add(number);
            }
        }

        foreach (int number in empty ?? [])
        {
            _byNumber.Remove(number);
        }
    }

    /// <summary>
    /// Forgets everything this control was tied to, and ends whatever was
    /// moving one of its state-driven properties.
    /// </summary>
    /// <param name="view">The control.</param>
    internal void Detach(BindableObject view)
    {
        if (!_byView.TryGetValue(view, out Dictionary<HostPropKey, StateAttachment>? tied))
        {
            return;
        }

        foreach (StateAttachment attachment in tied.Values)
        {
            // THE STATE'S CHANNEL IS NOT THIS CONTROL'S TO END: the value goes
            // on to wherever it was sent, for whatever else wears the number -
            // and a control described again a moment later joins it where it
            // is. A number left with nothing on it is dropped once its trip
            // has landed, by the next cycle's sweep.
            if (attachment.Channel is StateChannel channel)
            {
                channel.Remove(attachment);

                if (channel.Empty && channel.Moving is null)
                {
                    _byNumber.Remove(attachment.Number);
                }
            }

            // A feed listens to the platform, and a control nothing describes
            // any more is one nothing should hear from.
            if (attachment is FeedAttachment feed)
            {
                feed.Released?.Invoke();
                feed.Released = null;
            }

            // A motion of this control's own on the property - a visual
            // state's, the tree's - is one nothing reads any more: halted, so
            // its waiter hears false rather than never.
            if (attachment.Property is not null)
            {
                _walker.Halt(view, attachment.Property, TripEnd.Nothing);
            }
        }

        _byView.Remove(view);
    }

    /// <summary>
    /// Where every value the walker is carrying stands, for the image - one
    /// reading per number, in ascending order.
    /// </summary>
    /// <returns>Each number with the lanes being reported and its whole value.</returns>
    internal List<(int Number, ulong Mask, double[] Lanes)> Readings()
    {
        List<(int Number, ulong Mask, double[] Lanes)> batch = [];

        foreach ((int number, StateChannel channel) in _byNumber)
        {
            // ONE READING PER NUMBER, off the one channel: what the image says
            // is where the value got to, and the value is in one place.
            if (channel.Reports && channel.Reading() is (ulong mask, double[] lanes))
            {
                batch.Add((number, mask, lanes));
            }
        }

        batch.Sort((left, right) => left.Number.CompareTo(right.Number));
        return batch;
    }

    /// <summary>What a cycle wrote, onto the controls that wear it.</summary>
    /// <param name="batch">The batch the core answered with.</param>
    internal void Wear(ReadOnlySpan<byte> batch)
    {
        foreach ((int number, ulong mask, byte[] bytes) in StateBatch.Read(batch))
        {
            if (!_byNumber.TryGetValue(number, out StateChannel? channel))
            {
                continue;
            }

            // A JOURNEY IS WORN ONCE, by the number's channel, whatever the
            // number of controls on it; what is not a journey - a plain
            // value, a text, a run of placements - is each control's own.
            if (channel.Journeys)
            {
                channel.Wear(bytes, mask, _land);
            }

            foreach (StateAttachment attachment in channel.Attachments.ToArray())
            {
                if (attachment is not PropertyAttachment)
                {
                    attachment.Wear(bytes, mask, _walker, _land);
                }
            }
        }
    }
}
