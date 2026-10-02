import StateUI

/// Two buttons whose content is an icon, each drawn once per theme, and one whose picture stands beside its words.
struct IconButtonSample: SampleContent, ExampleContent {
    @State private var taps = 0
    @State private var pressed = false
    @State private var side = 0
    @State private var gap = 8.0

    static let sides = ["Leading", "Top", "Trailing", "Bottom"]
    static let positions: [IconPosition] = [.leading, .top, .trailing, .bottom]

    static let id = "iconButton"
    static let title = "Icon button"
    static let summary = "A button that is a picture, and one whose picture stands beside its words."

    static let code = """
        @State private var taps = 0
        @State private var pressed = false
        @State private var side = 0
        @State private var gap = 8.0

        static let sides = ["Leading", "Top", "Trailing", "Bottom"]
        static let positions: [IconPosition] = [.leading, .top, .trailing, .bottom]

        VStack {
            // The count is read here, so a press builds this closure again.
            DebugInfoLabel()

            HStack {
                Button(icon: ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                    .style("IconButton")
                    .aspect(.fit)
                    .width(64)
                    .height(64)
                    .stroke(Palette.outline)
                    .strokeWidth(1)
                    .shape(.roundedRectangle(12))
                    .onClicked { taps += 1 }
                    .onPressed { pressed = true }
                    .onReleased { pressed = false }

                Button(icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                    .style("IconButton")
                    .aspect(.fit)
                    .width(64)
                    .height(64)
                    .shape(.roundedRectangle(32))
                    .onClicked { taps += 1 }
            }

            Text(pressed ? "Held down" : "Tapped \\(taps) time\\(taps == 1 ? "" : "s")")

            // Words and a picture: the picture on the side chosen, the gap
            // between them as the slider says.
            Button("Media")
                .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                .iconPosition(Self.positions[side])
                .iconSpacing(gap)
                .onClicked { taps += 1 }

            Picker(Self.sides)
                .selectedIndex($side)
                .title("Picture")

            Slider($gap)
                .minimum(0)
                .maximum(24)
        }
        """

    var content: some View {
        VStack {
            DebugInfoLabel()

            HStack {
                Button(icon: ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                    .style("IconButton")
                    .aspect(.fit)
                    .width(64)
                    .height(64)
                    .padding(12)
                    .stroke(Palette.outline)
                    .strokeWidth(1)
                    .shape(.roundedRectangle(12))
                    .onClicked { taps += 1 }
                    .onPressed { pressed = true }
                    .onReleased { pressed = false }

                Button(icon: ImageSource(light: "nav_layout.png", dark: "nav_layout_dark.png"))
                    .style("IconButton")
                    .aspect(.fit)
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

            Button("Media")
                .icon(ImageSource(light: "nav_media.png", dark: "nav_media_dark.png"))
                .iconPosition(Self.positions[side])
                .iconSpacing(gap)
                .horizontalAlignment(.center)
                .onClicked { taps += 1 }

            Picker(Self.sides)
                .selectedIndex($side)
                .title("Picture")
                .horizontalAlignment(.center)

            Slider($gap)
                .minimum(0)
                .maximum(24)
        }
        .spacing(12)
    }

    var notes: (any View)? {
        VStack {
            Text("The picture is what gives it its purpose, so it goes in the initializer - "
                + "and it can be drawn once per theme, like any other, which is what these "
                + "two are.")
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
