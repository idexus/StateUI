import StateUI

/// A color chosen in the platform's own picker, which a swatch wears through the same state.
struct ColorPickerSample: SampleContent, ExampleContent {
    // listing: ColorPickerSample
    @State private var tint = Color.steelBlue
    @State private var seeThrough = false
    @State private var changes = 0
    // listing: end

    static let id = "colorPicker"
    static let title = "ColorPicker"
    static let summary = "A color chosen in the platform's own picker."

    // listing: ColorPickerSample
    var body: some View {
        VStack {
            ColorPicker($tint)
                .choosesOpacity(seeThrough)
                .accessibilityLabel("Tint")
                .horizontalAlignment(.center)
                .onColorChanged { _ in changes += 1 }

            // The swatch wears the same state: the color chosen reaches it
            // with no render of this view.
            Rectangle()
                .fill($tint)
                .cornerRadius(12)
                .height(80)

            Text("Changed \(changes) time\(changes == 1 ? "" : "s")")
                .fontSize(14)
                .horizontalTextAlignment(.center)

            SwitchRow("Chooses opacity", $seeThrough)

            // A color the program writes is shown, and heard by nobody: the
            // count stays where it is.
            Button("Back to steel blue")
                .horizontalAlignment(.center)
                .onClicked { tint = .steelBlue }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? { nil }
}
