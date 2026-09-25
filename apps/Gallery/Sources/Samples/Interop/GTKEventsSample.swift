#if GTK
import StateUI

/// Events the host raises on its own, heard with no control behind them.
struct GTKEventsSample: SampleContent, ExampleContent {
    @State private var battery = "not heard yet"
    @State private var log: [String] = []
    @State private var heard: [HostEventSubscription] = []

    static let id = "gtkEvents"
    static let title = "Hearing from GTK"
    static let summary = "Events the host raises on its own, heard with no control behind them."

    static let codeHeading = "In StateUI"

    static let code = """
        // The application's own events, declared beside its acts.
        public enum GalleryContract: ApplicationTier {
            public static let name = "Gallery"

            public static let batteryChanged =
                ElementEvent<Self, (Double, Bool)>("Gallery.BatteryChanged")

            public static let members: [any ContractMember] = [batteryChanged]
        }

        @State private var battery = "not heard yet"
        @State private var log: [String] = []
        @State private var heard: [HostEventSubscription] = []

        VStack {
            // What the host raised is read here, so every raise heard builds
            // this closure.
            DebugInfoLabel()

            Label("battery: \\(battery)")

            Label(log.isEmpty
                ? "Plug or unplug the power."
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
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
        """

    static let hostCode = HostCode(
        heading: "In GTK",
        language: .swift,
        code: """
            // Platforms/GTK/Host/GalleryEventSources.swift. Raising is safe
            // from any thread, and a raise nobody hears is an ordinary answer,
            // so the source is wired unconditionally.
            enum GalleryEventSources {
                @MainActor
                static func start() {
                    // What the host raises, declared where its source is
                    // wired: a handler listening for anything else is told.
                    StateUIEvents.raises(GalleryContract.batteryChanged)

                    // UPower's display device tells every change of the
                    // battery; a C callback carries no context, so the report
                    // is named in full.
                    guard let device = GalleryPower.device else { return }
                    let changed: @convention(c) (
                        OpaquePointer?, OpaquePointer?, OpaquePointer?, gpointer?
                    ) -> Void = { _, _, _, _ in
                        MainActor.assumeIsolated { GalleryEventSources.report() }
                    }
                    g_signal_connect_data(
                        UnsafeMutableRawPointer(device), "g-properties-changed",
                        unsafeBitCast(changed, to: GCallback.self), nil, nil, GConnectFlags(0))
                    report()
                }

                @MainActor
                private static func report() {
                    let (level, charging) = GalleryPower.battery()

                    // UPower tells more than a level change, so an unchanged
                    // reading raises nothing.
                    guard level > 0 else { return }
                    guard lastSaid?.level != level || lastSaid?.charging != charging else { return }

                    lastSaid = (level, charging)
                    StateUIEvents.raise(GalleryContract.batteryChanged, level, charging)
                }
            }

            // And in main.swift, before StateUIGTK.run(applicationID:):
            GalleryEventSources.start()
            """)

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label("battery: \(battery)")
                .fontSize(17)

            Label(log.isEmpty
                ? "Plug or unplug the power."
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
            ]
        }
        .onDestroying {
            heard.forEach { $0.cancel() }
            heard = []
        }
    }

    var notes: Element? {
        VStack {
            Label("The host calls `StateUIEvents.raise(event, values)` when the platform "
                + "reports something, from any thread. Every `HostEvents.on` subscription "
                + "to that member runs like a control's handler: on the library's "
                + "executor, handed the values the contract declares, free to await and to "
                + "write `@State`. The head declares each event it raises with "
                + "`StateUIEvents.raises`, so a handler listening for one nothing raises "
                + "is told so once.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The subscriptions are made in `.onCreated` and cancelled in "
                + "`.onDestroying`, so the page listens while it is in the tree. A raise "
                + "nobody hears is an ordinary answer, so the host wires its sources "
                + "unconditionally.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A desktop with no battery reports nothing at all, and that is the "
                + "honest answer rather than a failure: this page then keeps saying it "
                + "has not heard.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
#endif
