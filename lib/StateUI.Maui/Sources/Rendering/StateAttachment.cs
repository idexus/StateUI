// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// One of a control's values, attached to a state through one of this side's
/// doors - and the door is the attachment's own type: a walked value
/// (<see cref="PropertyAttachment"/>), text (<see cref="TextAttachment"/>), a
/// plain value (<see cref="PlainAttachment"/>), a run of placements
/// (<see cref="PlacementAttachment"/>), or the platform's own answer about the
/// control (<see cref="FeedAttachment"/>).
/// </summary>
/// <remarks>
/// A walked value's lanes are read through <see cref="JourneyCodec"/>, the one
/// place this side lays them out.
/// </remarks>
internal abstract class StateAttachment
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

    /// <summary>The control, or null once it has gone.</summary>
    internal BindableObject? View => _view.TryGetTarget(out BindableObject? view) ? view : null;

    /// <summary>
    /// The number's channel, shared with every other control on the number -
    /// what a journey on this property is carried by. Set by the channel as the
    /// attachment joins it.
    /// </summary>
    internal StateChannel? Channel { get; set; }

    /// <summary>An attachment of one of a control's values to a state.</summary>
    /// <param name="view">The control, held weakly.</param>
    /// <param name="entry">What the message said.</param>
    /// <param name="property">The property, or null for a value that is not one.</param>
    private protected StateAttachment(BindableObject view, HostStateBinding entry, BindableProperty? property)
    {
        _view = new WeakReference<BindableObject>(view);
        Key = entry.Key;
        Number = entry.Number;
        Mode = entry.Mode;
        Property = property;
    }

    /// <summary>Which property, as a key that reads either bag.</summary>
    internal HostPropKey Key { get; }

    /// <summary>The number the value rides on.</summary>
    internal int Number { get; }

    /// <summary>Which way it crosses.</summary>
    internal HostStateMode Mode { get; }

    /// <summary>The property itself, or null for a kind that is not one.</summary>
    internal BindableProperty? Property { get; }

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
                ? new PlacementAttachment(view, entry)
                : null;
        }

        if (entry.Kind == HostStateKind.Feed)
        {
            return new FeedAttachment(view, entry);
        }

        // A SCROLLER'S OFFSET IS ONE POINT AND HAS NO SETTABLE PROPERTY: the
        // platform declares ScrollX and ScrollY read-only, so this attachment
        // carries no property at all and aims at the scroller itself, which the
        // walker moves as a two-lane target. See ScrollMovement.Walked.
        if (entry.Key.Prop == HostProp.ScrollOffset)
        {
            return view is ScrollView ? new PropertyAttachment(view, entry, null, MotionValue.Offset) : null;
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
            return new TextAttachment(view, entry, property);
        }

        // A PLAIN value is one lane set as it stands - a flag, a count, a
        // number that never travels - on whatever property it names.
        if (entry.Kind == HostStateKind.Plain)
        {
            return new PlainAttachment(view, entry, property);
        }

        if (Shape(property) is not MotionValue shape)
        {
            return null;
        }

        return new PropertyAttachment(view, entry, property, shape);
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
    internal abstract void Landed(byte[] bytes, Walker walker);

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
    internal virtual void Wear(byte[] bytes, ulong mask, Walker walker, Action<int, bool> land)
    {
        // A JOURNEY IS NOT WORN HERE: it rides the number's channel, once for
        // every control on the number - see StateChannel.Wear - and a feed is
        // the platform's to write.
    }
}
