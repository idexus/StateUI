// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if WINDOWS
using WinElement = Microsoft.UI.Xaml.UIElement;

namespace StateUI.Maui.Rendering;

/// <summary>
/// A layout that ignores input on Windows, and everything in it with it.
/// </summary>
/// <remarks>
/// <para>
/// MAUI's WinUI backend answers <c>InputTransparent</c> on the layout itself
/// and reads <c>CascadeInputTransparent</c> nowhere, so a child of a layout
/// that ignores input would go on taking every tap.
/// </para>
/// <para>
/// WinUI's own answer is <c>IsHitTestVisible</c>, which excludes an element
/// AND everything under it, so it says exactly what ignoring input means. It is
/// written only where the tree asks for it and taken back where the tree stops
/// asking, so a layout nobody said this about is left to the platform.
/// </para>
/// </remarks>
internal static class TouchThrough
{
    /// <summary>Layouts this has written the platform flag on.</summary>
    private static readonly BindableProperty ThroughProperty =
        BindableProperty.CreateAttached("Through", typeof(bool), typeof(TouchThrough), false);

    /// <summary>
    /// Make a layout and its children ignore input, or stop them ignoring it.
    /// </summary>
    /// <param name="layout">The layout.</param>
    /// <param name="ignores">Whether the layout ignores input.</param>
    internal static void Cascade(Layout layout, bool ignores)
    {
        bool written = (bool)layout.GetValue(ThroughProperty);

        // Nothing to say about a layout that is not asking and never asked:
        // the flag is the platform's until this writes it.
        if (!ignores && !written) { return; }

        layout.SetValue(ThroughProperty, ignores);

        if (layout.Handler?.PlatformView is WinElement panel) { panel.IsHitTestVisible = !ignores; }
        else if (ignores) { Later(layout); }
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
