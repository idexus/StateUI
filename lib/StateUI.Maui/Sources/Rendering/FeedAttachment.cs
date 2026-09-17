// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// The platform's own answer about a control - the room it is given - put on
/// its state as it changes. Nothing is ever written onto the control from it.
/// </summary>
internal sealed class FeedAttachment : StateAttachment
{
    /// <summary>A feed from one control.</summary>
    /// <param name="view">The control, held weakly.</param>
    /// <param name="entry">What the message said.</param>
    internal FeedAttachment(BindableObject view, HostStateBinding entry)
        : base(view, entry, null)
    {
    }

    /// <summary>What a feed unsubscribes when the control is described away.</summary>
    internal Action? Released { get; set; }

    /// <summary>The room this feed last put on the state.</summary>
    /// <remarks>
    /// A pass reports each part of a frame separately, so the same room
    /// arrives four times; only a room that actually moved is worth a cycle.
    /// </remarks>
    internal Rect Fed { get; set; } = new(0, 0, -1, -1);

    /// <inheritdoc/>
    /// <remarks>A feed is the platform's word: registering one lands nothing.</remarks>
    internal override void Landed(byte[] bytes, Walker walker)
    {
    }
}
