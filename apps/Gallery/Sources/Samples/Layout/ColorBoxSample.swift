import StateUI

/// Rectangles of colour - square, rounded, round and faded - and a divider.
struct ColorBoxSample: SampleContent, ExampleContent {
    static let id = "colorBox"
    static let title = "ColorBox"
    static let summary = "A rectangle of colour - the simplest thing a host draws."

    static let code = """
        VStack {
            HStack {
                ColorBox(Palette.accent)
                    .width(44)
                    .height(44)

                ColorBox(Palette.accent)
                    .cornerRadius(10)
                    .width(44)
                    .height(44)

                ColorBox(Palette.accent)
                    .cornerRadius(22)
                    .width(44)
                    .height(44)

                ColorBox(Color.fromArgb("#E53935"))
                    .cornerRadius(10)
                    .opacity(0.4)
                    .width(44)
                    .height(44)
            }

            // A one-pixel ColorBox is also the usual divider.
            ColorBox(Palette.outline)
                .height(1)
        }
        """

    var content: any View {
        VStack {
            HStack {
                ColorBox(Palette.accent)
                    .width(44)
                    .height(44)

                ColorBox(Palette.accent)
                    .cornerRadius(10)
                    .width(44)
                    .height(44)

                ColorBox(Palette.accent)
                    .cornerRadius(22)
                    .width(44)
                    .height(44)

                ColorBox(Color.fromArgb("#E53935"))
                    .cornerRadius(10)
                    .opacity(0.4)
                    .width(44)
                    .height(44)
            }
            .spacing(12)
            .horizontalAlignment(.center)

            ColorBox(Palette.outline)
                .height(1)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("A ColorBox draws the colour its initializer takes, which is its `.color`. "
            + "`.background` is a second surface behind it that the corner radius "
            + "does not round. A one-pixel ColorBox is also the usual divider.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
