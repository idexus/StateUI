// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if WINDOWS
// WinUI's brush and WinUI's text box, each named after a MAUI type that is
// also in scope here - and only one of each can paint a platform control.
using WinBrush = Microsoft.UI.Xaml.Media.SolidColorBrush;
using WinTextBox = Microsoft.UI.Xaml.Controls.TextBox;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// A selection the TREE asked for, made visible on Windows - which paints none
/// in a field that has not got the focus.
/// </summary>
/// <remarks>
/// <para>
/// WinUI keeps two brushes for a selection: <c>SelectionHighlightColor</c>,
/// used while the field has the focus, and
/// <c>SelectionHighlightColorWhenNotFocused</c>, which is UNSET by default, so
/// a TextBox the reader is not in draws its selected text like any other text.
/// That is the platform's answer for a selection the READER made and then
/// clicked away from - and it is the wrong answer for one the tree wrote,
/// because an application selects a field's contents precisely while the
/// reader is somewhere else.
/// </para>
/// <para>
/// MEASURED on the gallery's Entry sample: with <c>12345</c> typed into the
/// serial-number field and its switch flipped, UIA reported the whole text
/// selected (<c>at 0 len 5</c>) while the pixels showed no highlight at all.
/// Mac Catalyst shows it, so this is the platform being made to agree with the
/// others rather than a behaviour of this library's own.
/// </para>
/// <para>
/// It is asked for and given back with the SELECTION: the brush is the focused
/// one for as long as the tree is describing a selection, and the platform's
/// default returns the moment the tree says the selection is empty - so a
/// reader's own selection is left to behave the way Windows behaves everywhere
/// else. Only a TextBox is answered, which is the Entry's platform control and
/// the Editor's; a SearchBar is an AutoSuggestBox and has no such brush.
/// </para>
/// </remarks>
internal static class TextSelection
{
    /// <summary>
    /// Show, or stop showing, a selection in <paramref name="view"/> while it
    /// has no focus.
    /// </summary>
    /// <param name="view">The field the message was about.</param>
    /// <param name="asked">Whether the tree is describing a selection.</param>
    internal static void Show(InputView view, bool asked)
    {
        if (view.Handler?.PlatformView is WinTextBox box) { Paint(box, asked); return; }
        if (!asked) { return; }

        // A control on its FIRST message has no handler yet - MAUI makes one
        // when the view joins the tree, which happens after this - so the
        // answer waits for it. The closure takes itself off, and a second one
        // added while the handler was still missing does no harm: painting the
        // same brush twice is painting it once.
        void Later(object? sender, EventArgs args)
        {
            view.HandlerChanged -= Later;
            if (view.Handler?.PlatformView is WinTextBox made) { Paint(made, true); }
        }

        view.HandlerChanged += Later;
    }

    /// <summary>
    /// Give the unfocused brush the focused one, or hand the property back to
    /// the platform.
    /// </summary>
    private static void Paint(WinTextBox box, bool asked)
    {
        if (!asked)
        {
            box.ClearValue(WinTextBox.SelectionHighlightColorWhenNotFocusedProperty);
            return;
        }

        // The control's own brush first - a style may have set it - and the
        // theme's resource behind it, since the property is free to be null.
        WinBrush? paint = box.SelectionHighlightColor;

        if (paint is null
            && Microsoft.UI.Xaml.Application.Current?.Resources is { } resources
            && resources.TryGetValue("TextControlSelectionHighlightColor", out object? themed))
        {
            paint = themed as WinBrush;
        }

        if (paint is not null) { box.SelectionHighlightColorWhenNotFocused = paint; }
    }
}
#endif
