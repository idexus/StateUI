using System.Runtime.Versioning;
using Microsoft.Maui.Platforms.Linux.Gtk4.Platform;

// WHICH OS THIS HEAD IS FOR, said once for the whole assembly. A plain net10.0
// target framework carries no platform, so the analyzer reads a call to the
// GTK4 backend - whose every entry point is [SupportedOSPlatform("linux")] - as
// reachable on Windows and macOS too, and answers CA1416. This is the head that
// is only ever built and run on Linux, which is what the attribute says.
[assembly: SupportedOSPlatform("linux")]

namespace Gallery;

/// <summary>
/// The Linux head's entry point - the stand-in for UIApplication.Main.
/// </summary>
/// <remarks>
/// A SUBCLASS rather than a call, because that is the shape a GTK application
/// takes: <c>GtkMauiApplication</c> is a <c>Gtk.Application</c> that asks for
/// the MAUI app once GTK has started, so the builder must be handed over as an
/// override rather than run before it.
/// </remarks>
public class Program : GtkMauiApplication
{
    /// <summary>Builds the MAUI application, once GTK asks for it.</summary>
    /// <returns>The gallery, hosted for this platform.</returns>
    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();

    /// <summary>Starts the GTK loop.</summary>
    /// <param name="args">The command line, which GTK reads for its own flags.</param>
    public static void Main(string[] args) => new Program().Run(args);
}
