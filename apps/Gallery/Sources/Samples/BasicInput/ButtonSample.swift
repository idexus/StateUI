import StateUI

/// A button wired to a click, above an outlined one and a disabled one.
struct ButtonSample: SampleContent, ExampleContent {
    // listing: ButtonSample
    @State private var counter = 0
    // listing: end

    static let id = "button"
    static let title = "Button"
    static let summary = "A tappable button wired to a click, with an outlined "
        + "and a disabled one below it."

    // listing: ButtonSample
    var body: some View {
        VStack {
            // The count is read here, so a click builds this closure again.
            DebugInfoLabel()

            Button("Increment")
                .background(Palette.accent)
                .textColor(.white)
                .shape(.roundedRectangle(8))
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            Text("Clicked \(counter) time(s)")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Button("Outlined")
                .background(.transparent)
                .textColor(Palette.accent)
                .stroke(Palette.accent)
                .lineWidth(1)
                .shape(.roundedRectangle(8))
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            Button("Disabled")
                .isEnabled(false)
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? {
        Text("Also `.onPressed` and `.onReleased`, for the moment the button goes "
            + "down and comes up.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
