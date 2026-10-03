import StateUI

/// The screen, its density and which way it is turned.
struct DeviceDisplaySample: SampleContent, ExampleContent {
    /// The main display, as the host measures it.
    @Environment(\.device) var device

    static let id = "deviceDisplay"
    static let title = "Display"
    static let summary = "The screen in pixels and points, and which way it "
        + "is turned - live through a rotation."

    static let code = """
        struct DisplayBadge: View {
            @Environment(\\.device) var device

            var body: some View {
                VStack {
                    // The display is read here, so a turn or a resize builds
                    // this closure.
                    DebugInfoLabel()

                    Text("\\(Int(device.display.width)) × \\(Int(device.display.height)) px")

                    Text(device.display.density > 0
                        ? "\\(Int(device.display.width / device.display.density)) × "
                            + "\\(Int(device.display.height / device.display.density)) pt "
                            + "at \\(device.display.density)x"
                        : "density not said")

                    Text("\\(device.display.orientation) · \\(device.display.rotation)")

                    Text(device.display.refreshRate > 0
                        ? "\\(Int(device.display.refreshRate)) Hz"
                        : "refresh not said")
                }
            }
        }
        """

    var body: some View {
        VStack {
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

    var notes: (any View)? {
        Text("The host measures the screen in PIXELS; a layout speaks "
            + "points, which is width divided by density. Rotate a phone "
            + "and every number above moves in one push - orientation, "
            + "rotation, and the width and height swapping places. A "
            + "desktop usually answers `.unknown` for both, its window "
            + "being the thing that turns.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
