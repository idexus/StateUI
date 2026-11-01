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

    /// Listed where the host reports it: one that says nothing of it would show placeholders alone.
    static func shows(_ device: Device) -> Bool { device.display.width != nil }

    // listing: DeviceDisplaySample
    var body: some View {
        VStack {
            // The display is read here, so each change the host reports
            // builds this closure.
            DebugInfoLabel()

            Text("\(Int(device.display.width ?? 0)) × \(Int(device.display.height ?? 0)) px")
                .fontSize(28)
                .fontWeight(.bold)
                .horizontalTextAlignment(.center)

            Text(device.display.density.map { density in
                "\(Int((device.display.width ?? 0) / density)) × "
                    + "\(Int((device.display.height ?? 0) / density)) pt at \(density)x"
            } ?? "density not said")
                .fontSize(15)

            Text("orientation · \(device.display.orientation)")
                .fontSize(15)
            Text("rotation · \(device.display.rotation)")
                .fontSize(15)
            Text(device.display.refreshRate.map { "refresh · \(Int($0)) Hz" } ?? "refresh · not said")
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
