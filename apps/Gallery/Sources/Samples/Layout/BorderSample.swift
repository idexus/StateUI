import StateUI

/// One view with a stroke around it: rounded, square and elliptical.
struct BorderSample: SampleContent, ExampleContent {
    static let id = "border"
    static let title = "Border"
    static let summary = "One view with a stroke around it, in the shape you give it."

    static let code = """
        VStack {
            Border {
                Label("Rounded")
                    .padding(16)
            }
            .stroke(Palette.outline)
            .strokeWidth(1)
            .shape(.roundedRectangle(12))

            Border {
                Label("Square, thicker, coloured")
                    .padding(16)
            }
            .stroke(Palette.accent)
            .strokeWidth(3)
            .shape(.rectangle)

            Border {
                Label("Ellipse")
                    .padding(24)
            }
            .stroke(Palette.accent)
            .strokeWidth(1)
            .shape(.ellipse)
        }
        """

    var content: any View {
        VStack {
            Border {
                Label("Rounded")
                    .fontSize(15)
                    .padding(16)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.outline)
            .strokeWidth(1)
            .shape(.roundedRectangle(12))

            Border {
                Label("Square, thicker, coloured")
                    .fontSize(15)
                    .padding(16)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeWidth(3)
            .shape(.rectangle)

            Border {
                Label("Ellipse")
                    .fontSize(15)
                    .padding(24)
                    .horizontalTextAlignment(.center)
            }
            .stroke(Palette.accent)
            .strokeWidth(1)
            .shape(.ellipse)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The shape is `.rectangle`, `.roundedRectangle(radius)` or `.ellipse`, and the "
            + "border's own background is painted to it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
