import StateUI

/// MAUI: Switch.
struct SwitchSample: SampleContent {
    @State private var soundOn = true

    static let id = "switch"
    static let title = "Switch"
    static let summary = "An on/off toggle, reported as the value it now has."

    static let code = """
        @State private var soundOn = true

        VStack {
            HStack {
                Label("Sound")
                    .verticalOptions(.center)

                Switch($soundOn)
            }

            Label(soundOn ? "on" : "off")
        }
        """

    var content: Element {
        VStack {
            HStack {
                Label("Sound")
                    .fontSize(16)
                    .verticalOptions(.center)

                Switch($soundOn)
                    .onColor(Palette.accent)
                    .offColor(Palette.outline)
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label(soundOn ? "on" : "off")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Label("The event carries MAUI's ToggledEventArgs.Value, so the binding is "
                + "written with what the switch now is - not with what this side guessed.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }
}
