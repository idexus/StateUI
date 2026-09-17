// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

/// <summary>
/// Raises the application's handlers in the order the reader and the platform
/// gave them - holding them while a message is being applied and raising each
/// once it is in, so no handler runs inside an apply and none is lost to one.
/// </summary>
/// <remarks>
/// <para>
/// A HANDLER RAISED INSIDE AN APPLY is Swift entered while this side is half way
/// through writing a tree Swift described: a render it asks for is computed
/// against a tree nobody finished, and what it writes lands under a message
/// still being taken. So a message holds the dispatch for as long as it is
/// being rendered - its retries included - and the handlers wait, in the order
/// they came, for its generation to be claimed.
/// </para>
/// <para>
/// What waits is the platform's and the reader's own word - a window the system
/// restored, a journey that landed, a scene's phase. A control's report of a
/// value the apply itself wrote is no word at all, and is refused before it
/// gets here: see <see cref="StateUIRenderer.Raise(object?, Protocol.HostEvent, byte[])"/>.
/// </para>
/// </remarks>
internal sealed class HandlerDispatch
{
    private readonly Action<int, byte[]?> _raise;
    private readonly Queue<(int Handler, byte[]? Payload)> _held = new();
    private int _holds;

    /// <summary>A dispatch that raises through <paramref name="raise"/>.</summary>
    /// <param name="raise">What reaches a handler: its id and its payload's wire bytes.</param>
    internal HandlerDispatch(Action<int, byte[]?> raise) => _raise = raise;

    /// <summary>Whether handlers are being held.</summary>
    internal bool Held => _holds > 0;

    /// <summary>Raises a handler, or holds it until what is being applied is in.</summary>
    /// <param name="handler">The handler's id - negative for a completion.</param>
    /// <param name="payload">The payload's wire bytes, or null for none.</param>
    internal void Raise(int handler, byte[]? payload)
    {
        if (_holds > 0)
        {
            _held.Enqueue((handler, payload));
            return;
        }

        _raise(handler, payload);
    }

    /// <summary>Holds every handler raised from now until the matching <see cref="Release"/>.</summary>
    internal void Hold() => _holds++;

    /// <summary>Lets go of one hold; the last raises what waited, in the order it came.</summary>
    internal void Release()
    {
        _holds--;

        // One at a time, and asked again after each: a handler raised here may
        // render, and a render holds and releases in its turn - which raises
        // the rest of the queue there, still in order.
        while (_holds == 0 && _held.TryDequeue(out (int Handler, byte[]? Payload) waiting))
        {
            _raise(waiting.Handler, waiting.Payload);
        }
    }
}
