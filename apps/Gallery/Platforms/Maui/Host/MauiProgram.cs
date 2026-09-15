using StateUI.Maui.Hosting;
using StateUI.Maui.Protocol;
using StateUI.Maui.Rendering;

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

        // The gallery's own acts: C# functions registered under the names
        // the application's contract declares, with what each takes and
        // answers - see Sources/Samples/Interop/GalleryContract.swift. A
        // performer is a plain or an async function, the two shapes Add takes.
        StateUIActs.Add("Gallery.SetClipboard", async call =>
        {
            await Clipboard.Default.SetTextAsync(call.GetString(0) ?? "");
            return [];
        });

        StateUIActs.Add("Gallery.ReadClipboard", async call =>
            [HostValue.Of(await Clipboard.Default.GetTextAsync() ?? "")]);

        StateUIActs.Add("Gallery.BatteryLevel", call =>
            [
                HostValue.Of(Battery.Default.ChargeLevel),
                HostValue.Of(Battery.Default.State == BatteryState.Charging),
            ]);

        // An act aimed at a control, declared in the control's contract - see
        // Sources/Samples/Interop/RatingBar.swift: argument 0 is the control's
        // identity, and TargetOf turns it back into the control - null once
        // the control has left the screen, which is an ordinary answer.
        StateUIActs.Add("Gallery.FlashRating", async call =>
        {
            if (StateUIActs.TargetOf(call) is RatingBar bar)
            {
                await bar.FadeToAsync(0.25, 120);
                await bar.FadeToAsync(1, 120);
            }

            return [];
        });

        // The gallery's own pushes: events raised by name with no control
        // behind them, declared in the same contract - see
        // Sources/Samples/Interop/GalleryContract.swift. Safe from any
        // thread, and a raise nobody hears is an ordinary answer, so the
        // sources are wired unconditionally.
        Battery.Default.BatteryInfoChanged += (_, e) =>
            StateUIEvents.Raise("Gallery.BatteryChanged",
                HostValue.Of(e.ChargeLevel),
                HostValue.Of(e.State == BatteryState.Charging));

        Connectivity.Current.ConnectivityChanged += (_, e) =>
            StateUIEvents.Raise("Gallery.ConnectivityChanged",
                HostValue.Of(e.NetworkAccess == NetworkAccess.Internet));

        // The gallery's own control. `create` runs once per element and wires
        // its events; `apply` runs on every message that touches it and reads
        // only what arrived. The renderer applies what every view shares -
        // margins, alignment, opacity, gestures - after it. See
        // Sources/Samples/Interop/CustomControlSample.swift.
        StateUIControls.Add("Gallery.TrafficLight",
            create: raise =>
            {
                var light = new TrafficLight();
                light.LampTapped += (_, index) =>
                    raise(light, "lampTapped", HostValue.Of(index));
                return light;
            },
            apply: (light, node) =>
            {
                if (node.GetEnumeration("signal") is int signal)
                {
                    light.Signal = signal;
                }
            });

        // A container: `content` fills the control's one slot with the
        // reconciled child, and is called only when the slot changes hands.
        // `count` is a name the library also uses; declared here, it is the
        // Badge's. See Sources/Samples/Interop/CustomContainerSample.swift.
        StateUIControls.Add("Gallery.Badge",
            create: _ => new Badge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["count"] = Badge.CountProperty,
            },
            content: (badge, inner) => badge.Inner = inner);

        // A DECLARED property: assigned by the renderer whenever a message
        // carries it, set by a style, and walked from a state - what
        // `.rating($stars)` and `$stars.journey.move(to:)` reach. See
        // Sources/Samples/Interop/RatingBar.swift.
        StateUIControls.Add("Gallery.RatingBar",
            create: raise =>
            {
                var stars = new RatingBar();
                stars.RatingChanged += (_, rating) =>
                    raise(stars, "ratingChanged", HostValue.Of(rating));
                return stars;
            },
            properties: new Dictionary<string, BindableProperty>
            {
                ["rating"] = RatingBar.RatingProperty,
            });

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
