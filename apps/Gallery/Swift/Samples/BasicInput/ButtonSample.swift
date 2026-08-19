import StateUI

/// MAUI: Button.
struct ButtonSample: SampleContent {
    @State private var counter = 0

    static let id = "button"
    static let title = "Button"
    static let summary = "A tappable button, and the three events MAUI gives it."

    static let code = """
        @State private var counter = 0

        VStack {
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

        // Also .onPressed and .onReleased, named after MAUI's own events.
        """

    var content: Element {
        VStack {
            Button("Increment")
                .backgroundColor(Palette.accent)
                .textColor(.white)
                .cornerRadius(8)
                .padding(20, 10)
                .horizontalOptions(.center)
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
                .horizontalOptions(.center)
                .onClicked { counter += 1 }

            Button("Disabled")
                .isEnabled(false)
                .padding(20, 10)
                .horizontalOptions(.center)

            Label("Also .onPressed and .onReleased, named after MAUI's own events.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
