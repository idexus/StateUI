// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Globalization;
using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// What the platform keeps for one window's scene session: which session it
/// is, and what this library wrote down for the system to hand back.
/// </summary>
/// <remarks>
/// A scene's MAIN window's session keeps the scene's <c>@State(sceneKey:)</c>
/// values; any other window's keeps which scene it belongs to - by that
/// scene's session - its group's kind, and its value as the tree wrote it.
/// Read as a session connects and written whenever one of those changes. See
/// <see cref="SceneSessions"/>.
/// </remarks>
/// <param name="Session">The platform's own identity for the session, where it has one.</param>
/// <param name="Owner">For a window that is not a scene's main one: the session of the scene it belongs to.</param>
/// <param name="Kind">Its group's kind.</param>
/// <param name="Value">Its value as the tree wrote it, for a group that opens one window per value.</param>
/// <param name="Kept">A main window's scene's kept values, in name order.</param>
internal sealed record SceneOrigin(
    string? Session,
    string? Owner,
    string? Kind,
    string? Value,
    IReadOnlyList<(string Name, SwiftWireValue Value)> Kept)
{
    /// <summary>A kept value as the text the platform keeps it as.</summary>
    /// <remarks>
    /// One letter for the kind, then the value - <c>b1</c>, <c>n0.25</c>,
    /// <c>steal</c> - because what comes back has to be the same KIND of value
    /// it went as: a whole number the scene keeps must not come back as text,
    /// and a store that takes only property-list values cannot say which of
    /// its numbers were true.
    /// </remarks>
    /// <param name="value">A value as it came off the wire.</param>
    /// <returns>Its text; null for a kind a scene key does not hold.</returns>
    internal static string? Write(SwiftWireValue value) => value.Tag switch
    {
        SwiftWireValue.TagTrue => "b1",
        SwiftWireValue.TagFalse => "b0",
        SwiftWireValue.TagNumber => "n" + value.Number.ToString("R", CultureInfo.InvariantCulture),
        SwiftWireValue.TagString => "s" + value.Text,
        _ => null,
    };

    /// <summary>A kept value back from its text - see <see cref="Write"/>.</summary>
    /// <param name="text">What the platform kept.</param>
    /// <returns>The value; null for text this library did not write.</returns>
    internal static SwiftWireValue? Read(string text)
    {
        if (text.Length == 0)
        {
            return null;
        }

        string rest = text[1..];

        return text[0] switch
        {
            'b' when rest == "1" => SwiftWireValue.Of(true),
            'b' when rest == "0" => SwiftWireValue.Of(false),
            'n' when double.TryParse(rest, NumberStyles.Float, CultureInfo.InvariantCulture, out double number) =>
                SwiftWireValue.Of(number),
            's' => SwiftWireValue.Of(rest),
            _ => null,
        };
    }
}
