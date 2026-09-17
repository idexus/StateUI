// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

using Microsoft.Maui.Controls;
using StateUI.Maui.Protocol;

/// <summary>
/// Words on one control - a caption out, a field both ways - which nothing
/// walks: text is dirty or it is not.
/// </summary>
internal sealed class TextAttachment : StateAttachment
{
    /// <summary>What the last text written onto the control was.</summary>
    /// <remarks>
    /// So a text state that was dirtied without its words changing writes
    /// nothing at all: a label re-measures whenever its text is set, whether
    /// or not the letters differ.
    /// </remarks>
    private string? _wrote;

    /// <summary>Words on one control's text property.</summary>
    /// <param name="view">The control, held weakly.</param>
    /// <param name="entry">What the message said.</param>
    /// <param name="property">Its text property.</param>
    internal TextAttachment(BindableObject view, HostStateBinding entry, BindableProperty property)
        : base(view, entry, property)
    {
    }

    /// <summary>
    /// Remembers the words the READER typed, so the state's echo of them on
    /// the next cycle is not set back onto the field under the caret.
    /// </summary>
    /// <param name="words">What was typed.</param>
    internal void Remember(string words) => _wrote = words;

    /// <summary>
    /// Writes words onto the control where they differ from the last ones
    /// written - what a text state's cycle does, and what a typed report does
    /// to every OTHER field the same state drives.
    /// </summary>
    /// <remarks>
    /// Under <see cref="Walker.Writing"/>, for the reason
    /// <see cref="PlainAttachment.Set(double[])"/> gives: the field's own changed notification
    /// is this side's write coming round.
    /// </remarks>
    /// <param name="words">The text.</param>
    internal void Wear(string words)
    {
        if (words == _wrote || Property is null)
        {
            return;
        }

        _wrote = words;

        Walker.Writing++;

        try
        {
            View?.SetValue(Property, words);
        }
        finally
        {
            Walker.Writing--;
        }
    }

    /// <inheritdoc/>
    internal override void Landed(byte[] bytes, Walker walker) => Wear(StateBatch.Text(bytes));

    /// <inheritdoc/>
    internal override void Wear(byte[] bytes, ulong mask, Walker walker, Action<int, bool> land) =>
        Wear(StateBatch.Text(bytes));
}
