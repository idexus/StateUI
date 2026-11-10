import StateUI

/// A button wired to a click, above an outlined one, a disabled one and one whose long words wrap.
struct ButtonSample: SampleContent, ExampleContent {
    // listing: ButtonSample
    @State private var counter = 0
    @State private var wraps = true
    // listing: end

    static let id = "button"
    static let title = "Button"
    static let summary = "A tappable button wired to a click, with an outlined "
        + "one, a disabled one and one whose long words wrap below it."

    // listing: ButtonSample
    var body: some View {
        VStack {
            // The count is read here, so a click builds this closure again.
            DebugInfoLabel()

            Button("Increment")
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            Text("Clicked \(counter) time(s)")
                .horizontalTextAlignment(.center)

            Button("Outlined")
                .background(.transparent)
                .textColor(Palette.accent)
                .stroke(Palette.accent)
                .lineWidth(1)
                .shape(.capsule)   // listing: keep
                .padding(horizontal: 20, vertical: 10)
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            Button("Disabled")
                .isEnabled(false)
                .horizontalAlignment(.center)

            Switch("Wrap the long words", isOn: $wraps)
                .horizontalAlignment(.center)

            // Wrapped, the words stand on as many lines as the width leaves them; else they are cut short.
            Button("Words enough to stand on more than one line")
                .lineBreak(wraps ? .wordWrap : .tailTruncation)
                .width(180)
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }
        }
        .spacing(12)
    }
    // listing: end

    var notes: (any View)? { nil }
}
