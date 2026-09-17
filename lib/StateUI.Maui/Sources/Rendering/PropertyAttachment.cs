// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// A walked value on one control - a property, or a scroller's offset - riding
/// the number's channel with every other control on the number.
/// </summary>
internal sealed class PropertyAttachment : StateAttachment
{
    private readonly MotionValue _shape;
    private readonly bool _fraction;

    /// <summary>A walked value of <paramref name="shape"/> on one control.</summary>
    /// <param name="view">The control, held weakly.</param>
    /// <param name="entry">What the message said.</param>
    /// <param name="property">The property, or null for a scroller's offset.</param>
    /// <param name="shape">What the value is made of.</param>
    internal PropertyAttachment(
        BindableObject view, HostStateBinding entry, BindableProperty? property, MotionValue shape)
        : base(view, entry, property)
    {
        _shape = shape;
        _fraction = property == VisualElement.OpacityProperty;
    }

    /// <summary>How many lanes the value takes.</summary>
    internal int Lanes => _shape switch
    {
        MotionValue.Number or MotionValue.Whole or MotionValue.Single => 1,
        MotionValue.Offset => 2,
        _ => 4,
    };

    /// <inheritdoc/>
    internal override void Landed(byte[] bytes, Walker walker)
    {
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
}
