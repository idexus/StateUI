import StateUI

/// MAUI: Switch.
struct SwitchSample: SampleContent {
    @State private var soundOn = true
    @State private var said = "not thrown yet"

    static let id = "switch"
    static let title = "Switch"
    static let summary = "An on/off toggle, reported as the value it now has."

    static let code = """
        @State private var soundOn = true
        @State private var said = "not thrown yet"

        VStack {
            HStack {
                Label("Sound")
                    .verticalOptions(.center)

                Switch($soundOn)
                    // Runs beside the binding's write-back, carrying what the
                    // switch NOW is rather than what this side guessed.
                    .onToggled { on in said = on ? "thrown on" : "thrown off" }
            }

            Label(soundOn ? "on" : "off")
            Label(said)
        }
        """

    var example: Element {
        VStack {
            HStack {
                Label("Sound")
                    .fontSize(16)
                    .verticalOptions(.center)

                Switch($soundOn)
                    .onColor(Palette.accent)
                    .offColor(Palette.outline)
                    .onToggled { on in said = on ? "thrown on" : "thrown off" }
            }
            .spacing(12)
            .horizontalOptions(.center)

            Label(soundOn ? "on" : "off")
                .fontSize(15)
                .horizontalTextAlignment(.center)

            Label(said)
                .fontSize(12)
                .textColor(Palette.subtle)
                .horizontalTextAlignment(.center)
        }
        .spacing(12)
    }

    var notes: Element? {
        Label("The event carries MAUI's ToggledEventArgs.Value, so the binding is "
            + "written with what the switch now is - not with what this side guessed.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
