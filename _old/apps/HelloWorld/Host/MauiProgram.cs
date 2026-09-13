using StateUI.Runtime.Hosting;

namespace HelloWorld;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        MauiAppBuilder builder = MauiApp.CreateBuilder();
        // The application, and the platform under it. One sentence in every
        // head: on Linux `StateUI.Linux` answers it with MAUI's GTK4 backend
        // and this library's answers to that backend's gaps, and everywhere
        // else it is MAUI's own UseMauiApp.
        builder.UseStateUIApp<App>();
        return builder.Build();
    }
}
