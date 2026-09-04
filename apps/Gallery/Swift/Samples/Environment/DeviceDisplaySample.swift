import StateUI

/// MAUI: DeviceDisplay - the screen, its density and which way it is turned.
struct DeviceDisplaySample: SampleContent {
    /// The main display, as MAUI measures it.
    @Environment var display: DeviceDisplay

    static let id = "deviceDisplay"
    static let title = "DeviceDisplay"
    static let summary = "The screen in pixels and points, and which way it "
        + "is turned - live through a rotation."

    static let code = """
        struct DisplayBadge: ContentView {
            @Environment var display: DeviceDisplay

            var content: Element {
                VStack {
                    Label("\\(Int(display.width)) × \\(Int(display.height)) px")

                    Label(display.density > 0
                        ? "\\(Int(display.width / display.density)) × "
                            + "\\(Int(display.height / display.density)) pt "
                            + "at \\(display.density)x"
                        : "density not said")

                    Label("\\(display.orientation) · \\(display.rotation)")

                    if display.refreshRate > 0 {
                        Label("\\(Int(display.refreshRate)) Hz")
                    }
                }
            }
        }
        """

    var example: Element {
        VStack {
            Label("\(Int(display.width)) × \(Int(display.height)) px")
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalTextAlignment(.center)

            Label(display.density > 0
                ? "\(Int(display.width / display.density)) × "
                    + "\(Int(display.height / display.density)) pt at "
                    + "\(display.density)x"
                : "density not said")
                .fontSize(15)

            Label("orientation · \(display.orientation)")
                .fontSize(15)
            Label("rotation · \(display.rotation)")
                .fontSize(15)
            Label(display.refreshRate > 0
                ? "refresh · \(Int(display.refreshRate)) Hz"
                : "refresh · not said")
                .fontSize(15)
        }
        .spacing(10)
    }

    var notes: Element? {
        Label("MAUI measures the screen in PIXELS; a layout speaks "
            + "points, which is width divided by density. Rotate a phone "
            + "and every number above moves in one push - orientation, "
            + "rotation, and the width and height swapping places. A "
            + "desktop usually answers .unknown for both, its window "
            + "being the thing that turns.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
