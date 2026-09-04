import StateUI

/// MAUI: Battery - the standard environment's provider, resolved by type.
struct BatterySample: SampleContent {
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

            var content: Element {
                VStack {
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

    var example: Element {
        VStack {
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
                + "pushes on every BatteryInfoChanged, and exactly the views "
                + "that read the battery are rebuilt. On Android, try "
                + "`adb shell dumpsys battery set level 50` - and note the "
                + "manifest declares BATTERY_STATS, which MAUI checks for.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A DESKTOP does not say the level straight: measured on Mac "
                + "Catalyst, a MacBook at 100% reports ChargeLevel 0.0099 - "
                + "the platform hands over the percentage divided by 100 "
                + "twice - and never fires the change event on mains. Read "
                + "state and source there; the LEVEL is the phones' to "
                + "report.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
