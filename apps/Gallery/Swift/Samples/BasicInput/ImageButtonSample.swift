import StateUI

/// MAUI: ImageButton.
struct ImageButtonSample: SampleContent {
    @State private var taps = 0
    @State private var pressed = false

    static let id = "imageButton"
    static let title = "ImageButton"
    static let summary = "A button whose caption is a picture - with a border, a corner radius and a pressed state."

    static let code = """
        @State private var taps = 0
        @State private var pressed = false

        VStack {
            HStack {
                ImageButton(light: "nav_media.png", dark: "nav_media_dark.png")
                    .aspect(.aspectFit)
                    .widthRequest(64)
                    .heightRequest(64)
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .cornerRadius(12)
                    .onClicked { taps += 1 }
                    .onPressed { pressed = true }
                    .onReleased { pressed = false }

                ImageButton(light: "nav_layout.png", dark: "nav_layout_dark.png")
                    .aspect(.aspectFit)
                    .widthRequest(64)
                    .heightRequest(64)
                    .cornerRadius(32)
                    .onClicked { taps += 1 }
            }

            Label(pressed ? "Held down" : "Tapped \\(taps) time\\(taps == 1 ? "" : "s")")
        }
        """

    var content: Element {
        VStack {
            HStack {
                ImageButton(light: "nav_media.png", dark: "nav_media_dark.png")
                    .aspect(.aspectFit)
                    .widthRequest(64)
                    .heightRequest(64)
                    .padding(12)
                    .borderColor(Palette.outline)
                    .borderWidth(1)
                    .cornerRadius(12)
                    .onClicked { taps += 1 }
                    .onPressed { pressed = true }
                    .onReleased { pressed = false }

                ImageButton(light: "nav_layout.png", dark: "nav_layout_dark.png")
                    .aspect(.aspectFit)
                    .widthRequest(64)
                    .heightRequest(64)
                    .padding(12)
                    .backgroundColor(Palette.accent)
                    .cornerRadius(32)
                    .onClicked { taps += 1 }
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label(pressed ? "Held down" : "Tapped \(taps) time\(taps == 1 ? "" : "s")")
                .fontSize(14)
                .horizontalOptions(.center)

            Label("The picture is what gives it its purpose, so it goes in the initializer - "
                + "and it can be drawn once per theme, like any other, which is what these "
                + "two are.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("Not an Image with a tap recognizer on it: that gives no pressed state, no "
                + "border and no corner radius. MAUI's ImageButton is a Button with a Source "
                + "instead of Text.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
