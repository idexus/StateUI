import StateUI

/// DeviceInfo and AppInfo - the two providers whose facts mostly stand still:
/// what machine this is, and what app this is.
struct DeviceInfoSample: SampleContent, ExampleContent {
    /// The machine's facts - the formFactor is the one the gallery itself builds
    /// by, listing desktop chrome only where it draws.
    @Environment var device: DeviceInfo

    /// The app's facts, from its own manifest.
    @Environment var app: AppInfo

    static let id = "deviceInfo"
    static let title = "DeviceInfo & AppInfo"
    static let summary = "What machine this is and what app this is - the "
        + "facts a layout branches on."

    static let code = """
        struct AboutBox: ContentView {
            @Environment var device: DeviceInfo
            @Environment var app: AppInfo

            var content: some View {
                VStack {
                    // The device never changes, so this stands at one build.
                    DebugInfoLabel()

                    Text("\\(app.name) \\(app.versionString) "
                        + "(\\(app.buildString))")
                    Text(app.packageName)

                    Text("\\(device.manufacturer) \\(device.model)")
                    Text("\\(device.platform) \\(device.versionString) · "
                        + "\\(device.formFactor) · \\(device.deviceType)")
                    Text(device.name.isEmpty ? "not said" : device.name)
                }
            }
        }
        """

    var content: some View {
        VStack {
            DebugInfoLabel()

            Text("\(app.name) \(app.versionString) (\(app.buildString))")
                .fontSize(22)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text(app.packageName)
                .fontSize(15)

            Text("device · \(device.manufacturer) \(device.model)")
                .fontSize(15)
            Text("system · \(device.platform) \(device.versionString)")
                .fontSize(15)
            Text("formFactor · \(device.formFactor), \(device.deviceType)")
                .fontSize(15)
            Text("name · \(device.name.isEmpty ? "not said" : device.name)")
                .fontSize(15)
        }
        .spacing(10)
    }

    var notes: (any View)? {
        VStack {
            Text("The formFactor is the value this gallery itself builds by: the "
                + "menu stands beside the page where device.formFactor answers "
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
