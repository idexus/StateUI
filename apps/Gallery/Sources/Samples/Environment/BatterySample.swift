import StateUI

/// The host's battery - the device's, read by name: `device.battery`.
struct BatterySample: SampleContent, ExampleContent {
    // listing: BatterySample
    /// The device, by its name: nothing is passed anywhere, and the host keeps
    /// its battery current.
    @Environment(\.device) var device
    // listing: end

    static let id = "battery"
    static let title = "Battery"
    static let summary = "The host's battery, provided to every view - level, "
        + "state, source and the saver."

    // listing: BatterySample
    var body: some View {
        VStack {
            // The battery is read here, so a change the host reports
            // builds this closure - and nothing else on the page.
            DebugInfoLabel()

            Text(device.battery.chargeLevel <= 0
                ? "the host has not said"
                : "\(Int(device.battery.chargeLevel * 100))%")
                .fontSize(34)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text("state · \(device.battery.state)")
                .fontSize(15)
            Text("source · \(device.battery.powerSource)")
                .fontSize(15)
            Text("saver · \(device.battery.energySaverStatus)")
                .fontSize(15)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("Reading a property is the whole subscription: the host "
                + "pushes each change the platform reports, and exactly the "
                + "views that read the battery are rebuilt. On Android, try "
                + "`adb shell dumpsys battery set level 50`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("A host that cannot observe a battery leaves the level at -1, "
                + "read here as \"the host has not said\", and the other "
                + "values at `.unknown`.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
