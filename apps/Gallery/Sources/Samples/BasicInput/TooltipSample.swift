import StateUI

/// Words a view shows while the pointer rests on it: two icon buttons and a swatch, their words short or detailed.
struct TooltipSample: SampleContent, ExampleContent {
    // listing: TooltipSample
    @State private var detailed = false
    // listing: end

    static let id = "tooltip"
    static let title = "Tooltip"
    static let summary = "Words a view shows while the pointer rests on it."

    // listing: TooltipSample
    var body: some View {
        VStack {
            Text("Rest the pointer on a button or on the swatch.")
                .fontSize(14)

            HStack {
                // A button that is a picture names itself twice: to a
                // screen reader, and to the eye under the pointer.
                Button(icon: ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                    .style(.iconButton)
                    .contentMode(.fit)
                    .width(48)
                    .height(48)
                    .padding(10)
                    .accessibilityLabel("Media")   // listing: keep
                    .tooltip(detailed ? "Opens the pictures, films and sounds" : "Media")

                Button(icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                    .style(.iconButton)
                    .contentMode(.fit)
                    .width(48)
                    .height(48)
                    .padding(10)
                    .accessibilityLabel("Layout")   // listing: keep
                    .tooltip(detailed ? "Opens the stacks, grids and placement" : "Layout")

                // Any view takes one, not only a control.
                ColorBox(Palette.accent)
                    .width(48)
                    .height(48)
                    .tooltip(detailed ? "The colour the gallery marks things with" : "Accent")
            }
            .spacing(12)

            HStack {
                Switch($detailed)
                    .accessibilityIdentifier("tooltip.detailed")
                    .accessibilityLabel("Detailed")

                Text("Detailed")
                    .verticalAlignment(.center)
            }
            .spacing(12)
        }
        .spacing(16)
    }
    // listing: end

    var notes: (any View)? {
        Text("An iPhone and an iPad show no tooltips; Android shows one after a long press too.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
