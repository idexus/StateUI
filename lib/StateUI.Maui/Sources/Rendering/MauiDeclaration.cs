// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Maui.Protocol;

namespace StateUI.Maui.Rendering;

/// <summary>
/// What this host declares it realizes, read off the registrations themselves:
/// the elements it makes a view for and, on each, the members its control
/// takes and the events it raises.
/// </summary>
/// <remarks>
/// <para>
/// THE REGISTRATIONS ARE THE DECLARATION. Nothing here is written by hand, so
/// nothing here can disagree with the code - which is the whole point of
/// reading a runtime rather than holding a list beside it.
/// </para>
/// <para>
/// What it says is PRESENCE: which member this host realizes on which element.
/// It never says who DECLARES that member, because whether <c>borderColor</c>
/// belongs to a button or to a tier the button wears is a fact of the
/// contract, and the contracts live on the Swift side. The join happens there,
/// against <c>Contract.worn</c>.
/// </para>
/// <para>
/// WHAT IS NOT HERE, said rather than left to be discovered: the shared tier.
/// The renderer subscribes to taps, pointer, drag and swipe AROUND every view
/// instead of inside a registration, and applies margins, opacity and sizing
/// the same way, so those members belong to no registration and are declared
/// where they are realized.
/// </para>
/// </remarks>
internal static class MauiDeclaration
{
    /// <summary>
    /// Each element this host realizes, with its members and its events, named
    /// as the wire and the contracts name them.
    /// </summary>
    internal static IEnumerable<(string Element, IEnumerable<string> Members, IEnumerable<string> Events)>
        Elements =>
        StateUIControls.Realizations()
            .Select(registration => (
                registration.Type,
                registration.Realized.Members.Select(TokenNames<HostProp>.Spelling),
                registration.Realized.Raised.Select(TokenNames<HostEvent>.Spelling)));

    /// <summary>The declaration as the wire writes it.</summary>
    internal static byte[] Bytes() => WireCodec.WriteDeclaration(Elements);

    /// <summary>
    /// The readable half, which a review diff reads instead of the bytes: one
    /// line per element, its members and then its events under it, an event
    /// told from a property by the parentheses every handler is called with.
    /// </summary>
    internal static string Sidecar()
    {
        List<string> lines = [];

        foreach ((string element, IEnumerable<string> members, IEnumerable<string> events) in
            Elements.OrderBy(element => element.Element, StringComparer.Ordinal))
        {
            lines.Add(element);
            lines.AddRange(members.Distinct().Order(StringComparer.Ordinal)
                .Select(member => $"  {member}"));
            lines.AddRange(events.Distinct().Order(StringComparer.Ordinal)
                .Select(raised => $"  {raised}()"));
        }

        return string.Join("\n", lines) + "\n";
    }
}
