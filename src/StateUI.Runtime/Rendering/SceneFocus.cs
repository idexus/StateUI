// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if MACCATALYST
using System.Runtime.InteropServices;
using Foundation;
using ObjCRuntime;
using UIKit;
#endif

namespace StateUI.Runtime.Rendering;

/// <summary>
/// Which window the reader is in, and hiding a scene's windows while another
/// scene is in front - where the platform can say the one and do the other.
/// </summary>
/// <remarks>
/// <para>
/// Mac Catalyst's. Moving between windows there raises nothing MAUI or UIKit
/// reports - <c>Window.Activated</c> fires as a window is made and never on a
/// switch - while AppKit's own <c>NSWindowDidBecomeKeyNotification</c>, posted
/// in the same process, fires on every one, clicked or raised. The NSWindow
/// behind a UIWindow is found through the application's window list, by
/// handle; it is not linked yet while the window is being attached, and it is
/// by the window's first key, which is why the listing is set there.
/// </para>
/// <para>
/// A window hidden with <c>orderOut:</c> reports that it went to the
/// background, and that it was activated once <c>orderFront:</c> shows it -
/// honest for that window and untrue of the application, which is why
/// <see cref="StateUIWindow.HiddenByScene"/> is set before it is hidden.
/// </para>
/// <para>
/// Elsewhere a switch is <c>Window.Activated</c>, which
/// <see cref="StateUIApplication"/> hears on every platform, and nothing is
/// hidden: a window its scene would hide stays where it is.
/// </para>
/// </remarks>
internal static class SceneFocus
{
#if MACCATALYST
    /// <summary>Whether the key notification is being listened to.</summary>
    private static bool _watching;

    /// <summary>Listens for the reader moving between windows, once per process.</summary>
    internal static void Watch()
    {
        if (_watching)
        {
            return;
        }

        _watching = true;

        NSNotificationCenter.DefaultCenter.AddObserver(new NSString("NSWindowDidBecomeKeyNotification"), note =>
        {
            if (OwnerOf(note.Object) is StateUIWindow window)
            {
                window.Application.CameToFront(window);
            }
        });
    }

    /// <summary>Hides a window or shows it again, where it is not already so.</summary>
    /// <param name="window">A window of the application.</param>
    /// <param name="shown">Whether it is to be seen.</param>
    internal static void Show(StateUIWindow window, bool shown)
    {
        if (window.Handler?.PlatformView is not UIWindow ui || NSWindowOf(ui) is not NSObject platform)
        {
            return;
        }

        bool visible = platform.ValueForKey(new NSString("visible")) is NSNumber { BoolValue: true };

        if (visible == shown)
        {
            return;
        }

        // Before it goes: what it reports about going is the scene's doing.
        if (!shown)
        {
            window.HiddenByScene = true;
        }

        platform.PerformSelector(new Selector(shown ? "orderFront:" : "orderOut:"), null);
    }

    /// <summary>Puts a window on the platform's list of the application's windows, or keeps it off.</summary>
    /// <param name="window">A window of the application.</param>
    /// <param name="listed">Whether the Window menu names it.</param>
    internal static void List(StateUIWindow window, bool listed)
    {
        if (window.Handler?.PlatformView is UIWindow ui && NSWindowOf(ui) is NSObject platform)
        {
            platform.SetValueForKey(NSNumber.FromBoolean(!listed), new NSString("excludedFromWindowsMenu"));
        }
    }

    /// <summary>
    /// Keeps a window above the application's others while the application is
    /// in front, or gives it its place among them.
    /// </summary>
    /// <remarks>
    /// AppKit's floating level, above every ordinary window - and with it
    /// <c>hidesOnDeactivate</c>, so a window that floats goes while another
    /// application is in front rather than standing over that application's
    /// windows, and comes back with its own.
    /// </remarks>
    /// <param name="window">A window of the application.</param>
    /// <param name="floats">Whether it floats on top.</param>
    internal static void Float(StateUIWindow window, bool floats)
    {
        if (window.Handler?.PlatformView is UIWindow ui && NSWindowOf(ui) is NSObject platform)
        {
            // NSFloatingWindowLevel, or NSNormalWindowLevel.
            platform.SetValueForKey(NSNumber.FromNInt(floats ? 3 : 0), new NSString("level"));
            platform.SetValueForKey(NSNumber.FromBoolean(floats), new NSString("hidesOnDeactivate"));
        }
    }

    /// <summary>The window of ours an NSWindow is the platform's half of.</summary>
    /// <param name="platform">The NSWindow a notification names.</param>
    private static StateUIWindow? OwnerOf(NSObject? platform)
    {
        if (platform is null)
        {
            return null;
        }

        foreach (Window window in Microsoft.Maui.Controls.Application.Current?.Windows ?? [])
        {
            if (window is StateUIWindow ours && ours.Handler?.PlatformView is UIWindow ui
                && NSWindowOf(ui) is NSObject found && found.Handle == platform.Handle)
            {
                return ours;
            }
        }

        return null;
    }

    /// <summary>The NSWindow a UIWindow is drawn in - null until the platform has linked them.</summary>
    /// <param name="ui">The UIWindow.</param>
    private static NSObject? NSWindowOf(UIWindow ui)
    {
        IntPtr type = Class.GetHandle("NSApplication");

        if (type == IntPtr.Zero)
        {
            return null;
        }

        NSObject? application = ObjCRuntime.Runtime.GetNSObject(
            IntPtr_objc_msgSend(type, Selector.GetHandle("sharedApplication")));

        if (application?.ValueForKey(new NSString("windows")) is not NSArray windows)
        {
            return null;
        }

        for (nuint index = 0; index < windows.Count; index++)
        {
            NSObject candidate = windows.GetItem<NSObject>(index);

            if (!candidate.RespondsToSelector(new Selector("uiWindows"))
                || candidate.ValueForKey(new NSString("uiWindows")) is not NSArray uiWindows)
            {
                continue;
            }

            for (nuint at = 0; at < uiWindows.Count; at++)
            {
                if (uiWindows.GetItem<NSObject>(at).Handle == ui.Handle)
                {
                    return candidate;
                }
            }
        }

        return null;
    }

    /// <summary>A message with no argument, answering an object - how the application object is reached.</summary>
    [DllImport("/usr/lib/libobjc.dylib", EntryPoint = "objc_msgSend")]
    private static extern IntPtr IntPtr_objc_msgSend(IntPtr receiver, IntPtr selector);
#else
    /// <summary>Nothing to listen for: a switch is <c>Window.Activated</c> here.</summary>
    internal static void Watch()
    {
    }

    /// <summary>Nothing is hidden where the platform cannot hide a window and keep it.</summary>
    /// <param name="window">A window of the application.</param>
    /// <param name="shown">Whether it would be seen.</param>
    internal static void Show(StateUIWindow window, bool shown)
    {
    }

    /// <summary>No list of the application's windows to keep a window off.</summary>
    /// <param name="window">A window of the application.</param>
    /// <param name="listed">Whether it would be listed.</param>
    internal static void List(StateUIWindow window, bool listed)
    {
    }

    /// <summary>Nothing floats where the platform is not asked to keep a window on top.</summary>
    /// <param name="window">A window of the application.</param>
    /// <param name="floats">Whether it would float on top.</param>
    internal static void Float(StateUIWindow window, bool floats)
    {
    }
#endif
}
