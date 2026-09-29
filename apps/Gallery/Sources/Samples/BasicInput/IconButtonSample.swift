import StateUI

/// Two buttons whose content is an icon, each drawn once per theme.
struct IconButtonSample: SampleContent, ExampleContent {
    @State private var taps = 0
    @State private var pressed = false

    static let id = "iconButton"
    static let title = "Icon button"
    static let summary = "A button whose content is an icon - with an outline, a rounded shape and a pressed state."

    static let code = """
        @State private var taps = 0
        @State private var pressed = false

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

            Label(pressed ? "Held down" : "Tapped \\(taps) time\\(taps == 1 ? "" : "s")")
        }
        """

    var content: any View {
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

            Label(pressed ? "Held down" : "Tapped \(taps) time\(taps == 1 ? "" : "s")")
                .fontSize(14)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        VStack {
            Label("The picture is what gives it its purpose, so it goes in the initializer - "
                + "and it can be drawn once per theme, like any other, which is what these "
                + "two are.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("It is a button, not an `Image` with a tap recognizer on it: that gives no "
                + "pressed state, no outline and no shape.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
