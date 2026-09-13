using System.Runtime.Versioning;
using StateUI.Runtime.Hosting;

// WHICH OS THIS HEAD IS FOR, said once for the whole assembly. A plain net10.0
// target framework carries no platform, so the analyzer reads a call into the
// GTK4 platform - whose every entry point is [SupportedOSPlatform("linux")] -
// as reachable on Windows and macOS too, and answers CA1416.
[assembly: SupportedOSPlatform("linux")]

namespace HelloWorld;

/// <summary>The Linux head's entry point - the stand-in for UIApplication.Main.</summary>
/// <remarks>
/// A SUBCLASS rather than a call, because that is the shape a GTK application
/// takes: the platform asks for the MAUI app once GTK has started, so the
/// builder is handed over as an override rather than run before it.
/// </remarks>
public class Program : StateUIApplication
{
    /// <summary>Builds the MAUI application, once GTK asks for it.</summary>
    /// <returns>This application, hosted for this platform.</returns>
    protected override MauiApp CreateMauiApp() => MauiProgram.CreateMauiApp();

    /// <summary>Starts the GTK loop.</summary>
    /// <param name="args">The command line, which GTK reads for its own flags.</param>
    public static void Main(string[] args) => Start<Program>(args);
}
