import StateUI

/// The screen, its density and which way it is turned.
struct DeviceDisplaySample: SampleContent, ExampleContent {
    // listing: DeviceDisplaySample
    /// The main display, as the host measures it.
    @Environment(\.device) var device
    // listing: end

    static let id = "deviceDisplay"
    static let title = "Display"
    static let summary = "The screen in pixels and points, and which way it "
        + "is turned - live through a rotation."

    // listing: DeviceDisplaySample
    var body: some View {
        VStack {
            // The display is read here, so each change the host reports
            // builds this closure.
            DebugInfoLabel()

            Text("\(Int(device.display.width)) × \(Int(device.display.height)) px")
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Text(device.display.density > 0
                ? "\(Int(device.display.width / device.display.density)) × "
                    + "\(Int(device.display.height / device.display.density)) pt at "
                    + "\(device.display.density)x"
                : "density not said")
                .fontSize(15)

            Text("orientation · \(device.display.orientation)")
                .fontSize(15)
            Text("rotation · \(device.display.rotation)")
                .fontSize(15)
            Text(device.display.refreshRate > 0
                ? "refresh · \(Int(device.display.refreshRate)) Hz"
                : "refresh · not said")
                .fontSize(15)
        }
        .spacing(10)
    }
    // listing: end

    var notes: (any View)? {
        Text("The host measures the screen in PIXELS; a layout speaks "
            + "points, which is width divided by density. Rotate a phone "
            + "and four values above move in one push - orientation, "
            + "rotation, and the width and height swapping places. A "
            + "desktop answers by its screen's shape: landscape unless it "
            + "is taller than wide.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
