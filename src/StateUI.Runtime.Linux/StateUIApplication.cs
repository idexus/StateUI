// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

using System.Runtime.Versioning;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

namespace StateUI.Runtime.Hosting;

/// <summary>
/// The Linux head's entry point - the stand-in for UIApplication.Main.
/// </summary>
/// <remarks>
/// <para>
/// A SUBCLASS rather than a call, because that is the shape a GTK application
/// takes: the platform's application asks for the MAUI app once GTK has
/// started, so the builder is handed over as an override rather than run
/// before it. An application writes the two lines that are its own:
/// </para>
/// <code>
/// public class Program : StateUIApplication
/// {
///     protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();
///
///     public static void Main(string[] args) => Start&lt;Program&gt;(args);
/// }
/// </code>
/// </remarks>
[SupportedOSPlatform("linux")]
public abstract class StateUIApplication : GtkMauiApplication
{
    /// <summary>
    /// Starts the GTK loop with a synchronization context under it.
    /// </summary>
    /// <remarks>
    /// The context is what the platform's own <c>Run</c> leaves out. Without
    /// one every <c>await</c> continuation resumes on the thread pool, and
    /// whatever it calls next enters GTK off the thread that owns it - within
    /// a few navigations that corrupts the heap. This one posts continuations
    /// back to the GLib main loop, which is what every other platform's
    /// context does for its own loop.
    /// </remarks>
    /// <typeparam name="TProgram">The head's own application class.</typeparam>
    /// <param name="args">The command line, which GTK reads for its own flags.</param>
    protected static void Start<TProgram>(string[] args)
        where TProgram : StateUIApplication, new()
    {
        SynchronizationContext.SetSynchronizationContext(
            new GLib.Internal.MainLoopSynchronizationContext());

        new TProgram().Run(args);
    }
}
