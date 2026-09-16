// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// How this host realizes one element: which of the element's members its
/// control takes, and what each one does to it.
/// </summary>
/// <remarks>
/// <para>
/// The registration IS the realization record. What a member's setter is given
/// has already been read as the type the member declares, so a control is
/// written with a value rather than with a wire shape - and a member the
/// message does not carry is not offered at all, since a patch names only what
/// changed.
/// </para>
/// <para>
/// A member is named by its <see cref="HostProp"/> until the contracts are
/// generated as typed C# accessors, when the same call site reads
/// <c>r.Property(ProgressBarContract.Progress, …)</c> and the value's type
/// comes from the member instead of from the call.
/// </para>
/// </remarks>
internal abstract class Realization
{
    /// <summary>One member and what it writes onto the control.</summary>
    /// <param name="Member">The member, as this side names it.</param>
    /// <param name="Write">Writes the member's value onto the control.</param>
    internal sealed record Applier(HostProp Member, Action<View, HostPatch> Write);

    /// <summary>The members this realization writes, in the order registered.</summary>
    internal List<Applier> Appliers { get; } = [];

    /// <summary>What the control is subscribed to, once, where it is made.</summary>
    internal List<Action<View, StateUIRenderer>> Wiring { get; } = [];

    /// <summary>
    /// Subscribes the control to what it reports, once - where it is made,
    /// the rule every built-in follows.
    /// </summary>
    /// <param name="view">The control.</param>
    /// <param name="renderer">The renderer its reports go to.</param>
    internal void Wire(View view, StateUIRenderer renderer)
    {
        foreach (Action<View, StateUIRenderer> wire in Wiring)
        {
            wire(view, renderer);
        }
    }

    /// <summary>
    /// Writes every member the message carries onto the control.
    /// </summary>
    /// <remarks>
    /// A member absent from the patch is one this message says nothing about,
    /// and is left exactly as it stands - the rule the whole wire follows.
    /// </remarks>
    /// <param name="view">The control.</param>
    /// <param name="node">The message about it.</param>
    internal void Apply(View view, HostPatch node)
    {
        foreach (Applier applier in Appliers)
        {
            if (node.Props?.ContainsKey(applier.Member) == true)
            {
                applier.Write(view, node);
            }
        }
    }
}

/// <summary>
/// The realization of one element, typed to the control this host makes for it -
/// so every setter is written against the real class rather than against
/// <see cref="View"/>.
/// </summary>
/// <typeparam name="TControl">The control's own class.</typeparam>
internal sealed class Realization<TControl> : Realization
    where TControl : View
{
    /// <summary>
    /// Registers one of the element's properties: the member, and what its
    /// value does to the control.
    /// </summary>
    /// <remarks>
    /// The setter runs only when a message CARRIES the member, so it is handed
    /// a value rather than an absence - and a control keeps what it has where
    /// the tree says nothing, which is what a sparse patch means.
    /// </remarks>
    /// <typeparam name="TValue">
    /// The type the member's value crosses as - <see cref="double"/>,
    /// <see cref="bool"/>, <see cref="string"/> or <see cref="int"/> for a
    /// member of a closed vocabulary.
    /// </typeparam>
    /// <param name="member">The member this host realizes.</param>
    /// <param name="write">What the value does to the control.</param>
    /// <returns>The same realization, so members chain.</returns>
    internal Realization<TControl> Property<TValue>(HostProp member, Action<TControl, TValue> write)
    {
        Appliers.Add(new Applier(member, (view, node) =>
        {
            if (Read<TValue>(node, member) is TValue value)
            {
                write((TControl)view, value);
            }
        }));

        return this;
    }

    /// <summary>
    /// Registers what the READER changes: the member whose value they moved,
    /// the control's own property carrying it, and the event the tree hears.
    /// </summary>
    /// <remarks>
    /// <para>
    /// ONE call, because the two halves have ONE order and it is not the
    /// registration's to choose: the value goes onto the state that carries it
    /// FIRST, and only then does the event reach its handler - which is what
    /// every arm of this renderer that reports a reader's value does, from a
    /// picker's choice to a switch's flip. A registration that could write them
    /// the other way round would be a registration that could get it wrong.
    /// </para>
    /// <para>
    /// The subscription is made where the control is MADE, once, and lives as
    /// long as it does.
    /// </para>
    /// </remarks>
    /// <typeparam name="TReported">What the reader's value is, as the event carries it.</typeparam>
    /// <param name="property">The control's own property carrying the value.</param>
    /// <param name="raised">The event the tree hears.</param>
    /// <param name="subscribe">
    /// Subscribes to the control's own notification, and hands back what the
    /// reader made it.
    /// </param>
    /// <remarks>
    /// The MEMBER is not named again here: <see cref="Property{TValue}"/>
    /// already declares which member this control realizes, and a second
    /// spelling of it would be a second place to get it wrong.
    /// </remarks>
    internal Realization<TControl> Reports<TReported>(
        BindableProperty property,
        HostEvent raised,
        Action<TControl, Action<TReported>> subscribe)
    {
        Wiring.Add((view, renderer) =>
        {
            var control = (TControl)view;

            subscribe(control, reported =>
            {
                renderer.Reported(control, property, Lanes(reported));
                renderer.Raise(control, raised, Value(reported));
            });
        });

        return this;
    }

    /// <summary>A reported value as the lanes a state carries it in.</summary>
    private static double[] Lanes<TReported>(TReported reported) => reported switch
    {
        bool flag => [flag ? 1 : 0],
        double number => [number],
        int member => [member],
        _ => throw new NotSupportedException(
            $"a reader's value cannot be carried as {typeof(TReported).Name}: a state "
            + "carries flags, numbers and members of a closed vocabulary."),
    };

    /// <summary>The same value as the event's payload.</summary>
    private static HostValue Value<TReported>(TReported reported) => reported switch
    {
        bool flag => HostValue.Of(flag),
        double number => HostValue.Of(number),
        int member => HostValue.Of((double)member),
        _ => throw new NotSupportedException(
            $"an event cannot carry {typeof(TReported).Name}."),
    };

    /// <summary>
    /// A member's value in the type it is declared as, or null where the
    /// message carries another kind - which is a Swift side and a host that
    /// disagree about the member, never something to guess at.
    /// </summary>
    private static TValue? Read<TValue>(HostPatch node, HostProp member)
    {
        object? value = default(TValue) switch
        {
            double => node.GetNumber(member),
            bool => node.GetBool(member),
            int => node.GetEnumeration(member),
            _ when typeof(TValue) == typeof(string) => node.GetString(member),
            _ => throw new NotSupportedException(
                $"a member cannot be realized as {typeof(TValue).Name}: the kinds a "
                + "property crosses as are number, flag, text and a member of a closed "
                + "vocabulary."),
        };

        return value is TValue read ? read : default;
    }
}
