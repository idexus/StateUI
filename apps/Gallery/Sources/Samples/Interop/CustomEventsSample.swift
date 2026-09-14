#if MAUI
import StateUI

/// The events MauiProgram raises on its own schedule, with no control behind
/// them.
extension Event {
    /// The battery reported: its level and whether it is charging.
    /// C#: `Battery.Default.BatteryInfoChanged`.
    static let batteryChanged = Event("Gallery.BatteryChanged")

    /// The network came or went. C#: `Connectivity.ConnectivityChanged`.
    static let connectivityChanged = Event("Gallery.ConnectivityChanged")
}

/// Events C# raises with no control behind them, heard by name.
struct CustomEventsSample: SampleContent, ExampleContent {
    @State private var battery = "not heard yet"
    @State private var network = "not heard yet"
    @State private var log: [String] = []
    @State private var heard: [HostEventSubscription] = []

    static let id = "customEvents"
    static let title = "Hearing from C#"
    static let summary = "Events C# raises on its own, heard by name with no control behind them."

    static let code = """
        extension Event {
            static let batteryChanged = Event("Gallery.BatteryChanged")
            static let connectivityChanged = Event("Gallery.ConnectivityChanged")
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
                HostEvents.on(.batteryChanged) { payload in
                    if let level = payload.value()?.number {
                        let charging = payload.value(1)?.bool == true
                        battery = "\\(Int(level * 100))%" + (charging ? ", charging" : "")
                        log.append("\\(log.count + 1). battery: \\(battery)")
                    }
                },
                HostEvents.on(.connectivityChanged) { payload in
                    network = payload.value()?.bool == true ? "online" : "offline"
                    log.append("\\(log.count + 1). network: \\(network)")
                },
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
        """

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
                HostEvents.on(.batteryChanged) { payload in
                    if let level = payload.value()?.number {
                        let charging = payload.value(1)?.bool == true
                        battery = "\(Int(level * 100))%" + (charging ? ", charging" : "")
                        log.append("\(log.count + 1). battery: \(battery)")
                    }
                },
                HostEvents.on(.connectivityChanged) { payload in
                    network = payload.value()?.bool == true ? "online" : "offline"
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
                + "name runs like a control's handler: on the library's executor, free "
                + "to await and to write `@State`.")
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
