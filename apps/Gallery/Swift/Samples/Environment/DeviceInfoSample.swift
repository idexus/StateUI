import StateUI

/// MAUI: DeviceInfo and AppInfo - the two providers whose facts mostly stand
/// still: what machine this is, and what app this is.
struct DeviceInfoSample: SampleContent {
    /// The machine's facts - the idiom is the one the gallery itself builds
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

            var content: Element {
                VStack {
                    Label("\\(app.name) \\(app.versionString) "
                        + "(\\(app.buildString))")
                    Label(app.packageName)

                    Label("\\(device.manufacturer) \\(device.model)")
                    Label("\\(device.platform) \\(device.versionString) · "
                        + "\\(device.idiom) · \\(device.deviceType)")

                    if device.idiom == .desktop {
                        Label("wide enough for a second column")
                    }
                }
            }
        }
        """

    var content: Element {
        VStack {
            Label("\(app.name) \(app.versionString) (\(app.buildString))")
                .fontSize(22)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label(app.packageName)
                .fontSize(15)

            Label("device · \(device.manufacturer) \(device.model)")
                .fontSize(15)
            Label("system · \(device.platform) \(device.versionString)")
                .fontSize(15)
            Label("idiom · \(device.idiom), \(device.deviceType)")
                .fontSize(15)
            Label("name · \(device.name.isEmpty ? "not said" : device.name)")
                .fontSize(15)
        }
        .spacing(10)
    }

    var notes: Element? {
        VStack {
            Label("The idiom is the value this gallery itself builds by: the "
                + "window wears a title bar and lists the TitleBar sample only "
                + "where device.idiom answers .desktop. It is pushed BEFORE "
                + "the first render, so the first tree already knows - which "
                + "pages exist is decided while the tree is built, and an act "
                + "could only answer a handler.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Headless - a test, a host that could not say - everything "
                + "here answers its default, .unknown included, which the "
                + "catalog reads as \"show everything\".")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(10)
    }
}
