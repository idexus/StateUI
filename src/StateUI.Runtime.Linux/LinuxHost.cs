// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Diagnostics.CodeAnalysis;
using System.Runtime.Versioning;
using Microsoft.Maui.Platforms.Linux.Gtk4.Essentials.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Hosting;

namespace StateUI.Runtime.Linux;

/// <summary>
/// Everything this platform needs under an application, in the order it needs
/// it.
/// </summary>
/// <remarks>
/// Linux is drawn by MAUI's own GTK4 backend, where every control is a real
/// GTK4 widget: <c>UseMauiAppLinuxGtk4</c> registers the app AND that
/// platform's handlers, which is why it stands in place of <c>UseMauiApp</c>
/// rather than beside it. The rest is this library's answer to what that
/// backend leaves undone - each file beside this one says what its own gap is,
/// and an application that misses any of them draws flat, hears no tap, never
/// hears a view load, or dies at the first navigation.
/// </remarks>
[SupportedOSPlatform("linux")]
internal static class LinuxHost
{
    /// <summary>Hosts one application on this platform.</summary>
    /// <typeparam name="TApp">The MAUI application class to host.</typeparam>
    /// <param name="builder">The builder to register it on.</param>
    /// <returns>The same builder.</returns>
    internal static MauiAppBuilder Use<
        [DynamicallyAccessedMembers(DynamicallyAccessedMemberTypes.PublicConstructors)] TApp>(
        MauiAppBuilder builder)
        where TApp : class, IApplication
    {
        // Before anything touches graphene: the seeded handle only matters
        // while no import has been bound yet.
        LinuxTransforms.Install();

        builder.UseMauiAppLinuxGtk4<TApp>();

        // Clipboard, preferences, battery, connectivity and the rest, which an
        // application reads through the library's standard environment.
        // LinuxEssentials says why the second line is needed beside the first.
        builder.AddLinuxGtk4Essentials();
        LinuxEssentials.Install();

        // Which look the desktop asked for, which the answer installed above
        // reads off a setting no desktop sets. It wraps that answer, so it
        // goes second.
        LinuxTheme.Install();

        // And the rest of that backend's gaps: the style sheet a widget wears,
        // which its own mappers overwrite one another in; the gestures, which
        // nothing there attaches; a scroller's measure and the axis it runs
        // along; a drawn view's measure, the size a border was asked for, and
        // the re-layout nothing there runs; a dispatch run inline instead of
        // queued, which is what dropped every report deferred past an apply;
        // a popped page's teardown, which left to the garbage collector
        // reaches GTK from the wrong thread; the application's own icon,
        // which nothing here ever tells GTK about; and the display's own
        // frame clock, which nothing here hands to anybody.
        // The display's own rhythm, which nothing here answers by itself: every
        // value this library moves is stepped by it.
        LinuxFrames.Install();

        LinuxArtwork.Install();
        LinuxStyling.Install();
        LinuxGestures.Install();
        LinuxScrolling.Install(builder);
        LinuxMeasures.Install(builder);
        LinuxDispatching.Install(builder);
        LinuxNavigation.Install();

        return builder;
    }
}
