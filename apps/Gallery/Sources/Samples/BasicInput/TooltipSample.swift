import StateUI

/// Words a view shows while the pointer rests on it: two icon buttons and a swatch, their words short or detailed.
struct TooltipSample: SampleContent, ExampleContent {
    // listing: TooltipSample
    @State private var detailed = false
    // listing: end

    static let id = "tooltip"
    static let title = "Tooltip"
    static let summary = "Words a view shows while the pointer rests on it."

    /// Listed where the host shows tooltips: an iPhone and an iPad show none.
    static func shows(_ device: Device) -> Bool { device.honors(VisualElementContract.tooltip) }

    // listing: TooltipSample
    var body: some View {
        VStack {
            Text("Rest the pointer on a button or on the swatch.")
                .fontSize(14)

            HStack {
                // A button that is only a picture says what it does
                // to the eye under the pointer.
                Button(icon: ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                    .style(.iconButton)
                    .contentMode(.fit)
                    .width(48)
                    .height(48)
                    .padding(10)
                    .accessibilityLabel("Media")
                    .tooltip(detailed ? "Opens the pictures, films and sounds" : "Media")

                Button(icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                    .style(.iconButton)
                    .contentMode(.fit)
                    .width(48)
                    .height(48)
                    .padding(10)
                    .accessibilityLabel("Layout")
                    .tooltip(detailed ? "Opens the stacks, grids and placement" : "Layout")

                // Any view takes one, not only a control.
                Rectangle()
                    .fill(Palette.accent)
                    .width(48)
                    .height(48)
                    .tooltip(detailed ? "The color the gallery marks things with" : "Accent")
            }
            .spacing(12)

            Switch($detailed)
                .text("Detailed")
                .accessibilityIdentifier("tooltip.detailed")
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("Android shows one after a long press too.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
