// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Runtime.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Runtime.Protocol;

/// <summary>
/// The properties a message says to WALK to rather than assign.
/// </summary>
/// <remarks>
/// <para>
/// A transition arrives as an ordinary property change with a
/// <see cref="SwiftTransition"/> beside it. This takes those properties out of
/// the node before the renderer applies it - so the assignment that would have
/// snapped never happens - and aims the engine at the value that arrived, from
/// wherever the control is now.
/// </para>
/// <para>
/// NOBODY IS WAITING. A transition is a law and nothing else: a value that
/// changed is a setpoint, the tree already says where it is going, and a render
/// in the middle of the walk says the same thing again. So there is no
/// bookkeeping here at all - what a message names, the engine is aimed at, and
/// the walk is the engine's business from that moment. A value somebody DOES
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
/// What actually MOVES is <see cref="MotionEngine"/>; this is the wire's face
/// on it - which properties a message says to walk, and under which law.
/// </para>
/// </remarks>
internal sealed class SwiftTransitions
{
    /// <summary>What actually moves the values.</summary>
    private readonly MotionEngine _engine;

    /// <summary>Reads a message's transitions onto an engine.</summary>
    /// <param name="engine">What moves the values.</param>
    internal SwiftTransitions(MotionEngine engine)
    {
        _engine = engine;
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
    internal List<(SwiftTransition Transition, SwiftWireValue Target)> Take(SwiftNode node)
    {
        if (node.Transitions is not { Count: > 0 } transitions || node.Props is null)
        {
            return [];
        }

        var taken = new List<(SwiftTransition, SwiftWireValue)>(transitions.Count);

        foreach (SwiftTransition transition in transitions)
        {
            // Out of the bag the property arrived in - the library's by
            // member, an application's own by the name it declared it under.
            SwiftWireValue target = default;

            bool named = transition.Property != SwiftProp.None
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

            if (transition.Property != SwiftProp.None)
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
    /// Whether this property is one the engine can carry a control through -
    /// it has a MAUI property behind it, and its value has a half-way.
    /// </summary>
    private static bool Walkable(SwiftNode node, SwiftTransition transition, SwiftWireValue target)
    {
        SwiftKey key = transition.Key;

        if (SwiftStyles.Property(node.Type, node.TypeName, key) is not BindableProperty property)
        {
            return false;
        }

        SwiftNode carrier = Carrier(transition, target);

        return SwiftStyles.Value(property, carrier, key) is object value
            && MotionProperty.Of(
                new Label(), property, value, false, out IMotionTarget _, out double[] _);
    }

    /// <summary>
    /// Ends the walks this message overwrote, and starts the ones it asked for.
    /// </summary>
    /// <param name="view">The control the node was applied to.</param>
    /// <param name="node">The node, with the walked properties already lifted.</param>
    /// <param name="taken">What <see cref="Take"/> answered.</param>
    internal void Apply(
        View view,
        SwiftNode node,
        List<(SwiftTransition Transition, SwiftWireValue Target)> taken)
    {
        Interrupt(view, node, taken);

        foreach ((SwiftTransition transition, SwiftWireValue target) in taken)
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
        SwiftNode node,
        List<(SwiftTransition Transition, SwiftWireValue Target)> taken)
    {
        if (!_engine.Stirring(view))
        {
            return;
        }

        if (node.Props is not null)
        {
            foreach (SwiftProp property in node.Props.Keys)
            {
                if (Walked(taken, property, null))
                {
                    continue;
                }

                if (SwiftStyles.Property(node.Type, node.TypeName, SwiftKey.Of(property, string.Empty))
                    is BindableProperty bindable
                    && _engine.Driven?.Invoke(view, bindable) != true)
                {
                    _engine.Halt(view, bindable, MotionEnd.Nothing);
                }
            }
        }

        if (node.OwnProps is null)
        {
            return;
        }

        foreach (string spelling in node.OwnProps.Keys)
        {
            if (Walked(taken, SwiftProp.None, spelling))
            {
                continue;
            }

            if (SwiftStyles.Property(node.Type, node.TypeName, SwiftKey.Of(SwiftProp.None, spelling))
                is BindableProperty bindable
                && _engine.Driven?.Invoke(view, bindable) != true)
            {
                _engine.Halt(view, bindable, MotionEnd.Nothing);
            }
        }
    }

    /// <summary>Whether this message says to WALK to the named property.</summary>
    private static bool Walked(
        List<(SwiftTransition Transition, SwiftWireValue Target)> taken,
        SwiftProp property,
        string? spelling)
    {
        foreach ((SwiftTransition transition, SwiftWireValue _) in taken)
        {
            if (spelling is null
                ? transition.Property == property
                : transition.Property == SwiftProp.None && transition.PropertyName == spelling)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>Aims the engine at one property's target, under the stated law.</summary>
    private void Start(
        View view,
        SwiftNodeType type,
        string typeName,
        SwiftTransition transition,
        SwiftWireValue target)
    {
        SwiftKey key = transition.Key;

        if (SwiftStyles.Property(type, typeName, key) is not BindableProperty property)
        {
            return;
        }

        SwiftNode carrier = Carrier(transition, target);

        if (SwiftStyles.Value(property, carrier, key) is not object destination)
        {
            return;
        }

        if (!MotionProperty.Of(
            view, property, destination, Fraction(property),
            out IMotionTarget moves, out double[] to))
        {
            // Not walkable - a string, an enum, a picture. Assign it: the
            // value is what the tree said, and only the travelling was refused.
            view.SetValue(property, destination);
            return;
        }

        _engine.Aim(moves, to, transition.Spec);
    }

    /// <summary>
    /// The shape <c>SwiftValues</c> reads a property off: a node with the one
    /// key on it, in the bag that key belongs to.
    /// </summary>
    /// <remarks>
    /// The same conversion a style setter takes, which is what makes a property
    /// walkable the moment it is styleable.
    /// </remarks>
    private static SwiftNode Carrier(SwiftTransition transition, SwiftWireValue target)
    {
        var carrier = new SwiftNode();

        if (transition.Property != SwiftProp.None)
        {
            carrier.Props = new Dictionary<SwiftProp, SwiftWireValue>
            {
                [transition.Property] = target,
            };
        }
        else
        {
            carrier.OwnProps = new Dictionary<string, SwiftWireValue>
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

    /// <summary>
    /// The MAUI easing behind the member Swift sent.
    /// </summary>
    /// <remarks>
    /// A translation by name rather than a cast, for the reason every closed
    /// vocabulary is translated - the wire's numbers are ours, see
    /// <c>Protocol/SwiftWireEnums.cs</c> - and one more besides: MAUI's
    /// <see cref="Easing"/> is a class of STATIC INSTANCES, so there is no enum
    /// on that side to cast to at all. A number this does not know is linear,
    /// which is the same answer MAUI gives for a null easing.
    /// </remarks>
    /// <param name="member">The curve's number, as <see cref="SwiftEasing"/>.</param>
    /// <returns>The easing to walk on.</returns>
    public static Easing Read(int member)
    {
        return (SwiftEasing)member switch
        {
            SwiftEasing.SinOut => Easing.SinOut,
            SwiftEasing.SinIn => Easing.SinIn,
            SwiftEasing.SinInOut => Easing.SinInOut,
            SwiftEasing.CubicIn => Easing.CubicIn,
            SwiftEasing.CubicOut => Easing.CubicOut,
            SwiftEasing.CubicInOut => Easing.CubicInOut,
            SwiftEasing.BounceOut => Easing.BounceOut,
            SwiftEasing.BounceIn => Easing.BounceIn,
            SwiftEasing.SpringIn => Easing.SpringIn,
            SwiftEasing.SpringOut => Easing.SpringOut,
            _ => Easing.Linear,
        };
    }
}
