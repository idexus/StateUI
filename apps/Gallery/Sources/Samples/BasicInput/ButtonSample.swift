import StateUI

/// A button wired to a click, beside an outlined one and a disabled one.
struct ButtonSample: SampleContent, ExampleContent {
    @State private var counter = 0

    static let id = "button"
    static let title = "Button"
    static let summary = "A tappable button wired to a click, with an outlined "
        + "and a disabled one beside it."

    static let code = """
        @State private var counter = 0

        VStack {
            // The count is read here, so a click builds this closure again.
            DebugInfoLabel()

            Button("Increment")
                .onClicked { counter += 1 }

            Label("Clicked \\(counter) time(s)")

            Button("Outlined")
                .backgroundColor(.transparent)
                .borderColor(Palette.accent)
                .borderWidth(1)
                .onClicked { counter += 1 }

            Button("Disabled")
                .isEnabled(false)
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            Button("Increment")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            Label("Clicked \(counter) time(s)")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Button("Outlined")
                .backgroundColor(.transparent)
                .textColor(Palette.accent)
                .borderColor(Palette.accent)
                .borderWidth(1)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalAlignment(.center)
                .onClicked { counter += 1 }

            Button("Disabled")
                .isEnabled(false)
                .padding(20, 10)
                .horizontalAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("Also `.onPressed` and `.onReleased`, for the moment the button goes "
            + "down and comes up.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
