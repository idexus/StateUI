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
