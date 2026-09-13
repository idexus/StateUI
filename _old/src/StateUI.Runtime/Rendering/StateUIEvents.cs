// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using StateUI.Runtime.Protocol;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Events the application raises by NAME, with no control behind them - the
/// push half of the interop surface, sister to the acts registered with
/// <see cref="StateUIActs"/>. Every other event belongs to an element of
/// the tree; what the host pushes on its own - connectivity changing, the
/// battery reporting - has none, so the C# side raises it here and the Swift
/// side subscribes by the same name with <c>HostEvents.on</c>.
/// </summary>
/// <remarks>
/// <para>
/// Wire the sources once, at startup, in <c>MauiProgram.CreateMauiApp</c>:
/// </para>
/// <code>
/// Battery.Default.BatteryInfoChanged += (_, e) =>
///     StateUIEvents.Raise("Gallery.BatteryChanged",
///         SwiftWireValue.Of(e.ChargeLevel));
///
/// // Swift, wherever the value is shown:
/// extension Event { static let batteryChanged = Event("Gallery.BatteryChanged") }
///
/// let heard = HostEvents.on(.batteryChanged) { payload in
///     level = payload.value()?.number ?? level
/// }
/// </code>
/// <para>
/// <see cref="Raise"/> is safe from any thread - the session marshals to the
/// thread MAUI draws on before anything enters Swift - and a raise nobody
/// subscribed to, or one made before the first interface exists, is dropped:
/// a subscription is written by a Swift handler, and a handler needs a
/// rendered tree, so there was nobody it could have reached. Prefix event
/// names with the application's own (<c>"Gallery."</c>) so they can never
/// meet an event this library adds later.
/// </para>
/// </remarks>
public static class StateUIEvents
{
    /// <summary>The session that carries a raise into Swift - the process's
    /// one live session, adopted as it takes the runtime, which is the
    /// interface that is showing.</summary>
    internal static StateUISession? Session { get; set; }

    /// <summary>
    /// Raises a named event to the Swift side, with one typed value per
    /// interesting fact - what a subscriber reads with
    /// <c>payload.value(…)</c>. Empty for an event with nothing to say.
    /// </summary>
    /// <param name="eventName">The name the Swift side subscribed to, e.g.
    /// <c>"Gallery.BatteryChanged"</c>.</param>
    /// <param name="payload">The raise's typed values, in a fixed order the
    /// two sides agree on.</param>
    public static void Raise(string eventName, params SwiftWireValue[] payload)
    {
        Session?.RaiseHostEvent(eventName, payload);
    }
}
