import StateUI

/// The device's and the application's `info` - the facts that mostly stand
/// still: what machine this is, and what app this is.
struct DeviceInfoSample: SampleContent, ExampleContent {
    /// The machine's facts - the formFactor is the one the gallery itself builds
    /// by, listing desktop chrome only where it draws.
    @Environment(\.device) var device

    /// The app's facts, from its own manifest.
    @Environment(\.application) var app

    static let id = "deviceInfo"
    static let title = "Device and app facts"
    static let summary = "What machine this is and what app this is - the "
        + "facts a layout branches on."

    static let code = """
        struct AboutBox: View {
            @Environment(\\.device) var device
            @Environment(\\.application) var app

            var body: some View {
                VStack {
                    // The device never changes, so this stands at one build.
                    DebugInfoLabel()

                    Text("\\(app.info.name) \\(app.info.versionString) "
                        + "(\\(app.info.buildString))")
                    Text(app.info.packageName)

                    Text("\\(device.info.manufacturer) \\(device.info.model)")
                    Text("\\(device.info.platform) \\(device.info.versionString) · "
                        + "\\(device.info.formFactor) · \\(device.info.deviceType)")
                    Text(device.info.name.isEmpty ? "not said" : device.info.name)
                }
            }
        }
        """

    var body: some View {
        VStack {
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

    var notes: (any View)? {
        VStack {
            Text("The formFactor is the value this gallery itself builds by: the "
                + "menu stands beside the page where device.info.formFactor answers "
                + ".desktop, and the Multi-window sample is listed only where a "
                + "second window has room. It is known BEFORE the first render, "
                + "so the first tree already has it - which pages exist is "
                + "decided while the tree is built.")
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
