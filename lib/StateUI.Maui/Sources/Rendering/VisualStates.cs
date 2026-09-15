// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// The states a control describes, as the groups the VisualStateManager
/// wants - each setter's property and value resolved through
/// <see cref="PropertyTable"/>, which a walked property's target is
/// resolved through too.
/// </summary>
internal static class VisualStates
{
    /// <summary>
    /// The states a control describes, grouped as the VisualStateManager wants
    /// them.
    /// </summary>
    /// <remarks>
    /// Called from <c>StateUIRenderer.ApplyVisualStates</c>, which is the one
    /// caller: whether the states were written on the control or came from its
    /// style, the Swift side has already merged them into one arranged list.
    /// </remarks>
    internal static VisualStateGroupList BuildStates(
        HostNodeType targetType,
        string typeName,
        List<HostPatch> states,
        Dictionary<string, List<(HostPropKey Key, BindableProperty Property, object Value)>>? travelling = null)
    {
        var groups = new VisualStateGroupList();

        foreach (HostPatch node in states)
        {
            // A visual state's group and its name are NAMES: they ride the
            // session dictionary, so they read back through GetName. Read as
            // strings they would both answer null, and every state would land
            // in CommonStates under the empty name - which is to say every
            // state would be the same state.
            string name = node.GetName(HostProp.Group) ?? "CommonStates";
            VisualStateGroup? group = groups.FirstOrDefault(candidate => candidate.Name == name);

            if (group is null)
            {
                group = new VisualStateGroup { Name = name };
                groups.Add(group);
            }

            var state = new VisualState { Name = node.GetName(HostProp.Name) ?? "" };

            foreach (HostPatch child in node.Children ?? [])
            {
                if (child.Type == HostNodeType.Setters)
                {
                    List<(HostPropKey Key, BindableProperty Property, object Value)>? moves = null;

                    if (travelling is not null)
                    {
                        moves = [];
                        travelling[state.Name] = moves;
                    }

                    AddSetters(state.Setters, targetType, typeName, child, moves);
                }
            }

            group.States.Add(state);
        }

        return groups;
    }

    /// <summary>
    /// One setter per property the node carries that the target type has.
    /// </summary>
    /// <remarks>
    /// <para>
    /// In a fixed order, because a Setter list is applied in order and a few
    /// properties care: a Slider clamps its Value into the range as it is set,
    /// so the range has to arrive first. Sorting by name almost says that -
    /// Maximum and Minimum sort before Value - but not for a DatePicker, where
    /// "date" sorts before "maximumDate", so a date set in a state would be
    /// clamped against the DEFAULT range before its own bounds ran. The bounds
    /// are therefore ordered out in front explicitly, and the rest stays sorted
    /// by name.
    /// </para>
    /// <para>
    /// The order is by NAME, so a member's spelling is what it is read from -
    /// derived once per member by <see cref="TokenNames{TToken}"/> rather
    /// than per setter. Both bags go in: a registered control's own properties
    /// are as settable in a state as a Label's, and they sort among them.
    /// </para>
    /// </remarks>
    private static void AddSetters(
        IList<Setter> setters,
        HostNodeType targetType,
        string typeName,
        HostPatch node,
        IList<(HostPropKey Key, BindableProperty Property, object Value)>? travelling = null)
    {
        List<(HostPropKey Key, string Name)> keys = [];

        foreach (HostProp prop in node.Props?.Keys ?? Enumerable.Empty<HostProp>())
        {
            string spelling = TokenNames<HostProp>.Spelling(prop);
            keys.Add((HostPropKey.Of(prop, spelling), spelling));
        }

        foreach (string name in node.OwnProps?.Keys ?? Enumerable.Empty<string>())
        {
            keys.Add((HostPropKey.Own(name), name));
        }

        foreach ((HostPropKey key, string _) in keys
            .OrderBy(entry => entry.Name.StartsWith("min", StringComparison.Ordinal)
                || entry.Name.StartsWith("max", StringComparison.Ordinal) ? 0 : 1)
            .ThenBy(entry => entry.Name, StringComparer.Ordinal))
        {
            if (PropertyTable.Property(targetType, typeName, key) is not BindableProperty property)
            {
                continue;
            }

            if (PropertyTable.Value(property, node, key) is not object value)
            {
                continue;
            }

            // A VALUE WITH A HALF-WAY IS NOT A SETTER. MAUI applies a setter by
            // assigning, which is the one thing in this library that cannot be
            // animated from the outside - so a colour, an opacity, a size or a
            // set of edges is taken OUT of the state and carried by the walker
            // instead, at whatever the control's own motion says. A control
            // whose motion is none gets exactly what a setter gave it.
            //
            // A PLACEMENT stays a setter: where a child sits belongs to its
            // layout, and two things carrying it would fight.
            if (travelling is not null
                && MotionProperty.ShapeOf(value) is MotionValue shape
                && shape != MotionValue.Bounds)
            {
                travelling.Add((key, property, value));
                continue;
            }

            setters.Add(new Setter { Property = property, Value = value });
        }
    }
}
