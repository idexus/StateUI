import StateUI

/// MAUI: Border.
struct BorderSample: SampleContent {
    static let id = "border"
    static let title = "Border"
    static let summary = "One view with a stroke around it, in the shape XAML writes."

    static let code = """
        VStack {
            Border {
                Label("Rounded")
                    .padding(16)
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(12))

            Border {
                Label("Square, thicker, coloured")
                    .padding(16)
            }
            .stroke(Palette.accent)
            .strokeThickness(3)
            .strokeShape(.rectangle)

            Border {
                Label("Ellipse")
                    .padding(24)
            }
            .stroke(Palette.accent)
            .strokeThickness(1)
            .strokeShape(.ellipse)
        }
        """

    var content: Element {
        VStack {
            Border {
                Label("Rounded")
                    .fontSize(15)
                    .padding(16)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.outline)
            .strokeThickness(1)
            .strokeShape(.roundRectangle(12))

            Border {
                Label("Square, thicker, coloured")
                    .fontSize(15)
                    .padding(16)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeThickness(3)
            .strokeShape(.rectangle)

            Border {
                Label("Ellipse")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeThickness(1)
            .strokeShape(.ellipse)

            Label("The shape travels as \"RoundRectangle 12\" - what XAML writes and what "
                + "MAUI's own converter reads. A second implementation of a format MAUI "
                + "already parses is a second thing to keep in step.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
