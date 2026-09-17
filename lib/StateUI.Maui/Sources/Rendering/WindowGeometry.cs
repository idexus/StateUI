// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if WINDOWS
using Microsoft.Maui.Platform;
using Microsoft.UI.Windowing;
using StateUI.Maui.Protocol;
using WinPoint = Windows.Graphics.PointInt32;
using WinSize = Windows.Graphics.SizeInt32;
using WinWindow = Microsoft.UI.Xaml.Window;

namespace StateUI.Maui.Rendering;

/// <summary>
/// A window's position and size on Windows, written on the platform window
/// itself.
/// </summary>
/// <remarks>
/// <para>
/// MAUI's <c>Window.X</c>, <c>Y</c>, <c>Width</c> and <c>Height</c> re-enter
/// their own setters here. Assigning one moves the <c>AppWindow</c>; the
/// platform reports the frame back inside that move; MAUI queues the report
/// behind the assignment still in progress and applies it afterwards as a value
/// of its own - past the guard meant to keep a report from moving the window
/// again - and the report differs from the request by the frame's invisible
/// border, so every round moves or shrinks the window by that much, for as long
/// as the process lives. Measured: a request for x 80 walked the window off the
/// desktop diagonally, 6.5 units a round; a request for width 900 shrank it to
/// its minimum, 13 a round.
/// </para>
/// <para>
/// So the four are never assigned. What the tree asks for is kept per window
/// and written on the <c>AppWindow</c> - the outer frame's corner with
/// <c>Move</c>, the content area with <c>ResizeClient</c>, which is what the
/// two pairs mean - once the platform window exists, and on each request after.
/// MAUI's four properties are then the platform's reports alone. A maximized
/// window is restored first: its frame is the desktop's, not a request's.
/// </para>
/// </remarks>
internal static class WindowGeometry
{
    /// <summary>What the tree last asked of a window, axis by axis.</summary>
    private sealed class Request
    {
        internal double? X;
        internal double? Y;
        internal double? Width;
        internal double? Height;

        /// <summary>Whether the window is waited for, to be placed once it exists.</summary>
        internal bool Awaited;
    }

    /// <summary>The request each window carries.</summary>
    private static readonly BindableProperty RequestProperty =
        BindableProperty.CreateAttached("Request", typeof(Request), typeof(WindowGeometry), null);

    /// <summary>
    /// Takes what <paramref name="node"/> says about the window's position and
    /// size, and places the window accordingly.
    /// </summary>
    /// <param name="window">The window.</param>
    /// <param name="node">The message about it.</param>
    internal static void Apply(Window window, HostPatch node)
    {
        if (window.GetValue(RequestProperty) is not Request request)
        {
            request = new Request();
            window.SetValue(RequestProperty, request);
        }

        // Taken only where the property arrived, like everything else: a
        // message carries what changed.
        bool asked = false;

        if (node.GetNumber(HostProp.X) is double x) { request.X = x; asked = true; }
        if (node.GetNumber(HostProp.Y) is double y) { request.Y = y; asked = true; }
        if (node.GetNumber(HostProp.Width) is double width) { request.Width = width; asked = true; }
        if (node.GetNumber(HostProp.Height) is double height) { request.Height = height; asked = true; }

        if (!asked)
        {
            return;
        }

        if (window.Handler?.PlatformView is WinWindow platform)
        {
            Place(platform, request);
        }
        else if (!request.Awaited)
        {
            // Not yet opened: placed the moment the platform window is made,
            // which is before it is shown.
            request.Awaited = true;
            window.HandlerChanged += (_, _) =>
            {
                if (window.Handler?.PlatformView is WinWindow made)
                {
                    Place(made, request);
                }
            };
        }
    }

    /// <summary>Writes a request on the platform window.</summary>
    /// <param name="platform">The platform window.</param>
    /// <param name="request">What the tree asked for.</param>
    private static void Place(WinWindow platform, Request request)
    {
        if (platform.GetAppWindow() is not AppWindow appWindow)
        {
            return;
        }

        double density = platform.GetDisplayDensity();

        if (appWindow.Presenter is OverlappedPresenter { State: OverlappedPresenterState.Maximized } presenter)
        {
            presenter.Restore();
        }

        if (request.X is double || request.Y is double)
        {
            WinPoint at = appWindow.Position;

            appWindow.Move(new WinPoint(
                request.X is double x ? (int)Math.Round(x * density) : at.X,
                request.Y is double y ? (int)Math.Round(y * density) : at.Y));
        }

        if (request.Width is double || request.Height is double)
        {
            WinSize size = appWindow.ClientSize;

            appWindow.ResizeClient(new WinSize(
                request.Width is double width ? (int)Math.Round(width * density) : size.Width,
                request.Height is double height ? (int)Math.Round(height * density) : size.Height));
        }
    }
}
#endif
