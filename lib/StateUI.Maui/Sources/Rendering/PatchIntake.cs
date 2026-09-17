// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using StateUI.Maui.Protocol;

/// <summary>
/// Takes the core's messages into the tree this side holds, one whole message
/// at a time.
/// </summary>
/// <remarks>
/// <para>
/// A patch means something only against the exact tree it was computed from.
/// The intake quotes the generation of the last message applied in full,
/// applies the next, and claims that message's generation only once it went in
/// whole - which is what makes the core send the whole tree again whenever this
/// side cannot be sure of what it is showing. Zero is never a generation the
/// core issues, so it always means "start over"; and a quote drops the
/// generation as it is read, so anything going wrong in between leaves this
/// side asking for the whole tree.
/// </para>
/// <para>
/// A MESSAGE TAKEN UNDER ANOTHER - a platform raising a report synchronously
/// inside an apply, a handler that hears it asking for a render - is computed
/// against a tree the outer apply has not finished writing, so once both are
/// in, what is on screen is not reliably either message: the outer claims
/// nothing, and whatever the inner one claimed, the next render is the whole
/// tree. That is cheap, because a resync keeps every identity, handler and
/// <c>@State</c>.
/// </para>
/// </remarks>
internal sealed class PatchIntake
{
    private int _generation;
    private int _depth;
    private bool _interrupted;

    /// <summary>Whether a message is being applied.</summary>
    internal bool IsApplying => _depth > 0;

    /// <summary>
    /// Whether a message has gone in whole - a tree is mounted, whatever the
    /// core is asked for next.
    /// </summary>
    internal bool Mounted { get; private set; }

    /// <summary>
    /// The generation to render against - the last message applied in full, or
    /// nought for the whole tree - dropped as it is quoted.
    /// </summary>
    /// <returns>The baseline the core's next message is computed against.</returns>
    internal int Quote()
    {
        int baseline = _generation;
        _generation = 0;
        return baseline;
    }

    /// <summary>Forgets the tree: the next render is the whole of it.</summary>
    internal void Forget() => _generation = 0;

    /// <summary>Applies one message, and says whether it went in whole.</summary>
    /// <param name="message">The message, its root already checked.</param>
    /// <param name="apply">What writes it into the tree, false where it drifted.</param>
    /// <returns>Whether the message went in whole.</returns>
    internal bool Take(HostRender message, Func<HostPatch, bool, bool> apply)
    {
        if (_depth > 0)
        {
            _interrupted = true;
        }

        _depth++;
        bool whole;
        bool interrupted = false;

        try
        {
            whole = apply(message.Root!, message.Complete);
        }
        finally
        {
            _depth--;

            if (_depth == 0)
            {
                interrupted = _interrupted;
                _interrupted = false;
            }
        }

        if (!whole)
        {
            return false;
        }

        Mounted = true;
        _generation = interrupted ? 0 : message.Generation;

        return true;
    }
}
