// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

namespace StateUI.Maui.Rendering;

/// <summary>
/// A window's title bar, never shorter than the band the platform keeps across
/// the top of the window for the window's own buttons.
/// </summary>
/// <remarks>
/// <para>
/// Mac Catalyst's. The window's controller sizes a title bar to what it
/// measures and starts the page directly below it, while the traffic lights sit
/// in a band as tall as the window's top safe area. A bar measured to its
/// content - a title and an icon at twelve points - covered twelve points of a
/// thirty-two point band, and the page took the rest as its own safe-area
/// inset, drawn as a white strip between the bar and the page. Measured on the
/// gallery's main window.
/// </para>
/// <para>
/// So the bar is at least as tall as the band, read at every measure: the
/// controller measures the bar on every layout of the window. Elsewhere there
/// is no band and the bar measures to its content.
/// </para>
/// </remarks>
internal sealed class StateUITitleBar : TitleBar
{
    /// <inheritdoc/>
    protected override Size MeasureOverride(double widthConstraint, double heightConstraint)
    {
        Size measured = base.MeasureOverride(widthConstraint, heightConstraint);
        return new Size(measured.Width, Math.Max(measured.Height, Band()));
    }

    /// <summary>The height of the window's own band, or zero where it has none.</summary>
    private double Band()
    {
#if MACCATALYST
        return Window?.Handler?.PlatformView is UIKit.UIWindow window ? (double)window.SafeAreaInsets.Top : 0;
#else
        return 0;
#endif
    }
}
