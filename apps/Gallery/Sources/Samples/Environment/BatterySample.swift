import StateUI

/// The host's battery - a standard environment provider, resolved by type.
struct BatterySample: SampleContent, ExampleContent {
    /// The provider itself: nothing is passed anywhere - the type is the key,
    /// and the host keeps the object current.
    @Environment var battery: Battery

    static let id = "battery"
    static let title = "Battery"
    static let summary = "The host's battery, provided to every view - level, "
        + "state, source and the saver."

    static let code = """
        struct BatteryBadge: ContentView {
            @Environment var battery: Battery

            var content: any View {
                VStack {
                    // The battery is read here, so a change the host reports
                    // builds this closure - and nothing else on the page.
                    DebugInfoLabel()

                    Label(battery.chargeLevel <= 0
                        ? "the host has not said"
                        : "\\(Int(battery.chargeLevel * 100))%")

                    Label("state · \\(battery.state)")
                    Label("source · \\(battery.powerSource)")
                    Label("saver · \\(battery.energySaverStatus)")
                }
            }
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Label(battery.chargeLevel <= 0
                ? "the host has not said"
                : "\(Int(battery.chargeLevel * 100))%")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label("state · \(battery.state)")
                .fontSize(15)
            Label("source · \(battery.powerSource)")
                .fontSize(15)
            Label("saver · \(battery.energySaverStatus)")
                .fontSize(15)
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("Reading a property is the whole subscription: the host "
                + "pushes each change the platform reports, and exactly the "
                + "views that read the battery are rebuilt. On Android, try "
                + "`adb shell dumpsys battery set level 50`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A host that cannot observe a battery leaves the level at -1, "
                + "read here as \"the host has not said\", and the other "
                + "values at `.unknown`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
