// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// The properties a message says to WALK to rather than assign.
/// </summary>
/// <remarks>
/// <para>
/// A transition arrives as an ordinary property change with a
/// <see cref="HostTransition"/> beside it. This takes those properties out of
/// the node before the renderer applies it - so the assignment that would have
/// snapped never happens - and aims the walker at the value that arrived, from
/// wherever the control is now.
/// </para>
/// <para>
/// NOBODY IS WAITING. A transition is a law and nothing else: a value that
/// changed is a setpoint, the tree already says where it is going, and a render
/// in the middle of the walk says the same thing again. So there is no
/// bookkeeping here at all - what a message names, the walker is aimed at, and
/// the walk is the walker's business from that moment. A value somebody DOES
/// await is a driven one, walked off its own image by <see cref="StateCycle"/>.
/// </para>
/// <para>
/// A property that arrives with NO transition while a walk is under way on it
/// is a plain assignment, and it ENDS the walk: the author wrote the value
/// rather than letting it travel, and a motion left running would go on writing
/// over what they wrote. That is the one place this class acts on a property
/// nobody said anything about.
/// </para>
/// <para>
/// What actually MOVES is <see cref="Walker"/>; this is the wire's face
/// on it - which properties a message says to walk, and under which law.
/// </para>
/// </remarks>
internal sealed class DescribedMotion
{
    /// <summary>What actually moves the values.</summary>
    private readonly Walker _walker;

    /// <summary>Reads a message's transitions onto a walker.</summary>
    /// <param name="walker">What moves the values.</param>
    internal DescribedMotion(Walker walker)
    {
        _walker = walker;
    }

    /// <summary>
    /// The properties this node says to walk, lifted OUT of it so the
    /// renderer's ordinary apply cannot assign them.
    /// </summary>
    /// <remarks>
    /// Called before the node is applied and answered after the control is in
    /// hand - which is the only order available, since a walk needs the control
    /// it is about and the control may not exist until the node is applied.
    /// </remarks>
    /// <param name="node">The node about to be applied.</param>
    /// <returns>What was lifted, empty when nothing was.</returns>
    internal List<(HostTransition Transition, HostValue Target)> Take(HostPatch node)
    {
        if (node.Transitions is not { Count: > 0 } transitions || node.Props is null)
        {
            return [];
        }

        var taken = new List<(HostTransition, HostValue)>(transitions.Count);

        foreach (HostTransition transition in transitions)
        {
            // Out of the bag the property arrived in - the library's by
            // member, an application's own by the name it declared it under.
            HostValue target = default;

            bool named = transition.Property != HostProp.None
                ? node.Props.TryGetValue(transition.Property, out target)
                : node.OwnProps is not null
                    && node.OwnProps.TryGetValue(transition.PropertyName, out target);

            // A transition names a property the patch is also sending. One
            // without is a message that contradicts itself, and the property
            // simply does not travel - there is nothing else it could cost.
            if (!named)
            {
                continue;
            }

            // NOTHING IS LIFTED THAT CANNOT BE WALKED. A property with no
            // MAUI property behind it, or one whose value has no half-way,
            // is left exactly where it is and applied the ordinary way - so
            // the worst a motion nobody can make costs is that it does not
            // happen, never that the value goes missing.
            if (!Walkable(node, transition, target))
            {
                continue;
            }

            if (transition.Property != HostProp.None)
            {
                node.Props.Remove(transition.Property);
            }
            else
            {
                node.OwnProps!.Remove(transition.PropertyName);
            }

            taken.Add((transition, target));
        }

        return taken;
    }

    /// <summary>
    /// Whether this property is one the walker can carry a control through -
    /// it has a MAUI property behind it, and its value has a half-way.
    /// </summary>
    private static bool Walkable(HostPatch node, HostTransition transition, HostValue target)
    {
        HostPropKey key = transition.Key;

        if (PropertyTable.Property(node.Type, node.TypeName, key) is not BindableProperty property)
        {
            return false;
        }

        HostPatch carrier = Carrier(transition, target);

        return PropertyTable.Value(property, carrier, key) is object value
            && MotionProperty.Of(
                new Label(), property, value, false, out ITripTarget _, out double[] _);
    }

    /// <summary>
    /// Ends the walks this message overwrote, and starts the ones it asked for.
    /// </summary>
    /// <param name="view">The control the node was applied to.</param>
    /// <param name="node">The node, with the walked properties already lifted.</param>
    /// <param name="taken">What <see cref="Take"/> answered.</param>
    internal void Apply(
        View view,
        HostPatch node,
        List<(HostTransition Transition, HostValue Target)> taken)
    {
        Interrupt(view, node, taken);

        foreach ((HostTransition transition, HostValue target) in taken)
        {
            Start(view, node.Type, node.TypeName, transition, target);
        }
    }

