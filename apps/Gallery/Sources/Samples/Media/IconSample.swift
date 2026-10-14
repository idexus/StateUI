import StateUI

/// The platform's own icons by their meaning, and a picture the application makes as bytes.
struct IconSample: SampleContent, ExampleContent {
    static let id = "icons"
    static let title = "Icons"
    static let summary = "The platform's own icons by their meaning, and a picture made as bytes."

    // listing: IconSample
    /// The hue of the picture the application makes.
    @State private var hue = 0.6

    var body: some View {
        VStack {
            Grid {
                ForEach(Array(Icon.allCases.enumerated()), id: \.offset) { place, icon in
                    VStack {
                        Image(.icon(icon))
                            .width(24)
                            .height(24)
                            .horizontalAlignment(.center)

                        Text("\(icon)")
                            .textStyle(.caption)
                            .horizontalTextAlignment(.center)
                    }
                    .spacing(4)
                    .gridColumn(place % 4)
                    .gridRow(place / 4)
                }
            }
            .columns(.fill(count: 4))
            .rows(.auto(count: 8))
            .rowSpacing(12)

            SectionTitle("In the button's colour")

            HStack {
                Button("Share")
                    .icon(.icon(.share))

                Button("Delete")
                    .icon(.icon(.delete))
                    .role(.destructive)

                Button(icon: .icon(.settings))
                    .accessibilityLabel("Settings")
            }
            .spacing(12)

            SectionTitle("Made as bytes")

            HStack {
                // Four pixels a point, shown as large as the icons above.
                Image(ImageSource(bytes: MadePicture.rings(side: 96, hue: hue)))
                    .width(24)
                    .height(24)
                    .verticalAlignment(.center)

                Button("Make another")
                    .onClicked { hue = (hue + 0.17).truncatingRemainder(dividingBy: 1) }
                    .verticalAlignment(.center)
            }
            .spacing(12)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Each icon is the platform's own, in the colour of what holds it; press Make another for new bytes.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
