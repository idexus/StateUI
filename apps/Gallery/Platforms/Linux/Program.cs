using Microsoft.Maui.Platform.Linux;

namespace Gallery;

public class Program
{
    static void Main(string[] args)
    {
        // OpenMaui's entry point: builds the MAUI application and runs its
        // X11 or Wayland loop - the Linux stand-in for UIApplication.Main.
        LinuxApplication.Run(MauiProgram.CreateMauiApp(), args);
    }
}
