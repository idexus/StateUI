using StateUI.Maui.Hosting;

namespace Gallery;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        MauiAppBuilder builder = MauiApp.CreateBuilder();

        // The application, and the platform under it. One sentence in every
        // head: on Linux `StateUI.Maui.Linux` answers it with MAUI's GTK4
        // backend and this library's answers to that backend's gaps, and
        // everywhere else it is MAUI's own UseMauiApp.
        builder.UseStateUIApp<App>();

        // The Map control's handlers - MAUI's own opt-in, kept out of
        // UseMauiApp so an application that shows no map registers none of
        // it. Android also wants a Google Maps API key in its manifest; the
        // comment there says where to get one.
        //
        // NOT ON WINDOWS, and this is a crash rather than a missing control:
        // `AddMauiMaps` THROWS there - "*.NET MAUI Maps is currently not
        // implemented for Windows*" - from inside handler registration, so the
        // app dies before its first render with nothing but exit code
        // 0xc000027b to show for it. Measured 2026-08-13; the Map sample is
        // meant to draw the unknown-control marker there, which it can only do
        // if the app starts at all. Linux stays out too: the GTK4 backend
        // implements no map control, and the marker is the honest answer there
        // as well.
#if !WINDOWS && !LINUX
        builder.UseMauiMaps();
#endif

#if IOS || MACCATALYST
        // A UISearchBar draws a bar of its own behind the field, and no MAUI
        // property removes it: a solid BackgroundColor becomes BarTintColor,
        // which the bar renders through its translucent material - visibly
        // OFF the card it sits on - and a CLEAR tint drops it into a legacy
        // look that is WHITE in both themes, with dark mode's light text
        // vanishing into it. Minimal is UIKit's own answer for a search
        // field embedded on a coloured surface: no bar at all, just the
        // field, its translucent grey compositing on whatever is behind.
        // AppendToMapping is MAUI's per-app hook, so this stays the
        // gallery's look rather than a renderer rule.
        Microsoft.Maui.Handlers.SearchBarHandler.Mapper.AppendToMapping(
            "GallerySearchBarStyle",
            (handler, _) => handler.PlatformView.SearchBarStyle = UIKit.UISearchBarStyle.Minimal);
#endif

        return builder.Build();
    }
}