    /// <summary>
    /// Ends a motion the message assigned over. An author who writes a value
    /// rather than letting it travel means the motion to stop, and one left
    /// running would overwrite what they wrote a frame later.
    /// </summary>
    /// <remarks>
    /// <para>
    /// Every property the node ASSIGNS - one arriving with no transition beside
    /// it - and nothing else. Nothing is written back: the assignment has
    /// already happened.
    /// </para>
    /// <para>
    /// A property a DRIVEN STATE drives is left alone: the value the message
    /// states for one of those is what the tree last heard from the state, and
    /// halting the motion the state started would stop the very journey the
    /// message is describing.
    /// </para>
    /// </remarks>
    private void Interrupt(
        View view,
        HostPatch node,
        List<(HostTransition Transition, HostValue Target)> taken)
    {
        if (!_walker.Stirring(view))
        {
            return;
        }

        if (node.Props is not null)
        {
            foreach (HostProp property in node.Props.Keys)
            {
                if (Walked(taken, property, null))
                {
                    continue;
                }

                if (PropertyTable.Property(node.Type, node.TypeName, HostPropKey.Of(property, string.Empty))
                    is BindableProperty bindable
                    && _walker.Driven?.Invoke(view, bindable) != true)
                {
                    _walker.Halt(view, bindable, TripEnd.Nothing);
                }
            }
        }

        if (node.OwnProps is null)
        {
            return;
        }

        foreach (string spelling in node.OwnProps.Keys)
        {
            if (Walked(taken, HostProp.None, spelling))
            {
                continue;
            }

            if (PropertyTable.Property(node.Type, node.TypeName, HostPropKey.Of(HostProp.None, spelling))
                is BindableProperty bindable
                && _walker.Driven?.Invoke(view, bindable) != true)
            {
                _walker.Halt(view, bindable, TripEnd.Nothing);
            }
        }
    }

    /// <summary>Whether this message says to WALK to the named property.</summary>
    private static bool Walked(
        List<(HostTransition Transition, HostValue Target)> taken,
        HostProp property,
        string? spelling)
    {
        foreach ((HostTransition transition, HostValue _) in taken)
        {
            if (spelling is null
                ? transition.Property == property
                : transition.Property == HostProp.None && transition.PropertyName == spelling)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>Aims the walker at one property's target, under the stated law.</summary>
    private void Start(
        View view,
        HostNodeType type,
        string typeName,
        HostTransition transition,
        HostValue target)
    {
        HostPropKey key = transition.Key;

        if (PropertyTable.Property(type, typeName, key) is not BindableProperty property)
        {
            return;
        }

        HostPatch carrier = Carrier(transition, target);

        if (PropertyTable.Value(property, carrier, key) is not object destination)
        {
            return;
        }

        // A SIZE WORKED OUT FROM A MEASUREMENT DOES NOT TRAVEL, and this is
        // the walker's half of the rule the arranger already keeps for the
        // same reason: where a layout is being measured, none of its children
        // is carried through a size, because what the measurement reports is
        // what the views in it leave it. A size the tree describes is carried
        // by the WALKER rather than by the arrangement, and without this it
        // would go on travelling: a page built from a `FrameReader`'s frame
        // crawls to every new room over a fifth of a second, re-measuring the
        // whole layout at every frame, and everything standing under it rides
        // each step. Measured on the gallery's held sample pages, where the caption
        // under a list flew onto the window's edge on every scroll.
        if (Measured(view) && (property == VisualElement.HeightRequestProperty
            || property == VisualElement.WidthRequestProperty))
        {
            view.SetValue(property, destination);
            return;
        }

        if (!MotionProperty.Of(
            view, property, destination, Fraction(property),
            out ITripTarget moves, out double[] to))
        {
            // Not walkable - a string, an enum, a picture. Assign it: the
            // value is what the tree said, and only the travelling was refused.
            view.SetValue(property, destination);
            return;
        }

        _walker.Aim(moves, to, transition.Motion);
    }

    /// <summary>Whether this view's size is one somebody is measuring.</summary>
    /// <remarks>
    /// Its own frame watched, or the frame of the layout that arranges it: in
    /// the first the size decides what the view itself reports, and in the
    /// second what it leaves its neighbours. Asked no higher, because a page
    /// that watches its own room and sizes a child from it is the whole of
    /// what this is for.
    /// </remarks>
    /// <param name="view">The view a size is being aimed at.</param>
    /// <returns>Whether the size should arrive rather than travel.</returns>
    private static bool Measured(View view) =>
        StateUIRenderer.Watched(view)
            || (view.Parent is VisualElement holder && StateUIRenderer.Watched(holder));

    /// <summary>
    /// The shape <c>Values</c> reads a property off: a node with the one
    /// key on it, in the bag that key belongs to.
    /// </summary>
    /// <remarks>
    /// The same conversion a style setter takes, which is what makes a property
    /// walkable the moment it is styleable.
    /// </remarks>
    private static HostPatch Carrier(HostTransition transition, HostValue target)
    {
        var carrier = new HostPatch();

        if (transition.Property != HostProp.None)
        {
            carrier.Props = new Dictionary<HostProp, HostValue>
            {
                [transition.Property] = target,
            };
        }
        else
        {
            carrier.OwnProps = new Dictionary<string, HostValue>
            {
                [transition.PropertyName] = target,
            };
        }

        return carrier;
    }

    /// <summary>
    /// Whether a number is a fraction of one, so a curve that overshoots is
    /// held back from asking a platform for something it cannot draw.
    /// </summary>
    private static bool Fraction(BindableProperty property) =>
        property == VisualElement.OpacityProperty;
}
