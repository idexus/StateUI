// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if WINDOWS
using StateUI.Runtime.Protocol;
using WinElement = Microsoft.UI.Xaml.UIElement;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// A transparent layout's CASCADE on Windows - whether its children are
/// touched through with it.
/// </summary>
/// <remarks>
/// <para>
/// MAUI's WinUI backend answers <c>InputTransparent</c> on the layout itself
/// and reads <c>CascadeInputTransparent</c> nowhere: measured 2026-09-07 on
/// the gallery's touch-through sample, where a cascading transparent stack's
/// label went on counting every tap - set as the control was made and flipped
/// afterwards alike, and with the transparency written again for it.
/// </para>
/// <para>
/// WinUI's own answer is <c>IsHitTestVisible</c>, which excludes an element
/// AND everything under it, so it says exactly what a cascade means. It is
/// written only where the tree asks for one and taken back where the tree
/// stops asking, so a layout nobody said this about is left to the platform.
/// </para>
/// </remarks>
internal static class TouchThrough
{
    /// <summary>Layouts this has written the platform flag on.</summary>
    private static readonly BindableProperty ThroughProperty =
        BindableProperty.CreateAttached("Through", typeof(bool), typeof(TouchThrough), false);

    /// <summary>
    /// Make a layout's transparency reach its children, or stop it reaching
    /// them.
    /// </summary>
    /// <remarks>
    /// THE TRANSPARENCY IS READ OFF THE MESSAGE and only then off the control:
    /// <c>ApplyView</c> writes that one AFTER <c>ApplyLayout</c>, so while this
    /// runs the control still holds whatever the last message left - which for
    /// a control being made is the platform's default, and the reason a first
    /// message about a transparent layout would otherwise be missed entirely.
    /// </remarks>
    /// <param name="node">The message about this layout.</param>
    /// <param name="layout">The layout the message was about.</param>
    internal static void Cascade(SwiftNode node, Layout layout)
    {
        bool transparent = node.GetBool(SwiftProp.InputTransparent) ?? layout.InputTransparent;
        bool cascades = node.GetBool(SwiftProp.CascadeInputTransparent) ?? layout.CascadeInputTransparent;
        bool through = transparent && cascades;
        bool written = (bool)layout.GetValue(ThroughProperty);

        // Nothing to say about a layout that is not asking and never asked:
        // the flag is the platform's until this writes it.
        if (!through && !written) { return; }

        layout.SetValue(ThroughProperty, through);

        if (layout.Handler?.PlatformView is WinElement panel) { panel.IsHitTestVisible = !through; }
        else if (through) { Later(layout); }
    }

    /// <summary>Waits for the handler a control on its first message has not got yet.</summary>
    private static void Later(Layout layout)
    {
        void Made(object? sender, EventArgs args)
        {
            layout.HandlerChanged -= Made;

            if (layout.Handler?.PlatformView is WinElement panel)
            {
                panel.IsHitTestVisible = !(bool)layout.GetValue(ThroughProperty);
            }
        }

        layout.HandlerChanged += Made;
    }
}
#endif
