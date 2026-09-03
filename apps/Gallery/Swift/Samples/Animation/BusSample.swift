import StateUI

/// A value both sides hold, moved by the host and read by arithmetic that
/// describes nothing.
struct BusSample: SampleContent {
    /// Where the marker sits - the value the HOST carries.
    @Bus private var offset = AnimatedValue(0.0)

    /// What the reading says, which an engine works out from the marker.
    @Bus private var reading = "0%"

    /// The rail's colour, which the HOST carries with no engine at all.
    @Bus private var tint = AnimatedValue(Palette.outline)

    @State private var slowly = false

    static let id = "bus"
    static let title = "A value on a bus"
    static let summary = "A value the host moves, and arithmetic that follows it every frame."

    /// How far the marker may travel - the rail's width less its own.
    private static let run = 240.0

    static let code = """
        @Bus private var offset = AnimatedValue(0.0)
        @Bus private var reading = "0%"
        @Bus private var tint = AnimatedValue(Palette.outline)

        @State private var slowly = false

        // How often this view has been described.
        let info = debugInfo()

        VStack {
            Label(info).textColor(Palette.accent)

            Grid {
                BoxView()
                    .color($tint)
                    .heightRequest(6)
                    .verticalOptions(.center)

                BoxView()
                    .color(Palette.brand)
                    .widthRequest(20)
                    .heightRequest(20)
                    .horizontalOptions(.start)
                    .translationX($offset)
            }
            .widthRequest(260)
            .heightRequest(28)

            Label().text($reading)

            HStack {
                Button("Empty").onClicked { go(to: 0) }
                Button("Half").onClicked { go(to: 0.5) }
                Button("Full").onClicked { go(to: 1) }
            }

            SwitchRow("Take the long way", $slowly)
        }
        .engine(following: $offset) { _ in
            reading = "\\(Int((offset.value / 240 * 100).rounded()))%"
        }

        /// One place to be sent to, under whichever law the switch asks for.
        private func go(to place: Double) {
            let law: Motion = slowly ? .eased(1600, .cubicInOut) : .eased(350, .cubicOut)

            offset.motion = law
            offset.setPoint = 240 * place

            tint.motion = law
            tint.setPoint = place > 0 ? Palette.accent : Palette.outline
        }
        """

    var content: Element {
        // How often this view has been described, read where a reading goes.
        // It is the whole point of the page: tap anything and watch the count
        // stand still while the marker crosses.
        let info = debugInfo()

        return VStack {
            Label(info)
                .fontSize(12)
                .textColor(Palette.accent)
                .horizontalOptions(.start)

            Border {
                Grid {
                    BoxView()
                        .color($tint)
                        .heightRequest(6)
                        .cornerRadius(3)
                        .verticalOptions(.center)

                    BoxView()
                        .color(Palette.brand)
                        .widthRequest(20)
                        .heightRequest(20)
                        .cornerRadius(10)
                        .horizontalOptions(.start)
                        .verticalOptions(.center)
                        .translationX($offset)
                }
                .widthRequest(260)
                .heightRequest(28)
            }
            .padding(16)
            .backgroundColor(Palette.surface)
            .stroke(.transparent)
            .strokeShape(.roundRectangle(12))
            .horizontalOptions(.center)

            Label()
                .text($reading)
                .fontSize(28)
                .fontAttributes(.bold)
                .horizontalOptions(.center)

            HStack {
                button("Empty") { go(to: 0) }
                button("Half") { go(to: 0.5) }
                button("Full") { go(to: 1) }
            }
            .spacing(8)
            .horizontalOptions(.center)

            SwitchRow("Take the long way", $slowly)
        }
        .spacing(12)
        .engine(following: $offset) { _ in
            reading = "\(Int((offset.value / Self.run * 100).rounded()))%"
        }
    }

    var notes: Element? {
        VStack {
            Label("A `@Bus` is a value both sides hold, and a property wears one the "
                + "way it wears a value: `.translationX($offset)`, `.color($tint)`. "
                + "Give the bus a setpoint from a handler - `offset.setPoint = 240` "
                + "under `offset.motion` - and the HOST carries the property there on "
                + "the display's own frames. Nothing is described on the way.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.engine(following: $offset)` runs on that same frame whenever a "
                + "bus it follows has moved, and writes buses of its own - so the "
                + "reading follows the marker the whole way across. The line at the "
                + "top is `debugInfo()`, which names how many times this view has been "
                + "described: press every button, throw the switch, watch the marker "
                + "cross and the percentage count up, and it stays at ONE. Nothing on "
                + "this page is described from a value that moves.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("An `AnimatedValue` holds three things: `value` is where it IS, "
                + "`setPoint` where it is GOING, and `velocity` how fast. Writing the "
                + "setpoint asks the host for a journey; writing `value` puts it there "
                + "at once, which is what arithmetic worked out per frame does. A "
                + "`Label().text($reading)` is written only when the letters actually "
                + "change, so a reading that rounds to the same number costs nothing.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The marker MOVES rather than resizing: a translation is a drawing "
                + "field and costs nothing, while a width written per frame measures "
                + "the layout again every time. It is the same rule wherever a value "
                + "moves quickly - reach for the transform.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(12)
    }

    /// One place to be sent to, under whichever law the switch asks for.
    private func go(to place: Double) {
        let law: Motion = slowly ? .eased(1600, .cubicInOut) : .eased(350, .cubicOut)

        offset.motion = law
        offset.setPoint = Self.run * place

        tint.motion = law
        tint.setPoint = place > 0 ? Palette.accent : Palette.outline
    }

    /// One of the buttons, all of which look the same.
    private func button(_ caption: String, _ act: @escaping EventHandler) -> Button {
        Button(caption)
            .fontSize(13)
            .padding(14, 6)
            .onClicked(act)
    }
}
