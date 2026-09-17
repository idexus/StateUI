#if MAUI
import StateUI

/// Events C# raises with no control behind them, heard through the
/// application's contract.
struct CustomEventsSample: SampleContent, ExampleContent {
    @State private var battery = "not heard yet"
    @State private var network = "not heard yet"
    @State private var log: [String] = []
    @State private var heard: [HostEventSubscription] = []

    static let id = "customEvents"
    static let title = "Hearing from C#"
    static let summary = "Events C# raises on its own, heard with no control behind them."

    static let code = """
        // The application's own acts and events, with no control behind them.
        enum GalleryContract: ApplicationTier {
            static let name = "Gallery"

            static let setClipboard = ElementAct<Self, String, Void>("Gallery.SetClipboard")
            static let readClipboard = ElementAct<Self, Void, String>("Gallery.ReadClipboard")
            static let batteryLevel = ElementAct<Self, Void, (Double, Bool)>("Gallery.BatteryLevel")
            static let nobody = ElementAct<Self, Void, Void>("Gallery.Nobody")

            static let batteryChanged = ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")
            static let connectivityChanged = ElementEvent<Self, Bool>("Gallery.ConnectivityChanged")

            static let members: [any ContractMember] = [
                setClipboard, readClipboard, batteryLevel, nobody, batteryChanged, connectivityChanged,
            ]
        }

        @State private var battery = "not heard yet"
        @State private var network = "not heard yet"
        @State private var log: [String] = []
        @State private var heard: [HostEventSubscription] = []

        VStack {
            // What the host raised is read here, so every raise heard builds
            // this closure.
            DebugInfoLabel()

            Label("battery: \\(battery)")
            Label("network: \\(network)")

            Label(log.isEmpty
                ? "Plug or unplug the power, or turn Wi-Fi off and on."
                : log.suffix(4).joined(separator: "\\n"))
        }
        // Listening for exactly as long as the view is in the tree.
        .onCreated {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(GalleryContract.batteryChanged) { level, charging in
                    battery = "\\(Int(level * 100))%" + (charging ? ", charging" : "")
                    log.append("\\(log.count + 1). battery: \\(battery)")
                },
                HostEvents.on(GalleryContract.connectivityChanged) { online in
                    network = online ? "online" : "offline"
                    log.append("\\(log.count + 1). network: \\(network)")
                },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
        """

    static let hostCode = HostCode(
        heading: "In C#",
        language: .csharp,
        code: """
            // In MauiProgram.CreateMauiApp. Raising is safe from any thread,
            // and a raise nobody hears is an ordinary answer, so the sources
            // are wired unconditionally.
            Battery.Default.BatteryInfoChanged += (_, e) =>
                StateUIEvents.Raise("Gallery.BatteryChanged",
                    HostValue.Of(e.ChargeLevel),
                    HostValue.Of(e.State == BatteryState.Charging));

            Connectivity.Current.ConnectivityChanged += (_, e) =>
                StateUIEvents.Raise("Gallery.ConnectivityChanged",
                    HostValue.Of(e.NetworkAccess == NetworkAccess.Internet));

            // Android also wants ACCESS_NETWORK_STATE declared in its manifest
            // for Connectivity to read the network state; the gallery's says so.
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("battery: \(battery)")
                .fontSize(17)

            Label("network: \(network)")
                .fontSize(17)

            Label(log.isEmpty
                ? "Plug or unplug the power, or turn Wi-Fi off and on."
                : log.suffix(4).joined(separator: "\n"))
                .fontSize(13)
                .textColor(Palette.subtle)
        }
        .spacing(8)
        .onCreated {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(GalleryContract.batteryChanged) { level, charging in
                    battery = "\(Int(level * 100))%" + (charging ? ", charging" : "")
                    log.append("\(log.count + 1). battery: \(battery)")
                },
                HostEvents.on(GalleryContract.connectivityChanged) { online in
                    network = online ? "online" : "offline"
                    log.append("\(log.count + 1). network: \(network)")
                },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }

    var notes: Element? {
        VStack {
            Label("C# calls `StateUIEvents.Raise(name, values)` when its own event "
                + "fires, from any thread. Every `HostEvents.on` subscription to that "
                + "member of `GalleryContract` runs like a control's handler: on the "
                + "library's executor, handed the values the contract declares, free to "
                + "await and to write `@State`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The subscriptions are made in `.onCreated` and cancelled in "
                + "`.onDestroying`, so the page listens while it is in the tree. A "
                + "raise nobody hears is an ordinary answer, so C# wires its sources "
                + "unconditionally.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A phone answers both: on Android, `adb shell dumpsys battery set "
                + "level 50` and `adb shell svc wifi disable`. A desktop on Ethernet "
                + "may stay silent - Wi-Fi does not move its reachability, and it may "
                + "have no battery to report.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
