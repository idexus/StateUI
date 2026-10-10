import StateUI

/// The device's and the application's `info` - the facts that mostly stand
/// still: what machine this is, and what app this is.
struct DeviceInfoSample: SampleContent, ExampleContent {
    // listing: DeviceInfoSample
    /// The machine's facts - the formFactor among them, which this gallery
    /// itself builds by.
    @Environment(\.device) var device

    /// The app's facts, from its own manifest.
    @Environment(\.application) var app
    // listing: end

    static let id = "deviceInfo"
    static let title = "Device and app facts"
    static let summary = "What machine this is and what app this is - the "
        + "facts a layout branches on."

    // listing: DeviceInfoSample
    var body: some View {
        VStack {
            // These facts stand still, so this closure stands at one build.
            DebugInfoLabel()

            Text("\(app.info.name) \(app.info.versionString) (\(app.info.buildString))")
                .fontSize(22)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text(app.info.packageName)
                .fontSize(15)

            Text("device · \(device.info.manufacturer) \(device.info.model)")
                .fontSize(15)
            Text("system · \(device.info.platform) \(device.info.versionString)")
                .fontSize(15)
            Text("formFactor · \(device.info.formFactor), \(device.info.deviceType)")
                .fontSize(15)
            Text("name · \(device.info.name.isEmpty ? "not said" : device.info.name)")
                .fontSize(15)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("The formFactor is the value this gallery itself builds by: a "
                + "desktop leaves the menu open after a choice, and the Multi-window "
                + "sample is listed only where a second window has room. It is known "
                + "BEFORE the first render, so the first tree already has it - which "
                + "pages exist is decided while the tree is built.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("Headless - a test, a host that could not say - everything "
                + "here answers its default, .unknown included, which the "
                + "catalog reads as \"show everything\".")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
