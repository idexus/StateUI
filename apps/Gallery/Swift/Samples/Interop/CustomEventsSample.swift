import StateUI

/// The events the gallery's MauiProgram raises on its own schedule - the
/// app's tokens, the acts pattern on the push channel.
extension Event {
    /// The battery reported - level and whether it is charging.
    /// C#: Battery.Default.BatteryInfoChanged.
    static let batteryChanged = Event("Gallery.BatteryChanged")

    /// The network came or went. C#: Connectivity.ConnectivityChanged.
    static let connectivityChanged = Event("Gallery.ConnectivityChanged")
}

/// The host speaks FIRST: an event C# raises with no control behind it,
/// heard by name - the push half of the interop surface, sister to the
/// registered acts.
struct CustomEventsSample: SampleContent {
    @State private var battery = "the host has not spoken yet"
    @State private var network = "the host has not spoken yet"
    @State private var log: [String] = []
    @State private var heard: [HostEventSubscription] = []

    static let id = "custom-events"
    static let title = "Hearing from C#"
    static let summary = "Events C# raises on its own - no control behind them, heard by name."

    static let code = """
        // Every other event belongs to an element of the tree. What the
        // host pushes on its own - the battery, the network - has none, so
        // it is heard by NAME, with the app's own tokens:
        extension Event {
            static let batteryChanged = Event("Gallery.BatteryChanged")
            static let connectivityChanged = Event("Gallery.ConnectivityChanged")
        }

        @State private var battery = "the host has not spoken yet"
        @State private var network = "the host has not spoken yet"
        @State private var heard: [HostEventSubscription] = []

        VStack {
            Label("battery: \\(battery)")
            Label("network: \\(network)")
        }
        // Subscribed for exactly as long as the page is on screen - the
        // lifecycle pair, the same road a clock's loop takes.
        .onLoaded {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(.batteryChanged) { payload in
                    if let level = payload.value()?.number {
                        let charging = payload.value(1)?.bool == true
                        battery = "\\(Int(level * 100))%"
                            + (charging ? ", charging" : "")
                    }
                },
                HostEvents.on(.connectivityChanged) { payload in
                    network = payload.value()?.bool == true
                        ? "online" : "offline"
                },
            ]
        }
        .onUnloaded {
            heard.forEach { $0.cancel() }
            heard = []
        }
        """

    /// The other half, in MauiProgram.CreateMauiApp: the sources wired once,
    /// raising by name. Safe from any thread - the session marshals - and a
    /// raise nobody is listening to is an ordinary answer, so the wiring is
    /// unconditional.
    static let codeCSharp = """
        Battery.Default.BatteryInfoChanged += (_, e) =>
            StateUIEvents.Raise("Gallery.BatteryChanged",
                SwiftWireValue.Of(e.ChargeLevel),
                SwiftWireValue.Of(e.State == BatteryState.Charging));

        Connectivity.Current.ConnectivityChanged += (_, e) =>
            StateUIEvents.Raise("Gallery.ConnectivityChanged",
                SwiftWireValue.Of(e.NetworkAccess == NetworkAccess.Internet));

        // Android also wants ACCESS_NETWORK_STATE declared in the manifest
        // for Connectivity to read the network state; the gallery's says so.
        """

    var content: Element {
        VStack {
            Label("battery: \(battery)")
                .fontSize(17)

            Label("network: \(network)")
                .fontSize(17)

            Label(log.isEmpty
                ? "LISTENING - now make the host speak: plug or unplug the "
                    + "power, or turn Wi-Fi off and on. A phone answers both "
                    + "at once; a desktop wired to Ethernet may stay silent, "
                    + "its reachability unmoved by the Wi-Fi switch and its "
                    + "battery with nothing to report."
                : log.suffix(4).joined(separator: "\n"))
                .fontSize(13)
                .textColor(Palette.subtle)

            Label("Nothing here polls and nothing ticks: C# raises "
                + "StateUIEvents.Raise when ITS event fires, the name finds "
                + "every HostEvents.on subscription, and the handlers run like "
                + "any control's - on the library's executor, free to await, "
                + "writing @State. The pair in onLoaded/onUnloaded scopes the "
                + "listening to the page being on screen; a raise nobody hears "
                + "is an ordinary answer, not an error.")
                .fontSize(14)
                .textColor(Palette.subtle)
        }
        .spacing(8)
        .onLoaded {
            heard.forEach { $0.cancel() }
            heard = [
                HostEvents.on(.batteryChanged) { payload in
                    if let level = payload.value()?.number {
                        let charging = payload.value(1)?.bool == true
                        battery = "\(Int(level * 100))%" + (charging ? ", charging" : "")
                        log.append("\(log.count + 1). battery spoke: \(battery)")
                    }
                },
                HostEvents.on(.connectivityChanged) { payload in
                    network = payload.value()?.bool == true ? "online" : "offline"
                    log.append("\(log.count + 1). network spoke: \(network)")
                },
            ]
        }
        .onUnloaded {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }
}
