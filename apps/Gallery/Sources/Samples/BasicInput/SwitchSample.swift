import StateUI

/// A switch bound to a flag, reporting each flip as the value it now has.
struct SwitchSample: SampleContent, ExampleContent {
    @State private var soundOn = true
    @State private var said = "not thrown yet"

    static let id = "switch"
    static let title = "Switch"
    static let summary = "An on/off toggle, reported as the value it now has."

    static let code = """
        @State private var soundOn = true
        @State private var said = "not thrown yet"

        VStack {
            // The flag is read here, so every flip builds this closure.
            DebugInfoLabel()

            HStack {
                Label("Sound")
                    .verticalAlignment(.center)

                Switch($soundOn)
                    // Runs beside the binding's write-back, carrying what the
                    // switch NOW is rather than what this side guessed.
                    .onToggled { on in said = on ? "thrown on" : "thrown off" }
            }

            Label(soundOn ? "on" : "off")
            Label(said)
        }
        """

    var content: any View {
        VStack {
            DebugInfoLabel()

            HStack {
                Label("Sound")
                    .fontSize(16)
                    .verticalAlignment(.center)

                Switch($soundOn)
                    .accessibilityIdentifier("switch.sound")
                    .accessibilityLabel("Sound on")
                    .tint(Palette.accent)
                    .onToggled { on in said = on ? "thrown on" : "thrown off" }
            }
            .spacing(12)
            .horizontalAlignment(.center)

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
        Label("`.onToggled` carries the value the switch now has, and runs after the "
            + "binding has written it - so both hold what the switch is, not what this "
            + "side guessed.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
