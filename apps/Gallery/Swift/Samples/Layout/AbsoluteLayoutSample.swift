import StateUI

/// MAUI: AbsoluteLayout.
struct AbsoluteLayoutSample: SampleContent {
    @State private var proportional = true

    static let id = "absoluteLayout"
    static let title = "AbsoluteLayout"
    static let summary = "Each child exactly where it is told - in device units, or as a fraction of the layout."

    static let code = """
        @State private var proportional = true

        VStack {
            AbsoluteLayout {
                // 1 by 1 with .all means "as big as the layout", whatever the
                // layout turns out to be.
                BoxView(Palette.outline)
                    .absoluteLayoutBounds(Rect(0, 0, 1, 1))
                    .absoluteLayoutFlags(.all)

                Marker(text: "0, 0", color: "#E53935")
                    .absoluteLayoutBounds(bounds(x: 0, y: 0))
                    .absoluteLayoutFlags(flags)

                Marker(text: "middle", color: "#1E88E5")
                    .absoluteLayoutBounds(bounds(x: 0.5, y: 0.5))
                    .absoluteLayoutFlags(flags)

                Marker(text: "1, 1", color: "#00897B")
                    .absoluteLayoutBounds(bounds(x: 1, y: 1))
                    .absoluteLayoutFlags(flags)
            }
            .heightRequest(180)

            SwitchRow("Position: proportional", $proportional)
        }

        /// The size is left to the child either way - that is what AutoSize is.
        private func bounds(x: Double, y: Double) -> Rect {
            Rect(
                x: proportional ? x : x * 140,
                y: proportional ? y : y * 120,
                width: AbsoluteLayout.autoSize,
                height: AbsoluteLayout.autoSize)
        }

        private var flags: AbsoluteLayoutFlags {
            proportional ? .positionProportional : .none
        }
        """

    var content: Element {
        VStack {
            AbsoluteLayout {
                // The whole area, as a fraction of it: 1 by 1 with .all means
                // "as big as the layout", whatever the layout turns out to be.
                BoxView(Palette.outline)
                    .absoluteLayoutBounds(Rect(0, 0, 1, 1))
                    .absoluteLayoutFlags(.all)

                Marker(text: "0, 0", color: "#E53935")
                    .absoluteLayoutBounds(bounds(x: 0, y: 0))
                    .absoluteLayoutFlags(flags)

                Marker(text: "middle", color: "#1E88E5")
                    .absoluteLayoutBounds(bounds(x: 0.5, y: 0.5))
                    .absoluteLayoutFlags(flags)

                Marker(text: "1, 1", color: "#00897B")
                    .absoluteLayoutBounds(bounds(x: 1, y: 1))
                    .absoluteLayoutFlags(flags)
            }
            .heightRequest(180)

            SwitchRow("Position: proportional", $proportional)
                .horizontalOptions(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The flags decide how the four numbers are read. A proportional 1 is the "
                + "far edge, and the layout keeps the child inside itself; the same 1 in "
                + "device units is one pixel from the left.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("A size of AbsoluteLayout.autoSize is MAUI's AutoSize: the child measures "
                + "itself, and only its position is dictated.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// The bounds for one marker, in whichever way the switch is set. The size
    /// is left to the child either way - which is what AutoSize means.
    private func bounds(x: Double, y: Double) -> Rect {
        Rect(
            x: proportional ? x : x * 140,
            y: proportional ? y : y * 120,
            width: AbsoluteLayout.autoSize,
            height: AbsoluteLayout.autoSize)
    }

    private var flags: AbsoluteLayoutFlags {
        proportional ? .positionProportional : .none
    }
}

/// One labelled marker, so the sample says what is being positioned rather than
/// how it is drawn.
private struct Marker: ContentView {
    let text: String
    let color: String

    var content: Element {
        Label(text)
            .fontSize(12)
            .textColor(.white)
            .backgroundColor(Color.fromArgb(color))
            .padding(10, 6)
    }
}
