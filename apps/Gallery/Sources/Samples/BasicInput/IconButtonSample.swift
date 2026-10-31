import StateUI

/// Two buttons standing for their picture alone, each drawn once per theme, and one whose picture stands beside its
/// words.
struct IconButtonSample: SampleContent, ExampleContent {
    // listing: IconButtonSample
    @State private var taps = 0
    @State private var pressed = false
    @State private var side = IconPosition.start
    @State private var gap = 8.0
    @State private var wide = false
    @State private var words = true

    static let sides: [IconPosition] = [.start, .top, .end, .bottom]
    // listing: end

    static let id = "iconButton"
    static let title = "Icon button"
    static let summary = "A button that is a picture, and one whose picture stands beside its words."

    // listing: IconButtonSample
    var body: some View {
        VStack {
            // The count is read here, so a press builds this closure again.
            DebugInfoLabel()

            HStack {
                // Its words name it to a screen reader; the picture stands alone.
                Button("Media")
                    .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                    .showsText(false)
                    .style(.iconButton)
                    .contentMode(.fit)
                    .width(64)
                    .height(64)
                    .padding(12)
                    .stroke(Palette.outline)
                    .lineWidth(1)
                    .shape(.roundedRectangle(12))
                    .onClicked { taps += 1 }
                    .onPressed { pressed = true }
                    .onReleased { pressed = false }

                Button("Layout")
                    .icon(ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                    .showsText(false)
                    .style(.iconButton)
                    .contentMode(.fit)
                    .width(64)
                    .height(64)
                    .padding(12)
                    .background(Palette.accent)
                    .shape(.roundedRectangle(32))
                    .onClicked { taps += 1 }
            }
            .spacing(12)
            .horizontalAlignment(.center)

            Text(pressed ? "Held down" : "Tapped \(taps) time\(taps == 1 ? "" : "s")")
                .fontSize(14)
                .horizontalAlignment(.center)

            // Words and a picture: the picture on the side chosen, the gap
            // between them as the slider says - together, however wide.
            Button("Media")
                .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                .showsText($words)
                .iconPosition(side)
                .iconSpacing(gap)
                .horizontalAlignment(wide ? .fill : .center)
                .onClicked { taps += 1 }

            Picker(Self.sides, selection: $side) { "\($0)".titled }
                .placeholder("Picture")
                .horizontalAlignment(.center)

            Slider($gap)
                .minimum(0)
                .maximum(24)

            SwitchRow("Full width", $wide)
            SwitchRow("Its words", $words)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        VStack {
            Text("A button standing for its picture keeps its words: `.showsText(false)` leaves "
                + "them out of sight, and they still name it to a screen reader. Its picture can "
                + "be drawn once per theme, like any other, which is what these two are.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Text("It is a button, not an `Image` with a tap recognizer on it: that gives no "
                + "pressed state, no outline and no shape.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
