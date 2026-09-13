// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if IOS || MACCATALYST

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Whether the pull a RefreshView exists for can be reached at all on Apple.
/// </summary>
/// <remarks>
/// <para>
/// A UIScrollView bounces only where its content is longer than the room it
/// has, and the refresh control lives in the space a bounce opens - so a list
/// with a screenful or less in it cannot be pulled, and the control is there
/// with no way to reach it. Measured on the gallery's RefreshView sample, Mac
/// Catalyst and the iPad alike: three rows, and neither a drag nor a trackpad
/// gesture moved anything.
/// </para>
/// <para>
/// So a scroller under a RefreshView is told to bounce whichever way its
/// content lies, which is what makes the pull always available. It is written
/// only while the tree asks for a refresh and taken back where the tree stops
/// asking, so a scroller nobody said this about is left to the platform.
/// </para>
/// </remarks>
internal static class RefreshReach
{
    /// <summary>Views this has written the platform flag on.</summary>
    private static readonly BindableProperty BouncesProperty =
        BindableProperty.CreateAttached("Bounces", typeof(bool), typeof(RefreshReach), false);

    /// <summary>
    /// Make the pull reachable, or give the scroller back to the platform.
    /// </summary>
    /// <param name="refresh">The RefreshView the message was about.</param>
    internal static void Open(RefreshView refresh)
    {
        bool bounces = refresh.IsRefreshEnabled;
        bool written = (bool)refresh.GetValue(BouncesProperty);

        // Nothing to say about a view that is not asking and never asked: the
        // flag is the platform's until this writes it.
        if (!bounces && !written)
        {
            return;
        }

        refresh.SetValue(BouncesProperty, bounces);

        if (Scroller(refresh) is UIKit.UIScrollView native)
        {
            native.AlwaysBounceVertical = bounces;
        }
        else if (bounces)
        {
            Later(refresh);
        }
    }

    /// <summary>Waits for a platform view the tree has only just described.</summary>
    /// <remarks>
    /// The scroller belongs to the CONTENT, whose handler arrives after the
    /// RefreshView's own, so the first message about a page finds nothing.
    /// HandlerChanged is when it is there - and it is an ordinary event with
    /// no platform observation behind it, which <c>Loaded</c> is not: wiring
    /// that to a view keeps the view, and everything under it, for as long as
    /// the process runs (see <c>StateUIRenderer.WatchFrame</c>).
    /// </remarks>
    private static void Later(RefreshView refresh)
    {
        if (refresh.Content is not View content)
        {
            return;
        }

        void Arrived(object? sender, EventArgs args)
        {
            content.HandlerChanged -= Arrived;

            if (Scroller(refresh) is UIKit.UIScrollView native)
            {
                native.AlwaysBounceVertical = (bool)refresh.GetValue(BouncesProperty);
            }
        }

        content.HandlerChanged += Arrived;
    }

    /// <summary>The scroller the pull has to open, wherever it sits.</summary>
    /// <remarks>
    /// The content's own platform view answers where an author wrapped a
    /// ScrollView, which is what a RefreshView holds; the walk answers where
    /// the platform put one of its own around something else.
    /// </remarks>
    /// <param name="refresh">The RefreshView to look under.</param>
    /// <returns>The scroller, or nothing while the platform has made none.</returns>
    private static UIKit.UIScrollView? Scroller(RefreshView refresh) =>
        refresh.Content?.Handler?.PlatformView as UIKit.UIScrollView
        ?? (refresh.Handler?.PlatformView is UIKit.UIView view ? Inside(view) : null);

    /// <summary>The first scroller anywhere under a view.</summary>
    /// <param name="view">The view to look under.</param>
    /// <returns>The scroller, or nothing where there is none.</returns>
    private static UIKit.UIScrollView? Inside(UIKit.UIView view)
    {
        foreach (UIKit.UIView child in view.Subviews)
        {
            if (child is UIKit.UIScrollView scroller)
            {
                return scroller;
            }

            if (Inside(child) is UIKit.UIScrollView deeper)
            {
                return deeper;
            }
        }

        return null;
    }
}
#endif
