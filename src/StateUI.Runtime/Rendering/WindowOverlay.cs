// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using Microsoft.Maui.Platform;

namespace StateUI.Runtime.Rendering;

/// <summary>
/// A view laid over a whole window, above its page - what a window's
/// <c>Overlay</c> slot shows, and what an inspector's panel is.
/// </summary>
/// <remarks>
/// <para>
/// MAUI has no place for a view that is not inside a page, so the view is
/// handed to the platform's own window directly: the same size as the window,
/// above everything the window already holds, and laid out by MAUI's own
/// layout from that size - a MAUI layout under a platform view that is not a
/// MAUI one measures and arranges itself.
/// </para>
/// <para>
/// A TOUCH THE OVERLAY'S VIEWS DO NOT TAKE GOES THROUGH TO THE PAGE. The
/// overlay's root is a layout that takes no touches of its own and leaves its
/// children theirs - <c>InputTransparent</c> without the cascade - which on
/// Apple answers a hit on itself with nothing and on Android declines the
/// touch, so the platform goes on to the page under it. On Windows a panel
/// with no background is not hit where nothing is drawn.
/// </para>
/// <para>
/// Nothing on the plain framework: the tests have no platform window, and
/// Linux has no host for it - an inspector there prefers a window of its own,
/// and one docked at the side or the bottom anyway is laid nowhere.
/// </para>
/// </remarks>
internal static class WindowOverlay
{
    /// <summary>Lays a view over a window, or brings it back on top.</summary>
    /// <param name="window">The window.</param>
    /// <param name="view">The view, already rendered.</param>
    internal static void Show(Window window, View view)
    {
        if (window.Handler?.MauiContext is not IMauiContext context)
        {
            // Not shown yet: the window lays it over itself when the platform
            // gives it a handler. See StateUIWindow.OnHandlerChanged.
            return;
        }

#if IOS || MACCATALYST
        if (window.Handler.PlatformView is not UIKit.UIWindow native)
        {
            return;
        }

        UIKit.UIView drawn = view.ToPlatform(context);

        if (!ReferenceEquals(drawn.Superview, native))
        {
            drawn.RemoveFromSuperview();
            drawn.Frame = native.Bounds;
            drawn.AutoresizingMask =
                UIKit.UIViewAutoresizing.FlexibleWidth | UIKit.UIViewAutoresizing.FlexibleHeight;
            native.AddSubview(drawn);
        }
        else if (!ReferenceEquals(native.Subviews.LastOrDefault(), drawn))
        {
            // Something presented since - a modal - lies over it now.
            native.BringSubviewToFront(drawn);
        }
#elif ANDROID
        if (window.Handler.PlatformView is not Android.App.Activity activity
            || activity.FindViewById<Android.Views.ViewGroup>(Android.Resource.Id.Content)
                is not Android.Views.ViewGroup content)
        {
            return;
        }

        Android.Views.View drawn = view.ToPlatform(context);

        if (!ReferenceEquals(drawn.Parent, content))
        {
            (drawn.Parent as Android.Views.ViewGroup)?.RemoveView(drawn);
            content.AddView(
                drawn,
                new Android.Widget.FrameLayout.LayoutParams(
                    Android.Views.ViewGroup.LayoutParams.MatchParent,
                    Android.Views.ViewGroup.LayoutParams.MatchParent));
        }
        else if (!ReferenceEquals(content.GetChildAt(content.ChildCount - 1), drawn))
        {
            drawn.BringToFront();
        }
#elif WINDOWS
        if (window.Handler.PlatformView is not Microsoft.UI.Xaml.Window native
            || native.Content is not Microsoft.UI.Xaml.Controls.Panel panel)
        {
            return;
        }

        Microsoft.UI.Xaml.FrameworkElement drawn = view.ToPlatform(context);

        if (!ReferenceEquals(drawn.Parent, panel))
        {
            (drawn.Parent as Microsoft.UI.Xaml.Controls.Panel)?.Children.Remove(drawn);
            panel.Children.Add(drawn);
        }
#endif
    }

    /// <summary>Takes a view off the window it was laid over.</summary>
    /// <param name="view">The view.</param>
    internal static void Hide(View view)
    {
        if (view.Handler is not IViewHandler handler)
        {
            return;
        }

        object? drawn = handler.ContainerView ?? handler.PlatformView;

#if IOS || MACCATALYST
        (drawn as UIKit.UIView)?.RemoveFromSuperview();
#elif ANDROID
        if (drawn is Android.Views.View native && native.Parent is Android.Views.ViewGroup parent)
        {
            parent.RemoveView(native);
        }
#elif WINDOWS
        if (drawn is Microsoft.UI.Xaml.FrameworkElement native
            && native.Parent is Microsoft.UI.Xaml.Controls.Panel panel)
        {
            panel.Children.Remove(native);
        }
#else
        _ = drawn;
#endif
    }
}
