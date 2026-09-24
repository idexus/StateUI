import StateUI

/// A layout's own box: its background and its outline on the shape it names, and what it holds cut to that shape.
struct OutlineSample: SampleContent, ExampleContent {
    @State private var clips = true

    static let id = "outline"
    static let title = "Shape and outline"
    static let summary = "A stack, a grid or a ZStack paints its own background and outline, in the shape you give it."

    static let code = """
        @State private var clips = true

        VStack {
            VStack {
                Label("A column")
                Label("rounded, with a hairline")
            }
            .padding(16)
            .stroke(Palette.outline)
            .strokeWidth(1)
            .shape(.roundedRectangle(12))

            HStack {
                Label("A row,")
                Label("square and thicker")
            }
            .spacing(6)
            .padding(16)
            .stroke(Palette.accent)
            .strokeWidth(3)
            .shape(.rectangle)

            ZStack {
                Label("An ellipse")
            }
            .padding(24)
            .stroke(Palette.accent)
            .shape(.ellipse)

            // The box fills the ZStack; its corners are cut only while the
            // ZStack clips what it holds.
            ZStack {
                ColorBox(Palette.accent)
            }
            .shape(.roundedRectangle(24))
            .clipsContent(clips)
            .height(60)

            SwitchRow("Cut what it holds", $clips)
        }
        """

    var content: any View {
        VStack {
            VStack {
                Label("A column")
                    .fontSize(15)
                Label("rounded, with a hairline")
                    .fontSize(13)
                    .textColor(Palette.subtle)
            }
            .spacing(2)
            .padding(16)
            .stroke(Palette.outline)
            .strokeWidth(1)
            .shape(.roundedRectangle(12))

            HStack {
                Label("A row,")
                    .fontSize(15)
                Label("square and thicker")
                    .fontSize(15)
            }
            .spacing(6)
            .padding(16)
            .stroke(Palette.accent)
            .strokeWidth(3)
            .shape(.rectangle)

            ZStack {
                Label("An ellipse")
                    .fontSize(15)
                    .horizontalAlignment(.center)
                    .verticalAlignment(.center)
            }
            .padding(24)
            .stroke(Palette.accent)
            .shape(.ellipse)

            ZStack {
                ColorBox(Palette.accent)
            }
            .shape(.roundedRectangle(24))
            .clipsContent(clips)
            .height(60)

            SwitchRow("Cut what it holds", $clips)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The shape is `.rectangle`, `.roundedRectangle(radius)` or `.ellipse`: the layout's background is "
            + "painted to it and its outline follows it. `.clipsContent(true)` cuts what the layout holds to it too.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
