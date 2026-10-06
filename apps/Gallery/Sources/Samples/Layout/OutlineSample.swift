import StateUI

/// A layout's own box: its background and its outline on the shape it names, and what it holds cut to that shape.
struct OutlineSample: SampleContent, ExampleContent {
    // listing: OutlineSample
    @State private var clips = true
    // listing: end

    static let id = "outline"
    static let title = "Shape and outline"
    static let summary = "A stack, a grid or a ZStack paints its own background and outline, in the shape you give it."

    // listing: OutlineSample
    var body: some View {
        VStack {
            VStack {
                Text("A column")
                    .fontSize(15)
                Text("rounded, with a hairline")
                    .fontSize(13)
                    .textColor(Palette.subtle)
            }
            .spacing(2)
            .padding(16)
            .stroke(Palette.outline)
            .lineWidth(1)
            .shape(.roundedRectangle(12))

            HStack {
                Text("A row,")
                    .fontSize(15)
                Text("square and thicker")
                    .fontSize(15)
            }
            .spacing(6)
            .padding(16)
            .stroke(Palette.accent)
            .lineWidth(3)
            .shape(.rectangle)

            // The box fills the ZStack; its corners are cut only while the
            // ZStack clips what it holds.
            ZStack {
                Text("An ellipse")
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
    // listing: end

    var notes: (any View)? {
        Text("The shape is `.rectangle`, `.roundedRectangle(radius)` or `.ellipse`: the layout's background is "
            + "painted to it and its outline follows it. `.clipsContent(true)` cuts what the layout holds to it too.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
