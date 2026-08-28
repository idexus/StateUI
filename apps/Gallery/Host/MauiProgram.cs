using StateUI.Runtime.Protocol;
using StateUI.Runtime.Rendering;
#if LINUX
using Microsoft.Maui.Platforms.Linux.Gtk4.Essentials.Hosting;
using Microsoft.Maui.Platforms.Linux.Gtk4.Hosting;
#endif

namespace Gallery;

public static class MauiProgram
{
    public static MauiApp CreateMauiApp()
    {
        MauiAppBuilder builder = MauiApp.CreateBuilder();

        // Linux is drawn by MAUI's own GTK4 backend, where every control is a
        // real GTK4 widget: one call registers the app AND that platform's
        // handlers, which is why it stands in place of UseMauiApp rather than
        // beside it.
#if LINUX
        // Before anything touches graphene: the seeded handle only matters
        // while no import has been bound yet.
        LinuxTransforms.Install();

        builder.UseMauiAppLinuxGtk4<App>();

        // Clipboard, preferences, battery, connectivity and the rest, which
        // this application reads through the library's standard environment
        // and its own acts. LinuxEssentials says why the second line is needed
        // beside the first.
        builder.AddLinuxGtk4Essentials();
        LinuxEssentials.Install();

        // And the rest of that backend's gaps: the style sheet a widget wears,
        // which its own mappers overwrite one another in; the gestures, which
        // nothing there attaches; the height of a scroller that runs across;
        // and a popped page's teardown, which left to the garbage collector
        // reaches GTK from the wrong thread. Each file says what its gap is.
        LinuxStyling.Install();
        LinuxGestures.Install();
        LinuxScrolling.Install();
        LinuxNavigation.Install();
#else
        builder.UseMauiApp<App>();
#endif

        // The gallery's own acts - C# functions registered under names the
        // Swift side declares as Act tokens, and calls like any act the
        // library ships. See Swift/Samples/Interop/CustomActsSample.swift;
        // one is a plain function, two are async, which are the two shapes
        // the registration takes.
        StateUIActs.Add("Gallery.SetClipboard", async command =>
        {
            await Clipboard.Default.SetTextAsync(command.GetString(0) ?? "");
            return [];
        });

        StateUIActs.Add("Gallery.ReadClipboard", async command =>
            [SwiftWireValue.Of(await Clipboard.Default.GetTextAsync() ?? "")]);

        // An act AIMED at a control, which is what StateUIActs.TargetOf is
        // for: the Swift side puts the control's identity in argument 0 -
        // `ControlState.target` - and this turns it back into the control. It
        // is how every act of the library's own finds its view, and an
        // application's performers reach it through the same door.
        StateUIActs.Add("Gallery.FlashRating", async command =>
        {
            // Null when the view has left the tree since the act was written,
            // which is an ordinary answer rather than a failure.
            if (StateUIActs.TargetOf(command) is RatingBar bar)
            {
                await bar.FadeToAsync(0.25, 120);
                await bar.FadeToAsync(1, 120);
            }

            return [];
        });

        StateUIActs.Add("Gallery.BatteryLevel", command =>
            [
                SwiftWireValue.Of(Battery.Default.ChargeLevel),
                SwiftWireValue.Of(Battery.Default.State == BatteryState.Charging),
            ]);

        // The gallery's own PUSHES - events C# raises on its own schedule,
        // with no control behind them: the Swift side subscribes by the same
        // names with HostEvents.on, and a raise nobody is listening to is an
        // ordinary answer. Safe from any thread; the session marshals. See
        // Swift/Samples/Interop/CustomEventsSample.swift.
        Battery.Default.BatteryInfoChanged += (_, e) =>
            StateUIEvents.Raise("Gallery.BatteryChanged",
                SwiftWireValue.Of(e.ChargeLevel),
                SwiftWireValue.Of(e.State == BatteryState.Charging));

        Connectivity.Current.ConnectivityChanged += (_, e) =>
            StateUIEvents.Raise("Gallery.ConnectivityChanged",
                SwiftWireValue.Of(e.NetworkAccess == NetworkAccess.Internet));

        // The gallery's own CONTROL - an ordinary C# ContentView, registered
        // under the node type the Swift side describes. `create` runs once
        // per element and is where its events are wired; `apply` runs on
        // every message that touches it and reads only what arrived. The
        // renderer keeps it between renders and applies the shared tier -
        // margins, opacity, gestures - around this, like any built-in. See
        // Swift/Samples/Interop/CustomControlSample.swift.
        StateUIControls.Add("Gallery.TrafficLight",
            create: raise =>
            {
                var light = new TrafficLight();
                light.LampTapped += (_, index) =>
                    raise(light, "lampTapped", SwiftWireValue.Of(index));
                return light;
            },
            apply: (light, node) =>
            {
                if (node.GetEnumeration("state") is int state)
                {
                    light.State = state;
                }
            });

        // The gallery's own CONTAINER - the same registry, plus the one
        // content slot: the Swift side writes Badge { … }, the child travels
        // as the node's child, and the renderer reconciles it into Inner -
        // created, patched and kept by identity, the way a Border's content
        // is. See Swift/Samples/Interop/CustomContainerSample.swift.
        StateUIControls.Add("Gallery.Badge",
            create: _ => new Badge(),
            properties: new Dictionary<string, BindableProperty>
            {
                ["count"] = Badge.CountProperty,
            },
            content: (badge, inner) => badge.Inner = inner);

        // The RatingBar's one value is DECLARED rather than applied by hand:
        // a BindableProperty in `properties` is assigned by the renderer
        // whenever a message carries it, and joins the table animations
        // resolve through - which is what lets a Swift handle
        // animate(.rating, to: 5, …) this control like any built-in. See
        // Swift/Samples/Interop/CustomBindingSample.swift and
        // CustomAnimationSample.swift.
        StateUIControls.Add("Gallery.RatingBar",
            create: raise =>
            {
                var stars = new RatingBar();
                stars.RatingChanged += (_, rating) =>
                    raise(stars, "ratingChanged", SwiftWireValue.Of(rating));
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
